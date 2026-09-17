import 'package:sqflite/sqflite.dart';
import 'package:untitled2/database.dart';
import 'package:untitled2/model/invoice.dart';
import 'package:untitled2/model/product.dart';

/// يُرمى عندما يحاول المستخدم بيع كمية أكبر من المتاح فعلياً في
/// المخزون. يُتحقَّق منه داخل نفس الـ Transaction (وليس فقط من
/// الواجهة) حتى لا يصبح المخزون سالباً بسبب خطأ بالواجهة أو تلاعب.
class InsufficientStockException implements Exception {
  final String productName;
  final int available;
  final int requested;
  InsufficientStockException(this.productName, this.available, this.requested);

  @override
  String toString() =>
      'الكمية المتوفرة من "$productName" غير كافية (المتوفر: $available، المطلوب: $requested)';
}

class InvalidPaymentException implements Exception {
  final String message;
  InvalidPaymentException(this.message);
  @override
  String toString() => message;
}

class InvoiceController {
  final table = "invoices";
  final itemsTable = "invoice_items";
  final paymentsTable = "payments";

  /// ينشئ فاتورة بيع كاملة داخل Transaction واحدة:
  /// 1) يتحقق من توفر المخزون الفعلي لكل صنف (من قاعدة البيانات
  ///    مباشرة، وليس فقط مما هو ظاهر بالواجهة)
  /// 2) يضيف صف الفاتورة
  /// 3) يضيف كل صنف كسطر منفصل في invoice_items (Snapshot للسعر
  ///    والتكلفة والاسم وقت البيع)
  /// 4) يخصم الكمية المباعة من مخزون كل منتج
  /// 5) يسجّل دفعة في جدول payments إذا كان المبلغ المدفوع > 0
  /// إن فشلت أي خطوة (مثل نقص مخزون) تُلغى كل الخطوات معاً تلقائياً
  /// (Transaction) ولا تُنشأ فاتورة ناقصة ولا يُخصم مخزون بلا فاتورة.
  ///
  /// [cartItems] عناصر السلة كما هي في CartService: كل عنصر
  /// ProductModel حيث `stock` يمثّل هنا الكمية المُباعة من هذا الصنف.
  Future<int> createInvoice({
    required List<ProductModel> cartItems,
    int? customerId,
    String customerName = 'عميل نقدي',
    String paymentMethod = 'نقدي',
    required PaymentStatus paymentStatus,
    required double paidAmount,
  }) async {
    if (cartItems.isEmpty) {
      throw InvalidPaymentException('لا يمكن حفظ فاتورة بدون أصناف');
    }

    final double total =
        cartItems.fold(0.0, (sum, i) => sum + (i.sellingPrice * i.stock));
    if (paidAmount < 0) {
      throw InvalidPaymentException('المبلغ المدفوع لا يمكن أن يكون سالباً');
    }
    // لا نسمح بدفع أكبر من إجمالي الفاتورة (Paid > Total) إلا إذا
    // كانت الحالة "مدفوعة بالكامل"، وفي هذه الحالة نقصّه إلى Total
    // تلقائياً بدل رفض العملية بالكامل.
    double normalizedPaid = paidAmount;
    if (normalizedPaid > total) {
      normalizedPaid = total;
    }
    // الحالة يجب أن تتوافق منطقياً مع المبلغ المدفوع كي لا تتضارب
    // البيانات (فاتورة "مدفوعة" لكن Paid < Total مثلاً).
    if (paymentStatus == PaymentStatus.paid && normalizedPaid < total) {
      normalizedPaid = total;
    } else if (paymentStatus == PaymentStatus.unpaid) {
      normalizedPaid = 0;
    }

    // فاتورة آجلة أو جزئية يجب أن تكون مرتبطة بعميل حقيقي (customer_id)
    // وليس فقط اسماً نصياً.
    if (paymentStatus != PaymentStatus.paid && customerId == null) {
      throw InvalidPaymentException(
          'الفواتير الآجلة أو الجزئية تتطلب اختيار عميل مسجَّل');
    }

    final double cost =
        cartItems.fold(0.0, (sum, i) => sum + (i.costPrice * i.stock));
    final double profit = total - cost;
    final String now = DateTime.now().toIso8601String();

    return DatabaseService.instance.runTransaction<int>((txn) async {
      // 1) تحقق حقيقي من المخزون داخل نفس المعاملة (يمنع أي احتمال
      // لبيع أكثر من المتوفر بسبب تأخر تحديث الواجهة أو عمليتي بيع
      // متزامنتين لنفس المنتج).
      for (final item in cartItems) {
        if (item.id == null) continue;
        final rows = await txn.query('products',
            columns: ['stock', 'name'], where: 'id = ?', whereArgs: [item.id]);
        if (rows.isEmpty) {
          throw InsufficientStockException(item.name, 0, item.stock);
        }
        final int available = (rows.first['stock'] as num).toInt();
        if (item.stock > available) {
          throw InsufficientStockException(
              rows.first['name'] as String, available, item.stock);
        }
      }

      final invoiceId = await txn.insert(table, {
        'customer_id': customerId,
        'customer_name': customerName,
        'total': total,
        'cost': cost,
        'profit': profit,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus.dbValue,
        'paid_amount': normalizedPaid,
        'created_at': now,
      });

      for (final item in cartItems) {
        await txn.insert(itemsTable, {
          'invoice_id': invoiceId,
          'product_id': item.id,
          'name': item.name,
          'qty': item.stock,
          'price': item.sellingPrice,
          'cost': item.costPrice,
        });

        if (item.id != null) {
          // شرط SQL إضافي (WHERE stock >= qty) كحاجز أخير يمنع نهائياً
          // وصول المخزون لقيمة سالبة حتى تحت التزامن.
          final affected = await txn.rawUpdate(
            'UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?',
            [item.stock, item.id, item.stock],
          );
          if (affected == 0) {
            throw InsufficientStockException(item.name, 0, item.stock);
          }
        }
      }

      if (normalizedPaid > 0) {
        await txn.insert(paymentsTable, {
          'invoice_id': invoiceId,
          'customer_id': customerId,
          'amount': normalizedPaid,
          'payment_method': paymentMethod,
          'payment_date': now,
          'notes': 'دفعة عند إنشاء الفاتورة',
        });
      }

      return invoiceId;
    });
  }

  /// جلب الفواتير (الأحدث أولاً) مع إمكانية الفلترة بحالة الدفع
  /// أو البحث باسم/هاتف العميل. لا يحمّل الأصناف لتبقى القائمة سريعة؛
  /// استخدم [getById] لتفاصيل فاتورة واحدة عند الحاجة.
  Future<List<InvoiceModel>> getAll({
    PaymentStatus? status,
    String? searchCustomer,
    int? customerId,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (status != null) {
      where.add('payment_status = ?');
      args.add(status.dbValue);
    }
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    if (searchCustomer != null && searchCustomer.trim().isNotEmpty) {
      where.add('customer_name LIKE ?');
      args.add('%${searchCustomer.trim()}%');
    }

    final sql = '''
      SELECT * FROM invoices
      ${where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : ''}
      ORDER BY created_at DESC
    ''';

    final rows = await DatabaseService.instance.rawQuery(sql, args);
    return rows.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  Future<InvoiceModel?> getById(int id) async {
    final rows = await DatabaseService.instance.GetById(table, id);
    if (rows.isEmpty) return null;
    final invoice = InvoiceModel.fromMap(rows.first);

    final itemRows = await DatabaseService.instance
        .rawQuery('SELECT * FROM invoice_items WHERE invoice_id = ?', [id]);
    invoice.items = itemRows.map((e) => InvoiceItemModel.fromMap(e)).toList();
    return invoice;
  }

  /// تسجيل دفعة جديدة على فاتورة واحدة (سداد جزئي أو كامل لاحقاً).
  /// يُسجَّل سطر جديد في جدول payments بتاريخه، وتُحدَّث حالة الدفع
  /// على الفاتورة تلقائياً حسب مجموع ما دُفع. كل ذلك داخل Transaction
  /// واحدة حتى لا يحدث تضارب بين جدول الدفعات وحالة الفاتورة.
  Future<void> registerPayment(
    int invoiceId,
    double additionalAmount, {
    String paymentMethod = 'نقدي',
    String? notes,
  }) async {
    if (additionalAmount <= 0) {
      throw InvalidPaymentException('مبلغ الدفعة يجب أن يكون أكبر من صفر');
    }

    await DatabaseService.instance.runTransaction<void>((txn) async {
      final rows = await txn.query(table, where: 'id = ?', whereArgs: [invoiceId]);
      if (rows.isEmpty) {
        throw InvalidPaymentException('الفاتورة غير موجودة');
      }
      final invoice = InvoiceModel.fromMap(rows.first);
      if (invoice.remainingAmount <= 0) {
        throw InvalidPaymentException('هذه الفاتورة مسدَّدة بالكامل بالفعل');
      }

      // لا نسمح بدفعة تتجاوز المتبقي فعلياً على الفاتورة.
      final appliedAmount = additionalAmount > invoice.remainingAmount
          ? invoice.remainingAmount
          : additionalAmount;

      final newPaid = invoice.paidAmount + appliedAmount;
      final status = newPaid >= invoice.total
          ? PaymentStatus.paid
          : (newPaid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid);

      await txn.update(
        table,
        {
          'paid_amount': newPaid > invoice.total ? invoice.total : newPaid,
          'payment_status': status.dbValue,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      await txn.insert(paymentsTable, {
        'invoice_id': invoiceId,
        'customer_id': invoice.customerId,
        'amount': appliedAmount,
        'payment_method': paymentMethod,
        'payment_date': DateTime.now().toIso8601String(),
        'notes': notes,
      });
    });
  }

  /// تسديد دَين عميل بمبلغ واحد يُوزَّع تلقائياً على فواتيره غير
  /// المسدَّدة (الأقدم أولاً/FIFO) حتى ينتهي المبلغ أو تُسدَّد كل
  /// الفواتير. يُستخدم من شاشة "تسديد دفعة" في صفحة العميل عندما لا
  /// يختار المستخدم فاتورة بعينها.
  Future<void> registerCustomerPayment(
    int customerId,
    double amount, {
    String paymentMethod = 'نقدي',
    String? notes,
  }) async {
    if (amount <= 0) {
      throw InvalidPaymentException('مبلغ الدفعة يجب أن يكون أكبر من صفر');
    }
    final outstanding = await DatabaseService.instance.rawQuery(
      '''
      SELECT * FROM invoices
      WHERE customer_id = ? AND payment_status != 'paid'
      ORDER BY created_at ASC
      ''',
      [customerId],
    );
    if (outstanding.isEmpty) {
      throw InvalidPaymentException('لا يوجد على هذا العميل أي مبلغ مستحق');
    }

    double remainingToApply = amount;
    for (final row in outstanding) {
      if (remainingToApply <= 0) break;
      final invoice = InvoiceModel.fromMap(row);
      final due = invoice.remainingAmount;
      if (due <= 0) continue;
      final applied = remainingToApply >= due ? due : remainingToApply;
      await registerPayment(invoice.id!, applied,
          paymentMethod: paymentMethod, notes: notes);
      remainingToApply -= applied;
    }
  }

  /// الفواتير غير المسدَّدة بالكامل.
  Future<List<InvoiceModel>> getOutstanding() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT * FROM invoices
      WHERE payment_status != 'paid'
      ORDER BY created_at ASC
    ''');
    return rows.map((e) => InvoiceModel.fromMap(e)).toList();
  }

  /// عدد العملاء المدينين حالياً (لزر الإشعارات في الرأس).
  Future<int> countDebtCustomers() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT COUNT(DISTINCT customer_id) AS c FROM invoices
      WHERE payment_status != 'paid' AND customer_id IS NOT NULL
    ''');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// ملخّص عميل واحد: إجمالي المشتريات / المدفوع / المتبقي — يُستخدم
  /// في شاشة تفاصيل العميل.
  Future<Map<String, double>> getCustomerSummary(int customerId) async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT COALESCE(SUM(total),0) AS total,
             COALESCE(SUM(paid_amount),0) AS paid,
             COALESCE(SUM(total - paid_amount),0) AS remaining
      FROM invoices WHERE customer_id = ?
    ''', [customerId]);
    final row = rows.first;
    return {
      'total': (row['total'] as num).toDouble(),
      'paid': (row['paid'] as num).toDouble(),
      'remaining': (row['remaining'] as num).toDouble(),
    };
  }

  /// المتبقي على كل عميل له فاتورة واحدة على الأقل، بجلب واحد بدل
  /// استعلام منفصل لكل عميل (أفضل أداءً في شاشة قائمة العملاء).
  Future<Map<int, double>> getAllCustomersRemaining() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT customer_id, COALESCE(SUM(total - paid_amount), 0) AS remaining
      FROM invoices
      WHERE customer_id IS NOT NULL
      GROUP BY customer_id
    ''');
    final map = <int, double>{};
    for (final row in rows) {
      map[row['customer_id'] as int] = (row['remaining'] as num).toDouble();
    }
    return map;
  }

  // ============ إحصائيات الأرباح والتقارير ============

  /// إجمالي المبيعات/الربح/عدد الفواتير ضمن مدى زمني (afterIso شامل).
  Future<Map<String, double>> getTotals({String? afterIso}) async {
    final rows = await DatabaseService.instance.rawQuery(
      '''
      SELECT COALESCE(SUM(total),0) AS total,
             COALESCE(SUM(profit),0) AS profit,
             COUNT(*) AS count
      FROM invoices
      ${afterIso != null ? 'WHERE created_at >= ?' : ''}
      ''',
      afterIso != null ? [afterIso] : null,
    );
    final row = rows.first;
    return {
      'total': (row['total'] as num).toDouble(),
      'profit': (row['profit'] as num).toDouble(),
      'count': (row['count'] as num).toDouble(),
    };
  }

  /// إحصاءات طرق الدفع (نقدي/آجل/جزئي) ضمن مدى زمني.
  Future<List<Map<String, dynamic>>> getPaymentStatusBreakdown(
      {String? afterIso}) async {
    return DatabaseService.instance.rawQuery('''
      SELECT payment_status, COUNT(*) AS count, COALESCE(SUM(total),0) AS total
      FROM invoices
      ${afterIso != null ? 'WHERE created_at >= ?' : ''}
      GROUP BY payment_status
    ''', afterIso != null ? [afterIso] : null);
  }

  /// إجمالي المبالغ المستحقة (غير المحصَّلة) على كل العملاء.
  Future<double> getTotalOutstandingAmount() async {
    final rows = await DatabaseService.instance.rawQuery(
        "SELECT COALESCE(SUM(total - paid_amount),0) AS v FROM invoices WHERE payment_status != 'paid'");
    return (rows.first['v'] as num).toDouble();
  }

  /// أكثر المنتجات مبيعاً (بالكمية) ضمن مدى زمني اختياري — يعتمد على
  /// product_id عند توفره (وليس الاسم فقط) لتجميع أدق.
  Future<List<Map<String, dynamic>>> getTopSellingProducts(
      {int limit = 5, String? afterIso}) async {
    return DatabaseService.instance.rawQuery('''
      SELECT COALESCE(ii.product_id, -ii.id) AS product_id,
             ii.name AS name,
             SUM(ii.qty) AS total_qty,
             SUM(ii.qty * ii.price) AS total_revenue
      FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      ${afterIso != null ? 'WHERE i.created_at >= ?' : ''}
      GROUP BY COALESCE(ii.product_id, ii.name)
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [if (afterIso != null) afterIso, limit]);
  }

  /// أكثر المنتجات ربحاً (بناءً على ما تم بيعه فعلياً من واقع الفواتير)
  /// ضمن مدى زمني اختياري.
  Future<List<Map<String, dynamic>>> getTopProfitableProducts(
      {int limit = 5, String? afterIso}) async {
    return DatabaseService.instance.rawQuery('''
      SELECT COALESCE(ii.product_id, -ii.id) AS product_id,
             ii.name AS name,
             SUM(ii.qty) AS total_qty,
             SUM(ii.qty * ii.price) AS total_revenue,
             SUM(ii.qty * (ii.price - ii.cost)) AS total_profit
      FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      ${afterIso != null ? 'WHERE i.created_at >= ?' : ''}
      GROUP BY COALESCE(ii.product_id, ii.name)
      ORDER BY total_profit DESC
      LIMIT ?
    ''', [if (afterIso != null) afterIso, limit]);
  }

  /// مبيعات مجمَّعة حسب فئة المنتج (category) ضمن مدى زمني — تُستخدم
  /// في الرسم الدائري بشاشة التقارير. المنتجات التي بلا فئة تُجمَّع
  /// تحت "غير مصنّف".
  Future<List<Map<String, dynamic>>> getCategoryBreakdown(
      {String? afterIso}) async {
    return DatabaseService.instance.rawQuery('''
      SELECT COALESCE(NULLIF(TRIM(p.category), ''), 'غير مصنّف') AS category,
             SUM(ii.qty * ii.price) AS total_revenue
      FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      LEFT JOIN products p ON p.id = ii.product_id
      ${afterIso != null ? 'WHERE i.created_at >= ?' : ''}
      GROUP BY category
      ORDER BY total_revenue DESC
    ''', afterIso != null ? [afterIso] : null);
  }

  /// إجمالي المبيعات/الأرباح/عدد الفواتير مجمَّعة يومياً لآخر [days]
  /// يوم — لعرضها كرسم بياني في شاشتي الأرباح والتقارير.
  Future<List<Map<String, dynamic>>> getDailyTotals({int days = 7}) async {
    // نقارن على مستوى التاريخ (YYYY-MM-DD) فقط حتى تبقى المقارنة
    // متوافقة سواء كانت created_at مخزَّنة بصيغة ISO8601 (بها T) أو
    // بصيغة SQLite العادية (بها مسافة).
    return DatabaseService.instance.rawQuery('''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(total), 0) AS total,
             COALESCE(SUM(profit), 0) AS profit,
             COUNT(*) AS invoices
      FROM invoices
      WHERE substr(created_at, 1, 10) >= date('now', ?)
      GROUP BY day
      ORDER BY day ASC
    ''', ['-$days days']);
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:untitled2/database.dart';
import 'package:untitled2/model/invoice.dart';
import 'package:untitled2/model/product.dart';

class InvoiceController {
  final table = "invoices";
  final itemsTable = "invoice_items";

  /// ينشئ فاتورة بيع كاملة داخل Transaction واحدة:
  /// 1) يضيف صف الفاتورة
  /// 2) يضيف كل صنف كسطر منفصل في invoice_items
  /// 3) يخصم الكمية المباعة من مخزون كل منتج
  /// إن فشلت أي خطوة تُلغى كل الخطوات معاً (لا تبقى فاتورة ناقصة).
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
    final double total =
        cartItems.fold(0.0, (sum, i) => sum + (i.sellingPrice * i.stock));
    final double cost =
        cartItems.fold(0.0, (sum, i) => sum + (i.costPrice * i.stock));
    final double profit = total - cost;
    final String now = DateTime.now().toIso8601String();

    return DatabaseService.instance.runTransaction<int>((txn) async {
      final invoiceId = await txn.insert(table, {
        'customer_id': customerId,
        'customer_name': customerName,
        'total': total,
        'cost': cost,
        'profit': profit,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus.dbValue,
        'paid_amount': paidAmount,
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
          await txn.rawUpdate(
            'UPDATE products SET stock = stock - ? WHERE id = ?',
            [item.stock, item.id],
          );
        }
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
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (status != null) {
      where.add('payment_status = ?');
      args.add(status.dbValue);
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

  /// تسجيل دفعة جديدة على فاتورة (سداد جزئي أو كامل لاحقاً) —
  /// تُحدَّث حالة الدفع تلقائياً حسب المبلغ المدفوع الإجمالي.
  Future<void> registerPayment(int invoiceId, double additionalAmount) async {
    final invoice = await getById(invoiceId);
    if (invoice == null) return;

    final newPaid = invoice.paidAmount + additionalAmount;
    final status = newPaid >= invoice.total
        ? PaymentStatus.paid
        : (newPaid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid);

    await DatabaseService.instance.UpdataData(table, invoiceId, {
      'paid_amount': newPaid > invoice.total ? invoice.total : newPaid,
      'payment_status': status.dbValue,
    });
  }

  /// الفواتير غير المسدَّدة بالكامل — الأساس الذي سيُبنى عليه لاحقاً
  /// إرسال تذكير عبر البريد الإلكتروني لكل عميل مدين (EmailService).
  Future<List<InvoiceModel>> getOutstanding() async {
    final rows = await DatabaseService.instance.rawQuery('''
      SELECT * FROM invoices
      WHERE payment_status != 'paid'
      ORDER BY created_at ASC
    ''');
    return rows.map((e) => InvoiceModel.fromMap(e)).toList();
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

  /// إجمالي المبالغ المستحقة (غير المحصَّلة) على كل العملاء.
  Future<double> getTotalOutstandingAmount() async {
    final rows = await DatabaseService.instance.rawQuery(
        "SELECT COALESCE(SUM(total - paid_amount),0) AS v FROM invoices WHERE payment_status != 'paid'");
    return (rows.first['v'] as num).toDouble();
  }

  /// أكثر المنتجات ربحاً (بناءً على ما تم بيعه فعلياً من واقع الفواتير)
  Future<List<Map<String, dynamic>>> getTopProfitableProducts(
      {int limit = 5}) async {
    return DatabaseService.instance.rawQuery('''
      SELECT name,
             SUM(qty) AS total_qty,
             SUM(qty * price) AS total_revenue,
             SUM(qty * (price - cost)) AS total_profit
      FROM invoice_items
      GROUP BY name
      ORDER BY total_profit DESC
      LIMIT ?
    ''', [limit]);
  }

  /// إجمالي المبيعات/الأرباح مجمَّعة يومياً لآخر [days] يوم — لعرضها
  /// كرسم بياني بسيط في شاشة الأرباح.
  Future<List<Map<String, dynamic>>> getDailyTotals({int days = 7}) async {
    // نقارن على مستوى التاريخ (YYYY-MM-DD) فقط حتى تبقى المقارنة
    // متوافقة سواء كانت created_at مخزَّنة بصيغة ISO8601 (بها T) أو
    // بصيغة SQLite العادية (بها مسافة).
    return DatabaseService.instance.rawQuery('''
      SELECT substr(created_at, 1, 10) AS day,
             COALESCE(SUM(total), 0) AS total,
             COALESCE(SUM(profit), 0) AS profit
      FROM invoices
      WHERE substr(created_at, 1, 10) >= date('now', ?)
      GROUP BY day
      ORDER BY day ASC
    ''', ['-$days days']);
  }
}

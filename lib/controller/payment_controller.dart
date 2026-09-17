import 'package:sqflite/sqflite.dart';
import 'package:untitled2/database.dart';

/// دفعة واحدة كما تُخزَّن وتُعرض من جدول payments.
class PaymentModel {
  final int? id;
  final int invoiceId;
  final int? customerId;
  final double amount;
  final String paymentMethod;
  final String paymentDate;
  final String? notes;

  PaymentModel({
    this.id,
    required this.invoiceId,
    this.customerId,
    required this.amount,
    this.paymentMethod = 'نقدي',
    required this.paymentDate,
    this.notes,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int,
      customerId: map['customer_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? 'نقدي',
      paymentDate: map['payment_date'] as String,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate,
      if (notes != null) 'notes': notes,
    };
  }
}

/// ═══════════════════════════════════════════════════════════════
/// PaymentController
/// سجل الدفعات الحقيقي: كل دفعة (كاملة أو جزئية) تُسجَّل كسطر
/// مستقل بتاريخها، بدلاً من الاكتفاء بتعديل paid_amount على
/// الفاتورة مباشرة. هذا يسمح بمعرفة تاريخ كل دفعة على حدة (مثال:
/// 40 يوم 17، ثم 30 يوم 20، ثم 30 يوم 25).
/// لا تُستخدم مباشرة من الواجهات غالباً — InvoiceController هو من
/// ينسّق تسجيل الدفعة + تحديث الفاتورة معاً داخل Transaction واحدة.
/// ═══════════════════════════════════════════════════════════════
class PaymentController {
  final table = 'payments';

  Future<int> insert(PaymentModel p, {Transaction? txn}) async {
    if (txn != null) {
      return txn.insert(table, p.toMap());
    }
    return DatabaseService.instance.insert(table, p.toMap());
  }

  Future<List<PaymentModel>> getByInvoice(int invoiceId) async {
    final rows = await DatabaseService.instance.rawQuery(
        'SELECT * FROM payments WHERE invoice_id = ? ORDER BY payment_date ASC',
        [invoiceId]);
    return rows.map((e) => PaymentModel.fromMap(e)).toList();
  }

  Future<List<PaymentModel>> getByCustomer(int customerId) async {
    final rows = await DatabaseService.instance.rawQuery(
        'SELECT * FROM payments WHERE customer_id = ? ORDER BY payment_date DESC',
        [customerId]);
    return rows.map((e) => PaymentModel.fromMap(e)).toList();
  }
}

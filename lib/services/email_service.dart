import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/model/invoice.dart';

/// ═══════════════════════════════════════════════════════════════
/// EmailService
/// نقطة التوسّع الجاهزة لميزة "إرسال بريد تذكيري لكل العملاء الذين
/// لم يدفعوا". البيانات (من هو مدين وبكم) جاهزة الآن عبر
/// InvoiceController.getOutstanding() — الناقص فقط هو ربط مزوّد
/// بريد فعلي (مثل حزمة `mailer` مع SMTP، أو API خدمة بريد).
///
/// طريقة الاستخدام لاحقاً:
///   final service = EmailService();
///   final debts = await service.buildReminderList();
///   for (final d in debts) { service.sendReminder(d); }
/// ═══════════════════════════════════════════════════════════════
class EmailService {
  final InvoiceController _invoices = InvoiceController();
  final CustomerController _customers = CustomerController();

  /// يبني قائمة "من يدين بكم" مجمَّعة حسب العميل، جاهزة لتُستخدم
  /// كمصدر لإرسال رسائل التذكير.
  Future<List<CustomerDebt>> buildReminderList() async {
    final outstanding = await _invoices.getOutstanding();

    final Map<int, CustomerDebt> byCustomer = {};
    for (final invoice in outstanding) {
      if (invoice.customerId == null) continue; // فاتورة بلا عميل مسجَّل
      final existing = byCustomer[invoice.customerId];
      if (existing != null) {
        existing.amountDue += invoice.remainingAmount;
        existing.invoiceCount += 1;
      } else {
        final customer = await _customers.getById(invoice.customerId!);
        byCustomer[invoice.customerId!] = CustomerDebt(
          customerId: invoice.customerId!,
          name: invoice.customerName,
          email: customer?.email,
          phone: customer?.phone,
          amountDue: invoice.remainingAmount,
          invoiceCount: 1,
        );
      }
    }

    return byCustomer.values.toList();
  }

  /// TODO (مستقبلاً): تنفيذ الإرسال الفعلي.
  /// اربطها بحزمة `mailer` (SMTP) أو أي مزوّد بريد، ثم استدعِ هذه
  /// الدالة لكل عنصر من buildReminderList(). حالياً تطبع فقط تنبيهاً
  /// حتى لا يفشل التطبيق عند استدعائها بالخطأ.
  Future<void> sendReminder(CustomerDebt debt) async {
    if (debt.email == null || debt.email!.isEmpty) {
      // لا يوجد بريد إلكتروني مسجَّل لهذا العميل — لا يمكن الإرسال.
      return;
    }
    // ignore: avoid_print
    print('EmailService: سيتم لاحقاً إرسال تذكير إلى ${debt.email} '
        'بمبلغ ${debt.amountDue.toStringAsFixed(2)}');
  }
}

/// يمثّل مجموع ما يدين به عميل واحد عبر كل فواتيره غير المسدَّدة.
class CustomerDebt {
  final int customerId;
  final String name;
  final String? email;
  final String? phone;
  double amountDue;
  int invoiceCount;

  CustomerDebt({
    required this.customerId,
    required this.name,
    this.email,
    this.phone,
    required this.amountDue,
    required this.invoiceCount,
  });
}

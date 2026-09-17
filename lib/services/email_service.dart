import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/controller/settings_controller.dart';

/// يُرمى عند محاولة الإرسال بدون إعداد SMTP، أو عند فشل الإرسال
/// فعلياً — برسالة عربية واضحة تُعرض للمستخدم بدل أن يفشل التطبيق
/// بصمت أو يطبع في الـ console فقط.
class EmailSendException implements Exception {
  final String message;
  EmailSendException(this.message);
  @override
  String toString() => message;
}

/// ═══════════════════════════════════════════════════════════════
/// EmailService
/// إرسال بريد فعلي عبر SMTP (حزمة mailer) بدلاً من print()/Placeholder.
/// بيانات الاتصال (Host/Port/Username/Password) تُقرأ من جدول
/// settings في SQLite — يملؤها المستخدم من شاشة الإعدادات، ولا تُكتب
/// أي بيانات اعتماد داخل الكود المصدري.
/// ═══════════════════════════════════════════════════════════════
class EmailService {
  final InvoiceController _invoices = InvoiceController();
  final CustomerController _customers = CustomerController();
  final SettingsController _settings = SettingsController();

  /// يبني قائمة "من يدين بكم" مجمَّعة حسب العميل، جاهزة لتُستخدم
  /// كمصدر لإرسال رسائل التذكير أو لعرضها في شاشة الإشعارات.
  Future<List<CustomerDebt>> buildReminderList() async {
    final outstanding = await _invoices.getOutstanding();

    final Map<int, CustomerDebt> byCustomer = {};
    for (final invoice in outstanding) {
      if (invoice.customerId == null) continue; // فاتورة بلا عميل مسجَّل
      final existing = byCustomer[invoice.customerId];
      if (existing != null) {
        existing.amountDue += invoice.remainingAmount;
        existing.invoiceCount += 1;
        if (invoice.createdAt.compareTo(existing.lastInvoiceDate) > 0) {
          existing.lastInvoiceDate = invoice.createdAt;
        }
      } else {
        final customer = await _customers.getById(invoice.customerId!);
        byCustomer[invoice.customerId!] = CustomerDebt(
          customerId: invoice.customerId!,
          name: invoice.customerName,
          email: customer?.email,
          phone: customer?.phone,
          amountDue: invoice.remainingAmount,
          invoiceCount: 1,
          lastInvoiceDate: invoice.createdAt,
        );
      }
    }

    return byCustomer.values.toList()
      ..sort((a, b) => b.amountDue.compareTo(a.amountDue));
  }

  /// يبني نص الرسالة العربية (اسم العميل، المبلغ المستحق، عدد
  /// الفواتير، تاريخ آخر عملية).
  String buildMessage(CustomerDebt debt) {
    final lastDate = debt.lastInvoiceDate.split('T').first;
    return '''
السلام عليكم ${debt.name}،

نود تذكيركم بوجود مبلغ مستحق لدى المتجر.

عدد الفواتير المرتبطة بالدين: ${debt.invoiceCount}
إجمالي المبلغ المستحق: ${debt.amountDue.toStringAsFixed(2)} ر.س
تاريخ آخر عملية: $lastDate

يرجى التواصل مع المتجر لتسوية المبلغ.

شكراً لتعاملكم معنا.
''';
  }

  /// إرسال فعلي عبر SMTP. يرمي [EmailSendException] برسالة عربية
  /// واضحة عند عدم توفر إعداد SMTP، أو عدم توفر بريد للعميل، أو فشل
  /// الإرسال (خطأ اتصال/مصادقة...).
  Future<void> sendReminder(CustomerDebt debt) async {
    if (debt.email == null || debt.email!.trim().isEmpty) {
      throw EmailSendException(
          'لا يوجد بريد إلكتروني مسجَّل للعميل "${debt.name}"');
    }

    final smtp = await _settings.getSmtpSettings();
    if (!smtp.isConfigured) {
      throw EmailSendException(
          'لم يتم إعداد بريد المتجر بعد — يرجى ضبط إعدادات SMTP من شاشة الإعدادات أولاً');
    }

    final server = SmtpServer(
      smtp.host!,
      port: smtp.port,
      username: smtp.username,
      password: smtp.password,
      ssl: smtp.useSsl,
    );

    final message = Message()
      ..from = Address(smtp.username!, smtp.senderName)
      ..recipients.add(debt.email!)
      ..subject = 'تذكير بمبلغ مستحق - ${debt.name}'
      ..text = buildMessage(debt);

    try {
      await send(message, server);
    } on MailerException catch (e) {
      final firstProblem =
          e.problems.isNotEmpty ? e.problems.first.msg : e.message;
      throw EmailSendException('فشل إرسال البريد إلى ${debt.email}: $firstProblem');
    } catch (_) {
      throw EmailSendException(
          'فشل إرسال البريد إلى ${debt.email} — تحقق من الاتصال بالإنترنت وإعدادات SMTP');
    }
  }

  /// إرسال تذكير لكل العملاء المدينين الذين لديهم بريد إلكتروني.
  /// يُرجع (عدد الناجح، قائمة الأخطاء) حتى لا يوقف فشلُ عميلٍ واحد
  /// إرسال البقية.
  Future<(int, List<String>)> sendAllReminders() async {
    final debts = await buildReminderList();
    int success = 0;
    final errors = <String>[];
    for (final d in debts) {
      try {
        await sendReminder(d);
        success++;
      } on EmailSendException catch (e) {
        errors.add(e.message);
      }
    }
    return (success, errors);
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
  String lastInvoiceDate;

  CustomerDebt({
    required this.customerId,
    required this.name,
    this.email,
    this.phone,
    required this.amountDue,
    required this.invoiceCount,
    required this.lastInvoiceDate,
  });
}

import 'dart:async';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/services.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/controller/settings_controller.dart';
import 'package:untitled2/model/invoice.dart';

/// يُرمى عند محاولة الإرسال بدون إعداد SMTP، أو عند فشل الإرسال
/// فعلياً — برسالة عربية واضحة تُعرض للمستخدم بدل أن يفشل التطبيق
/// بصمت أو يطبع في الـ console فقط.
class EmailSendException implements Exception {
  final String message;
  EmailSendException(this.message);
  @override
  String toString() => message;
}

/// إرسال تذكيرات الديون عبر SMTP، مع نسخة HTML تحتوي على جدول تفصيلي
/// بالفواتير غير المسددة أو المسددة جزئياً.
class EmailService {
  final InvoiceController _invoices = InvoiceController();
  final CustomerController _customers = CustomerController();
  final SettingsController _settings = SettingsController();

  /// يبني قائمة الديون مجمعة حسب العميل، مع الاحتفاظ بالفواتير نفسها
  /// حتى يمكن عرضها في جدول داخل رسالة البريد.
  Future<List<CustomerDebt>> buildReminderList() async {
    final outstanding = await _invoices.getOutstanding();
    final Map<int, CustomerDebt> byCustomer = {};

    for (final invoice in outstanding) {
      if (invoice.customerId == null) continue;

      final customerId = invoice.customerId!;
      final customer = await _customers.getById(customerId);
      final detail = DebtInvoiceDetail.fromInvoice(invoice);
      final existing = byCustomer[customerId];

      if (existing != null) {
        existing.amountDue += detail.remaining;
        existing.invoiceCount += 1;
        existing.invoices.add(detail);
        if (invoice.createdAt.compareTo(existing.lastInvoiceDate) > 0) {
          existing.lastInvoiceDate = invoice.createdAt;
        }
      } else {
        byCustomer[customerId] = CustomerDebt(
          customerId: customerId,
          name: customer?.name ?? invoice.customerName,
          email: customer?.email,
          phone: customer?.phone,
          amountDue: detail.remaining,
          invoiceCount: 1,
          lastInvoiceDate: invoice.createdAt,
          invoices: [detail],
        );
      }
    }

    for (final debt in byCustomer.values) {
      debt.invoices.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return byCustomer.values.toList()
      ..sort((a, b) => b.amountDue.compareTo(a.amountDue));
  }

  /// نسخة نصية بديلة لمنصات البريد التي لا تعرض HTML.
  String buildMessage(CustomerDebt debt) {
    final buffer = StringBuffer('''
السلام عليكم ${debt.name}،

نود تذكيركم بوجود مبلغ مستحق لدى المتجر.

الفواتير غير المسددة:
''');

    for (final invoice in debt.invoices) {
      buffer.writeln(
        'فاتورة #${invoice.id} | التاريخ: ${invoice.dateOnly} | '
            'الإجمالي: ${invoice.total.toStringAsFixed(2)} ر.س | '
            'المدفوع: ${invoice.paid.toStringAsFixed(2)} ر.س | '
            'المتبقي: ${invoice.remaining.toStringAsFixed(2)} ر.س',
      );
    }

    buffer.write('''

عدد الفواتير المرتبطة بالدين: ${debt.invoiceCount}
إجمالي المبلغ المستحق: ${debt.amountDue.toStringAsFixed(2)} ر.س
تاريخ آخر عملية: ${debt.lastInvoiceDate.split('T').first}

يرجى التواصل مع المتجر لتسوية المبلغ.

شكراً لتعاملكم معنا.
''');

    return buffer.toString();
  }

  /// يحمي النصوص القادمة من بيانات العملاء قبل وضعها داخل HTML.
  String _escapeHtml(String? value) {
    return (value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _money(double value) => '${value.toStringAsFixed(2)} ر.س';

  /// يبني رسالة HTML RTL تحتوي على ملخص الدين وجدولاً تفصيلياً للفواتير.
  String buildHtmlMessage(CustomerDebt debt) {
    final rows = debt.invoices.map((invoice) {
      return '''
        <tr>
          <td class="cell invoice-number">#${invoice.id}</td>
          <td class="cell">${_escapeHtml(invoice.dateOnly)}</td>
          <td class="cell">${_money(invoice.total)}</td>
          <td class="cell paid">${_money(invoice.paid)}</td>
          <td class="cell remaining">${_money(invoice.remaining)}</td>
        </tr>''';
    }).join();

    return '''
<!doctype html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="utf-8">
    <meta name="color-scheme" content="light">
    <style>
      body { margin:0; padding:0; background:#f2f6f3; color:#24352c; font-family:Arial,Tahoma,sans-serif; line-height:1.7; }
      .wrapper { width:100%; padding:28px 0; background:#f2f6f3; }
      .card { max-width:760px; margin:0 auto; background:#fff; border:1px solid #dce8df; border-radius:18px; overflow:hidden; box-shadow:0 8px 26px rgba(15,81,50,.10); }
      .header { padding:26px 28px; color:#fff; background:linear-gradient(135deg,#0f5132,#198754); }
      .brand { display:flex; align-items:center; gap:14px; }
      .logo { width:58px; height:58px; border-radius:16px; background:#fff; padding:4px; }
      .brand-name { margin:0; font-size:22px; font-weight:700; }
      .brand-subtitle { margin:3px 0 0; color:#d9efe1; font-size:13px; }
      .content { padding:28px; }
      .hello { font-size:18px; font-weight:700; color:#0f5132; margin:0 0 8px; }
      .summary { margin:20px 0 24px; padding:18px; background:#f8fbf9; border:1px solid #d9ebe0; border-radius:12px; }
      .summary-title { margin:0 0 8px; color:#0f5132; font-size:15px; font-weight:700; }
      .total { color:#b42318; font-size:23px; font-weight:700; }
      .muted { color:#63756a; font-size:13px; }
      .section-title { margin:0 0 12px; color:#0f5132; font-size:17px; }
      .table-wrap { overflow-x:auto; border:1px solid #dce8df; border-radius:12px; }
      table { width:100%; border-collapse:collapse; min-width:610px; font-size:13px; }
      th { padding:12px 10px; background:#e9f4ed; color:#0f5132; border-bottom:2px solid #c9dfd0; text-align:center; white-space:nowrap; }
      .cell { padding:11px 10px; text-align:center; border-bottom:1px solid #e6eee8; white-space:nowrap; }
      tbody tr:nth-child(even) { background:#fbfdfb; }
      tbody tr:last-child .cell { border-bottom:0; }
      .invoice-number { color:#0f5132; font-weight:700; }
      .paid { color:#247a4b; }
      .remaining { color:#b42318; font-weight:700; }
      .notice { margin-top:24px; padding:14px 16px; background:#fff8e6; border-right:4px solid #e0a72f; border-radius:8px; color:#624b12; font-size:13px; }
      .footer { padding:18px 28px; background:#f8fbf9; border-top:1px solid #e5eee7; color:#63756a; font-size:12px; text-align:center; }
      @media only screen and (max-width:600px) { .content,.header { padding:20px; } .brand-name { font-size:19px; } }
    </style>
  </head>
  <body>
    <div class="wrapper">
      <div class="card">
        <div class="header">
          <div class="brand">
            <img class="logo" src="cid:store-logo@estore" alt="شعار E-Store">
            <div style=" padding-inline:10px;">
              <h1 class="brand-name">متجري</h1>
              <p class="brand-subtitle">تذكير بمبلغ مستحق</p>
            </div>
          </div>
        </div>
        <div class="content">
          <p class="hello">مرحباً ${_escapeHtml(debt.name)}،</p>
          <p>نود تذكيركم بوجود مبلغ مستحق لدى المتجر.</p>

          <div class="summary">
            <p class="summary-title">ملخص الحساب</p>
            <div class="total">${_money(debt.amountDue)}</div>
            <div class="muted">إجمالي المبلغ المستحق</div>
            <div class="muted">عدد الفواتير: ${debt.invoiceCount} · تاريخ آخر عملية: ${_escapeHtml(debt.lastInvoiceDate.split('T').first)}</div>
          </div>

          <h2 class="section-title">تفاصيل الفواتير</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>رقم الفاتورة</th>
                  <th>التاريخ</th>
                  <th>الإجمالي</th>
                  <th>المدفوع</th>
                  <th>المتبقي</th>
                </tr>
              </thead>
              <tbody>$rows</tbody>
            </table>
          </div>

          <div class="notice">يرجى التواصل مع المتجر لتسوية المبلغ المستحق.</div>
          <p>شكراً لتعاملكم معنا.</p>
        </div>
        <div class="footer">هذه رسالة آلية من نظام إدارة المتجر، يرجى عدم الرد عليها.</div>
      </div>
    </div>
  </body>
</html>
''';
  }

  /// إرسال تذكير فعلي عبر SMTP.
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

    final logoData = await rootBundle.load('assets/store_logo.png');
    final logoAttachment = StreamAttachment(
      Stream.value(logoData.buffer.asUint8List()),
      'image/png',
      fileName: 'store_logo.png',
    )
      ..cid = 'store-logo@estore'
      ..location = Location.inline;

    final message = Message()
      ..from = Address(smtp.username!, smtp.senderName)
      ..recipients.add(debt.email!)
      ..subject = 'تذكير بمبلغ مستحق - ${debt.name}'
      ..text = buildMessage(debt)
      ..html = buildHtmlMessage(debt);
    message.attachments.add(logoAttachment);

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
  Future<(int, List<String>)> sendAllReminders() async {
    final debts = await buildReminderList();
    int success = 0;
    final errors = <String>[];
    for (final debt in debts) {
      try {
        await sendReminder(debt);
        success++;
      } on EmailSendException catch (e) {
        errors.add(e.message);
      }
    }
    return (success, errors);
  }
}

/// فاتورة واحدة ضمن جدول رسالة التذكير.
class DebtInvoiceDetail {
  final int id;
  final String createdAt;
  final double total;
  final double paid;
  final double remaining;

  DebtInvoiceDetail({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.paid,
    required this.remaining,
  });

  factory DebtInvoiceDetail.fromInvoice(InvoiceModel invoice) {
    return DebtInvoiceDetail(
      id: invoice.id!,
      createdAt: invoice.createdAt,
      total: invoice.total,
      paid: invoice.paidAmount,
      remaining: invoice.remainingAmount,
    );
  }

  String get dateOnly => createdAt.split('T').first;
}

/// يمثّل مجموع ما يدين به عميل واحد عبر فواتيره غير المسددة.
class CustomerDebt {
  final int customerId;
  final String name;
  final String? email;
  final String? phone;
  double amountDue;
  int invoiceCount;
  String lastInvoiceDate;
  final List<DebtInvoiceDetail> invoices;

  CustomerDebt({
    required this.customerId,
    required this.name,
    this.email,
    this.phone,
    required this.amountDue,
    required this.invoiceCount,
    required this.lastInvoiceDate,
    required this.invoices,
  });
}

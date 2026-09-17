import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/controller/payment_controller.dart';
import 'package:untitled2/model/customer.dart';
import 'package:untitled2/model/invoice.dart';
import 'package:untitled2/services/app_events.dart';

const _primary = Color(0xFF0F5132);

/// صفحة العميل: بياناته، ملخّص المشتريات/المدفوع/المتبقي (من
/// SQLite فعلياً)، سجل الفواتير والدفعات، وإمكانية "تسجيل دفعة"
/// جديدة تُوزَّع تلقائياً على فواتيره الآجلة/الجزئية (الأقدم أولاً).
class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({Key? key, required this.customerId}) : super(key: key);

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final CustomerController _customerController = CustomerController();
  final InvoiceController _invoiceController = InvoiceController();
  final PaymentController _paymentController = PaymentController();

  CustomerModel? _customer;
  Map<String, double> _summary = {'total': 0, 'paid': 0, 'remaining': 0};
  List<InvoiceModel> _invoices = [];
  List<PaymentModel> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _customerController.getById(widget.customerId),
      _invoiceController.getCustomerSummary(widget.customerId),
      _invoiceController.getAll(customerId: widget.customerId),
      _paymentController.getByCustomer(widget.customerId),
    ]);
    if (!mounted) return;
    setState(() {
      _customer = results[0] as CustomerModel?;
      _summary = results[1] as Map<String, double>;
      _invoices = results[2] as List<InvoiceModel>;
      _payments = results[3] as List<PaymentModel>;
      _loading = false;
    });
  }

  Future<void> _registerPayment() async {
    final remaining = _summary['remaining'] ?? 0;
    if (remaining <= 0) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentDialog(maxAmount: remaining),
    );
    if (result == null) return;
    final amount = result['amount'] as double;
    final method = result['method'] as String;

    try {
      await _invoiceController.registerCustomerPayment(widget.customerId, amount,
          paymentMethod: method);
      AppEvents.instance.fireMany(
          [AppEventType.invoices, AppEventType.payments, AppEventType.customers]);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _summary['remaining'] ?? 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: Text(_customer?.name ?? 'تفاصيل العميل')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _customer == null
                ? const Center(child: Text('العميل غير موجود'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _infoCard(),
                        const SizedBox(height: 14),
                        _summaryCard(remaining),
                        if (remaining > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _registerPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.payments_outlined, color: Colors.white),
                              label: const Text('تسجيل دفعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text('الفواتير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        if (_invoices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('لا توجد فواتير', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ..._invoices.map(_invoiceRow),
                        const SizedBox(height: 20),
                        const Text('سجل الدفعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        if (_payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('لا توجد دفعات بعد', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ..._payments.map(_paymentRow),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _infoCard() {
    final c = _customer!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          if (c.phone != null && c.phone!.isNotEmpty)
            _infoRow(Icons.phone_outlined, c.phone!),
          if (c.email != null && c.email!.isNotEmpty)
            _infoRow(Icons.email_outlined, c.email!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
          ],
        ),
      );

  Widget _summaryCard(double remaining) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(child: _statColumn('إجمالي المشتريات', _summary['total']!, _primary)),
          Expanded(child: _statColumn('المدفوع', _summary['paid']!, Colors.green)),
          Expanded(child: _statColumn('المتبقي', remaining, remaining > 0 ? Colors.red : Colors.grey)),
        ],
      ),
    );
  }

  Widget _statColumn(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
        const SizedBox(height: 4),
        Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }

  Widget _invoiceRow(InvoiceModel inv) {
    Color statusColor;
    switch (inv.paymentStatus) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.orange;
        break;
      case PaymentStatus.unpaid:
        statusColor = Colors.red;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فاتورة #${inv.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(inv.createdAt.split('T').first, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${inv.total.toStringAsFixed(2)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(inv.paymentStatus.label, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(PaymentModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('فاتورة #${p.invoiceId} • ${p.paymentDate.split('T').first}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ),
          Text('${p.amount.toStringAsFixed(2)} ر.س',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final double maxAmount;
  const _PaymentDialog({required this.maxAmount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _ctrl = TextEditingController();
  String _method = 'نقدي';
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'أدخل مبلغاً صحيحاً أكبر من صفر');
      return;
    }
    if (amount > widget.maxAmount) {
      setState(() => _error = 'المبلغ أكبر من الدَين الحالي (${widget.maxAmount.toStringAsFixed(2)})');
      return;
    }
    Navigator.pop(context, {'amount': amount, 'method': _method});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الدَين الحالي: ${widget.maxAmount.toStringAsFixed(2)} ر.س',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _method,
              items: const [
                DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                DropdownMenuItem(value: 'تحويل بنكي', child: Text('تحويل بنكي')),
                DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'نقدي'),
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

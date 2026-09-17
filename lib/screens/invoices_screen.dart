import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/model/invoice.dart';
import 'package:untitled2/services/app_events.dart';
import 'package:untitled2/widgets/notification_bell.dart';

const _primary = Color(0xFF0F5132);

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({Key? key}) : super(key: key);

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoiceController _controller = InvoiceController();
  List<InvoiceModel> _invoices = [];
  bool _loading = true;
  PaymentStatus? _filter;
  String _search = '';

  StreamSubscription<AppEventType>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _eventsSub = AppEvents.instance.stream.listen((_) => _load());
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data =
        await _controller.getAll(status: _filter, searchCustomer: _search);
    setState(() {
      _invoices = data;
      _loading = false;
    });
  }

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.partial:
        return Colors.orange;
      case PaymentStatus.unpaid:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('الفواتير'), actions: const [NotificationBell()]),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _load();
                },
                decoration: InputDecoration(
                  hintText: 'ابحث باسم العميل...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _filterChip('الكل', null),
                  _filterChip('مدفوعة', PaymentStatus.paid),
                  _filterChip('دفع جزئي', PaymentStatus.partial),
                  _filterChip('غير مدفوعة', PaymentStatus.unpaid),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _invoices.isEmpty
                      ? const Center(child: Text('لا توجد فواتير'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _invoices.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _invoiceCard(_invoices[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, PaymentStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _primary,
        labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12),
        onSelected: (_) {
          setState(() => _filter = status);
          _load();
        },
      ),
    );
  }

  Widget _invoiceCard(InvoiceModel invoice) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetails(invoice),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(invoice.createdAt.substring(0, 16).replaceAll('T', '  '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${invoice.total.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(invoice.paymentStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(invoice.paymentStatus.label,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(invoice.paymentStatus))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(InvoiceModel invoice) async {
    final full = await _controller.getById(invoice.id!);
    if (full == null || !mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(full.customerName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('الحالة: ${full.paymentStatus.label}',
                      style: TextStyle(color: _statusColor(full.paymentStatus), fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: full.items.length,
                      itemBuilder: (_, i) {
                        final item = full.items[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text('${item.name} × ${item.qty}')),
                              Text('${item.lineTotal.toStringAsFixed(2)} ر.س'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${full.total.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                    ],
                  ),
                  if (!full.isSettled) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المتبقي', style: TextStyle(color: Colors.red)),
                        Text('${full.remainingAmount.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          try {
                            await _controller.registerPayment(full.id!, full.remainingAmount);
                            AppEvents.instance.fireMany(
                                [AppEventType.invoices, AppEventType.payments, AppEventType.customers]);
                            if (mounted) Navigator.pop(context);
                            _load();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                            }
                          }
                        },
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('تسجيل سداد المتبقي بالكامل',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: _primary),
                        onPressed: () async {
                          final amount = await showDialog<double>(
                            context: context,
                            builder: (_) => _PartialPaymentDialog(maxAmount: full.remainingAmount),
                          );
                          if (amount == null) return;
                          try {
                            await _controller.registerPayment(full.id!, amount);
                            AppEvents.instance.fireMany(
                                [AppEventType.invoices, AppEventType.payments, AppEventType.customers]);
                            if (mounted) Navigator.pop(context);
                            _load();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                            }
                          }
                        },
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('تسجيل دفعة جزئية بمبلغ محدَّد'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PartialPaymentDialog extends StatefulWidget {
  final double maxAmount;
  const _PartialPaymentDialog({required this.maxAmount});

  @override
  State<_PartialPaymentDialog> createState() => _PartialPaymentDialogState();
}

class _PartialPaymentDialogState extends State<_PartialPaymentDialog> {
  final _ctrl = TextEditingController();
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
      setState(() => _error =
          'المبلغ أكبر من المتبقي على الفاتورة (${widget.maxAmount.toStringAsFixed(2)})');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تسجيل دفعة جزئية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المتبقي على الفاتورة: ${widget.maxAmount.toStringAsFixed(2)} ر.س',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع الآن'),
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

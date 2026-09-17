import 'package:flutter/material.dart';
import 'package:untitled2/services/email_service.dart';
import 'customer_detail_screen.dart';

const _primary = Color(0xFF0F5132);

/// شاشة الإشعارات: تعرض العملاء الذين عليهم دين (Unpaid/Partial) من
/// بيانات حقيقية عبر EmailService.buildReminderList()، مع زر "إرسال
/// إشعار" فعلي لكل عميل.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final EmailService _emailService = EmailService();
  List<CustomerDebt> _debts = [];
  bool _loading = true;
  final Set<int> _sending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _emailService.buildReminderList();
    if (!mounted) return;
    setState(() {
      _debts = data;
      _loading = false;
    });
  }

  Future<void> _sendOne(CustomerDebt d) async {
    setState(() => _sending.add(d.customerId));
    try {
      await _emailService.sendReminder(d);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرسال الإشعار إلى ${d.name}')));
    } on EmailSendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sending.remove(d.customerId));
    }
  }

  Future<void> _sendAll() async {
    setState(() => _loading = true);
    final (success, errors) = await _emailService.sendAllReminders();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(errors.isEmpty
          ? 'تم إرسال $success إشعار بنجاح'
          : 'تم إرسال $success بنجاح، وفشل ${errors.length}: ${errors.first}'),
      backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('الإشعارات'),
          actions: [
            if (_debts.isNotEmpty)
              TextButton(
                onPressed: _loading ? null : _sendAll,
                child: const Text('إرسال للكل', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                onRefresh: _load,
                child: _debts.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text('🔔\nلا توجد ديون مستحقة حالياً',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _debts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _debtCard(_debts[i]),
                      ),
              ),
      ),
    );
  }

  Widget _debtCard(CustomerDebt d) {
    final sending = _sending.contains(d.customerId);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customerId: d.customerId)),
        ).then((_) => _load()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text('${d.amountDue.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('عدد الفواتير: ${d.invoiceCount}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (d.email != null && d.email!.isNotEmpty)
              Text(d.email!, style: TextStyle(color: Colors.grey[600], fontSize: 12))
            else
              const Text('لا يوجد بريد إلكتروني مسجَّل',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: sending ? null : () => _sendOne(d),
                icon: sending
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.email_outlined, size: 16),
                label: Text(sending ? 'جارِ الإرسال...' : 'إرسال إشعار'),
                style: OutlinedButton.styleFrom(foregroundColor: _primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

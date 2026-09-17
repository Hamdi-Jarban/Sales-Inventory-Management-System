import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/services/app_events.dart';
import 'package:untitled2/screens/notifications_screen.dart';

/// زر إشعارات ثابت (🔔 مع عدد حقيقي من قاعدة البيانات) — يُستخدم في
/// AppBar للشاشات الرئيسية. العدد هو عدد العملاء الذين عليهم دين
/// (فواتير آجلة أو جزئية) حالياً، ويتحدّث تلقائياً بعد أي عملية بيع
/// أو تسديد عبر AppEvents.
class NotificationBell extends StatefulWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final InvoiceController _controller = InvoiceController();
  int _count = 0;
  StreamSubscription<AppEventType>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = AppEvents.instance.stream.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _controller.countDebtCustomers();
    if (mounted) setState(() => _count = c);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: _open,
      icon: Badge(
        label: Text('$_count'),
        isLabelVisible: _count > 0,
        backgroundColor: Colors.red,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

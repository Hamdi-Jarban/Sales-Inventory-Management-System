import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/services/app_events.dart';

const _primary = Color(0xFF0F5132);

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({Key? key}) : super(key: key);

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  final InvoiceController _controller = InvoiceController();

  bool _loading = true;
  Map<String, double> _today = {'total': 0, 'profit': 0, 'count': 0};
  Map<String, double> _week = {'total': 0, 'profit': 0, 'count': 0};
  Map<String, double> _month = {'total': 0, 'profit': 0, 'count': 0};
  double _outstanding = 0;
  List<Map<String, dynamic>> _topProducts = [];

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

  String _isoDaysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).toIso8601String();

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _controller.getTotals(afterIso: _isoDaysAgo(1)),
      _controller.getTotals(afterIso: _isoDaysAgo(7)),
      _controller.getTotals(afterIso: _isoDaysAgo(30)),
      _controller.getTotalOutstandingAmount(),
      _controller.getTopProfitableProducts(limit: 5),
    ]);

    setState(() {
      _today = results[0] as Map<String, double>;
      _week = results[1] as Map<String, double>;
      _month = results[2] as Map<String, double>;
      _outstanding = results[3] as double;
      _topProducts = results[4] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('الأرباح')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statCard('اليوم', _today)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('آخر 7 أيام', _week)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _statCard('آخر 30 يوم', _month, wide: true),
                    const SizedBox(height: 14),
                    _debtCard(),
                    const SizedBox(height: 14),
                    const Text('الأكثر ربحاً',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (_topProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('لا توجد بيانات مبيعات بعد')),
                      )
                    else
                      ..._topProducts.map((p) => _topProductRow(p)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statCard(String title, Map<String, double> data, {bool wide = false}) {
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
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 6),
          Text('${data['total']!.toStringAsFixed(2)} ر.س',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primary)),
          const SizedBox(height: 4),
          Text('ربح: ${data['profit']!.toStringAsFixed(2)} ر.س',
              style: const TextStyle(color: Colors.green, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${data['count']!.toInt()} فاتورة', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _debtCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.money_off_outlined, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي المبالغ غير المحصَّلة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text('من فواتير غير مدفوعة أو مدفوعة جزئياً',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Text('${_outstanding.toStringAsFixed(2)} ر.س',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _topProductRow(Map<String, dynamic> p) {
    final profit = (p['total_profit'] as num).toDouble();
    final qty = (p['total_qty'] as num).toInt();
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
                Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$qty قطعة مباعة', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Text('${profit.toStringAsFixed(2)} ر.س',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/model/customer.dart';
import 'customer_detail_screen.dart';

const _primary = Color(0xFF0F5132);

/// قائمة كل العملاء (بحث حقيقي من SQLite) — الدخول إلى صفحة كل
/// عميل لعرض تفاصيله وسجل فواتيره ودفعاته وتسديد دينه.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerController _controller = CustomerController();
  final InvoiceController _invoiceController = InvoiceController();
  List<CustomerModel> _all = [];
  List<CustomerModel> _filtered = [];
  final Map<int, double> _remaining = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customers = await _controller.getAll();
    final remainingMap = await _invoiceController.getAllCustomersRemaining();
    if (!mounted) return;
    setState(() {
      _all = customers;
      _filtered = customers;
      _remaining
        ..clear()
        ..addAll(remainingMap);
      _loading = false;
    });
  }

  void _onSearch(String q) {
    setState(() {
      _search = q;
      _filtered = q.trim().isEmpty
          ? _all
          : _all
              .where((c) =>
                  c.name.toLowerCase().contains(q.toLowerCase()) ||
                  (c.phone ?? '').contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('العملاء')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الهاتف...',
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _filtered.isEmpty
                      ? const Center(child: Text('لا يوجد عملاء'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _customerCard(_filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(CustomerModel c) {
    final debt = _remaining[c.id] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withOpacity(0.1),
          child: const Icon(Icons.person_outline, color: _primary),
        ),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(c.phone ?? 'بدون رقم هاتف',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: debt > 0
            ? Text('${debt.toStringAsFixed(2)} ر.س',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))
            : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id!)),
        ).then((_) => _load()),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/model/customer.dart';

const _primary = Color(0xFF0F5132);

/// حقل بحث/اختيار عميل حقيقي من SQLite (وليس قائمة ثابتة)، مع
/// Debounce حتى لا يُنفَّذ Query عند كل حرف، وخيار "إضافة عميل جديد"
/// عندما لا يظهر العميل في نتائج البحث. يبحث بالاسم أو رقم الهاتف.
class CustomerSearchField extends StatefulWidget {
  final CustomerModel? selected;
  final ValueChanged<CustomerModel?> onSelected;
  final bool required;

  const CustomerSearchField({
    Key? key,
    required this.onSelected,
    this.selected,
    this.required = false,
  }) : super(key: key);

  @override
  State<CustomerSearchField> createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  final CustomerController _controller = CustomerController();
  final TextEditingController _textCtrl = TextEditingController();
  Timer? _debounce;
  List<CustomerModel> _results = [];
  bool _loading = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      _textCtrl.text = widget.selected!.name;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    // أي كتابة جديدة تُلغي الاختيار الحالي حتى يعاد اختيار عميل صريح.
    widget.onSelected(null);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final results = await _controller.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _showResults = true;
      });
    });
  }

  Future<void> _createCustomer() async {
    final created = await showDialog<CustomerModel>(
      context: context,
      builder: (_) => _NewCustomerDialog(initialName: _textCtrl.text.trim()),
    );
    if (created == null) return;
    final id = await _controller.insert(created);
    final saved = CustomerModel(
      id: id,
      name: created.name,
      phone: created.phone,
      email: created.email,
    );
    setState(() {
      _textCtrl.text = saved.name;
      _showResults = false;
      _results = [];
    });
    widget.onSelected(saved);
  }

  void _select(CustomerModel c) {
    setState(() {
      _textCtrl.text = c.name;
      _showResults = false;
      _results = [];
    });
    widget.onSelected(c);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textCtrl,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.required
                ? 'ابحث عن عميل بالاسم أو الهاتف (مطلوب)'
                : 'ابحث عن عميل بالاسم أو الهاتف',
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
            suffixIcon: widget.selected != null
                ? const Icon(Icons.check_circle, color: _primary)
                : (_loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_showResults) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._results.map((c) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: c.phone != null && c.phone!.isNotEmpty
                          ? Text(c.phone!)
                          : null,
                      onTap: () => _select(c),
                    )),
                if (!_loading && _results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    child: Text('لا يوجد عميل مطابق',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_add_alt_1, color: _primary, size: 20),
                  title: const Text('إضافة عميل جديد',
                      style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                  onTap: _createCustomer,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NewCustomerDialog extends StatefulWidget {
  final String initialName;
  const _NewCustomerDialog({required this.initialName});

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String? _error;

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اسم العميل مطلوب');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'رقم الهاتف مطلوب');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    Navigator.pop(
      context,
      CustomerModel(name: name, phone: phone, email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم العميل *'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني *'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

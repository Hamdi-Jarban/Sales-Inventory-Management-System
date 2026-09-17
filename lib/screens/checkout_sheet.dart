import 'package:flutter/material.dart';
import 'package:untitled2/model/customer.dart';
import 'package:untitled2/model/invoice.dart';
import 'package:untitled2/widgets/customer_search_field.dart';

const _primary = Color(0xFF0F5132);

/// نتيجة شاشة إتمام البيع — تُستخدم في PosScreen/شاشة المسح المستمر
/// لإنشاء الفاتورة. customerId يكون null فقط في حالة "عميل نقدي"
/// مدفوعة بالكامل؛ أي حالة آجلة أو جزئية تُجبَر على عميل حقيقي.
class CheckoutResult {
  final int? customerId;
  final String customerName;
  final PaymentStatus paymentStatus;
  final double paidAmount;
  final String paymentMethod;

  CheckoutResult({
    this.customerId,
    required this.customerName,
    required this.paymentStatus,
    required this.paidAmount,
    required this.paymentMethod,
  });
}

/// يفتح نافذة سفلية لاختيار طريقة الدفع (وربما العميل) قبل حفظ
/// الفاتورة. يرجع null إذا ألغى المستخدم العملية.
Future<CheckoutResult?> showCheckoutSheet(
  BuildContext context, {
  required double total,
}) {
  return showModalBottomSheet<CheckoutResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CheckoutSheetBody(total: total),
  );
}

enum _PayMode { cash, credit, partial }

class _CheckoutSheetBody extends StatefulWidget {
  final double total;
  const _CheckoutSheetBody({required this.total});

  @override
  State<_CheckoutSheetBody> createState() => _CheckoutSheetBodyState();
}

class _CheckoutSheetBodyState extends State<_CheckoutSheetBody> {
  final _paidCtrl = TextEditingController();
  _PayMode _mode = _PayMode.cash;
  CustomerModel? _selectedCustomer;
  String? _error;

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  bool get _needsCustomer => _mode != _PayMode.cash;

  void _confirm() {
    setState(() => _error = null);

    if (_needsCustomer && _selectedCustomer == null) {
      setState(() => _error = 'يجب اختيار عميل مسجَّل للبيع الآجل أو الجزئي');
      return;
    }

    double paidAmount;
    PaymentStatus status;
    switch (_mode) {
      case _PayMode.cash:
        paidAmount = widget.total;
        status = PaymentStatus.paid;
        break;
      case _PayMode.credit:
        paidAmount = 0;
        status = PaymentStatus.unpaid;
        break;
      case _PayMode.partial:
        final entered = double.tryParse(_paidCtrl.text.trim());
        if (entered == null || entered <= 0 || entered >= widget.total) {
          setState(() =>
              _error = 'أدخل مبلغاً مدفوعاً صحيحاً أقل من الإجمالي وأكبر من صفر');
          return;
        }
        paidAmount = entered;
        status = PaymentStatus.partial;
        break;
    }

    Navigator.pop(
      context,
      CheckoutResult(
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'عميل نقدي',
        paymentStatus: status,
        paidAmount: paidAmount,
        paymentMethod: _mode == _PayMode.cash ? 'نقدي' : 'آجل',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text('إتمام عملية البيع',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('الإجمالي: ${widget.total.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _primary)),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                _modeOption(_PayMode.cash, 'نقدي (مدفوعة بالكامل)', Icons.check_circle_outline),
                _modeOption(_PayMode.partial, 'دفع جزئي', Icons.pie_chart_outline),
                _modeOption(_PayMode.credit, 'آجل (بدون دفع الآن)', Icons.money_off_outlined),
                if (_mode == _PayMode.partial) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _decoration('المبلغ المدفوع الآن', Icons.payments_outlined),
                  ),
                ],
                const SizedBox(height: 16),
                if (_needsCustomer) ...[
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('بيانات العميل (مطلوبة)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  CustomerSearchField(
                    required: true,
                    selected: _selectedCustomer,
                    onSelected: (c) => setState(() => _selectedCustomer = c),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('سيتم تسجيل الفاتورة كـ "عميل نقدي" دون بيانات شخصية',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تأكيد وحفظ الفاتورة',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeOption(_PayMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() {
        _mode = mode;
        _error = null;
        if (mode == _PayMode.cash) _selectedCustomer = null;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _primary : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? _primary : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? _primary : Colors.black87)),
            const Spacer(),
            Radio<_PayMode>(
              value: mode,
              groupValue: _mode,
              activeColor: _primary,
              onChanged: (v) => setState(() {
                _mode = v!;
                _error = null;
                if (v == _PayMode.cash) _selectedCustomer = null;
              }),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}

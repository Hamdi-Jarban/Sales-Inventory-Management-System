import 'package:flutter/material.dart';
import 'package:untitled2/model/invoice.dart';

const _primary = Color(0xFF0F5132);

/// نتيجة شاشة إتمام البيع — تُستخدم في PosScreen لإنشاء الفاتورة.
class CheckoutResult {
  final String customerName;
  final String? customerPhone;
  final PaymentStatus paymentStatus;
  final double paidAmount;

  CheckoutResult({
    required this.customerName,
    this.customerPhone,
    required this.paymentStatus,
    required this.paidAmount,
  });
}

/// يفتح نافذة سفلية لإدخال بيانات العميل وحالة الدفع قبل حفظ الفاتورة.
/// يرجع null إذا ألغى المستخدم العملية.
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

class _CheckoutSheetBody extends StatefulWidget {
  final double total;
  const _CheckoutSheetBody({required this.total});

  @override
  State<_CheckoutSheetBody> createState() => _CheckoutSheetBodyState();
}

class _CheckoutSheetBodyState extends State<_CheckoutSheetBody> {
  final _nameCtrl = TextEditingController(text: 'عميل نقدي');
  final _phoneCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  PaymentStatus _status = PaymentStatus.paid;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim().isEmpty ? 'عميل نقدي' : _nameCtrl.text.trim();
    double paidAmount;

    if (_status == PaymentStatus.paid) {
      paidAmount = widget.total;
    } else if (_status == PaymentStatus.unpaid) {
      paidAmount = 0;
    } else {
      final entered = double.tryParse(_paidCtrl.text.trim());
      if (entered == null || entered <= 0 || entered >= widget.total) {
        setState(() =>
            _error = 'أدخل مبلغاً مدفوعاً صحيحاً أقل من الإجمالي وأكبر من صفر');
        return;
      }
      paidAmount = entered;
    }

    Navigator.pop(
      context,
      CheckoutResult(
        customerName: name,
        customerPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        paymentStatus: _status,
        paidAmount: paidAmount,
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
              TextField(
                controller: _nameCtrl,
                decoration: _decoration('اسم العميل (اختياري)', Icons.person_outline),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _decoration('رقم الهاتف (اختياري)', Icons.phone_outlined),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('حالة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _statusOption(PaymentStatus.paid, 'مدفوعة بالكامل', Icons.check_circle_outline),
              _statusOption(PaymentStatus.partial, 'دفع جزئي', Icons.pie_chart_outline),
              _statusOption(PaymentStatus.unpaid, 'بدون دفع (دَين)', Icons.money_off_outlined),
              if (_status == PaymentStatus.partial) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _decoration('المبلغ المدفوع الآن', Icons.payments_outlined),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
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
    );
  }

  Widget _statusOption(PaymentStatus status, String label, IconData icon) {
    final selected = _status == status;
    return InkWell(
      onTap: () => setState(() {
        _status = status;
        _error = null;
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
            Radio<PaymentStatus>(
              value: status,
              groupValue: _status,
              activeColor: _primary,
              onChanged: (v) => setState(() {
                _status = v!;
                _error = null;
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

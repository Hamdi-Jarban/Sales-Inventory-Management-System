import 'package:flutter/material.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/model/cart_service.dart';
import 'package:untitled2/services/app_events.dart';
import 'checkout_sheet.dart';

const _primary = Color(0xFF0F5132);

/// مراجعة الطلب القادم من شاشة المسح المستمر قبل إتمام البيع:
/// Product / Quantity / Unit Price / Subtotal ثم Total، كل ذلك من
/// السلة الفعلية (CartService) وليس بيانات ثابتة.
class ReviewOrderScreen extends StatefulWidget {
  final CartService cart;
  const ReviewOrderScreen({Key? key, required this.cart}) : super(key: key);

  @override
  State<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends State<ReviewOrderScreen> {
  final InvoiceController _invoiceController = InvoiceController();
  bool _saving = false;

  Future<void> _confirm() async {
    if (widget.cart.isEmpty) return;
    final result = await showCheckoutSheet(context, total: widget.cart.grandTotal);
    if (result == null) return;

    setState(() => _saving = true);
    try {
      await _invoiceController.createInvoice(
        cartItems: widget.cart.items,
        customerId: result.customerId,
        customerName: result.customerName,
        paymentMethod: result.paymentMethod,
        paymentStatus: result.paymentStatus,
        paidAmount: result.paidAmount,
      );
      AppEvents.instance.fireMany(
          [AppEventType.products, AppEventType.invoices, AppEventType.customers]);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ الفاتورة بنجاح')));
      Navigator.pop(context, true);
    } on InsufficientStockException catch (e) {
      _showError(e.toString());
    } on InvalidPaymentException catch (e) {
      _showError(e.toString());
    } catch (e) {
      _showError('حدث خطأ أثناء حفظ الفاتورة، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cart.items;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text('مراجعة الطلب')),
        body: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد أصناف'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final subtotal = item.sellingPrice * item.stock;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              Expanded(
                                child: Text('${item.stock} × ${item.sellingPrice.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ),
                              Expanded(
                                child: Text(subtotal.toStringAsFixed(2),
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, color: _primary, fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${widget.cart.grandTotal.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_saving || items.isEmpty) ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('تأكيد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

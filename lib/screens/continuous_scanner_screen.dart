import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled2/controller/product_controller.dart';
import 'package:untitled2/model/cart_service.dart';
import 'package:untitled2/model/product.dart';
import 'review_order_screen.dart';

const _primary = Color(0xFF0F5132);

/// شاشة مسح باركود مستقلة عن زر الباركود الأصلي في نقطة البيع —
/// الكاميرا هنا لا تُغلق بعد مسح منتج واحد، بل تستمر بالعمل حتى
/// يضغط المستخدم "إتمام الطلب". هذا الملف لا يغيّر أي شيء في
/// BarcodeScannerScreen (زر الباركود الأصلي) ولا في سلوكه.
class ContinuousScannerScreen extends StatefulWidget {
  const ContinuousScannerScreen({Key? key}) : super(key: key);

  @override
  State<ContinuousScannerScreen> createState() =>
      _ContinuousScannerScreenState();
}

class _ContinuousScannerScreenState extends State<ContinuousScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final ProductController _productController = ProductController();
  final CartService _cart = CartService();

  bool _processing = false;
  String? _lastCode;
  DateTime? _lastCodeAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // نتجاهل مسح نفس الكود مرتين خلال ثانيتين (اهتزاز الكاميرا) حتى
    // لا يفتح نفس المربع الحواري عدة مرات لنفس الطلقة.
    final now = DateTime.now();
    if (_lastCode == code &&
        _lastCodeAt != null &&
        now.difference(_lastCodeAt!) < const Duration(seconds: 2)) {
      return;
    }

    _processing = true;
    _lastCode = code;
    _lastCodeAt = now;

    final product = await _productController.getByBarcode(code);
    if (!mounted) {
      _processing = false;
      return;
    }
    if (product == null) {
      _showSnack('لا يوجد منتج بهذا الباركود: $code');
      _processing = false;
      return;
    }
    await _askQuantityAndAdd(product);
    _processing = false;
  }

  Future<void> _askQuantityAndAdd(ProductModel product) async {
    final alreadyInCart = _cart.items
        .where((i) => i.barcode == product.barcode)
        .fold<int>(0, (s, i) => s + i.stock);
    final remainingStock = product.stock - alreadyInCart;

    if (remainingStock <= 0) {
      _showSnack('لا توجد كمية إضافية متاحة من "${product.name}" في المخزون');
      return;
    }

    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        product: product,
        maxQty: remainingStock,
      ),
    );
    if (qty == null || qty <= 0) return;

    setState(() {
      _cart.addOrMerge(product.copyWith(), qty);
    });
    _showSnack('تمت إضافة ${product.name} × $qty');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _completeOrder() async {
    if (_cart.isEmpty) {
      _showSnack('لم تقم بمسح أي منتج بعد');
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReviewOrderScreen(cart: _cart)),
    );
    if (saved == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('مسح مستمر (${_cart.uniqueCount} صنف)'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _controller.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_cart.isEmpty)
                      const Text('وجّه الكاميرا نحو الباركود — يمكنك مسح عدة منتجات متتالية',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5))
                    else
                      Text(
                        'الإجمالي حتى الآن: ${_cart.grandTotal.toStringAsFixed(2)} ر.س (${_cart.totalPieces} قطعة)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _completeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('إتمام الطلب',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  final ProductModel product;
  final int maxQty;
  const _QuantityDialog({required this.product, required this.maxQty});

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late int _qty = widget.maxQty > 0 ? 1 : 0;
  String? _error;

  void _change(int delta) {
    setState(() {
      final next = _qty + delta;
      if (next < 1 || next > widget.maxQty) return;
      _qty = next;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('السعر: ${widget.product.sellingPrice.toStringAsFixed(2)} ر.س'),
            Text('المتاح في المخزون: ${widget.maxQty}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _change(-1),
                ),
                Text('$_qty', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _change(1),
                ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: widget.maxQty <= 0
                ? null
                : () => Navigator.pop(context, _qty),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

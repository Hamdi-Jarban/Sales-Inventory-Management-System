import 'package:flutter/material.dart';
import 'package:untitled2/barcode_scanner_screen.dart';
import 'package:untitled2/controller/customer_controller.dart';
import 'package:untitled2/controller/invoice_controller.dart';
import 'package:untitled2/controller/product_controller.dart';
import 'package:untitled2/model/cart_service.dart';
import 'package:untitled2/model/product.dart';
import 'checkout_sheet.dart';

const _primary = Color(0xFF0F5132);

class PosScreen extends StatefulWidget {
  const PosScreen({Key? key}) : super(key: key);

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductController _productController = ProductController();
  final InvoiceController _invoiceController = InvoiceController();
  final CustomerController _customerController = CustomerController();
  final CartService _cart = CartService();

  List<ProductModel> _allProducts = [];
  String _selectedCategory = 'الكل';
  String _search = '';
  bool _showCartMobile = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _productController.GetAll();
    setState(() {
      _allProducts = products.where((p) => !p.hidden).toList();
      _loading = false;
    });
  }

  List<String> get _categories {
    final set = <String>{'الكل'};
    for (final p in _allProducts) {
      if (p.category.trim().isNotEmpty) set.add(p.category.trim());
    }
    return set.toList();
  }

  List<ProductModel> get _filtered {
    return _allProducts.where((p) {
      final matchesCategory =
          _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final matchesSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.barcode.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(ProductModel product) {
    if (product.stock <= 0) return;
    // ننسخ المنتج حتى لا نعدّل الكمية الأصلية في القائمة (lineTotal
    // في السلة يعتمد على `stock` كحقل للكمية المُختارة، بينما `stock`
    // في _allProducts يمثّل الكمية المتوفرة في المخزون).
    final inCartAlready =
        _cart.items.where((i) => i.barcode == product.barcode).isNotEmpty;
    final currentQtyInCart = inCartAlready
        ? _cart.items.firstWhere((i) => i.barcode == product.barcode).stock
        : 0;
    if (currentQtyInCart + 1 > product.stock) {
      _showSnack('الكمية المتوفرة في المخزون غير كافية');
      return;
    }
    setState(() {
      _cart.addOrMerge(product.copyWith(), 1);
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty) return;

    final product = await _productController.getByBarcode(code);
    if (product == null) {
      _showSnack('لا يوجد منتج بهذا الباركود');
      return;
    }
    _addToCart(product);
    setState(() => _showCartMobile = true);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final result =
        await showCheckoutSheet(context, total: _cart.grandTotal);
    if (result == null) return;

    setState(() => _saving = true);
    try {
      int? customerId;
      if (result.customerPhone != null || result.customerName != 'عميل نقدي') {
        customerId = await _customerController.findOrCreate(
          name: result.customerName,
          phone: result.customerPhone,
        );
      }

      await _invoiceController.createInvoice(
        cartItems: _cart.items,
        customerId: customerId,
        customerName: result.customerName,
        paymentStatus: result.paymentStatus,
        paidAmount: result.paidAmount,
      );

      setState(() {
        _cart.clear();
        _showCartMobile = false;
      });
      await _loadProducts(); // لتحديث الكميات المتبقية في الواجهة
      if (mounted) _showSnack('تم حفظ الفاتورة بنجاح');
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ الفاتورة: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('نقطة البيع'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _cart.isEmpty
                  ? null
                  : () => setState(() => _cart.clear()),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scanBarcode,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : (isWide ? _buildWide() : _buildNarrow()),
      ),
    );
  }

  Widget _buildNarrow() {
    return _showCartMobile ? _buildCartPanel() : _buildProductsPanel();
  }

  Widget _buildWide() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildProductsPanel()),
        Container(
          width: 380,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.black12)),
          ),
          child: _buildCartPanel(),
        ),
      ],
    );
  }

  Widget _buildProductsPanel() {
    final filtered = _filtered;

    return Column(
      children: [
        Container(
          color: _primary,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الباركود...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final selected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected ? Colors.transparent : Colors.white30),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: selected ? _primary : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('لا توجد منتجات'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _productTile(filtered[i]),
                ),
        ),
        if (MediaQuery.of(context).size.width < 720 && !_cart.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _showCartMobile = true),
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                label: Text(
                  'عرض السلة • ${_cart.grandTotal.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _productTile(ProductModel p) {
    final isOut = p.stock <= 0;
    final isLow = p.isLow;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isOut ? null : () => _addToCart(p),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOut
                      ? Colors.grey.withOpacity(0.1)
                      : _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: isOut ? Colors.grey : _primary, size: 22),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 4),
              Text('${p.sellingPrice.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      color: _primary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                isOut ? 'نفد المخزون' : (isLow ? 'كمية محدودة' : 'متوفر'),
                style: TextStyle(
                  fontSize: 10.5,
                  color: isOut ? Colors.red : (isLow ? Colors.orange : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width < 720)
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => setState(() => _showCartMobile = false),
                ),
              const Text('السلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(child: Text('السلة فارغة'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = _cart.items[i];
                    return _CartItemWidget(
                      name: item.name,
                      price: item.sellingPrice,
                      qty: item.stock,
                      onAdd: () => setState(() => item.stock += 1),
                      onRemove: () => setState(() {
                        if (item.stock > 1) {
                          item.stock -= 1;
                        } else {
                          _cart.removeAt(i);
                        }
                      }),
                      onDelete: () => setState(() => _cart.removeAt(i)),
                    );
                  },
                ),
        ),
        _buildSummary(),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          _row('المجموع', '${_cart.grandTotal.toStringAsFixed(2)} ر.س',
              bold: true, color: _primary, fontSize: 16),
          const SizedBox(height: 4),
          _row('الربح المتوقع', '${_cart.expectedProfit.toStringAsFixed(2)} ر.س',
              color: Colors.green),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_cart.isEmpty || _saving) ? null : _checkout,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _saving
                    ? 'جارِ الحفظ...'
                    : 'إتمام البيع • ${_cart.grandTotal.toStringAsFixed(2)} ر.س',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize,
                  color: bold ? null : Colors.grey[700])),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}

class _CartItemWidget extends StatelessWidget {
  final String name;
  final double price;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  const _CartItemWidget({
    required this.name,
    required this.price,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('$price ر.س', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                _btn(Icons.remove, Colors.red, onRemove),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  alignment: Alignment.center,
                  child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                _btn(Icons.add, Colors.green, onAdd),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text((price * qty).toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primary)),
              InkWell(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

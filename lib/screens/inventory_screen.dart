import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled2/model/product.dart';
import '../controller/product_controller.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum StockFilter { all, available, low, outOfStock, hidden }

class _InventoryScreenState extends State<InventoryScreen> {
  StockFilter _filter = StockFilter.all;
  String _searchQuery = '';

  final ProductController product=ProductController();
  List<ProductModel>_products=[];
  @override
  void initState()
  {
    super.initState();
    _loadData();
  }
  Future<void>_loadData() async
  {
    List<ProductModel>data=await product.GetAll();
    if (!mounted) return;
    setState(() {
      _products = data;
    });
  }
  int _countByFilter(StockFilter filter) {
    return _products.where((p) {
      final stock = p.stock as int;
      final min = p.minAlert as int;
      final hidden = p.isHidden  == 1;

      switch (filter) {
        case StockFilter.all:
          return !hidden;
        case StockFilter.available:
          return !hidden && stock > min;
        case StockFilter.low:
          return !hidden && stock > 0 && stock <= min;
        case StockFilter.outOfStock:
          return !hidden && stock == 0;
        case StockFilter.hidden:
          return hidden;
      }
      return false;
    }).length;
  }

  List<ProductModel> get _filtered {
    return _products.where((p) {
      final hidden = p.isHidden == 1;
      final stock = p.stock as int;
      final min = p.minAlert as int;

      // فلتر الإخفاء
      if (_filter == StockFilter.hidden) {
        if (!hidden) return false;
      } else {
        if (hidden) return false;
      }

      // البحث
      final q = _searchQuery.toLowerCase().trim();
      if (q.isNotEmpty) {
        final match = p.name.toString().toLowerCase().contains(q) ||
            p.barcode.toString().contains(q);
        if (!match) return false;
      }

      // فلتر الحالة
      switch (_filter) {
        case StockFilter.all:
          return true;
        case StockFilter.available:
          return stock > min;
        case StockFilter.low:
          return stock > 0 && stock <= min;
        case StockFilter.outOfStock:
          return stock == 0;
        case StockFilter.hidden:
          return true;
      }
    }).toList();
  }

  // ============ الإحصائيات ============
  int get _totalProducts =>
      _products.where((p) => p.isHidden != true).length;
  int get _availableCount =>
      _products.where((p) => p.isHidden != true && (p.stock as int) > (p.minAlert as int)).length;
  int get _lowCount =>
      _products.where((p) => p.isHidden != true && (p.stock as int) > 0 && (p.stock as int) <= (p.minAlert as int)).length;
  int get _outCount =>
      _products.where((p) => p.isHidden != true && (p.stock as int) == 0).length;

  String _money(num v) => '${v.toStringAsFixed(2)} ر.ي';

  // ============ حالة المنتج ============
  Color _statusColor(ProductModel p) {
    if (p.isHidden == true) return Colors.grey;
    final stock = p.stock as int;
    final min = p.minAlert as int;
    if (stock == 0) return Colors.red;
    if (stock <= min) return Colors.orange;
    return Colors.green;
  }

  String _statusText(ProductModel p) {
    if (p.isHidden == true) return 'مخفي';
    final stock = p.stock as int;
    final min = p.minAlert as int;
    if (stock == 0) return 'نفد';
    if (stock <= min) return 'قريب من النفاد';
    return 'متوفر';
  }

  // ============ العمليات ============

  // 1) إضافة كمية
  void _showAddQuantitySheet(ProductModel producted) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // مؤشر السحب
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // الرأس
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_box_outlined,
                          color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إضافة كمية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF0F5132),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            producted.name,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // الكمية الحالية
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 18, color: Color(0xFF0F5132)),
                      const SizedBox(width: 8),
                      Text(
                        'الكمية الحالية: ',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${producted.stock}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F5132),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // حقل الكمية
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: 'وحدة',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل الكمية';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) {
                      return 'أدخل رقماً أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // أزرار
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {

                          if (!formKey.currentState!.validate()) return;
                          final added = int.parse(controller.text);
                          setState(() async {
                            producted.stock =
                                (producted.stock as int) + added;
                            bool f= await product.Update(producted.id as int,producted);
                            _loadData();
                            Navigator.pop(sheetContext);
                            HapticFeedback.mediumImpact();
                            _snack(
                                'تمت إضافة $added إلى "${producted.name}"');
                          });
                        },
                        icon: const Icon(Icons.check,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'إضافة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2) تعديل المنتج
  void _editProduct(ProductModel producted) {
    final nameCtrl =
    TextEditingController(text: producted.name as String);
    final barcodeCtrl =
    TextEditingController(text: producted.barcode as String);
    final categoryCtrl =
    TextEditingController(text: producted.category as String);
    final costCtrl = TextEditingController(
        text: (producted.costPrice as double).toStringAsFixed(2));
    final sellCtrl = TextEditingController(
        text: (producted.sellingPrice as double).toStringAsFixed(2));
    final minAlertCtrl = TextEditingController(
        text: (producted.minAlert as int).toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تعديل المنتج',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF0F5132),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _fieldLabel('اسم المنتج *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _inputDeco('اسم المنتج'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel('الباركود *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: barcodeCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: _inputDeco('الباركود'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel('الفئة'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: categoryCtrl,
                    decoration: _inputDeco('مثال: ألبان'),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('سعر التكلفة *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: costCtrl,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _inputDeco('0.00',
                                  suffix: 'ر.س'),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'مطلوب';
                                }
                                if (double.tryParse(v) == null) {
                                  return 'خطأ';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('سعر البيع *'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: sellCtrl,
                              keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _inputDeco('0.00',
                                  suffix: 'ر.س'),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'مطلوب';
                                }
                                final n = double.tryParse(v);
                                if (n == null) return 'خطأ';
                                final cost = double.tryParse(costCtrl.text);
                                if (cost != null && n < cost) {
                                  return 'أقل من التكلفة';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel('حد التنبيه'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: minAlertCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('5'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'مطلوب';
                      if (int.tryParse(v) == null) return 'خطأ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5132),
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            setState(() async {
                              producted.name = nameCtrl.text.trim();
                              producted.barcode = barcodeCtrl.text.trim();
                              producted.category = categoryCtrl.text.trim();
                              producted.costPrice = double.parse(costCtrl.text.trim());
                              producted.sellingPrice = double.parse(sellCtrl.text.trim());
                              producted.minAlert = int.parse(minAlertCtrl.text.trim());
                              await product.Update(producted.id as int, producted);
                              _loadData();
                              Navigator.pop(sheetContext);
                              _snack('تم تحديث المنتج بنجاح');

                            });
                          },
                          icon: const Icon(Icons.check,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'حفظ التعديلات',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 3) إخفاء / إظهار
  Future<void> _toggleVisibility(ProductModel producted) async {
    final bool newHiddenState = !producted.hidden;
    final updatedProduct = producted.copyWith(isHidden: newHiddenState ? 1 : 0,);
    bool result = await product.Update(updatedProduct.id!, updatedProduct);
    if (result) {
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere((p) => p.id == updatedProduct.id);
        if (index != -1) {
          _products[index] = updatedProduct;
        }
      });
      HapticFeedback.selectionClick();
      _snack(
        newHiddenState
            ? 'تم إخفاء "${updatedProduct.name}"'
            : 'تم إظهار "${updatedProduct.name}"',
      );
    } else {
      if (!mounted) return;
      _snack('فشل تعديل حالة المنتج');
    }
  }
  // 4) حذف
  void _confirmDelete(ProductModel producted) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف "${producted.name}"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() async {
                product.Delete(producted.id as int);
                _loadData();
                _products.remove(product);
                _snack('تم حذف "${producted.name}"');
              });
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ============ UI Helpers ============
  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? const Color(0xFF0F5132),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Color(0xFF0F5132),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {String? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  // ============ البناء ============
  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('إدارة المخزون'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => {
                _loadData(),
                _snack('تم التحديث')},

            ),
          ],
        ),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) => _buildProductCard(items[i]),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0F5132),
          onPressed: () async {
            // فتح شاشة إضافة منتج
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddProductScreen()),
            );
            _loadData();
            // TODO: تحديث القائمة بعد العودة
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'إضافة منتج',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ============ الرأس ============
  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF0F5132),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          // الإحصائيات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _headerStat(
                    'الإجمالي',
                    '$_totalProducts',
                    Icons.inventory_2_outlined,
                    Colors.white,
                  ),
                ),
                _divider(),
                Expanded(
                  child: _headerStat(
                    'متوفر',
                    '$_availableCount',
                    Icons.check_circle_outline,
                    Colors.green[300]!,
                  ),
                ),
                _divider(),
                Expanded(
                  child: _headerStat(
                    'قليل',
                    '$_lowCount',
                    Icons.warning_amber_rounded,
                    Colors.orange[300]!,
                  ),
                ),
                _divider(),
                Expanded(
                  child: _headerStat(
                    'نفد',
                    '$_outCount',
                    Icons.error_outline,
                    Colors.red[300]!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // البحث
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
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
          const SizedBox(height: 12),

          // الفلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('الكل', StockFilter.all),
                const SizedBox(width: 8),
                _chip('متوفر', StockFilter.available),
                const SizedBox(width: 8),
                _chip('قريب من النفاد', StockFilter.low),
                const SizedBox(width: 8),
                _chip('نفد', StockFilter.outOfStock),
                const SizedBox(width: 8),
                _chip('مخفي', StockFilter.hidden),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _headerStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, StockFilter filter) {
    final selected = _filter == filter;
    final count = _countByFilter(filter);

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF198754)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white30,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.25)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ بطاقة المنتج ============
  Widget _buildProductCard(ProductModel product) {
    final stock = product.stock as int;
    final min = product.minAlert as int;
    final cost = product.costPrice as double;
    final sell = product.sellingPrice as double;
    final isHidden = product.isHidden == true;
    final profit = sell - cost;
    final margin = cost > 0 ? (profit / cost) * 100 : 0;
    final statusColor = _statusColor(product);
    final statusText = _statusText(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHidden ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHidden
              ? Colors.grey[300]!
              : statusColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // الجزء العلوي: المعلومات
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أيقونة
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isHidden
                        ? Icons.visibility_off_outlined
                        : Icons.inventory_2_outlined,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                // التفاصيل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isHidden
                                    ? Colors.grey[600]
                                    : Colors.black87,
                                decoration: isHidden
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.qr_code,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            product.barcode,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F5132)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.category.isEmpty ? "غير مصنف" : product.category,
                              style: const TextStyle(
                                color: Color(0xFF0F5132),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // الأسعار والكمية
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _infoChip(
                            'البيع',
                            _money(sell),
                            const Color(0xFF0F5132),
                          ),
                          _infoChip(
                            'التكلفة',
                            _money(cost),
                            Colors.grey[700]!,
                          ),
                          _infoChip(
                            'الربح',
                            '${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(0)}%)',
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // شريط المخزون
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              border: Border(
                top: BorderSide(color: statusColor.withOpacity(0.15)),
                bottom: BorderSide(color: statusColor.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  'المخزون: ',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$stock',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' / حد التنبيه: $min',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // الأزرار الأربعة
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.add_box_outlined,
                  label: 'كمية',
                  color: Colors.green,
                  onTap: () => _showAddQuantitySheet(product),
                ),
                _actionButton(
                  icon: Icons.edit_outlined,
                  label: 'تعديل',
                  color: Colors.blue,
                  onTap: () => _editProduct(product),
                ),
                _actionButton(
                  icon: isHidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: isHidden ? 'إظهار' : 'إخفاء',
                  color: Colors.orange,
                  onTap: () => _toggleVisibility(product),
                ),
                _actionButton(
                  icon: Icons.delete_outline,
                  label: 'حذف',
                  color: Colors.red,
                  onTap: () => _confirmDelete(product),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isLast
                  ? null
                  : Border(
                left: BorderSide(
                    color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ Empty State ============
  Widget _buildEmpty() {
    String message = 'لا توجد منتجات مطابقة';
    IconData icon = Icons.search_off;

    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_filter == StockFilter.hidden) {
      message = 'لا توجد منتجات مخفية';
      icon = Icons.visibility_off_outlined;
    } else if (_filter != StockFilter.all) {
      message = 'لا توجد منتجات في هذه الفئة';
      icon = Icons.inventory_2_outlined;
    } else if (_products.isEmpty) {
      message = 'لا توجد منتجات بعد';
      icon = Icons.inventory_2_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F5132).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: const Color(0xFF0F5132).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F5132),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _products.isEmpty
                ? 'اضغط على "إضافة منتج" للبدء'
                : 'جرّب تعديل البحث أو الفلتر',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
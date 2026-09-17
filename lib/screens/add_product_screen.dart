import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../barcode_scanner_screen.dart';
import '../controller/product_controller.dart';
import '../model/cart_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _barcodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minAlertCtrl = TextEditingController(text: '5');
  final _notesCtrl = TextEditingController();
  ProductController p=ProductController();
  bool _isSaving = false;
  bool _hasBarcodeError = false;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _costCtrl.dispose();
    _sellCtrl.dispose();
    _stockCtrl.dispose();
    _minAlertCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
  // ===== الحفظ =====
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _isSaving = true);
    try {
      final minAlert = int.tryParse(_minAlertCtrl.text.trim()) ?? 0;
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
      final sellingPrice = double.tryParse(_sellCtrl.text.trim()) ?? 0.0;
      final costPrice = double.tryParse(_costCtrl.text.trim()) ?? 0.0;

      final categoryText = _categoryCtrl.text.trim();
      final category = categoryText.isEmpty ? 1 : (int.tryParse(categoryText) ?? categoryText);
      final String rawBarcode = _barcodeCtrl.text.trim();
      final String normalizedBarcode = BarcodeNormalizer.normalize(rawBarcode);
      final product = {
        'name': _nameCtrl.text.trim(),
        'barcode': normalizedBarcode.trim(),
        'category': category,
        'min_alert': minAlert,
        'stock': stock,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await p.Insert(product);

      if (!mounted) return;
      if (result >= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ المنتج بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.pop(context);
        }
      else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشلت عملية حفظ المنتج')),);
         }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      // التأكد من إيقاف مؤشر التحميل في جميع الأحوال (سواء نجح أو فشل)
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  // ===== حسابات مباشرة =====
  double get _profit {
    final c = double.tryParse(_costCtrl.text) ?? 0;
    final s = double.tryParse(_sellCtrl.text) ?? 0;
    return s - c;
  }

  double get _profitMargin {
    final c = double.tryParse(_costCtrl.text) ?? 0;
    if (c <= 0) return 0;
    return (_profit / c) * 100;
  }

  bool get _isValidPrices {
    final c = double.tryParse(_costCtrl.text) ?? 0;
    final s = double.tryParse(_sellCtrl.text) ?? 0;
    return c > 0 && s > 0 && s >= c;
  }

// ===== المسح =====
  Future<void> _openScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      await HapticFeedback.mediumImpact();

      if (!mounted) return;

      setState(() {
        _barcodeCtrl.text = result;
        _hasBarcodeError = false;
      });
    }
  }


  void _reset() {
    _formKey.currentState?.reset();
    _barcodeCtrl.clear();
    _nameCtrl.clear();
    _categoryCtrl.clear();
    _costCtrl.clear();
    _sellCtrl.clear();
    _stockCtrl.text = '0';
    _minAlertCtrl.text = '5';
    _notesCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 850;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('إضافة منتج جديد'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تفريغ الحقول',
              onPressed: _reset,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ============ تخطيط الشاشات الكبيرة ============
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // النموذج
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBarcodeSection(),
                const SizedBox(height: 16),
                _buildBasicInfoSection(),
                const SizedBox(height: 16),
                _buildPricingSection(),
                const SizedBox(height: 16),
                _buildStockSection(),
                const SizedBox(height: 16),
                _buildNotesSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // المعاينة المباشرة
        Container(
          width: 340,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.black12)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildLivePreview(),
          ),
        ),
      ],
    );
  }

  // ============ تخطيط الجوال ============
  Widget _buildNarrowLayout() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBarcodeSection(),
        const SizedBox(height: 16),
        _buildBasicInfoSection(),
        const SizedBox(height: 16),
        _buildPricingSection(),
        const SizedBox(height: 16),
        _buildStockSection(),
        const SizedBox(height: 16),
        _buildNotesSection(),
        const SizedBox(height: 100),
      ],
    );
  }

  // ============ 1. قسم الباركود ============
  Widget _buildBarcodeSection() {
    return _sectionCard(
      icon: Icons.qr_code_2,
      title: 'الباركود',
      required: true,
      color: const Color(0xFF0F5132),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() => _hasBarcodeError = false),
                  decoration: InputDecoration(
                    hintText: 'مثال: 6281000123456',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: Icon(
                      Icons.qr_code,
                      color: _hasBarcodeError
                          ? Colors.red
                          : const Color(0xFF0F5132),
                    ),
                    suffixIcon: _barcodeCtrl.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _barcodeCtrl.clear();
                          _hasBarcodeError = false;
                        });
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    errorText: _hasBarcodeError
                        ? 'هذا الباركود مستخدم مسبقاً'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _hasBarcodeError
                            ? Colors.red
                            : Colors.grey[300]!,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'الباركود مطلوب';
                    }
                    if (v.trim().length < 6) {
                      return 'الباركود قصير جداً (6 أرقام على الأقل)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              _scanButton(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'امسح الباركود بالكاميرا أو أدخله يدوياً',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF198754),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: _openScanner,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'مسح',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 2. قسم المعلومات الأساسية ============
  Widget _buildBasicInfoSection() {
    return _sectionCard(
      icon: Icons.info_outline,
      title: 'المعلومات الأساسية',
      required: true,
      color: Colors.blue,
      child: Column(
        children: [
          _fieldLabel('اسم المنتج', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(
              hint: 'مثال: حليب المراعي 1 لتر',
              icon: Icons.inventory_2_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'اسم المنتج مطلوب';
              }
              if (v.trim().length < 2) {
                return 'الاسم قصير جداً';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('الفئة'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _categoryCtrl,
            decoration: _inputDecoration(
              hint: 'مثال: ألبان، بقالة، مشروبات',
              icon: Icons.category_outlined,
            ),
          ),
          const SizedBox(height: 10),
          // شرائح الفئات السريعة
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'ألبان',
              'بقالة',
              'مشروبات',
              'زيوت',
              'مخبوزات',
              'منظفات',
            ].map((cat) {
              final selected = _categoryCtrl.text == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _categoryCtrl.text = selected ? '' : cat;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF0F5132)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF0F5132)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : const Color(0xFF0F5132),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============ 3. قسم الأسعار ============
  Widget _buildPricingSection() {
    final profit = _profit;
    final margin = _profitMargin;
    final isValid = _isValidPrices;

    return _sectionCard(
      icon: Icons.attach_money,
      title: 'الأسعار',
      required: true,
      color: Colors.green,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('سعر التكلفة', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        hint: '0.00',
                        icon: Icons.shopping_cart_outlined,
                        suffix: 'ر.س',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('سعر البيع', required: true),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _sellCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        hint: '0.00',
                        icon: Icons.point_of_sale_outlined,
                        suffix: 'ر.س',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'مطلوب';
                        }
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        final cost = double.tryParse(_costCtrl.text);
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

          // حساب الربح المباشر
          if (_costCtrl.text.isNotEmpty && _sellCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid
                    ? Colors.green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isValid
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isValid
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isValid
                          ? Icons.trending_up
                          : Icons.warning_amber_rounded,
                      color: isValid ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isValid
                              ? 'الربح لكل وحدة'
                              : 'سعر البيع أقل من التكلفة!',
                          style: TextStyle(
                            color: isValid
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isValid)
                          Text(
                            '${profit.toStringAsFixed(2)} ر.س  •  هامش ${margin.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 4. قسم المخزون ============
  Widget _buildStockSection() {
    return _sectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'المخزون',
      color: Colors.orange,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('الكمية الأولية'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: '0',
                        icon: Icons.inventory,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        final n = int.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('حد التنبيه'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _minAlertCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        hint: '5',
                        icon: Icons.warning_amber_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        final n = int.tryParse(v);
                        if (n == null || n < 0) return 'رقم غير صحيح';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.orange[800], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حد التنبيه: عندما تصل الكمية لهذا الرقم سيظهر تنبيه "قريب من النفاد"',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 5. قسم الملاحظات ============
  Widget _buildNotesSection() {
    return _sectionCard(
      icon: Icons.notes_outlined,
      title: 'ملاحظات (اختياري)',
      color: Colors.grey,
      child: TextFormField(
        controller: _notesCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'أي ملاحظات إضافية عن المنتج...',
          hintTextDirection: TextDirection.rtl,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ============ المعاينة المباشرة ============
  Widget _buildLivePreview() {
    final name = _nameCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final sell = double.tryParse(_sellCtrl.text) ?? 0;
    final stock = int.tryParse(_stockCtrl.text) ?? 0;
    final minAlert = int.tryParse(_minAlertCtrl.text) ?? 5;
    final hasPrices = _isValidPrices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // عنوان المعاينة
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F5132).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.visibility_outlined,
                  color: Color(0xFF0F5132), size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'معاينة مباشرة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0F5132),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // بطاقة المنتج
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F5132), Color(0xFF198754)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F5132).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'اسم المنتج' : name,
                      style: TextStyle(
                        color: name.isEmpty
                            ? Colors.white54
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 14),
              if (sell > 0)
                Text(
                  '${sell.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '0.00 ر.س',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _previewTag(
                    Icons.inventory_2_outlined,
                    'المخزون: $stock',
                    stock == 0
                        ? Colors.red[300]!
                        : Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 8),
                  if (hasPrices)
                    _previewTag(
                      Icons.trending_up,
                      'ربح ${_profit.toStringAsFixed(1)}',
                      const Color(0xFF20C997),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // تفاصيل إضافية
        _previewRow('الباركود',
            barcode.isEmpty ? '—' : barcode),
        _previewRow('الفئة',
            category.isEmpty ? '—' : category),
        _previewRow('حد التنبيه', '$minAlert'),
        _previewRow(
          'الحالة',
          stock == 0
              ? 'نفد'
              : stock <= minAlert
              ? 'قريب من النفاد'
              : 'متوفر',
          valueColor: stock == 0
              ? Colors.red
              : stock <= minAlert
              ? Colors.orange
              : Colors.green,
        ),

        if (name.isNotEmpty && hasPrices) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F5132).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF0F5132).withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF0F5132), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'جاهز للحفظ',
                    style: TextStyle(
                      color: const Color(0xFF0F5132),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _previewTag(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              )),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============ الشريط السفلي ============
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close,
                    color: Colors.grey, size: 18),
                label: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? 'جارٍ الحفظ...' : 'حفظ المنتج',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ عناصر مساعدة ============

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
    bool required = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس القسم
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                if (required)
                  const Text(' *',
                      style:
                      TextStyle(color: Colors.red, fontSize: 14)),
                const Spacer(),
              ],
            ),
          ),
          // المحتوى
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF212529),
          ),
        ),
        if (required)
          const Text(' *',
              style: TextStyle(color: Colors.red, fontSize: 13)),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      prefixIcon: Icon(icon, color: const Color(0xFF0F5132), size: 20),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
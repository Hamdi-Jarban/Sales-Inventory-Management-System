import 'package:untitled2/model/product.dart';
class BarcodeNormalizer {
  BarcodeNormalizer._();

  /// يحوّل الباركود أو الرابط إلى الصيغة القانونية
  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) return '';

    String cleaned = raw
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]'), '')
        .trim();

    // 1. إذا كان النص عبارة عن رابط صريح
    final Uri? uri = Uri.tryParse(cleaned);
    if (uri != null && (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {

      // إذا كنت تريد استخراج الكود من نهاية الرابط (مثلاً: https://site.com/products/880123)
      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        if (lastSegment.isNotEmpty) {
          return lastSegment.toUpperCase(); // يُرجع "880123"
        }
      }

      // أو إذا كنت تخزن الرابط كاملاً في قاعدة البيانات:
      return cleaned;
    }

    // 2. إذا كان باركود عادي (نص/أرقام)
    return cleaned
        .replaceAll(RegExp(r'[\s\u00A0]+'), '')
        .toUpperCase();
  }

  /// التحقق من صلاحية الباركود أو الرابط
  static bool isValid(String normalized) {
    if (normalized.isEmpty || normalized.length > 2048) return false;

    // قبول الروابط الصريحة
    if (Uri.tryParse(normalized)?.hasAbsolutePath ?? false) {
      return true;
    }

    // قبول الباركودات الاعتيادية (تحوي رموز شائعة)
    return RegExp(r'^[A-Z0-9\-_.:?=/&]+$').hasMatch(normalized);
  }

  static String key(String? raw) => normalize(raw);
}
/// ═══════════════════════════════════════════════════════════════
/// CartService
/// إدارة سلة المشتريات بمنطق Idempotent (لا تسجيل مزدوج)
/// ═══════════════════════════════════════════════════════════════
class CartService {
  final List<ProductModel> _items = [];
  final Map<String, int> _indexByBarcode = {};

  List<ProductModel> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get uniqueCount => _items.length;
  int get totalPieces =>
      _items.fold(0, (sum, item) => sum + (item.stock ?? 0));

  /// الإجمالي المالي
  double get grandTotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// إجمالي التكلفة
  double get totalCost =>
      _items.fold(0.0, (sum, item) => sum + item.lineCost);

  /// الربح المتوقع
  double get expectedProfit => grandTotal - totalCost;

  /// إضافة منتج أو دمج كميته إن وُجد بنفس الباركود.
  /// Returns: true إذا أُضيف كمنتج جديد، false إذا تم الدمج.
  bool addOrMerge(ProductModel product, int quantity) {
    final String canonicalKey = BarcodeNormalizer.key(product.barcode);

    if (_indexByBarcode.containsKey(canonicalKey)) {
      final int index = _indexByBarcode[canonicalKey]!;
      final existing = _items[index];
      existing.stock = (existing.stock ?? 0) + quantity;
      return false;
    }

    product.barcode = canonicalKey;
    product.stock = quantity;
    _indexByBarcode[canonicalKey] = _items.length;
    _items.add(product);
    return true;
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    _indexByBarcode.remove(BarcodeNormalizer.key(removed.barcode));
    _rebuildIndex();
  }

  void clear() {
    _items.clear();
    _indexByBarcode.clear();
  }

  void _rebuildIndex() {
    _indexByBarcode.clear();
    for (int i = 0; i < _items.length; i++) {
      _indexByBarcode[BarcodeNormalizer.key(_items[i].barcode)] = i;
    }
  }
}
class ProductModel {
  int? id;
  String name;
  double costPrice;
  double sellingPrice;
  String barcode;
  int minAlert;
  int stock;
  int isHidden;
  String category;

  ProductModel({
    this.id,
    required this.name,
    required this.costPrice,
    required this.sellingPrice,
    required this.barcode,
    this.minAlert = 5,
    this.stock = 0,
    this.isHidden = 0,
    this.category = "",
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      costPrice: (map['cost_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      barcode: map['barcode'] as String,
      minAlert: (map['min_alert'] as num?)?.toInt() ?? 5,
      stock: (map['stock'] as num).toInt(),
      isHidden: (map['is_hidden'] as num?)?.toInt() ?? 0,
      // ملاحظة: كانت هذه القيمة مفقودة سابقاً فكانت الفئة تُفرَّغ
      // في كل مرة تُقرأ فيها بيانات المنتج من القاعدة.
      category: (map['category'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'barcode': barcode,
      'min_alert': minAlert,
      'stock': stock,
      'is_hidden': isHidden,
      'category': category,
    };
  }

  ProductModel copyWith({
    int? id,
    String? name,
    double? costPrice,
    double? sellingPrice,
    String? barcode,
    int? minAlert,
    int? stock,
    int? isHidden,
    String? category,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      barcode: barcode ?? this.barcode,
      minAlert: minAlert ?? this.minAlert,
      stock: stock ?? this.stock,
      isHidden: isHidden ?? this.isHidden,
      category: category ?? this.category,
    );
  }

  double get lineTotal => sellingPrice * stock;
  double get lineCost => costPrice * stock;

  /// ربح السطر
  double get lineProfit => lineTotal - lineCost;

  bool get hidden => isHidden == 1;
  bool get isAvailable => stock > minAlert && !hidden;
  bool get isLow => stock > 0 && stock <= minAlert && !hidden;
  bool get isOutOfStock => stock == 0 && !hidden;

  set hidden(bool value) => isHidden = value ? 1 : 0;
}

/// حالة دفع الفاتورة
enum PaymentStatus { paid, partial, unpaid }

extension PaymentStatusX on PaymentStatus {
  String get dbValue {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.unpaid:
        return 'unpaid';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'مدفوعة';
      case PaymentStatus.partial:
        return 'دفع جزئي';
      case PaymentStatus.unpaid:
        return 'غير مدفوعة';
    }
  }

  static PaymentStatus fromDb(String value) {
    switch (value) {
      case 'partial':
        return PaymentStatus.partial;
      case 'unpaid':
        return PaymentStatus.unpaid;
      default:
        return PaymentStatus.paid;
    }
  }
}

class InvoiceItemModel {
  int? id;
  int? invoiceId;
  int? productId;
  String name;
  int qty;
  double price;
  double cost;

  InvoiceItemModel({
    this.id,
    this.invoiceId,
    this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.cost,
  });

  double get lineTotal => price * qty;
  double get lineProfit => (price - cost) * qty;

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int?,
      productId: map['product_id'] as int?,
      name: map['name'] as String,
      qty: (map['qty'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'product_id': productId,
      'name': name,
      'qty': qty,
      'price': price,
      'cost': cost,
    };
  }
}

class InvoiceModel {
  int? id;
  int? customerId;
  String customerName;
  double total;
  double cost;
  double profit;
  String paymentMethod;
  PaymentStatus paymentStatus;
  double paidAmount;
  String createdAt;
  List<InvoiceItemModel> items;

  InvoiceModel({
    this.id,
    this.customerId,
    this.customerName = 'عميل نقدي',
    required this.total,
    required this.cost,
    required this.profit,
    this.paymentMethod = 'نقدي',
    this.paymentStatus = PaymentStatus.paid,
    double? paidAmount,
    required this.createdAt,
    this.items = const [],
  }) : paidAmount = paidAmount ?? total;

  /// المبلغ المتبقي على العميل
  double get remainingAmount =>
      (total - paidAmount) < 0 ? 0 : (total - paidAmount);

  bool get isSettled => paymentStatus == PaymentStatus.paid;

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? 'عميل نقدي',
      total: (map['total'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      profit: (map['profit'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? 'نقدي',
      paymentStatus:
          PaymentStatusX.fromDb((map['payment_status'] as String?) ?? 'paid'),
      paidAmount: (map['paid_amount'] as num?)?.toDouble(),
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'total': total,
      'cost': cost,
      'profit': profit,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus.dbValue,
      'paid_amount': paidAmount,
      'created_at': createdAt,
    };
  }
}

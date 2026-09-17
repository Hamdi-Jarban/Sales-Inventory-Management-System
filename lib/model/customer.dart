class CustomerModel {
  int? id;
  String name;
  String? phone;
  String? email;
  String? notes;
  String? createdAt;

  CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.createdAt,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
    };
  }
}

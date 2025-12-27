// lib/models/product_model.dart

class Product {
  final int? id;
  final String name;
  final double price;
  final DateTime lastUsed;
  final int usageCount;

  Product({
    this.id,
    required this.name,
    required this.price,
    DateTime? lastUsed,
    this.usageCount = 1,
  }) : lastUsed = lastUsed ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'last_used': lastUsed.toIso8601String(),
      'usage_count': usageCount,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      lastUsed: DateTime.parse(map['last_used'] as String),
      usageCount: map['usage_count'] as int? ?? 1,
    );
  }

    Product copyWith({
    int? id,
    String? name,
    double? price,
    DateTime? lastUsed,
    int? usageCount,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
    );
  }
  
}
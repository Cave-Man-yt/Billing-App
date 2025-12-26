// lib/models/bill_item_model.dart

class BillItem {
  final int? id;
  final String productName;
  final double quantity;
  final double price;
  final double total;

  BillItem({
    this.id,
    required this.productName,
    required this.quantity,
    required this.price,
  }) : total = quantity * price;

  Map<String, dynamic> toMap(int billId) {
    return {
      'bill_id': billId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as int?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
    );
  }

  BillItem copyWith({
    String? productName,
    double? quantity,
    double? price,
  }) {
    return BillItem(
      id: id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }
}
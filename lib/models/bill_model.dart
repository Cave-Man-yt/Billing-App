// lib/models/bill_model.dart
class Bill {
  final int? id;
  final String billNumber;
  final int? customerId;
  final String customerName;
  final String? customerCity;
  final bool isCredit;
  final double subtotal;
  final double discount;
  final double total;

  // Transient fields - NOT final so copyWith can override them
  double amountPaid;
  double previousBalance;
  double newBalance;
  double grandTotal;

  final DateTime createdAt;

  Bill({
    this.id,
    required this.billNumber,
    this.customerId,
    required this.customerName,
    this.customerCity,
    this.isCredit = false,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    this.amountPaid = 0.0,
    this.previousBalance = 0.0,
    this.newBalance = 0.0,
    this.grandTotal = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Bill copyWith({
    int? id,
    String? billNumber,
    int? customerId,
    String? customerName,
    String? customerCity,
    bool? isCredit,
    double? subtotal,
    double? discount,
    double? total,
    double? amountPaid,
    double? previousBalance,
    double? newBalance,
    double? grandTotal,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerCity: customerCity ?? this.customerCity,
      isCredit: isCredit ?? this.isCredit,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      grandTotal: grandTotal ?? this.grandTotal,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_city': customerCity,
      'is_credit': isCredit ? 1 : 0,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String,
      customerCity: map['customer_city'] as String?,
      isCredit: (map['is_credit'] as int?) == 1,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      // Transient defaults when loading from DB
      amountPaid: 0.0,
      previousBalance: 0.0,
      newBalance: 0.0,
      grandTotal: 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
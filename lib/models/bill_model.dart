// lib/models/bill_model.dart

class Bill {
  final int? id;
  final String billNumber;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerCity;
  final bool isCredit;
  final double subtotal;
  final double discount;
  final double total;
  // Transient fields (not persisted by current DB schema)
  final double amountPaid;
  final double previousBalance;
  final double newBalance;
  final double grandTotal;
  final DateTime createdAt;

  Bill({
    this.id,
    required this.billNumber,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
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
      customerPhone: map['customer_phone'] as String?,
      customerAddress: map['customer_address'] as String?,
      isCredit: (map['is_credit'] as int) == 1,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      // transient fields default to 0. Application layer may populate these.
      amountPaid: 0.0,
      previousBalance: 0.0,
      newBalance: 0.0,
      grandTotal: 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
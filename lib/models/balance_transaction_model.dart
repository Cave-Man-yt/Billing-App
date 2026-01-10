
class BalanceTransaction {
  final int? id;
  final int customerId;
  final double amount; // Positive = Charge (Bill), Negative = Payment
  final String type; // 'BILL', 'PAYMENT', 'ADJUSTMENT'
  final String? description;
  final int? billId;
  final DateTime createdAt;

  BalanceTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    this.description,
    this.billId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'transaction_type': type,
      'description': description,
      'bill_id': billId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BalanceTransaction.fromMap(Map<String, dynamic> map) {
    return BalanceTransaction(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      type: map['transaction_type'] as String,
      description: map['description'] as String?,
      billId: map['bill_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

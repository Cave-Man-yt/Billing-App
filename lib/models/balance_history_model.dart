
// lib/models/balance_history_model.dart

class BalanceHistory {
  final int? id;
  final int customerId;
  final int? billId;
  final double amount;
  final String description;
  final DateTime createdAt;

  BalanceHistory({
    this.id,
    required this.customerId,
    this.billId,
    required this.amount,
    required this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'bill_id': billId,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BalanceHistory.fromMap(Map<String, dynamic> map) {
    return BalanceHistory(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      billId: map['bill_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

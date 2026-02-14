// lib/models/bill_model.dart
class Bill {
  final int? id;
  final String billNumber;
  final int? customerId;
  final String customerName;
  final String? customerCity;
  final bool isCredit;
  final double subtotal;
  final double packageCharge;
  final int boxCount;
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
    this.packageCharge = 0.0,
    this.boxCount = 0,
    required this.total,
    this.amountPaid = 0.0,
    this.previousBalance = 0.0,
    this.newBalance = 0.0,
    this.grandTotal = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Helpers for UI/Print display - strictly non-negative
  double get displayPreviousBalance =>
      previousBalance < 0 ? 0.0 : previousBalance;
  double get displayNewBalance => newBalance < 0 ? 0.0 : newBalance;

  // For Grand Total, if the calculation (Total + Prev Balance) is negative
  // (meaning they had huge credit), we display 0 to indicate they owe nothing.
  double get displayGrandTotal {
    final calculated = total + previousBalance;
    return calculated < 0 ? 0.0 : calculated;
  }

  Bill copyWith({
    int? id,
    String? billNumber,
    int? customerId,
    String? customerName,
    String? customerCity,
    bool? isCredit,
    double? subtotal,
    double? packageCharge,
    int? boxCount,
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
      packageCharge: packageCharge ?? this.packageCharge,
      boxCount: boxCount ?? this.boxCount,
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
      'package_charge': packageCharge,
      'box_count': boxCount,
      'total': total,
      'amount_paid': amountPaid, // ← ADD THIS
      'previous_balance': previousBalance, // ← ADD THIS
      'new_balance': newBalance, // ← ADD THIS
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
      packageCharge: (map['package_charge'] as num?)?.toDouble() ?? 0.0,
      boxCount: (map['box_count'] as int?) ?? 0,
      total: (map['total'] as num).toDouble(),
      // ← CHANGED: Load these from DB instead of defaulting to 0
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (map['previous_balance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (map['new_balance'] as num?)?.toDouble() ?? 0.0,
      grandTotal: 0.0, // This can be calculated on the fly
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

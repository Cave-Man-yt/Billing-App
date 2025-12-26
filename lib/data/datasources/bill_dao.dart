import 'package:sqflite/sqflite.dart';
import '../datasources/local_database_helper.dart';
import 'dart:convert';

class BillDao {
  Future<int> saveBill({
    required double total,
    required String customerName,
    required bool hasCredit,
    required String itemsJson,
    String shopName = "LG",
  }) async {
    final db = await LocalDatabaseHelper().database;
    return await db.insert('bills', {
      'date': DateTime.now().toIso8601String(),
      'total': total,
      'customer_name': customerName,
      'has_credit': hasCredit ? 1 : 0,
      'items_json': itemsJson,
      'shop_name': shopName,
    });
  }

  Future <List<BillData>> getBills() async {
    final db = await LocalDatabaseHelper().database;
    final results = await db.query('bills', orderBy: 'date DESC');
    return results.map((row) => BillData.fromMap(row)).toList();
  }
}

class BillData {
  final int id;
  final DateTime date;
  final double total;
  final String customerName;
  final bool hasCredit;
  final List<Map<String, dynamic>> items;

  BillData({
    required this.id,
    required this.date,
    required this.total,
    required this.customerName,
    required this.hasCredit,
    required this.items,
  });

  factory BillData.fromMap(Map<String, dynamic> map) {
    return BillData(
      id: map['id'],
      date: DateTime.parse(map['date']),
      total: map['total'].toDouble(),
      customerName: map['customer_name'] ?? 'Cash',
      hasCredit: map['has_credit'] == 1,
      items: (jsonDecode(map['items']) as List)
          .cast<Map<String, dynamic>>(),
    );
  }
}
import 'package:sqflite/sqflite.dart';
import '../datasources/local_database_helper.dart';

class ProductDao {
  Future<void> saveProduct(String name, double price) async {
    final db = await LocalDatabaseHelper().database;
    await db.insert('products',
      {'name': name, 'price': price},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.rawUpdate(
      'UPDATE products SET usage_count = usage_count + 1, last_used = datetime("now") WHERE name = ?',
      [name],
    );
  }

  Future<List<ProductData>> getSuggestions(String query) async {
    final db = await LocalDatabaseHelper().database;
    final results = await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'usage_count DESC, last_used DESC',
      limit: 5,
    );

    return results.map((row) => ProductData.fromMap(row)).toList();
  }

  Future<List<ProductData>> getTopProducts() async {
    final db = await LocalDatabaseHelper().database;
    final results = await db.query(
      'products',
      orderBy: 'usage_count DESC',
      limit: 10,
    );

    return results.map((row) => ProductData.fromMap(row)).toList();
  }
}

class ProductData {
  final int? id;
  final String name;
  final double price;
  final int usageCount;

  ProductData({
    this.id,
    required this.name,
    required this.price,
    required this.usageCount,
  });

  factory ProductData.fromMap(Map<String, dynamic> map) {
    return ProductData(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      usageCount: map['usage_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'usage_count': usageCount,
    };
  }
}
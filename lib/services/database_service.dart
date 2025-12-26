// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/customer_model.dart';
import 'package:billing_app/models/product_model.dart';
import 'package:billing_app/models/bill_item_model.dart';

/// Singleton database service for managing SQLite operations
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  /// Get database instance (creates if doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wholesale_billing.db');
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        // Ensure migrations for customers table: add `city` and `balance` if missing.
        try {
          final cols = await db.rawQuery("PRAGMA table_info(customers);");
          final names = cols.map((r) => r['name'] as String).toSet();
          if (!names.contains('city')) {
            await db.execute("ALTER TABLE customers ADD COLUMN city TEXT;");
          }
          if (!names.contains('balance')) {
            await db.execute("ALTER TABLE customers ADD COLUMN balance REAL DEFAULT 0.0;");
            // If the old schema had current_credit, copy it into balance
            if (names.contains('current_credit')) {
              await db.execute('UPDATE customers SET balance = current_credit;');
            }
          }
        } catch (e) {
          // ignore migration errors; table may not exist yet
        }
      },
    );
  }

  /// Create all database tables
  Future<void> _createDB(Database db, int version) async {
    // Customers table (simple: name, city, balance)
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        city TEXT,
        balance REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Products table (for memory/suggestions)
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        price REAL NOT NULL,
        last_used TEXT NOT NULL,
        usage_count INTEGER DEFAULT 1
      )
    ''');

    // Bills table
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_address TEXT,
        is_credit INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // Bill items table
    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_name TEXT NOT NULL,
        shop_address TEXT,
        shop_phone TEXT,
        shop_email TEXT,
        tax_percentage REAL DEFAULT 0.0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'shop_name': 'Your Shop Name',
      'shop_address': '',
      'shop_phone': '',
      'shop_email': '',
      'tax_percentage': 0.0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== CUSTOMER OPERATIONS ====================

  /// Create a new customer
  Future<int> createCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  /// Get all customers
  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final result = await db.query('customers', orderBy: 'name ASC');
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  /// Search customers by name or city
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'name LIKE ? OR city LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  /// Update customer
  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Update customer balance (set to newBalance)
  Future<int> updateCustomerBalance(int customerId, double newBalance) async {
    final db = await database;
    return await db.update(
      'customers',
      {
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  // ==================== PRODUCT OPERATIONS ====================

  /// Create or update product (for memory/suggestions)
  Future<void> upsertProduct(Product product) async {
    final db = await database;
    final existing = await db.query(
      'products',
      where: 'name = ?',
      whereArgs: [product.name],
    );

    if (existing.isNotEmpty) {
      // Update existing product
      final existingProduct = Product.fromMap(existing.first);
      await db.update(
        'products',
        {
          'price': product.price,
          'last_used': DateTime.now().toIso8601String(),
          'usage_count': existingProduct.usageCount + 1,
        },
        where: 'name = ?',
        whereArgs: [product.name],
      );
    } else {
      // Insert new product
      await db.insert('products', product.toMap());
    }
  }

  /// Search products for suggestions
  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'usage_count DESC, last_used DESC',
      limit: 10,
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  /// Get all products
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query(
      'products',
      orderBy: 'usage_count DESC, last_used DESC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  // ==================== BILL OPERATIONS ====================

  /// Create a new bill with items
  Future<int> createBill(Bill bill, List<BillItem> items) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Insert bill
      final billId = await txn.insert('bills', bill.toMap());

      // Insert bill items
      for (var item in items) {
        await txn.insert('bill_items', item.toMap(billId));

        // Update or insert product using the transaction to avoid DB locks
        final existing = await txn.query(
          'products',
          where: 'name = ?',
          whereArgs: [item.productName],
        );

        if (existing.isNotEmpty) {
          final existingProduct = Product.fromMap(existing.first);
          await txn.update(
            'products',
            {
              'price': item.price,
              'last_used': DateTime.now().toIso8601String(),
              'usage_count': existingProduct.usageCount + 1,
            },
            where: 'id = ?',
            whereArgs: [existingProduct.id],
          );
        } else {
          await txn.insert('products', Product(
            name: item.productName,
            price: item.price,
            lastUsed: DateTime.now(),
          ).toMap());
        }
      }

      // Customer balance is managed by the application layer (BillProvider).

      return billId;
    });
  }

  /// Get all bills
  Future<List<Bill>> getAllBills() async {
    final db = await database;
    final result = await db.query('bills', orderBy: 'created_at DESC');
    return result.map((map) => Bill.fromMap(map)).toList();
  }

  /// Get bill by ID
  Future<Bill?> getBillById(int id) async {
    final db = await database;
    final result = await db.query(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Bill.fromMap(result.first);
  }

  /// Get bill items
  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await database;
    final result = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    return result.map((map) => BillItem.fromMap(map)).toList();
  }

  /// Search bills
  Future<List<Bill>> searchBills(String query) async {
    final db = await database;
    final result = await db.query(
      'bills',
      where: 'bill_number LIKE ? OR customer_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Bill.fromMap(map)).toList();
  }

  // ==================== SETTINGS OPERATIONS ====================

  /// Get shop settings
  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    return result.first;
  }

  /// Update settings
  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    settings['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('settings', settings, where: 'id = 1');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

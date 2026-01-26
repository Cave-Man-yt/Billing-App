// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/customer_model.dart';
import 'package:billing_app/models/product_model.dart';
import 'package:billing_app/models/bill_item_model.dart';
import 'package:billing_app/models/balance_history_model.dart'; // Import BalanceHistory

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
      version: 2, // Increment database version
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // Add onUpgrade callback
      onOpen: (db) async {
        // Existing customer migrations (from version 1 or earlier)...
        try {
          final cols = await db.rawQuery("PRAGMA table_info(customers);");
          final names = cols.map((r) => r['name'] as String).toSet();
          if (!names.contains('city')) {
            await db.execute("ALTER TABLE customers ADD COLUMN city TEXT;");
          }
          // The 'balance' column should already be handled by _createDB or _onUpgrade for newer versions
          // For older dbs migrating to v1 then to v2, this ensures balance exists before we use it.
          if (!names.contains('balance')) {
            await db.execute("ALTER TABLE customers ADD COLUMN balance REAL DEFAULT 0.0;");
            if (names.contains('current_credit')) { // If an old column 'current_credit' exists
              await db.execute('UPDATE customers SET balance = current_credit;');
            }
          }
        } catch (e) {
          // ignore - likely column already exists or table doesn't exist yet (handled by onCreate)
        }
        
        // Existing bill migrations (from version 1 or earlier)...
        try {
          final billCols = await db.rawQuery("PRAGMA table_info(bills);");
          final billNames = billCols.map((r) => r['name'] as String).toSet();
          
          if (billNames.contains('discount') && !billNames.contains('package_charge')) {
            await db.execute("ALTER TABLE bills ADD COLUMN package_charge REAL DEFAULT 0.0;");
            await db.execute('UPDATE bills SET package_charge = discount;');
          } else if (!billNames.contains('package_charge')) {
            await db.execute("ALTER TABLE bills ADD COLUMN package_charge REAL DEFAULT 0.0;");
          }

          if(!billNames.contains('box_count')) {
            await db.execute("ALTER TABLE bills ADD COLUMN box_count INTEGER DEFAULT 0;");
          }
          
          if (!billNames.contains('customer_city')) {
            await db.execute("ALTER TABLE bills ADD COLUMN customer_city TEXT;");
          }
          if (!billNames.contains('customer_phone')) {
            await db.execute("ALTER TABLE bills ADD COLUMN customer_phone TEXT;");
          }
          if (!billNames.contains('customer_address')) {
            await db.execute("ALTER TABLE bills ADD COLUMN customer_address TEXT;");
          }
          if (!billNames.contains('amount_paid')) {
            await db.execute("ALTER TABLE bills ADD COLUMN amount_paid REAL DEFAULT 0.0;");
          }
          if (!billNames.contains('previous_balance')) {
            await db.execute("ALTER TABLE bills ADD COLUMN previous_balance REAL DEFAULT 0.0;");
          }
          if (!billNames.contains('new_balance')) {
            await db.execute("ALTER TABLE bills ADD COLUMN new_balance REAL DEFAULT 0.0;");
          }
        } catch (e) {
          // ignore
        }
      },
    );
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // This example assumes a linear upgrade path.
    // For more complex migrations, a switch statement on oldVersion is typical.
    if (oldVersion < 2) {
      // Add balance_history table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS balance_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          bill_id INTEGER,
          amount REAL NOT NULL,
          description TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
          FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE SET NULL
        )
      ''');
    }
    // Add other upgrade scripts for future versions here
    // if (oldVersion < 3) { ... }
  }

  /// Create all database tables (called only on first creation of DB)
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
        customer_city TEXT,
        customer_phone TEXT,
        customer_address TEXT,
        is_credit INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL,
        package_charge REAL DEFAULT 0.0,
        box_count INTEGER DEFAULT 0,
        total REAL NOT NULL,
        amount_paid REAL DEFAULT 0.0,
        previous_balance REAL DEFAULT 0.0,
        new_balance REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
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

    // Balance History table
    await db.execute('''
      CREATE TABLE balance_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        bill_id INTEGER,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE SET NULL
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
  /// If this is called for "editing" an old bill, we create a NEW bill (fresh billId)
  /// Old items are not relevant since we're always creating fresh records
  Future<int> createBill(Bill bill, List<BillItem> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Insert the bill row → get fresh billId
      final billId = await txn.insert('bills', bill.toMap());

      // NO NEED to delete old items — we're creating a completely new bill
      // (If you ever implement true "update existing bill", then add delete here)

      // Insert fresh bill items — NEVER pass 'id' so SQLite auto-generates
      for (var item in items) {
        await txn.insert(
          'bill_items',
          item.toMap(billId),  // ← This must NOT contain 'id' key
          // Optional: explicitly null out id to be 100% safe
          // conflictAlgorithm: ConflictAlgorithm.replace, // not needed
        );

        // Upsert product (fast suggestions + price memory)
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
            where: 'name = ?',
            whereArgs: [existingProduct.id],
          );
        } else {
          await txn.insert(
            'products',
            Product(
              name: item.productName,
              price: item.price,
            ).toMap(),
          );
        }
      }

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

  // ==================== BALANCE HISTORY OPERATIONS ====================

  /// Create a new balance history record
  Future<int> createBalanceHistory(BalanceHistory history) async {
    final db = await database;
    return await db.insert('balance_history', history.toMap());
  }

  /// Get all balance history records for a customer
  Future<List<BalanceHistory>> getBalanceHistoryForCustomer(int customerId) async {
    final db = await database;
    final result = await db.query(
      'balance_history',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => BalanceHistory.fromMap(map)).toList();
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

  Future<void> deleteBill(int billId) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [billId]);
    // bill_items cascade delete via FOREIGN KEY ON DELETE CASCADE
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);
  }

  /// Update an existing bill — overwrites bill row and replaces all items
  Future<void> updateBill(Bill bill, List<BillItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update the bill row
      await txn.update(
        'bills',
        bill.toMap(),
        where: 'id = ?',
        whereArgs: [bill.id],
      );

      // Delete old items
      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [bill.id]);

      // Insert new items with same bill_id
      for (var item in items) {
        await txn.insert('bill_items', item.toMap(bill.id!));
        
        // Upsert product (same as create)
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
            where: 'name = ?',
            whereArgs: [existingProduct.id],
          );
        } else {
          await txn.insert('products', Product(name: item.productName, price: item.price).toMap());
        }
      }
    });
  }
}
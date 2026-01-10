// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/customer_model.dart';
import 'package:billing_app/models/product_model.dart';
import 'package:billing_app/models/bill_item_model.dart';

/// Model for balance transactions
class BalanceTransaction {
  final int? id;
  final int customerId;
  final double amount;
  final String description;
  final String transactionType;
  final int? billId;
  final DateTime createdAt;

  BalanceTransaction({
    this.id,
    required this.customerId,
    required this.amount,
    required this.description,
    required this.transactionType,
    this.billId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'description': description,
      'transaction_type': transactionType,
      'bill_id': billId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BalanceTransaction.fromMap(Map<String, dynamic> map) {
    return BalanceTransaction(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      transactionType: map['transaction_type'] as String,
      billId: map['bill_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

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
        // Existing customer migrations
        try {
          final cols = await db.rawQuery("PRAGMA table_info(customers);");
          final names = cols.map((r) => r['name'] as String).toSet();
          if (!names.contains('city')) {
            await db.execute("ALTER TABLE customers ADD COLUMN city TEXT;");
          }
          if (!names.contains('balance')) {
            await db.execute("ALTER TABLE customers ADD COLUMN balance REAL DEFAULT 0.0;");
            if (names.contains('current_credit')) {
              await db.execute('UPDATE customers SET balance = current_credit;');
            }
          }
        } catch (e) {
          // ignore
        }
        
        // Bills table migrations
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

        // NEW: Create balance_transactions table if not exists
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS balance_transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              description TEXT NOT NULL,
              transaction_type TEXT NOT NULL,
              bill_id INTEGER,
              created_at TEXT NOT NULL,
              FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
            )
          ''');
          
          // Create index for faster queries
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_balance_transactions_customer 
            ON balance_transactions(customer_id, created_at DESC)
          ''');
        } catch (e) {
          // ignore - table might already exist
        }
      },
    );
  }

  /// Create all database tables
  Future<void> _createDB(Database db, int version) async {
    // Customers table
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

    // Products table
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

    // Balance transactions table (NEW)
    await db.execute('''
      CREATE TABLE balance_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        bill_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Create index for performance
    await db.execute('''
      CREATE INDEX idx_balance_transactions_customer 
      ON balance_transactions(customer_id, created_at DESC)
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

  Future<int> createCustomer(Customer customer) async {
    final db = await database;
    return await db.transaction((txn) async {
      final customerId = await txn.insert('customers', customer.toMap());

      // If opening balance > 0, record it as a transaction
      if (customer.balance > 0) {
        await txn.insert('balance_transactions', {
          'customer_id': customerId,
          'amount': customer.balance,
          'description': 'Opening Balance',
          'transaction_type': 'adjustment',
          'bill_id': null,
          'created_at': customer.createdAt.toIso8601String(),
        });
      }
      return customerId;
    });
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final result = await db.query('customers', orderBy: 'name ASC');
    return result.map((map) => Customer.fromMap(map)).toList();
  }

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

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

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

  // ==================== BALANCE TRANSACTION OPERATIONS ====================

  /// Insert a balance transaction (called internally by other methods)
  Future<int> insertBalanceTransaction(BalanceTransaction transaction) async {
    final db = await database;
    return await db.insert('balance_transactions', transaction.toMap());
  }

  /// Get balance transaction history for a customer (limit to recent 100)
  Future<List<BalanceTransaction>> getBalanceHistory(int customerId, {int limit = 100}) async {
    final db = await database;
    final result = await db.query(
      'balance_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((map) => BalanceTransaction.fromMap(map)).toList();
  }

  /// Add a payment transaction (reduces balance)
  Future<void> addPaymentTransaction(int customerId, double amount, String description) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get current balance
      final customerData = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      
      if (customerData.isEmpty) throw Exception('Customer not found');
      
      final currentBalance = (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance - amount;
      
      // Update customer balance
      await txn.update(
        'customers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
      
      // Insert transaction record (negative amount for payment)
      await txn.insert('balance_transactions', {
        'customer_id': customerId,
        'amount': -amount,
        'description': description,
        'transaction_type': 'payment',
        'bill_id': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Add a manual adjustment transaction
  Future<void> addAdjustmentTransaction(
    int customerId, 
    double amount, 
    String description,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get current balance
      final customerData = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      
      if (customerData.isEmpty) throw Exception('Customer not found');
      
      final currentBalance = (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;
      
      // Update customer balance
      await txn.update(
        'customers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
      
      // Insert transaction record
      await txn.insert('balance_transactions', {
        'customer_id': customerId,
        'amount': amount,
        'description': description,
        'transaction_type': 'adjustment',
        'bill_id': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // ==================== PRODUCT OPERATIONS ====================

  Future<void> upsertProduct(Product product) async {
    final db = await database;
    final existing = await db.query(
      'products',
      where: 'name = ?',
      whereArgs: [product.name],
    );

    if (existing.isNotEmpty) {
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
      await db.insert('products', product.toMap());
    }
  }

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

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query(
      'products',
      orderBy: 'usage_count DESC, last_used DESC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  // ==================== BILL OPERATIONS ====================

  Future<int> createBill(Bill bill, List<BillItem> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      final billId = await txn.insert('bills', bill.toMap());

      for (var item in items) {
        await txn.insert('bill_items', item.toMap(billId));

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
          await txn.insert(
            'products',
            Product(name: item.productName, price: item.price).toMap(),
          );
        }
      }

      // Insert balance transaction for the bill
      if (bill.customerId != null && bill.newBalance > 0) {
        final balanceChange = bill.newBalance - bill.previousBalance;
        await txn.insert('balance_transactions', {
          'customer_id': bill.customerId,
          'amount': balanceChange,
          'description': 'Bill ${bill.billNumber}: ₹${bill.total.toStringAsFixed(2)}',
          'transaction_type': 'bill',
          'bill_id': billId,
          'created_at': bill.createdAt.toIso8601String(),
        });
      }

      return billId;
    });
  }

  Future<void> updateBill(Bill bill, List<BillItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get original bill to calculate delta
      final originalData = await txn.query(
        'bills',
        where: 'id = ?',
        whereArgs: [bill.id],
        limit: 1,
      );
      
      if (originalData.isNotEmpty) {
        final originalBill = Bill.fromMap(originalData.first);
        
        // Calculate the actual impact on customer balance (Amount owed - Amount paid)
        final oldImpact = originalBill.total - originalBill.amountPaid;
        final newImpact = bill.total - bill.amountPaid;
        
        // The delta is the difference in impact
        // e.g. Old: Total 200, Paid 150 -> Impact +50
        //      New: Total 250, Paid 150 -> Impact +100
        //      Delta: 100 - 50 = +50 (Increase in debt)
        final delta = newImpact - oldImpact;
        
        // If there's a balance change, add adjustment transaction
        if (delta.abs() > 0.01 && bill.customerId != null) {
          await txn.insert('balance_transactions', {
            'customer_id': bill.customerId,
            'amount': delta,
            'description': 'Adjustment for edited bill ${bill.billNumber}: ${delta >= 0 ? '+' : ''}₹${delta.toStringAsFixed(2)}',
            'transaction_type': 'adjustment',
            'bill_id': bill.id,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Update the bill
      await txn.update(
        'bills',
        bill.toMap(),
        where: 'id = ?',
        whereArgs: [bill.id],
      );

      // Delete old items and insert new ones
      await txn.delete('bill_items', where: 'bill_id = ?', whereArgs: [bill.id]);

      for (var item in items) {
        await txn.insert('bill_items', item.toMap(bill.id!));
        
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
          await txn.insert('products', Product(name: item.productName, price: item.price).toMap());
        }
      }
    });
  }

  Future<List<Bill>> getAllBills() async {
    final db = await database;
    final result = await db.query('bills', orderBy: 'created_at DESC');
    return result.map((map) => Bill.fromMap(map)).toList();
  }

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

  Future<List<BillItem>> getBillItems(int billId) async {
    final db = await database;
    final result = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
    return result.map((map) => BillItem.fromMap(map)).toList();
  }

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

  Future<void> deleteBill(int billId) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [billId]);
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);
  }

  // ==================== SETTINGS OPERATIONS ====================

  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final result = await db.query('settings', limit: 1);
    return result.first;
  }

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    settings['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('settings', settings, where: 'id = 1');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
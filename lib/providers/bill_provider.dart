// lib/providers/bill_provider.dart
import 'package:billing_app/providers/customer_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';

class BillProvider with ChangeNotifier {
  List<Bill> _bills = [];
  List<BillItem> _currentBillItems = [];
  Customer? _currentCustomer;
  double _packageCharge = 0.0;
  int _boxCount = 0;
  bool _isLoading = false;

  // Editing mode for overwrite from history
  bool _isEditingExistingBill = false;
  int? _editingBillId;

  // Public getters
  List<Bill> get bills => List.unmodifiable(_bills);
  List<BillItem> get currentBillItems => _currentBillItems;
  Customer? get currentCustomer => _currentCustomer;
  double get packageCharge => _packageCharge;
  int get boxCount => _boxCount;
  bool get isLoading => _isLoading;

  bool get isEditingExistingBill => _isEditingExistingBill;
  int? get editingBillId => _editingBillId;

  double get subtotal => _currentBillItems.fold(0.0, (sum, item) => sum + item.total);
  double get total => subtotal + _packageCharge;

  BillProvider() {
    loadBills();
  }

  Future<void> loadBills() async {
    _isLoading = true;
    notifyListeners();
    try {
      _bills = await DatabaseService.instance.getAllBills();
    } catch (e) {
      debugPrint('Error loading bills: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  double roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  void addBillItem(BillItem item) {
    _currentBillItems.add(item);
    notifyListeners();
  }

  void updateBillItem(int index, BillItem item) {
    if (index >= 0 && index < _currentBillItems.length) {
      _currentBillItems[index] = item;
      notifyListeners();
    }
  }

  void removeBillItem(int index) {
    if (index >= 0 && index < _currentBillItems.length) {
      _currentBillItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearBillItems() {
    _currentBillItems.clear();
    notifyListeners();
  }

  void setCustomer(Customer? customer) {
    _currentCustomer = customer;
    notifyListeners();
  }

  void setPackageCharge(double value) {
    _packageCharge = value;
    notifyListeners();
  }

  void setBoxCount(int value) {
    _boxCount = value;
    notifyListeners();
  }

  String generateBillNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    return 'INV-$dateStr-$timeStr';
  }

  // Called from History when tapping a bill to edit
  Future<void> loadBillForEditing(Bill bill, List<BillItem> items) async {
    _currentBillItems = List.from(items);
    _packageCharge = bill.packageCharge;
    _boxCount = bill.boxCount;

    // 🔴 FIX: Get CURRENT customer balance from DB, not historical balance
    // This ensures reprinted bills show the correct current balance
    final db = await DatabaseService.instance.database;
    final customerData = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [bill.customerId],
      limit: 1,
    );
    
    double currentBalance = bill.previousBalance; // fallback to historical
    if (customerData.isNotEmpty) {
      currentBalance = (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
    }

    _currentCustomer = Customer(
      id: bill.customerId,
      name: bill.customerName,
      city: bill.customerCity,
      balance: currentBalance, // Use CURRENT balance, not historical
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  void startEditingExistingBill(int billId) {
    _isEditingExistingBill = true;
    _editingBillId = billId;
    notifyListeners();
  }

  void clearEditingMode() {
    _isEditingExistingBill = false;
    _editingBillId = null;
  }

  Future<Bill?> saveBill(
    double amountPaid, {
    bool clearAfterSave = true,
    CustomerProvider? customerProvider,
  }) async {
    if (_currentBillItems.isEmpty) return null;
    if (_currentCustomer == null) return null;

    try {
      final db = await DatabaseService.instance.database;
      
      // CRITICAL: Always get the CURRENT customer balance from DB
      final customerData = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [_currentCustomer!.id],
        limit: 1,
      );
      
      double currentCustomerBalance = 0.0;
      if (customerData.isNotEmpty) {
        currentCustomerBalance = (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
      }

      double previousBalance = currentCustomerBalance;

      if (_isEditingExistingBill && _editingBillId != null) {
        // When editing, we need to "undo" the effect of the old bill first
        final originalBill = _bills.firstWhere((b) => b.id == _editingBillId);

        // Calculate what the balance was BEFORE the original bill was created
        final originalBillEffect = originalBill.newBalance - originalBill.previousBalance;
        previousBalance = roundMoney(currentCustomerBalance - originalBillEffect);

        debugPrint('🔧 Editing bill ${originalBill.billNumber}:');
        debugPrint('   Current customer balance in DB: $currentCustomerBalance');
        debugPrint('   Original bill effect: $originalBillEffect (${originalBill.previousBalance} → ${originalBill.newBalance})');
        debugPrint('   Restored previous balance: $previousBalance');
      } else {
        // For new bills, previous balance is simply the current customer balance
        previousBalance = currentCustomerBalance;
        debugPrint('💚 New bill - using current customer balance as previous: $previousBalance');
      }

      final grandTotal = roundMoney(total + previousBalance);
      final newBalance = roundMoney(grandTotal - amountPaid);
      final bool willBeCredit = newBalance > 0.01;

      debugPrint('📊 Bill calculation:');
      debugPrint('   Bill total: $total');
      debugPrint('   Previous balance: $previousBalance');
      debugPrint('   Grand total: $grandTotal');
      debugPrint('   Amount paid: $amountPaid');
      debugPrint('   New balance: $newBalance');

      final bill = Bill(
        id: _isEditingExistingBill ? _editingBillId : null,
        billNumber: _isEditingExistingBill
            ? _bills.firstWhere((b) => b.id == _editingBillId).billNumber
            : generateBillNumber(),
        customerId: _currentCustomer!.id,
        customerName: _currentCustomer!.name,
        customerCity: _currentCustomer!.city,
        isCredit: willBeCredit,
        previousBalance: previousBalance,
        subtotal: subtotal,
        packageCharge: _packageCharge,
        boxCount: _boxCount,
        total: total,
        amountPaid: amountPaid,
        newBalance: newBalance,
        grandTotal: grandTotal,
      );

      final itemsToSave = List<BillItem>.from(_currentBillItems);

      if (_isEditingExistingBill && bill.id != null) {
        // 🔴 UPDATE EXISTING BILL
        // Check if anything actually changed before updating
        final originalBill = _bills.firstWhere((b) => b.id == _editingBillId);
        final hasChanges = 
            bill.total != originalBill.total ||
            bill.amountPaid != originalBill.amountPaid ||
            bill.packageCharge != originalBill.packageCharge ||
            bill.boxCount != originalBill.boxCount ||
            bill.newBalance != originalBill.newBalance;
        
        if (hasChanges) {
          // The database service will automatically:
          // 1. Calculate the delta (new balance - old balance)
          // 2. Add an adjustment transaction if there's a change
          // 3. Update the bill record
          await DatabaseService.instance.updateBill(bill, itemsToSave);
          debugPrint('✅ Updated existing bill with transaction adjustment');
        } else {
          debugPrint('ℹ️ No changes detected - skipping database update');
          // Still need to reload to refresh UI
          await loadBills();
          if (clearAfterSave) {
            clearCurrentBill();
          }
          clearEditingMode();
          return bill;
        }
      } else {
        // 🔴 CREATE NEW BILL
        // The database service will automatically:
        // 1. Insert the bill
        // 2. Add a balance transaction for this bill
        await DatabaseService.instance.createBill(bill, itemsToSave);
        debugPrint('✅ Created new bill with transaction record');
      }

      // Update customer balance to the new balance
      if (_currentCustomer!.id != null) {
        await DatabaseService.instance.updateCustomerBalance(_currentCustomer!.id!, newBalance);
        debugPrint('💾 Updated customer balance in DB to: $newBalance');
      }

      if (customerProvider != null) {
        await customerProvider.refresh();
      }

      await loadBills();
      if (clearAfterSave) {
        clearCurrentBill();
      }
      clearEditingMode();
      return bill;
    } catch (e) {
      debugPrint('❌ Error saving bill: $e');
      rethrow;
    }
  }

  void clearCurrentBill() {
    _currentBillItems.clear();
    _currentCustomer = null;
    _packageCharge = 0.0;
    _boxCount = 0;
    clearEditingMode();
    notifyListeners();
  }

  Future<List<BillItem>> getBillItems(int billId) async {
    return await DatabaseService.instance.getBillItems(billId);
  }

  Future<List<Bill>> searchBills(String query) async {
    if (query.isEmpty) return _bills;
    return await DatabaseService.instance.searchBills(query);
  }
}
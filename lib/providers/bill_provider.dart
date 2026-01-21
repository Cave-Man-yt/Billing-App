// lib/providers/bill_provider.dart
import 'package:billing_app/providers/customer_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';

/// Manages the state of bills, bill items, and billing calculations.
/// 
/// Handles creating new bills, editing existing ones, and calculating totals
/// including package charges, box counts, and customer balances.
/// Provider class for managing Bill state and operations.
/// Handles loading, creating, updating, and deleting bills.
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

  /// Loads all bills from the database and updates the state.
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

    // NOTE: Show HISTORICAL balance in UI (what it was when bill was created)
    // This makes the preview look correct
    _currentCustomer = Customer(
      id: bill.customerId,
      name: bill.customerName,
      city: bill.customerCity,
      balance: bill.previousBalance, // Use the historical balance from the bill
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

  /// Saves the current bill to the database.
  /// 
  /// Calculates final balances, updates customer records, and handles both
  /// new bill creation and existing bill updates.
  /// 
  /// [amountPaid] is the amount paid by the customer for this specific bill.
  /// Saves the current bill to the database.
  /// 
  /// If [amountPaid] is provided, it calculates the new balance.
  /// [clearAfterSave] determines if the current bill state should be reset after saving.
  Future<Bill?> saveBill(
    double amountPaid, {
    bool clearAfterSave = true,
    CustomerProvider? customerProvider,
  }) async {
    if (_currentBillItems.isEmpty) return null;
    if (_currentCustomer == null) return null;

    try {
      final db = await DatabaseService.instance.database;
      
      // NOTE: Always get the CURRENT customer balance from DB
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
        // NOTE: When editing, we need to "undo" the effect of the old bill first
        final originalBill = _bills.firstWhere((b) => b.id == _editingBillId);

        // Calculate what the balance was BEFORE the original bill was created
        // Original bill added: (originalBill.newBalance - originalBill.previousBalance) to customer
        // So to undo it: currentBalance - (newBalance - previousBalance) of original
        final originalBillEffect = originalBill.newBalance - originalBill.previousBalance;
        previousBalance = roundMoney(currentCustomerBalance - originalBillEffect);

        debugPrint('🔧 Editing bill ${originalBill.billNumber}:');
        debugPrint('   Current customer balance in DB: $currentCustomerBalance');
        debugPrint('   Original bill effect: $originalBillEffect (${originalBill.previousBalance} → ${originalBill.newBalance})');
        debugPrint('   Restored previous balance: $previousBalance');
      } else {
        // NOTE: For new bills, previous balance is simply the current customer balance
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
        await DatabaseService.instance.updateBill(bill, itemsToSave);
        debugPrint('✅ Updated existing bill');
      } else {
        await DatabaseService.instance.createBill(bill, itemsToSave);
        debugPrint('✅ Created new bill');
      }

      // NOTE: Update customer balance to the new balance
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

  bool isLatestBill(int billId, int customerId) {
    // Filter bills for this customer
    final customerBills = _bills.where((b) => b.customerId == customerId).toList();
    if (customerBills.isEmpty) return true;

    // Find the bill in question
    try {
      final bill = customerBills.firstWhere((b) => b.id == billId);
      
      // Check if there are any newer bills (created after this one)
      // We use isAfter and a small tolerance for safety, but strict comparison should work
      // effectively checking if ANY bill has createdAt > this bill.
      final hasNewer = customerBills.any((b) => b.createdAt.isAfter(bill.createdAt));
      
      return !hasNewer;
    } catch (e) {
      // If bill not found in list (shouldn't happen), assume it's not editable safely
      return false;
    }
  }
}
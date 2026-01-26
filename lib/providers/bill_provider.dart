// lib/providers/bill_provider.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';
import 'customer_provider.dart'; // Import CustomerProvider

/// Manages the state of bills, bill items, and billing calculations.
///
/// Handles creating new bills, editing existing ones, and calculating totals
/// including package charges, box counts, and customer balances.
/// Provider class for managing Bill state and operations.
/// Handles loading, creating, updating, and deleting bills.
class BillProvider with ChangeNotifier {
  CustomerProvider _customerProvider; // Make it non-final

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

  BillProvider(this._customerProvider) {
    loadBills();
  }
  
  void update(CustomerProvider customerProvider) {
    _customerProvider = customerProvider;
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
  Future<Bill?> saveBill({
    required double amountPaid,
    bool clearAfterSave = true,
  }) async { // Removed onCustomerUpdate
    if (_currentBillItems.isEmpty || _currentCustomer == null) {
      return null;
    }

    try {
      final db = await DatabaseService.instance.database;

      final customerData = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [_currentCustomer!.id],
        limit: 1,
      );

      double currentCustomerBalance = 0.0;
      if (customerData.isNotEmpty) {
        currentCustomerBalance =
            (customerData.first['balance'] as num?)?.toDouble() ?? 0.0;
      }

      double previousBalance = currentCustomerBalance;

      if (_isEditingExistingBill && _editingBillId != null) {
        final originalBill =
            _bills.firstWhere((b) => b.id == _editingBillId);
        // The original bill's effect on balance should be reversed
        // to get the balance *before* that bill was applied.
        final originalBillImpact = originalBill.newBalance - originalBill.previousBalance;
        previousBalance = roundMoney(currentCustomerBalance - originalBillImpact);
      } else {
        previousBalance = currentCustomerBalance;
      }

      final grandTotal = roundMoney(total + previousBalance);
      final newBalance = roundMoney(grandTotal - amountPaid);
      final bool willBeCredit = newBalance > 0.01;

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
      int savedBillId;

      if (_isEditingExistingBill && bill.id != null) {
        await DatabaseService.instance.updateBill(bill, itemsToSave);
        savedBillId = bill.id!;
        final index = _bills.indexWhere((b) => b.id == bill.id);
        if (index != -1) {
          _bills[index] = bill;
        }
      } else {
        savedBillId = await DatabaseService.instance.createBill(bill, itemsToSave);
        _bills.insert(0, bill.copyWith(id: savedBillId));
      }

      // Update customer balance and record history via CustomerProvider
      if (_currentCustomer!.id != null) {
        final balanceChange = newBalance - currentCustomerBalance;
        String description = _isEditingExistingBill
            ? 'Bill #${bill.billNumber} (Updated)'
            : 'Bill #${bill.billNumber}';

        await _customerProvider.updateCustomerBalance(
          _currentCustomer!.id!,
          newBalance,
          description,
          billId: savedBillId,
        );
      }

      if (clearAfterSave) {
        clearCurrentBill();
      }
      clearEditingMode();

      notifyListeners();
      return bill.copyWith(id: savedBillId);
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
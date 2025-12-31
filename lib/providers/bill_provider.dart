// lib/providers/bill_provider.dart
import 'package:billing_app/providers/customer_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
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

  // REMOVE THESE LINES - they're no longer needed:
  // double _currentAmountPaid = 0.0;
  // double get currentAmountPaid => _currentAmountPaid;

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

  _currentCustomer = Customer(
    id: bill.customerId,
    name: bill.customerName,
    city: bill.customerCity,
    // Use the previousBalance stored in the bill (this is the correct historical value)
    balance: bill.previousBalance,
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
    double previousBalance = _currentCustomer!.balance;

    if (_isEditingExistingBill && _editingBillId != null) {
      final originalBill = _bills.firstWhere((b) => b.id == _editingBillId);

      final db = await DatabaseService.instance.database;
      final originalCreatedAt = originalBill.createdAt.toIso8601String();
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) FROM bills WHERE customer_id = ? AND created_at > ?',
        [_currentCustomer!.id, originalCreatedAt],
      );
      final int count = Sqflite.firstIntValue(countResult) ?? 0;

      if (count == 0 && roundMoney(_currentCustomer!.balance) != roundMoney(originalBill.newBalance)) {
        // Manual edit detected - use current balance as previous (no reversion)
        previousBalance = _currentCustomer!.balance;
      } else {
        // Normal case or other bills - revert old effect
        previousBalance = roundMoney(
          _currentCustomer!.balance - originalBill.newBalance + originalBill.previousBalance,
        );
      }
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

    if (_isEditingExistingBill && bill.id != null) {
      await DatabaseService.instance.updateBill(bill, itemsToSave);
    } else {
      await DatabaseService.instance.createBill(bill, itemsToSave);
    }

    if (_currentCustomer!.id != null) {
      await DatabaseService.instance.updateCustomerBalance(_currentCustomer!.id!, newBalance);
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
    debugPrint('Error saving bill: $e');
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

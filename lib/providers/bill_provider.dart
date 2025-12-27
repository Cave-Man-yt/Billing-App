// lib/providers/bill_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../services/database_service.dart';

class BillProvider with ChangeNotifier {
  List<Bill> _bills = [];
  List<BillItem> _currentBillItems = [];
  Customer? _currentCustomer;
  double _discount = 0.0;
  bool _isLoading = false;

  // Editing mode for overwrite from history
  bool _isEditingExistingBill = false;
  int? _editingBillId;

  // Public getters
  List<Bill> get bills => List.unmodifiable(_bills);
  List<BillItem> get currentBillItems => _currentBillItems;
  Customer? get currentCustomer => _currentCustomer;
  double get discount => _discount;
  bool get isLoading => _isLoading;

  bool get isEditingExistingBill => _isEditingExistingBill;
  int? get editingBillId => _editingBillId;

  double get subtotal => _currentBillItems.fold(0.0, (sum, item) => sum + item.total);
  double get total => subtotal - _discount;

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

  void setDiscount(double value) {
    _discount = value;
    notifyListeners();
  }

  String generateBillNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    return 'INV-$dateStr-$timeStr';
  }

  // Called from History when tapping a bill to edit
  void loadBillForEditing(Bill bill, List<BillItem> items) {
    _currentCustomer = Customer(
      id: bill.customerId,
      name: bill.customerName,
      city: bill.customerCity,
      balance: bill.previousBalance,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _currentBillItems = List.from(items);
    _discount = bill.discount;
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

  Future<Bill?> saveBill(double amountPaid, {bool clearAfterSave = true}) async {
    if (_currentBillItems.isEmpty) return null;
    if (_currentCustomer == null) return null;

    try {
      final previousBalance = _currentCustomer!.balance;
      final grandTotal = total + previousBalance;
      final newBalance = grandTotal - amountPaid;
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
        discount: _discount,
        total: total,
        amountPaid: amountPaid,
        newBalance: newBalance,
        grandTotal: grandTotal,
      );

      final itemsToSave = List<BillItem>.from(_currentBillItems);

      if (_isEditingExistingBill && bill.id != null) {
        // Overwrite existing bill
        await DatabaseService.instance.updateBill(bill, itemsToSave);
      } else {
        // Create new bill
        await DatabaseService.instance.createBill(bill, itemsToSave);
      }

      // Update customer balance
      if (_currentCustomer!.id != null) {
        await DatabaseService.instance.updateCustomerBalance(_currentCustomer!.id!, newBalance);
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
    _discount = 0.0;
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
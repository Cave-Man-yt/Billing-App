// lib/providers/bill_provider.dart

import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class BillProvider with ChangeNotifier {
  List<Bill> _bills = [];
  List<BillItem> _currentBillItems = [];
  Customer? _currentCustomer;
  double _discount = 0.0;
  bool _isLoading = false;

  List<Bill> get bills => _bills;
  List<BillItem> get currentBillItems => _currentBillItems;
  Customer? get currentCustomer => _currentCustomer;
  double get discount => _discount;
  bool get isLoading => _isLoading;

  double get subtotal =>
      _currentBillItems.fold(0.0, (sum, item) => sum + item.total);
  
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

  Future<Bill?> saveBill(double amountPaid) async {
    if (_currentBillItems.isEmpty) return null;
    if (_currentCustomer == null) return null;

    try {
      final previousBalance = _currentCustomer!.balance;
      final grandTotal = total + previousBalance;
      final newBalance = (grandTotal - amountPaid);

      final bill = Bill(
        billNumber: generateBillNumber(),
        customerId: _currentCustomer!.id,
        customerName: _currentCustomer!.name,
        customerCity: _currentCustomer!.city,
        previousBalance: previousBalance,
        subtotal: subtotal,
        discount: _discount,
        total: total,
        amountPaid: amountPaid,
        newBalance: newBalance,
        grandTotal: grandTotal,
      );

      // make a copy of items for printing before clearing
      final itemsToSave = List<BillItem>.from(_currentBillItems);

      // persist bill and items
      await DatabaseService.instance.createBill(bill, itemsToSave);

      // update customer's balance in DB
      if (_currentCustomer!.id != null) {
        await DatabaseService.instance.updateCustomerBalance(_currentCustomer!.id!, newBalance);
      }

      await loadBills();

      clearCurrentBill();

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
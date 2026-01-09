// lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;

  CustomerProvider() {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _customers = await DatabaseService.instance.getAllCustomers();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      await DatabaseService.instance.createCustomer(customer);
      await loadCustomers();
    } catch (e) {
      debugPrint('Error adding customer: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await DatabaseService.instance.updateCustomer(customer);
      await loadCustomers();
    } catch (e) {
      debugPrint('Error updating customer: $e');
    }
  }

  /// Add a payment (reduces customer balance)
  Future<void> addPayment(int customerId, double amount, String description) async {
    try {
      await DatabaseService.instance.addPaymentTransaction(
        customerId,
        amount,
        description,
      );
      await loadCustomers();
      debugPrint('✅ Payment added: ₹${amount.toStringAsFixed(2)} for customer $customerId');
    } catch (e) {
      debugPrint('❌ Error adding payment: $e');
      rethrow;
    }
  }

  /// Add a manual adjustment to customer balance
  Future<void> addAdjustment(int customerId, double amount, String description) async {
    try {
      await DatabaseService.instance.addAdjustmentTransaction(
        customerId,
        amount,
        description,
      );
      await loadCustomers();
      debugPrint('✅ Adjustment added: ₹${amount.toStringAsFixed(2)} for customer $customerId');
    } catch (e) {
      debugPrint('❌ Error adding adjustment: $e');
      rethrow;
    }
  }

  /// Get balance transaction history for a customer
  Future<List<BalanceTransaction>> getBalanceHistory(int customerId) async {
    try {
      return await DatabaseService.instance.getBalanceHistory(customerId);
    } catch (e) {
      debugPrint('Error loading balance history: $e');
      return [];
    }
  }

  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCustomer = null;
    notifyListeners();
  }

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return _customers;
    return await DatabaseService.instance.searchCustomers(query);
  }

  Future<void> refresh() async {
    await loadCustomers();
  }
}
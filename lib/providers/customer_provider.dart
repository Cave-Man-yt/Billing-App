// lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';
import '../models/balance_history_model.dart'; // Import BalanceHistory

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
      final id = await DatabaseService.instance.createCustomer(customer);
      final newCustomer = customer.copyWith(id: id);
      _customers.add(newCustomer);

      // Record initial balance in history if not zero
      if (newCustomer.balance != 0) {
        await DatabaseService.instance.createBalanceHistory(
          BalanceHistory(
            customerId: newCustomer.id!,
            amount: newCustomer.balance,
            description: 'Initial balance',
            createdAt: newCustomer.createdAt,
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding customer: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await DatabaseService.instance.updateCustomer(customer);
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
    }
  }

  /// Update customer balance and record history
  Future<void> updateCustomerBalance(int customerId, double newBalance, String description, {int? billId}) async {
    try {
      final oldCustomer = _customers.firstWhere((c) => c.id == customerId);
      final oldBalance = oldCustomer.balance;
      
      await DatabaseService.instance.updateCustomerBalance(customerId, newBalance);
      
      // Record balance change in history
      final changedAmount = newBalance - oldBalance;
      if (changedAmount != 0) {
        await DatabaseService.instance.createBalanceHistory(
          BalanceHistory(
            customerId: customerId,
            billId: billId,
            amount: changedAmount,
            description: description,
          ),
        );
      }

      // Update the customer in the local list
      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = oldCustomer.copyWith(balance: newBalance);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating customer balance: $e');
    }
  }

  /// Deduct amount from customer balance and record as payment
  Future<void> deductCustomerPayment(int customerId, double amount, String description) async {
    try {
      final customer = _customers.firstWhere((c) => c.id == customerId);
      final newBalance = customer.balance - amount;

      await DatabaseService.instance.updateCustomerBalance(customerId, newBalance);

      // Record payment in history
      await DatabaseService.instance.createBalanceHistory(
        BalanceHistory(
          customerId: customerId,
          amount: -amount, // Negative for deduction
          description: description,
        ),
      );

      // Update the customer in the local list
      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = customer.copyWith(balance: newBalance);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deducting customer payment: $e');
    }
  }

  Future<List<BalanceHistory>> getCustomerBalanceHistory(int customerId) async {
    return await DatabaseService.instance.getBalanceHistoryForCustomer(customerId);
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
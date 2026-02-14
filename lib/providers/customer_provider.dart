// lib/providers/customer_provider.dart

import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/payment_model.dart';
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

  // Payment & Ledger Logic

  Future<void> addPayment(Payment payment) async {
    try {
      await DatabaseService.instance.addPayment(payment);
      await loadCustomers(); // Refresh balances
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding payment: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLedger(int customerId) async {
    final db = DatabaseService.instance;
    final allBills = await db.getAllBills(); // Optimization: Should filter by customerId in DB
    // But currently DatabaseService doesn't have getBillsByCustomer.
    // Let's filter here for now or add method to DB.
    // Adding method to DB is better but for speed:
    final customerBills = allBills.where((b) => b.customerId == customerId).toList();
    
    final payments = await db.getCustomerPayments(customerId);

    final ledger = <Map<String, dynamic>>[];

    // Add Bills (Debit) and Bill Payments (Credit)
    for (var bill in customerBills) {
      ledger.add({
        'type': 'bill',
        'date': bill.createdAt,
        'amount': bill.grandTotal > 0 ? bill.grandTotal : (bill.total + bill.packageCharge), // Total bill amount
        // Wait, bill.total includes items total. Grand total includes prev balance? 
        // We want the TRANSACTION amount (current bill total).
        // bill.total is items total. 
        // bill.grandTotal is usually used for display.
        // Let's check Bill model.
        // bill.total is subtotal of items. 
        // bill.grandTotal (if stored) is final amount.
        // But for ledger, we want the amount added to debt *today*.
        // That is (Total Items + Package Charge).
        // Previous balance is just carried forward, not a new debt.
        
        // Correct Logic:
        // Debit = bill.total + bill.packageCharge
        
        'debit': bill.total + bill.packageCharge, 
        'credit': 0.0,
        'description': 'Bill #${bill.billNumber}',
        'id': bill.id,
      });

      if (bill.amountPaid > 0) {
        ledger.add({
          'type': 'bill_payment',
          'date': bill.createdAt, // Same time
          'amount': bill.amountPaid,
          'debit': 0.0,
          'credit': bill.amountPaid,
          'description': 'Paid with Bill #${bill.billNumber}',
          'id': bill.id,
        });
      }
    }

    // Add Independent Payments (Credit)
    for (var payment in payments) {
      ledger.add({
        'type': 'payment',
        'date': payment.date,
        'amount': payment.amount,
        'debit': 0.0,
        'credit': payment.amount,
        'description': payment.notes ?? 'Payment Received',
        'id': payment.id,
      });
    }

    // Sort by date descending
    ledger.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return ledger;
  }
}
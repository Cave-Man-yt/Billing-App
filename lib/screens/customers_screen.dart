// lib/screens/customers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:billing_app/providers/customer_provider.dart';
import 'package:billing_app/models/customer_model.dart';
import 'package:billing_app/utils/app_theme.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  void _showAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddCustomerDialog(),
    );
  }

  void _showEditBalanceDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => EditBalanceDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, customerProvider, _) {
          if (customerProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (customerProvider.customers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: AppTheme.textHint),
                  SizedBox(height: 16),
                  Text('No customers yet', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customerProvider.customers.length,
            itemBuilder: (context, index) {
              final customer = customerProvider.customers[index];
              final hasBalance = customer.balance > 0;

              return Card(
                child: ListTile(
                  onTap: () => _showEditBalanceDialog(context, customer),
                  leading: CircleAvatar(
                    backgroundColor: hasBalance ? AppTheme.warningColor : AppTheme.accentColor,
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (customer.city != null) Text(customer.city!),
                      if (hasBalance)
                        Text(
                          'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: hasBalance,
                  trailing: hasBalance
                      ? const Icon(Icons.account_balance_wallet, color: AppTheme.warningColor)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  Future<void> _addCustomer() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    final customer = Customer(
      name: _nameController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      balance: double.tryParse(_balanceController.text) ?? 0.0,
    );

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.addCustomer(customer);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer added successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              control// File: lib/providers/bill_ler: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Opening Balance (₹)',
                prefixIcon: Icon(Icons.account_balance_wallet),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addCustomer,
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}

class EditBalanceDialog extends StatefulWidget {
  final Customer customer;

  const EditBalanceDialog({super.key, required this.customer});

  @override
  State<EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<EditBalanceDialog> {
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _balanceController.text = widget.customer.balance.toString();
  }

  Future<void> _updateBalance() async {
    final newBalance = double.tryParse(_balanceController.text) ?? 0.0;

    final updatedCustomer = widget.customer.copyWith(
      balance: newBalance,
      updatedAt: DateTime.now(),
    );

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    await customerProvider.updateCustomer(updatedCustomer);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Balance updated successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Balance - ${widget.customer.name}'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.customer.city ?? 'No city',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Balance (₹)',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will set the customer\'s current balance',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateBalance,
          child: const Text('Update'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }
}
// lib/screens/customers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/customer_provider.dart';
import '../models/customer_model.dart';
import '../utils/app_theme.dart';
import 'package:billing_app/services/database_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    setState(() {
      _filteredCustomers = customerProvider.customers;
    });
  }

  void _searchCustomers(String query) async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = customerProvider.customers;
      });
    } else {
      final results = await customerProvider.searchCustomers(query);
      if (mounted) {
        setState(() {
          _filteredCustomers = results;
        });
      }
    }
  }

  void _showAddCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddCustomerDialog(),
    ).then((_) => _loadCustomers());
  }

  void _showEditBalanceDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (_) => EditBalanceDialog(customer: customer),
    ).then((_) => _loadCustomers());
  }

  Future<void> _deleteCustomer(BuildContext context, Customer customer) async {
  // ← FIX: Store ALL references BEFORE any async operations
  final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Customer'),
      content: const Text('Are you sure you want to delete this customer? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  
  if (confirm != true) return;
  
  if (!mounted) return;
  
  await DatabaseService.instance.deleteCustomer(customer.id!);
  
  if (!mounted) return;
  
  await customerProvider.loadCustomers();
  _loadCustomers();
  
  if (mounted) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Customer deleted')),
    );
  }
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
              _loadCustomers();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          // ← NEW: Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customers by name or city...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: null,
              ),
              onChanged: _searchCustomers,
            ),
          ),
          // ← NEW: Customer list
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, _) {
                if (customerProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_filteredCustomers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 80, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty 
                              ? 'No customers yet'
                              : 'No customers found',
                          style: const TextStyle(
                              fontSize: 18, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    final hasBalance = customer.balance > 0;
                    return Card(
                      child: ListTile(
                        onTap: () => _showEditBalanceDialog(context, customer),
                        onLongPress: () => _deleteCustomer(context, customer),
                        leading: CircleAvatar(
                          backgroundColor:
                              hasBalance ? AppTheme.warningColor : AppTheme.accentColor,
                          child: Text(
                            customer.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.city != null) Text(customer.city!),
                            if (hasBalance)
                              Text(
                                'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        isThreeLine: hasBalance,
                        trailing: hasBalance
                            ? const Icon(Icons.account_balance_wallet,
                                color: AppTheme.warningColor)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _balanceController = TextEditingController();

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

  // ← FIX: Store references before async
  final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  await customerProvider.addCustomer(customer);

  if (!mounted) return;

  navigator.pop();
  messenger.showSnackBar(
    const SnackBar(
        content: Text('Customer added successfully'),
        backgroundColor: AppTheme.successColor),
  );
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
              controller: _cityController,
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
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _addCustomer, child: const Text('Add')),
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
  late final _balanceController = TextEditingController(
      text: widget.customer.balance.toStringAsFixed(2));

  Future<void> _updateBalance() async {
  final newBalance = double.tryParse(_balanceController.text) ?? 0.0;

  final updatedCustomer = widget.customer.copyWith(
    balance: newBalance,
    updatedAt: DateTime.now(),
  );

  // ← FIX: Store references before async
  final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  await customerProvider.updateCustomer(updatedCustomer);

  if (!mounted) return;

  navigator.pop();
  messenger.showSnackBar(
    const SnackBar(
        content: Text('Balance updated successfully'),
        backgroundColor: AppTheme.successColor),
  );
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
            Text(widget.customer.city ?? 'No city',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            TextField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Balance (₹)',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppTheme.warningColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'This will set the customer\'s current outstanding balance',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _updateBalance, child: const Text('Update')),
      ],
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }
}
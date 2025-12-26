// lib/widgets/customer_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../models/customer_model.dart';
import '../utils/app_theme.dart';

class CustomerSelector extends StatelessWidget {
  const CustomerSelector({super.key});

  void _showCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CustomerSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BillProvider, CustomerProvider>(
      builder: (context, billProvider, customerProvider, _) {
        final customer = billProvider.currentCustomer;

        return Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.backgroundLight,
          child: customer == null
              ? ElevatedButton.icon(
                  onPressed: () => _showCustomerDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('SELECT CUSTOMER'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              : Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: customer.balance > 0
                          ? AppTheme.warningColor
                          : AppTheme.accentColor,
                      child: Text(
                        customer.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: customer.balance > 0
                        ? Text(
                            'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : (customer.city != null ? Text(customer.city!) : null),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        billProvider.setCustomer(null);
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class CustomerSelectionDialog extends StatefulWidget {
  const CustomerSelectionDialog({super.key});

  @override
  State<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<CustomerSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  
  bool _showNewCustomerForm = false;
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

  void _searchCustomers(String query) {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = customerProvider.customers;
      } else {
        _filteredCustomers = customerProvider.customers
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectCustomer(Customer customer) {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    billProvider.setCustomer(customer);
    Navigator.pop(context);
  }

  Future<void> _createNewCustomer() async {
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

    if (!mounted) return;
    _loadCustomers();
    setState(() {
      _showNewCustomerForm = false;
      _nameController.clear();
      _cityController.clear();
      _balanceController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer added'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _showNewCustomerForm ? 'New Customer' : 'Select Customer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            if (!_showNewCustomerForm) ...[
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _searchCustomers,
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _filteredCustomers.isEmpty
                    ? const Center(child: Text('No customers found'))
                    : ListView.builder(
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: customer.balance > 0
                                    ? AppTheme.warningColor
                                    : AppTheme.accentColor,
                                child: Text(
                                  customer.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(customer.name),
                              subtitle: customer.balance > 0
                                  ? Text(
                                      'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                                      style: const TextStyle(color: AppTheme.warningColor),
                                    )
                                  : (customer.city != null ? Text(customer.city!) : null),
                              trailing: customer.balance > 0
                                  ? const Icon(Icons.account_balance_wallet,
                                      color: AppTheme.warningColor)
                                  : null,
                              onTap: () => _selectCustomer(customer),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showNewCustomerForm = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('NEW CUSTOMER'),
              ),
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Customer Name *'),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _balanceController,
                        decoration: const InputDecoration(
                          labelText: 'Opening Balance (₹)',
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
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showNewCustomerForm = false;
                          _nameController.clear();
                          _cityController.clear();
                          _balanceController.clear();
                        });
                      },
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _createNewCustomer,
                      child: const Text('CREATE'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}
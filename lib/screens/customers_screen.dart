// screens/customers_screen.dart

import 'package:billing_app/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/customer_model.dart';
import '../models/balance_transaction_model.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

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

  void _showPaymentDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (_) => PaymentDialog(customer: customer),
    ).then((_) => _loadCustomers());
  }

  void _showHistoryDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (_) => HistoryDialog(customer: customer),
    );
  }

  // 🔴 FINAL FIX: No more async gap warnings
  Future<void> _deleteCustomer(BuildContext outerContext, Customer customer) async {
    // Check if customer has any bills
    final db = await DatabaseService.instance.database;
    final billCountResult = await db.rawQuery(
      'SELECT COUNT(*) FROM bills WHERE customer_id = ?',
      [customer.id],
    );
    final count = Sqflite.firstIntValue(billCountResult) ?? 0;

    if (count > 0) {
      if (!outerContext.mounted) return;
      ScaffoldMessenger.of(outerContext).showSnackBar(
        const SnackBar(content: Text('Cannot delete customer with existing bills')),
      );
      return;
    }

    // Show confirmation dialog and get result BEFORE any await
    if (!outerContext.mounted) return;
    final bool shouldDelete = await showDialog<bool>(
          context: outerContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Customer'),
            content: const Text('Are you sure you want to delete this customer? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false; // default to false if dialog dismissed

    if (!shouldDelete) return;
    if (!outerContext.mounted) return;

    try {
      await DatabaseService.instance.deleteCustomer(customer.id!);

      if (!outerContext.mounted) return;
      // Refresh list
      final customerProvider = Provider.of<CustomerProvider>(outerContext, listen: false);
      await customerProvider.loadCustomers();
      _loadCustomers();

      if (outerContext.mounted) {
        ScaffoldMessenger.of(outerContext).showSnackBar(
          const SnackBar(content: Text('Customer deleted')),
        );
      }
    } catch (e) {
      if (outerContext.mounted) {
        ScaffoldMessenger.of(outerContext).showSnackBar(
          const SnackBar(content: Text('Error deleting customer')),
        );
      }
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customers by name or city...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchCustomers,
            ),
          ),
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
                        const Icon(Icons.people_outline, size: 80, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty ? 'No customers yet' : 'No customers found',
                          style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary),
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
                      child: Column(
                        children: [
                          ListTile(
                            onTap: () => _showHistoryDialog(context, customer),
                            onLongPress: () => _deleteCustomer(context, customer),
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
                                    style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            trailing: hasBalance
                                ? const Icon(Icons.account_balance_wallet, color: AppTheme.warningColor)
                                : null,
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.textSecondary,
                                  ),
                                  icon: const Icon(Icons.history, size: 18),
                                  label: const Text('History'),
                                  onPressed: () => _showHistoryDialog(context, customer),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.textSecondary,
                                  ),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Adjust'),
                                  onPressed: () => _showEditBalanceDialog(context, customer),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.payment, size: 16),
                                  label: const Text('Payment'),
                                  onPressed: () => _showPaymentDialog(context, customer),
                                ),
                              ],
                            ),
                          ),
                        ],
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

// AddCustomerDialog and EditBalanceDialog remain exactly the same as before
// (copy them from the previous version you have — they are already clean)

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

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await customerProvider.addCustomer(customer);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Customer added successfully'),
        backgroundColor: AppTheme.successColor,
      ),
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
              decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person)),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city)),
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
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
    text: widget.customer.balance.toStringAsFixed(2),
  );
  final _reasonController = TextEditingController();

  Future<void> _updateBalance() async {
    final newBalance = double.tryParse(_balanceController.text) ?? 0.0;
    
    // Calculate adjustment needed
    // current + adjustment = new
    // adjustment = new - current
    final currentBalance = widget.customer.balance;
    final adjustment = newBalance - currentBalance;

    if (adjustment.abs() < 0.01) {
       Navigator.pop(context);
       return;
    }

    final String reason = _reasonController.text.isEmpty 
        ? 'Manual Adjustment' 
        : 'Adj: ${_reasonController.text}';

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await customerProvider.addAdjustment(widget.customer.id!, adjustment, reason);
      
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Balance adjusted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
         SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Balance - ${widget.customer.name}'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.customer.city ?? 'No city', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            TextField(
              controller: _balanceController,
              decoration: const InputDecoration(labelText: 'New Balance (₹)', prefixIcon: Icon(Icons.account_balance_wallet)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              autofocus: true,
            ),
             const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason (Optional)', prefixIcon: Icon(Icons.comment)),
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
                  Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This helps correct data errors. For payments, please use the Payment button.',
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _updateBalance, child: const Text('Update')),
      ],
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}

class PaymentDialog extends StatefulWidget {
  final Customer customer;
  const PaymentDialog({super.key, required this.customer});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      final note = _noteController.text.trim();
      final description = note.isEmpty ? 'Payment Received' : 'Payment: $note';
      
      await customerProvider.addPayment(widget.customer.id!, amount, description);
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error recording payment: $e')),
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive Payment'),
      content: SizedBox(
         width: 300,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Customer: ${widget.customer.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
             Text('Current Balance: ₹${widget.customer.balance.toStringAsFixed(2)}'),
             const SizedBox(height: 24),
             TextField(
               controller: _amountController,
               decoration: const InputDecoration(
                 labelText: 'Amount Received (₹)', 
                 prefixIcon: Icon(Icons.attach_money),
                 border: OutlineInputBorder(),
               ),
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
               autofocus: true,
             ),
             const SizedBox(height: 16),
             TextField(
               controller: _noteController,
               decoration: const InputDecoration(
                 labelText: 'Note (Optional)', 
                 prefixIcon: Icon(Icons.note),
                 border: OutlineInputBorder(),
               ),
             ),
           ],
         ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment, 
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, foregroundColor: Colors.white),
          child: _isLoading 
             ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
             : const Text('Receive Payment'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

class HistoryDialog extends StatefulWidget {
  final Customer customer;
  const HistoryDialog({super.key, required this.customer});

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  List<BalanceTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final history = await customerProvider.getHistory(widget.customer.id!);
    if (mounted) {
      setState(() {
        _transactions = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('History - ${widget.customer.name}', overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 600,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty 
             ? const Center(child: Text('No transactions found'))
             : ListView.builder(
                 itemCount: _transactions.length,
                 itemBuilder: (context, index) {
                   final txn = _transactions[index];
                   final isPayment = txn.amount < 0;
                   
                   return ListTile(
                     leading: CircleAvatar(
                       backgroundColor: isPayment 
                          ? AppTheme.successColor.withValues(alpha: 0.2) 
                          : AppTheme.errorColor.withValues(alpha: 0.2),
                       child: Icon(
                         isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                         color: isPayment ? AppTheme.successColor : AppTheme.errorColor,
                         size: 20,
                       ),
                     ),
                     title: Text(
                       txn.description ?? txn.type, 
                       style: const TextStyle(fontWeight: FontWeight.w600),
                     ),
                     subtitle: Text(
                       DateFormat('MMM d, y • h:mm a').format(txn.createdAt),
                       style: const TextStyle(fontSize: 12),
                     ),
                     trailing: Text(
                       '${isPayment ? '-' : '+'}₹${txn.amount.abs().toStringAsFixed(2)}',
                       style: TextStyle(
                         color: isPayment ? AppTheme.successColor : AppTheme.errorColor,
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                       ),
                     ),
                   );
                 },
               ),
      ),
    );
  }
}

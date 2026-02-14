import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/payment_model.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';

class CustomerLedgerDialog extends StatefulWidget {
  final Customer customer;

  const CustomerLedgerDialog({super.key, required this.customer});

  @override
  State<CustomerLedgerDialog> createState() => _CustomerLedgerDialogState();
}

class _CustomerLedgerDialogState extends State<CustomerLedgerDialog> {
  late Future<List<Map<String, dynamic>>> _ledgerFuture;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  void _loadLedger() {
    setState(() {
      _ledgerFuture = Provider.of<CustomerProvider>(context, listen: false)
          .getLedger(widget.customer.id!);
    });
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddPaymentDialog(customerId: widget.customer.id!),
    ).then((_) {
      if (!mounted) return;
      _loadLedger();
      // Also refresh the customer to get updated balance in title if needed
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider to get updated customer balance
    final customerProvider = Provider.of<CustomerProvider>(context);
    final currentCustomer = customerProvider.customers.firstWhere(
        (c) => c.id == widget.customer.id,
        orElse: () => widget.customer);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600, // Fixed width like CustomerSelector
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentCustomer.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (currentCustomer.city != null)
                      Text(
                        currentCustomer.city!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Current Balance',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '₹${currentCustomer.displayBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Ledger List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _ledgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final ledger = snapshot.data ?? [];

                  if (ledger.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long,
                              size: 60, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          const Text(
                            'No transaction history',
                            style: TextStyle(
                                fontSize: 16, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: ledger.length,
                    itemBuilder: (context, index) {
                      final item = ledger[index];
                      final isDebit = (item['debit'] as double) > 0;
                      final amount = isDebit ? item['debit'] : item['credit'];
                      final date = item['date'] as DateTime;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.borderColor
                                      .withValues(alpha: 0.5))),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        child: Row(
                          children: [
                            // Date
                            SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    DateFormat('yy, hh:mm a').format(date),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Description
                            Expanded(
                              child: Text(
                                item['description'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            // Amount
                            Text(
                              isDebit
                                  ? '- ₹${(amount as double).toStringAsFixed(2)}'
                                  : '+ ₹${(amount as double).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDebit
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor,
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

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddPaymentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD PAYMENT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddPaymentDialog extends StatefulWidget {
  final int customerId;
  const AddPaymentDialog({super.key, required this.customerId});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final payment = Payment(
      customerId: widget.customerId,
      amount: amount,
      date: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? 'Payment Received'
          : _notesController.text.trim(),
    );

    final navigator = Navigator.of(context);
    final provider = Provider.of<CustomerProvider>(context, listen: false);

    await provider.addPayment(payment);

    if (mounted) {
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment added successfully'),
            backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount (₹) *',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.note),
              hintText: 'e.g., GPay, Cash',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _savePayment, child: const Text('Save')),
      ],
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

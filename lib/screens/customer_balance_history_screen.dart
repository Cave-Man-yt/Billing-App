// lib/screens/customer_balance_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/balance_history_model.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../utils/app_theme.dart';

class CustomerBalanceHistoryScreen extends StatefulWidget {
  final Customer customer;

  const CustomerBalanceHistoryScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerBalanceHistoryScreen> createState() =>
      _CustomerBalanceHistoryScreenState();
}

class _CustomerBalanceHistoryScreenState
    extends State<CustomerBalanceHistoryScreen> {
  late Future<List<BalanceHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<BalanceHistory>> _fetchHistory() {
    return Provider.of<CustomerProvider>(context, listen: false)
        .getCustomerBalanceHistory(widget.customer.id!);
  }

  Future<void> _showDeductPaymentDialog() async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Deduct Payment'),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListBody(
                children: <Widget>[
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.description),
                      hintText: 'e.g., Cash Payment',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
              child: const Text('Deduct'),
              onPressed: () async {
                final String amountText = amountController.text;
                final String description = descriptionController.text.trim();

                if (amountText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount.')),
                  );
                  return;
                }

                final double? amount = double.tryParse(amountText);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }

                await Provider.of<CustomerProvider>(context, listen: false)
                    .deductCustomerPayment(
                  widget.customer.id!,
                  amount,
                  description.isEmpty ? 'Payment received' : description,
                );

                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _historyFuture = _fetchHistory();
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, child) {
        final freshCustomer = customerProvider.customers.firstWhere(
          (c) => c.id == widget.customer.id,
          orElse: () => widget.customer,
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('${freshCustomer.name}\'s Balance History'),
          contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<BalanceHistory>>(
                    future: _historyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No balance history found.'));
                      } else {
                        final history = snapshot.data!;
                        double runningBalance = freshCustomer.balance;

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final BalanceHistory entry = history[index];
                            final double currentRunningBalance = runningBalance;
                            runningBalance -= entry.amount;

                            final isCredit = entry.amount >= 0;
                            final color = isCredit ? AppTheme.creditColor : AppTheme.errorColor;
                            final icon = isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline;

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('MMM d, yyyy  h:mm a').format(entry.createdAt),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        Row(
                                          children: [
                                            Icon(icon, color: color, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${isCredit ? '+' : ''}${entry.amount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(entry.description, style: const TextStyle(fontSize: 15)),
                                    const SizedBox(height: 8),
                                    const Divider(thickness: 0.5),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        'New Balance: ${currentRunningBalance.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: _showDeductPaymentDialog,
              icon: const Icon(Icons.payment),
              label: const Text('Deduct Payment'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:billing_app/providers/bill_provider.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/utils/app_theme.dart';
import 'package:billing_app/services/pdf_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Bill> _filteredBills = [];

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  void _loadBills() {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    setState(() {
      _filteredBills = billProvider.bills;
    });
  }

  void _searchBills(String query) async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final results = await billProvider.searchBills(query);
    setState(() {
      _filteredBills = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<BillProvider>(context, listen: false).loadBills();
              _loadBills();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by bill number or customer...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchBills,
            ),
          ),
          
          // Bills list
          Expanded(
            child: Consumer<BillProvider>(
              builder: (context, billProvider, _) {
                if (billProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredBills.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: AppTheme.textHint,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No bills found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredBills.length,
                  itemBuilder: (context, index) {
                    final bill = _filteredBills[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: bill.isCredit
                              ? AppTheme.creditColor
                              : AppTheme.accentColor,
                          child: Icon(
                            bill.isCredit
                                ? Icons.credit_card
                                : Icons.receipt,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          bill.billNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${bill.customerName}\n${DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${bill.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            if (bill.isCredit)
                              const Text(
                                'CREDIT',
                                style: TextStyle(
                                  color: AppTheme.creditColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          final items = await billProvider.getBillItems(bill.id!);
                          if (context.mounted) {
                            await PdfService.generateAndPrintBill(
                              context,
                              bill,
                              items,
                            );
                          }
                        },
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
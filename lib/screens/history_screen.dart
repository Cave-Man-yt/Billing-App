// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bill_provider.dart';
import '../models/bill_model.dart';
import '../utils/app_theme.dart';
import '../services/pdf_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

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
    if (mounted) {
      setState(() {
        _filteredBills = results;
      });
    }
  }

  Future<void> _deleteBill(int billId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Are you sure you want to delete this bill? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final billProvider = Provider.of<BillProvider>(context, listen: false);

    // Check if the deleted bill is currently loaded in billing screen
    final isCurrentlyEditing = billProvider.isEditingExistingBill && 
                                billProvider.editingBillId == billId;

    await DatabaseService.instance.deleteBill(billId);

    if (!mounted) return;

    await billProvider.loadBills();
    _loadBills();

    // If the deleted bill was being edited, clear the billing screen
    if (isCurrentlyEditing) {
      billProvider.clearCurrentBill();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill deleted successfully')),
      );
    }
  }

  // Load bill for editing and navigate to billing screen
  Future<void> _openBillForEditing(Bill bill) async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final items = await billProvider.getBillItems(bill.id!);
    if (!mounted) return;

    // This now fetches the current customer balance from DB
    await billProvider.loadBillForEditing(bill, items);
    billProvider.startEditingExistingBill(bill.id!);

    // Navigate to home screen and switch to billing tab (index 0)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
        homeScreenState?.switchToTab(0);
      }
    }
  }

  // 🔴 FIX: Print/share should NOT load the bill for editing
  Future<void> _printBill(Bill bill) async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final items = await billProvider.getBillItems(bill.id!);
    if (!mounted) return;

    // 🔴 CRITICAL: Do NOT call loadBillForEditing here!
    // Just generate and print the PDF directly
    await PdfService.generateAndPrintBill(context, bill, items);
  }

  Future<void> _shareBill(Bill bill) async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final items = await billProvider.getBillItems(bill.id!);
    if (!mounted) return;

    // 🔴 CRITICAL: Do NOT call loadBillForEditing here!
    // Just share the PDF directly
    await PdfService.shareBill(context, bill, items, filename: '${bill.billNumber}.pdf');
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
                        Icon(Icons.receipt_long_outlined, size: 80, color: AppTheme.textHint),
                        SizedBox(height: 16),
                        Text(
                          'No bills found',
                          style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
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
                        onTap: () => _openBillForEditing(bill),
                        onLongPress: () => _deleteBill(bill.id!),
                        leading: CircleAvatar(
                          backgroundColor: bill.isCredit ? AppTheme.creditColor : AppTheme.accentColor,
                          child: Icon(
                            bill.isCredit ? Icons.credit_card : Icons.receipt,
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${(bill.grandTotal > 0 ? bill.grandTotal : bill.previousBalance + bill.total).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
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
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'Share PDF',
                              onPressed: () => _shareBill(bill), // 🔴 FIX: Use dedicated method
                            ),
                            IconButton(
                              icon: const Icon(Icons.print),
                              tooltip: 'Print',
                              onPressed: () => _printBill(bill), // 🔴 FIX: Use dedicated method
                            ),
                          ],
                        ),
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
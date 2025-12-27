// lib/screens/edit_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../services/pdf_service.dart';
import '../utils/app_theme.dart';
import 'billing_screen.dart';

class EditBillScreen extends StatefulWidget {
  final Bill bill;
  final List<BillItem> items;

  const EditBillScreen({super.key, required this.bill, required this.items});

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  late BillProvider billProvider;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    billProvider = Provider.of<BillProvider>(context, listen: false);
    billProvider.loadBillForEditing(widget.bill, widget.items);
  }

  Future<void> _saveAndPrint() async {
    setState(() => _isProcessing = true);
    try {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      const amountPaid = 0.0;
      final updatedBill = await billProvider.saveBill(
        amountPaid,
        clearAfterSave: false,
        customerProvider: customerProvider,
      );
      if (updatedBill == null || !mounted) return;

      final items = billProvider.currentBillItems;
      await PdfService.generateAndPrintBill(context, updatedBill, items);

      if (mounted) {
        billProvider.clearCurrentBill();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill updated & printed!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Bill - ${widget.bill.billNumber}'),
        actions: [
          IconButton(
            icon: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.print),
            onPressed: _isProcessing ? null : _saveAndPrint,
          ),
        ],
      ),
      body: const BillingScreen(),
    );
  }
}
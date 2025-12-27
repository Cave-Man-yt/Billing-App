// lib/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/bill_provider.dart';
import '../providers/product_provider.dart';
import '../models/bill_item_model.dart';
import '../models/product_model.dart';
import '../models/bill_model.dart';
import '../utils/app_theme.dart';
import '../widgets/customer_selector.dart';
import '../services/pdf_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(); // Empty by default
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _amountPaidController = TextEditingController(); // Empty by default
  final _itemNameFocus = FocusNode();
  final _quantityFocus = FocusNode();
  final _priceFocus = FocusNode();

  int? _editingIndex;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final billProvider = Provider.of<BillProvider>(context, listen: false);
      _discountController.text = billProvider.discount.toStringAsFixed(2);
    });
    _discountController.addListener(() {
      final value = double.tryParse(_discountController.text) ?? 0.0;
      Provider.of<BillProvider>(context, listen: false).setDiscount(value);
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _amountPaidController.dispose();
    _itemNameFocus.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _addOrUpdateItem() async {
  final name = _itemNameController.text.trim();
  final qtyText = _quantityController.text.trim();
  final qty = qtyText.isEmpty ? 1.0 : (double.tryParse(qtyText) ?? 0.0);
  final price = double.tryParse(_priceController.text) ?? 0.0;

  if (name.isEmpty || qty <= 0 || price <= 0) return;

  final item = BillItem(productName: name, quantity: qty, price: price);
  final billProvider = Provider.of<BillProvider>(context, listen: false);

  if (_editingIndex != null) {
    billProvider.updateBillItem(_editingIndex!, item);
    setState(() => _editingIndex = null);
  } else {
    billProvider.addBillItem(item);
  }

  // Update product price in suggestions immediately
  final productProvider = Provider.of<ProductProvider>(context, listen: false);
  await productProvider.upsertProductPrice(name, price);

  // Reset fields
  _itemNameController.clear();
  _quantityController.clear();
  _priceController.clear();
  _itemNameFocus.requestFocus();
  FocusScope.of(context).unfocus(); // ← Closes keyboard after adding item
}

  void _editItem(int index, BillItem item) {
    setState(() {
      _editingIndex = index;
      _itemNameController.text = item.productName;
      _quantityController.text = item.quantity.toString();
      _priceController.text = item.price.toString();
      _quantityFocus.requestFocus();
    });
  }

  Future<void> _completeAndPrint() async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);

    if (billProvider.currentBillItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    if (billProvider.currentCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amountPaidText = _amountPaidController.text.trim();
      final amountPaid = amountPaidText.isEmpty ? 0.0 : (double.tryParse(amountPaidText) ?? 0.0);

      final itemsCopy = List<BillItem>.from(billProvider.currentBillItems);
      final bill = await billProvider.saveBill(amountPaid, clearAfterSave: false);

      if (bill == null || !mounted) return;

      await PdfService.generateAndPrintBill(context, bill, itemsCopy);

      billProvider.clearCurrentBill();
      _discountController.clear();
      _amountPaidController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill saved & printed!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
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

  Future<void> _shareViaWhatsApp() async {
  final billProvider = Provider.of<BillProvider>(context, listen: false);

  if (billProvider.currentBillItems.isEmpty || billProvider.currentCustomer == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add customer & items first')),
    );
    return;
  }

  setState(() => _isProcessing = true);

  try {
    final amountPaidText = _amountPaidController.text.trim();
    final amountPaid = amountPaidText.isEmpty ? 0.0 : (double.tryParse(amountPaidText) ?? 0.0);

    final itemsCopy = List<BillItem>.from(billProvider.currentBillItems);
    final bill = await billProvider.saveBill(amountPaid, clearAfterSave: false);

    if (bill == null || !mounted) return;

    // Use public method — no need to access private _buildPdfBytes
    await PdfService.shareBill(
      context,
      bill,
      itemsCopy,
      filename: '${bill.billNumber}.pdf',
    );

    billProvider.clearCurrentBill();
    _discountController.clear();
    _amountPaidController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill saved & sent to WhatsApp!'),
        backgroundColor: AppTheme.successColor,
      ),
    );
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
      title: Consumer<BillProvider>(
        builder: (context, billProvider, _) {
          if (billProvider.isEditingExistingBill && billProvider.editingBillId != null) {
            final originalBill = billProvider.bills.firstWhere(
              (b) => b.id == billProvider.editingBillId,
              orElse: () => Bill(
                billNumber: 'Unknown',
                customerName: '',
                subtotal: 0.0,
                discount: 0.0,
                total: 0.0,
              ),
            );
            return Text('Edit Bill - ${originalBill.billNumber}');
          }
          return const Text('New Estimate');
        },
      ),
      actions: [],
    ),
    body: Row(
  children: [
    Expanded(flex: 4, child: _buildItemEntrySection()),
    Expanded(
      flex: 7,
      child: Column(
        children: [
          const CustomerSelector(),
          const Divider(height: 1),
          // Scrollable items list — takes all available space
          Expanded(
            child: _buildPreviewSectionItems(),
          ),
          // Summary + buttons — always visible at bottom, no scroll
          _buildSummarySection(),
        ],
      ),
    ),
  ],
),
  );
}

  Widget _buildItemEntrySection() {
    return Container(
      color: AppTheme.backgroundLight,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editingIndex != null ? 'Edit Item' : 'Add Items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Consumer<ProductProvider>(
  builder: (context, productProvider, _) {
    return TypeAheadField<Product>(
      controller: _itemNameController,
      focusNode: _itemNameFocus,
      suggestionsCallback: (pattern) async {
        final trimmed = pattern.trim();
        if (trimmed.isEmpty) {
          // Show top 10 most used when field focused
          return productProvider.products.take(10).toList();
        }
        return await productProvider.searchProducts(trimmed);
      },
      itemBuilder: (context, suggestion) => ListTile(
        dense: true,
        title: Text(suggestion.name),
        trailing: Text('₹${suggestion.price.toStringAsFixed(0)}'),
      ),
      onSelected: (suggestion) {
        _itemNameController.text = suggestion.name;
        _priceController.text = suggestion.price.toString();
        _quantityFocus.requestFocus();
      },
      builder: (context, controller, focusNode) => TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: const InputDecoration(
          labelText: 'Item Name',
          prefixIcon: Icon(Icons.inventory_2_outlined),
        ),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _quantityFocus.requestFocus(),
      ),
    );
  },
),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              focusNode: _quantityFocus,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onSubmitted: (_) => _priceFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              focusNode: _priceFocus,
              decoration: const InputDecoration(
                labelText: 'Price (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onSubmitted: (_) => _addOrUpdateItem(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addOrUpdateItem,
              icon: Icon(_editingIndex != null ? Icons.check : Icons.add),
              label: Text(_editingIndex != null ? 'UPDATE ITEM' : 'ADD ITEM'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.accentColor,
              ),
            ),
            if (_editingIndex != null)
              TextButton(
                onPressed: () => setState(() => _editingIndex = null),
                child: const Text('Cancel Edit'),
              ),
            const SizedBox(height: 16),
            Consumer<BillProvider>(
              builder: (context, _, __) {
                final qty = double.tryParse(_quantityController.text) ?? 0;
                final price = double.tryParse(_priceController.text) ?? 0;
                final lineTotal = qty * price;
                if (lineTotal > 0) {
                  return Card(
                    color: AppTheme.primaryLight.withAlpha(26),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Line Total:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '₹${lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

Widget _buildPreviewSection() {
  return _buildSummarySection();  // ← Fixed "Summsry" → "Summary"
}

  Widget _buildSummarySection() {
  return Consumer<BillProvider>(
    builder: (context, billProvider, _) {
      final canSave = billProvider.currentBillItems.isNotEmpty && billProvider.currentCustomer != null;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Discount (₹)',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountPaidController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payment),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 16),
              _summaryRow('Subtotal:', '₹${billProvider.subtotal.toStringAsFixed(2)}'),
              if (billProvider.discount > 0)
                _summaryRow('Discount:', '-₹${billProvider.discount.toStringAsFixed(2)}', color: AppTheme.successColor),
              const Divider(height: 32),
              _summaryRow('TOTAL:', '₹${billProvider.total.toStringAsFixed(2)}', isBold: true, fontSize: 24),
              const SizedBox(height: 32),

              // BIG ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSave && !_isProcessing ? () => _shareViaWhatsApp() : null,
                      icon: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Icon(Icons.send, size: 28),
                      label: const Text('SEND TO WHATSAPP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSave && !_isProcessing ? _completeAndPrint : null,
                      icon: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Icon(Icons.print, size: 28),
                      label: const Text('PRINT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildPreviewSectionItems() {
  return Consumer<BillProvider>(
    builder: (context, billProvider, _) {
      if (billProvider.currentBillItems.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: AppTheme.textHint),
              SizedBox(height: 16),
              Text('No items added', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: billProvider.currentBillItems.length,
        itemBuilder: (context, index) {
          final item = billProvider.currentBillItems[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _editItem(index, item),
              title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${item.quantity} × ${item.price.toStringAsFixed(2)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                    onPressed: () => billProvider.removeBillItem(index),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _summaryRow(String label, String value, {Color? color, bool isBold = false, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize ?? 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize ?? 18,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
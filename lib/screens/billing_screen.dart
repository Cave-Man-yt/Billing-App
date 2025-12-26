// lib/screens/billing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/bill_provider.dart';
import '../providers/product_provider.dart';
import '../models/bill_item_model.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';
import '../widgets/customer_selector.dart';
import '../services/pdf_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();

  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();

  int? _editingIndex;
  bool _isProcessing = false;

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

  void _addItem() {
    final itemName = _itemNameController.text.trim();
    final quantity = double.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text);

    if (itemName.isEmpty || quantity == null || price == null) {
      return;
    }

    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final item = BillItem(
      productName: itemName,
      quantity: quantity,
      price: price,
    );

    if (_editingIndex != null) {
      billProvider.updateBillItem(_editingIndex!, item);
      _editingIndex = null;
    } else {
      billProvider.addBillItem(item);
    }

    _itemNameController.clear();
    _quantityController.clear();
    _priceController.clear();
    
    // Close keyboard
    FocusScope.of(context).unfocus();
  }

  void _editItem(int index, BillItem item) {
    setState(() {
      _editingIndex = index;
      _itemNameController.text = item.productName;
      _quantityController.text = item.quantity.toString();
      _priceController.text = item.price.toString();
      _itemNameFocus.requestFocus();
    });
  }

  Future<void> _completeBill() async {
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

    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;

    setState(() { _isProcessing = true; });
    try {
      // copy current items for printing (saveBill will clear current items)
      final itemsForPrint = List<BillItem>.from(billProvider.currentBillItems);

      final bill = await billProvider.saveBill(amountPaid);

      if (!mounted) return;

      if (bill != null) {
        await PdfService.generateAndPrintBill(
          context,
          bill,
          itemsForPrint,
        );

        _amountPaidController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill saved and printed!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        actions: [
          Consumer<BillProvider>(
            builder: (context, billProvider, _) {
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: billProvider.currentBillItems.isEmpty
                    ? null
                    : () {
                        billProvider.clearCurrentBill();
                        _amountPaidController.clear();
                      },
                tooltip: 'Clear Bill',
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 4, child: _buildItemEntrySection()),
          Expanded(flex: 6, child: _buildBillPreviewSection()),
        ],
      ),
    );
  }

  Widget _buildItemEntrySection() {
    return Container(
      color: AppTheme.backgroundLight,
      padding: const EdgeInsets.all(24),
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
                  if (pattern.length < 2) return [];
                  return await productProvider.searchProducts(pattern);
                },
                itemBuilder: (context, Product suggestion) {
                  return ListTile(
                    dense: true,
                    title: Text(suggestion.name),
                    trailing: Text('₹${suggestion.price.toStringAsFixed(0)}'),
                  );
                },
                onSelected: (Product suggestion) {
                  _itemNameController.text = suggestion.name;
                  _priceController.text = suggestion.price.toString();
                  _quantityFocus.requestFocus();
                },
                hideOnEmpty: true,
                hideOnLoading: true,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _quantityFocus.requestFocus(),
                  );
                },
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
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
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
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onSubmitted: (_) => _addItem(),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _addItem,
            icon: Icon(_editingIndex != null ? Icons.check : Icons.add),
            label: Text(_editingIndex != null ? 'UPDATE ITEM' : 'ADD ITEM'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.accentColor,
            ),
          ),
          
          if (_editingIndex != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _editingIndex = null;
                  _itemNameController.clear();
                  _quantityController.clear();
                  _priceController.clear();
                });
              },
              child: const Text('Cancel Edit'),
            ),
          ],

          const SizedBox(height: 16),
          Consumer<BillProvider>(
            builder: (context, billProvider, _) {
              final qty = double.tryParse(_quantityController.text) ?? 0;
              final price = double.tryParse(_priceController.text) ?? 0;
              final lineTotal = qty * price;

              if (lineTotal > 0) {
                return Card(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Line Total:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
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
        ],
      ),
    );
  }

  Widget _buildBillPreviewSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const CustomerSelector(),
          const Divider(height: 1),
          Expanded(
            child: Consumer<BillProvider>(
              builder: (context, billProvider, _) {
                if (billProvider.currentBillItems.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 80, color: AppTheme.textHint),
                        SizedBox(height: 16),
                        Text('No items added',
                            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
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
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _editItem(index, item),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${item.quantity} × ₹${item.price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${item.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppTheme.errorColor,
                              onPressed: () {
                                billProvider.removeBillItem(index);
                              },
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
          _buildBillSummary(),
        ],
      ),
    );
  }

  Widget _buildBillSummary() {
    return Consumer<BillProvider>(
      builder: (context, billProvider, _) {
        final previousBalance = billProvider.currentCustomer?.balance ?? 0.0;
        final grandTotal = billProvider.total + previousBalance;

        return Container(
          padding: const EdgeInsets.all(24),
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
          child: Column(
            children: [
              TextField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Discount (₹)',
                  prefixIcon: Icon(Icons.local_offer_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  final discount = double.tryParse(value) ?? 0.0;
                  billProvider.setDiscount(discount);
                },
              ),
              const SizedBox(height: 16),

              _buildSummaryRow('Subtotal:', '₹${billProvider.subtotal.toStringAsFixed(2)}'),
              if (billProvider.discount > 0) ...[
                const SizedBox(height: 8),
                _buildSummaryRow('Discount:', '-₹${billProvider.discount.toStringAsFixed(2)}',
                    color: AppTheme.successColor),
              ],
              if (previousBalance > 0) ...[
                const SizedBox(height: 8),
                _buildSummaryRow('Previous Balance:', '₹${previousBalance.toStringAsFixed(2)}',
                    color: AppTheme.warningColor),
              ],
              const Divider(height: 24),

              _buildSummaryRow('GRAND TOTAL:', '₹${grandTotal.toStringAsFixed(2)}',
                  isBold: true, fontSize: 24),
              const SizedBox(height: 16),

              TextField(
                controller: _amountPaidController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (₹)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    onPressed: (billProvider.currentBillItems.isEmpty || _isProcessing) ? null : _completeBill,
                    icon: _isProcessing ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white)) : const Icon(Icons.print),
                    label: _isProcessing ? const Text('PROCESSING...') : const Text('COMPLETE & PRINT'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, double? fontSize, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? AppTheme.textPrimary,
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
    );
  }
}
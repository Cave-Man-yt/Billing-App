// lib/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/bill_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../models/bill_item_model.dart';
import '../models/product_model.dart';
import '../models/bill_model.dart';
import '../utils/app_theme.dart';
import '../widgets/customer_selector.dart';
import '../services/pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _packageChargeController = TextEditingController();
  final _boxCountController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _itemNameFocus = FocusNode();
  final _quantityFocus = FocusNode();
  final _priceFocus = FocusNode();

  int? _editingIndex;
  bool _isProcessing = false;

@override
void initState() {
  super.initState();

  // Clear both fields to be empty from the start
  _packageChargeController.clear();
  _boxCountController.clear();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final billProvider = Provider.of<BillProvider>(context, listen: false);

    // Keep existing values when editing, but show empty if 0
    if (billProvider.packageCharge > 0) {
      _packageChargeController.text = billProvider.packageCharge.toStringAsFixed(2);
    } else {
      _packageChargeController.clear(); // empty if 0
    }

    if (billProvider.boxCount > 0) {
      _boxCountController.text = billProvider.boxCount.toString();
    } else {
      _boxCountController.clear(); // empty if 0
    }

    // Existing amount paid logic (keep it)
    if (billProvider.isEditingExistingBill && billProvider.editingBillId != null) {
      final originalBill = billProvider.bills.firstWhere(
        (b) => b.id == billProvider.editingBillId,
        orElse: () => Bill(
          billNumber: '',
          customerName: '',
          subtotal: 0.0,
          total: 0.0,
        ),
      );
      _amountPaidController.text = originalBill.amountPaid.toStringAsFixed(2);
    }
  });

  // Existing listeners
  _packageChargeController.addListener(() {
    final value = double.tryParse(_packageChargeController.text) ?? 0.0;
    Provider.of<BillProvider>(context, listen: false).setPackageCharge(value);
  });

  _boxCountController.addListener(() {
    final value = int.tryParse(_boxCountController.text) ?? 0;
    Provider.of<BillProvider>(context, listen: false).setBoxCount(value);
  });
}

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _packageChargeController.dispose();
    _boxCountController.dispose();
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
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
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
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    if (billProvider.currentBillItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one item')),
        );
      }
      return;
    }
    if (billProvider.currentCustomer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a customer')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amountPaidText = _amountPaidController.text.trim();
      final amountPaid = amountPaidText.isEmpty ? 0.0 : (double.tryParse(amountPaidText) ?? 0.0);

      final itemsCopy = List<BillItem>.from(billProvider.currentBillItems);
      final bill = await billProvider.saveBill(
        amountPaid,
        clearAfterSave: false,
        customerProvider: customerProvider,
      );

      if (bill == null || !mounted) return;

      await PdfService.generateAndPrintBill(context, bill, itemsCopy);

      billProvider.clearCurrentBill();
      _packageChargeController.clear();
      _boxCountController.clear();
      _amountPaidController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill saved & printed!'),
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

  Future<void> _shareViaWhatsApp() async {
    final billProvider = Provider.of<BillProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    if (billProvider.currentBillItems.isEmpty || billProvider.currentCustomer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add customer & items first')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amountPaidText = _amountPaidController.text.trim();
      final amountPaid = amountPaidText.isEmpty ? 0.0 : (double.tryParse(amountPaidText) ?? 0.0);

      final itemsCopy = List<BillItem>.from(billProvider.currentBillItems);
      final bill = await billProvider.saveBill(
        amountPaid,
        clearAfterSave: false,
        customerProvider: customerProvider,
      );

      if (bill == null || !mounted) return;

      final images = await PdfService.generateBillAsImages(context, bill, itemsCopy);

      if (images.isNotEmpty) {
        final xFiles = images.mapIndexed((index, bytes) {
          return XFile.fromData(
            bytes,
            name: '${bill.billNumber}_page_${index + 1}.png',
            mimeType: 'image/png',
          );
        }).toList();

        await Share.shareXFiles(xFiles, text: 'Bill No: ${bill.billNumber}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill saved & sent to WhatsApp!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate bill images'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }

      billProvider.clearCurrentBill();
      _packageChargeController.clear();
      _boxCountController.clear();
      _amountPaidController.clear();
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
            packageCharge: 0.0,
            total: 0.0,
          ),
        );
        return Text('Edit Bill - ${originalBill.billNumber}');
      }
      return const Text('New Estimate');
    },
  ),
  // ← NEW: Add action button to cancel editing
  actions: [
    Consumer<BillProvider>(
      builder: (context, billProvider, _) {
        if (billProvider.isEditingExistingBill) {
          return TextButton.icon(
            onPressed: () {
  final billProvider = Provider.of<BillProvider>(context, listen: false);
  
  // NOTE: Remove all traces of the old bill
  billProvider.clearCurrentBill();
  
  // Clear text fields manually (extra safety)
  _packageChargeController.clear();
  _boxCountController.clear();
  _amountPaidController.clear();
  
  // Optional: Clear item entry fields too
  _itemNameController.clear();
  _quantityController.clear();
  _priceController.clear();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Edit cancelled — ready for new bill')),
  );
},
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('Cancel Edit', style: TextStyle(color: Colors.white)),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  ],
),
      body: Row(
        children: [
          Expanded(flex: 4, child: _buildItemEntrySection()),
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(child: _buildPreviewSectionItems()),
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
          // NOTE: Customer selector now at top of LEFT panel
          Consumer<BillProvider>(
            builder: (context, billProvider, _) {
              final customer = billProvider.currentCustomer;
              if (customer == null) {
  return ElevatedButton.icon(
    onPressed: () {
      // Open the same customer selection dialog used elsewhere
      showDialog(
        context: context,
        builder: (_) => const CustomerSelectionDialog(),
      );
    },
    icon: const Icon(Icons.person_add),
    label: const Text('SELECT CUSTOMER'),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  );
}
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: customer.balance > 0
                            ? AppTheme.warningColor
                            : AppTheme.accentColor,
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            if (customer.balance > 0)
                              Text(
                                'Balance: ₹${customer.balance.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => billProvider.setCustomer(null),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Original "Add Items" title and fields
          Text(
            _editingIndex != null ? 'Edit Item' : 'Add Items',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          // Rest of your existing item entry fields (keep everything below unchanged)
          Consumer<ProductProvider>(
            builder: (context, productProvider, _) {
              return TypeAheadField<Product>(
                controller: _itemNameController,
                focusNode: _itemNameFocus,
                suggestionsCallback: (pattern) async {
                  final trimmed = pattern.trim();
                  if (trimmed.isEmpty) {
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
          // Line total card (your existing one)
          Consumer<BillProvider>(
            builder: (context, _, __) {
              final qty = double.tryParse(_quantityController.text) ?? 0;
              final price = double.tryParse(_priceController.text) ?? 0;
              final lineTotal = qty * price;
              if (lineTotal > 0) {
                return Card(
                  color: AppTheme.primaryLight.withValues(alpha: 0.1),
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

  Widget _buildSummarySection() {
    return Consumer<BillProvider>(
      builder: (context, billProvider, _) {
        final canSave = billProvider.currentBillItems.isNotEmpty && billProvider.currentCustomer != null;

        final previousBalance = billProvider.currentCustomer?.balance ?? 0.0;
        final grandTotal = billProvider.total + previousBalance;
        final amountPaidText = _amountPaidController.text.trim();
        final amountPaid = amountPaidText.isEmpty ? 0.0 : (double.tryParse(amountPaidText) ?? 0.0);
        final finalBalance = grandTotal - amountPaid;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Package Charge and Box Count side by side
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _packageChargeController,
                      decoration: const InputDecoration(
                        labelText: 'Package Charge',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _boxCountController,
                      decoration: const InputDecoration(
                        labelText: 'Boxes',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountPaidController,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payment),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              ),
              const SizedBox(height: 8),
              _summaryRow('Subtotal:', billProvider.subtotal.toStringAsFixed(2), fontSize: 14),
              if (billProvider.packageCharge > 0)
                _summaryRow('Package Charge:', '+${billProvider.packageCharge.toStringAsFixed(2)}', color: AppTheme.warningColor, fontSize: 14),
              const Divider(height: 12),
              _summaryRow('Bill Total:', billProvider.total.toStringAsFixed(2), isBold: true, fontSize: 16),
              const SizedBox(height: 8),
              if (previousBalance > 0)
                _summaryRow('Prev. Bal:', previousBalance.toStringAsFixed(2), fontSize: 14),
              _summaryRow('Grand Total:', grandTotal.toStringAsFixed(2), isBold: true, fontSize: 18),
              const SizedBox(height: 8),
              _summaryRow('Amount Paid:', amountPaid.toStringAsFixed(2), color: AppTheme.successColor, fontSize: 14),
              _summaryRow(
                'Final Bal:',
                finalBalance.toStringAsFixed(2),
                isBold: true,
                fontSize: 18,
                color: finalBalance > 0 ? AppTheme.errorColor : AppTheme.successColor,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSave && !_isProcessing ? () => _shareViaWhatsApp() : null,
                      icon: _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, size: 24),
                      label: const Text('WHATSAPP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canSave && !_isProcessing ? _completeAndPrint : null,
                      icon: _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.print, size: 24),
                      label: const Text('PRINT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () => _editItem(index, item),
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${item.quantity} × ${item.price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.total.toStringAsFixed(2),
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
              fontSize: fontSize ?? 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

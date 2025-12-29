// lib/services/pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../providers/settings_provider.dart';

class PdfService {
  PdfService._();

  static pw.Font get regular => pw.Font.helvetica();
  static pw.Font get bold => pw.Font.helveticaBold();

  static Future<void> generateAndPrintBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    try {
      final bytes = await _buildPdfBytes(context, bill, items);

      await Future.delayed(const Duration(milliseconds: 600));

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: bill.billNumber,
        usePrinterSettings: true,
      );
    } catch (e, stack) {
      debugPrint('Print failed: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print failed – sharing PDF instead')),
        );
        final bytes = await _buildPdfBytes(context, bill, items);
        await Printing.sharePdf(bytes: bytes, filename: '${bill.billNumber}.pdf');
      }
    }
  }

  static Future<void> shareBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items, {
    String filename = 'invoice.pdf',
  }) async {
    final bytes = await _buildPdfBytes(context, bill, items);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<Uint8List> _buildPdfBytes(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(settings.shopName,
                        style: pw.TextStyle(font: bold, fontSize: 24)),
                    if (settings.shopAddress.isNotEmpty) pw.Text(settings.shopAddress),
                    if (settings.shopPhone.isNotEmpty) pw.Text('Ph: ${settings.shopPhone}'),
                    if (settings.shopEmail.isNotEmpty) pw.Text(settings.shopEmail),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('ESTIMATE', style: pw.TextStyle(font: bold, fontSize: 20)),
                    pw.Text('No: ${bill.billNumber}'),
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(bill.createdAt)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Bill To
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill To:', style: pw.TextStyle(font: bold, fontSize: 12)),
                  pw.Text(bill.customerName, style: const pw.TextStyle(fontSize: 14)),
                  if (bill.customerCity != null) pw.Text(bill.customerCity!),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items Table - ← UPDATED with S.No column
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7), // ← NEW: S.No column
                1: const pw.FlexColumnWidth(3),   // Item
                2: const pw.FlexColumnWidth(1),   // Qty
                3: const pw.FlexColumnWidth(1.5), // Price
                4: const pw.FlexColumnWidth(1.5), // Total
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('S.No', header: true, align: pw.TextAlign.center), // ← NEW
                    _cell('Item', header: true),
                    _cell('Qty', header: true, align: pw.TextAlign.center),
                    _cell('Price', header: true, align: pw.TextAlign.right),
                    _cell('Total', header: true, align: pw.TextAlign.right),
                  ],
                ),
                // Data rows - ← UPDATED with serial numbers
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return pw.TableRow(children: [
                    _cell('${index + 1}', align: pw.TextAlign.center), // ← NEW: Serial number
                    _cell(item.productName),
                    _cell(item.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
                    _cell(item.price.toStringAsFixed(2), align: pw.TextAlign.right),
                    _cell(item.total.toStringAsFixed(2), align: pw.TextAlign.right),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                child: pw.Column(
                  children: [
                    _summaryRow('Subtotal:', bill.subtotal.toStringAsFixed(2)),
                    if (bill.packageCharge > 0)
                      _summaryRow('Package Charge:', '+${bill.packageCharge.toStringAsFixed(2)}'),
                    if (bill.boxCount > 0)
                      _summaryRow('No. of Boxes:', '${bill.boxCount}'),
                    pw.Divider(),
                    _summaryRow('Bill Total:', bill.total.toStringAsFixed(2), bold: true),
                    pw.SizedBox(height: 10),
                    _summaryRow('Previous Balance:', bill.previousBalance.toStringAsFixed(2)),
                    _summaryRow('Grand Total:', bill.grandTotal.toStringAsFixed(2), bold: true),
                    pw.Divider(),
                    _summaryRow('Amount Paid:', bill.amountPaid.toStringAsFixed(2)),
                    _summaryRow('Final Balance:', bill.newBalance.toStringAsFixed(2), bold: true),
                  ],
                ),
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text('Thank you for your business!'),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text,
      {bool header = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: header ? bold : regular,
          fontSize: header ? 11 : 10,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: bold ? PdfService.bold : PdfService.regular,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold ? PdfService.bold : PdfService.regular,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
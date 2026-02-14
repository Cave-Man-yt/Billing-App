// lib/services/pdf_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../models/bill_item_model.dart';
import '../providers/settings_provider.dart';

enum PdfPageSize { a4, a5 }

/// Service for generating and printing PDF bills.
/// Handles page formatting, PDF layout, and printer integration.
class PdfService {
  PdfService._();

  static pw.Font get regular => pw.Font.helvetica();
  static pw.Font get bold => pw.Font.helveticaBold();

  // Store user's preference (defaults to A5 for wholesale)

  static PdfPageSize preferredSize = PdfPageSize.a5;

  static PdfPageFormat _getPageFormat(PdfPageSize size) {
    switch (size) {
      case PdfPageSize.a4:
        return PdfPageFormat.a4;
      case PdfPageSize.a5:
        // A5 is exactly half of A4: 148mm x 210mm
        return const PdfPageFormat(
          148 * PdfPageFormat.mm, // width
          210 * PdfPageFormat.mm, // height
          marginAll: 10 * PdfPageFormat.mm,
        );
    }
  }

  /// Show dialog to let user choose print size, then print
  static Future<void> generateAndPrintBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    // Show size selection dialog
    final selectedSize = await showDialog<PdfPageSize>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Select Print Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<PdfPageSize>(
                value: PdfPageSize.a5,
                // ignore: deprecated_member_use
                groupValue: preferredSize,
                // ignore: deprecated_member_use
                onChanged: (_) {},
              ),
              title: const Text('A5 (148mm × 210mm)'),
              subtitle: const Text('Recommended for invoices'),
              onTap: () => Navigator.pop(dialogContext, PdfPageSize.a5),
            ),
            ListTile(
              leading: Radio<PdfPageSize>(
                value: PdfPageSize.a4,
                // ignore: deprecated_member_use
                groupValue: preferredSize,
                // ignore: deprecated_member_use
                onChanged: (_) {},
              ),
              title: const Text('A4 (210mm × 297mm)'),
              subtitle: const Text('Standard letter size'),
              onTap: () => Navigator.pop(dialogContext, PdfPageSize.a4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedSize == null || !context.mounted) return;

    // Remember user's choice
    preferredSize = selectedSize;

    try {
      final bytes = await _buildPdfBytes(context, bill, items, selectedSize);

      await Future.delayed(const Duration(milliseconds: 100));

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${bill.billNumber}_${selectedSize.name.toUpperCase()}',
        format: _getPageFormat(selectedSize),
      );
    } catch (e, stack) {
      debugPrint('Print failed: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print failed – sharing PDF instead')),
        );
        final bytes = await _buildPdfBytes(context, bill, items, selectedSize);
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${bill.billNumber}_${selectedSize.name.toUpperCase()}.pdf',
        );
      }
    }
  }

  /// Share bill with size options
  static Future<void> shareBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items, {
    String? filename,
  }) async {
    // Show size selection dialog
    final selectedSize = await showDialog<PdfPageSize>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Select PDF Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<PdfPageSize>(
                value: PdfPageSize.a5,
                // ignore: deprecated_member_use
                groupValue: preferredSize,
                // ignore: deprecated_member_use
                onChanged: (_) {},
              ),
              title: const Text('A5 (148mm × 210mm)'),
              subtitle: const Text('Recommended for invoices'),
              onTap: () => Navigator.pop(dialogContext, PdfPageSize.a5),
            ),
            ListTile(
              leading: Radio<PdfPageSize>(
                value: PdfPageSize.a4,
                // ignore: deprecated_member_use
                groupValue: preferredSize,
                // ignore: deprecated_member_use
                onChanged: (_) {},
              ),
              title: const Text('A4 (210mm × 297mm)'),
              subtitle: const Text('Standard letter size'),
              onTap: () => Navigator.pop(dialogContext, PdfPageSize.a4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedSize == null || !context.mounted) return;

    // Remember user's choice
    preferredSize = selectedSize;

    final bytes = await _buildPdfBytes(context, bill, items, selectedSize);
    final finalFilename =
        filename ?? '${bill.billNumber}_${selectedSize.name.toUpperCase()}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: finalFilename);
  }

  static Future<List<Uint8List>> generateBillAsImages(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    final pdfBytes = await _buildPdfBytes(context, bill, items, preferredSize);

    // Convert PDF pages to images
    // Rasterize returns a Stream of PdfRaster
    final images = <Uint8List>[];
    await for (final page in Printing.raster(pdfBytes, dpi: 200)) {
      images.add(await page.toPng());
    }
    return images;
  }

  static Future<Uint8List> _buildPdfBytes(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
    PdfPageSize pageSize,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pdf = pw.Document();

    // Adjust font sizes based on page size
    final isA5 = pageSize == PdfPageSize.a5;
    final headerSize = isA5 ? 18.0 : 24.0;
    final titleSize = isA5 ? 14.0 : 20.0;
    final normalSize = isA5 ? 9.0 : 10.0;
    final tableHeaderSize = isA5 ? 9.0 : 11.0;
    final tableDataSize = isA5 ? 8.0 : 10.0;

    // Load Om symbol
    final omSymbolImage = pw.MemoryImage(
      (await rootBundle.load('assets/images/om_symbol.png'))
          .buffer
          .asUint8List(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: _getPageFormat(pageSize),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (pw.Context ctx) {
          return [
            // Om Symbol
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Image(omSymbolImage, height: 40, width: 40),
            ),
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.shopName,
                        style: pw.TextStyle(font: bold, fontSize: headerSize),
                      ),
                      if (settings.shopAddress.isNotEmpty)
                        pw.Text(
                          settings.shopAddress,
                          style: pw.TextStyle(fontSize: normalSize),
                        ),
                      if (settings.shopPhone.isNotEmpty)
                        pw.Text(
                          'Ph: ${settings.shopPhone}',
                          style: pw.TextStyle(fontSize: normalSize),
                        ),
                      if (settings.shopEmail.isNotEmpty)
                        pw.Text(
                          settings.shopEmail,
                          style: pw.TextStyle(fontSize: normalSize),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ESTIMATE',
                      style: pw.TextStyle(font: bold, fontSize: titleSize),
                    ),
                    pw.Text(
                      'No: ${bill.billNumber}',
                      style: pw.TextStyle(fontSize: normalSize),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(bill.createdAt)}',
                      style: pw.TextStyle(fontSize: normalSize),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: isA5 ? 10 : 20),

            // Bill To
            pw.Container(
              padding: pw.EdgeInsets.all(isA5 ? 8 : 10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Bill To:',
                    style: pw.TextStyle(font: bold, fontSize: normalSize),
                  ),
                  pw.Text(
                    bill.customerName,
                    style: pw.TextStyle(fontSize: normalSize + 1),
                  ),
                  if (bill.customerCity != null)
                    pw.Text(
                      bill.customerCity!,
                      style: pw.TextStyle(fontSize: normalSize),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: isA5 ? 10 : 20),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('S.No',
                        header: true,
                        align: pw.TextAlign.center,
                        fontSize: tableHeaderSize),
                    _cell('Item', header: true, fontSize: tableHeaderSize),
                    _cell('Qty',
                        header: true,
                        align: pw.TextAlign.center,
                        fontSize: tableHeaderSize),
                    _cell('Price',
                        header: true,
                        align: pw.TextAlign.right,
                        fontSize: tableHeaderSize),
                    _cell('Total',
                        header: true,
                        align: pw.TextAlign.right,
                        fontSize: tableHeaderSize),
                  ],
                ),
                // Data rows
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return pw.TableRow(children: [
                    _cell('${index + 1}',
                        align: pw.TextAlign.center, fontSize: tableDataSize),
                    _cell(item.productName, fontSize: tableDataSize),
                    _cell(item.quantity.toStringAsFixed(0),
                        align: pw.TextAlign.center, fontSize: tableDataSize),
                    _cell(item.price.toStringAsFixed(2),
                        align: pw.TextAlign.right, fontSize: tableDataSize),
                    _cell(item.total.toStringAsFixed(2),
                        align: pw.TextAlign.right, fontSize: tableDataSize),
                  ]);
                }),
              ],
            ),
            pw.SizedBox(height: isA5 ? 10 : 20),

            // Summary
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: isA5 ? 180 : 250,
                child: pw.Column(
                  children: [
                    _summaryRow('Subtotal:', bill.subtotal.toStringAsFixed(2),
                        fontSize: normalSize),
                    if (bill.packageCharge > 0)
                      _summaryRow('Package Charge:',
                          '+${bill.packageCharge.toStringAsFixed(2)}',
                          fontSize: normalSize),
                    if (bill.boxCount > 0)
                      _summaryRow('No. of Boxes:', '${bill.boxCount}',
                          fontSize: normalSize),
                    pw.Divider(),
                    _summaryRow('Bill Total:', bill.total.toStringAsFixed(2),
                        bold: true, fontSize: normalSize + 1),
                    pw.SizedBox(height: 5),
                    _summaryRow('Previous Balance:',
                        bill.displayPreviousBalance.toStringAsFixed(2),
                        fontSize: normalSize),
                    _summaryRow(
                      'Grand Total:',
                      bill.displayGrandTotal.toStringAsFixed(2),
                      bold: true,
                      fontSize: normalSize + 1,
                    ),
                    pw.Divider(),
                    _summaryRow(
                        'Amount Paid:', bill.amountPaid.toStringAsFixed(2),
                        fontSize: normalSize),
                    _summaryRow('Final Balance:',
                        bill.displayNewBalance.toStringAsFixed(2),
                        bold: true, fontSize: normalSize + 1),
                  ],
                ),
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontSize: normalSize),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(
    String text, {
    bool header = false,
    pw.TextAlign align = pw.TextAlign.left,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: header ? bold : regular,
          fontSize: fontSize,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: bold ? PdfService.bold : PdfService.regular,
              fontSize: fontSize,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold ? PdfService.bold : PdfService.regular,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

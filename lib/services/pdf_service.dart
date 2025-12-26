// lib/services/pdf_service.dart

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/bill_item_model.dart';
import 'package:billing_app/providers/settings_provider.dart';

class PdfService {
  PdfService._();
  static late pw.Font _regularFont;
  static late pw.Font _boldFont;

  static Future<void> generateAndPrintBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    final bytes = await _buildPdfBytes(context, bill, items);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  static Future<Uint8List> buildPdfBytesOnly(BuildContext context, Bill bill, List<BillItem> items) async {
    return await _buildPdfBytes(context, bill, items);
  }

  static Future<void> shareBill(BuildContext context, Bill bill, List<BillItem> items, {String filename = 'invoice.pdf'}) async {
    final bytes = await _buildPdfBytes(context, bill, items);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<Uint8List> _buildPdfBytes(BuildContext context, Bill bill, List<BillItem> items) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pdf = pw.Document();

    // Load embedded fonts (ensure assets/fonts contain the TTF files and are listed in pubspec.yaml)
    try {
      final regData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      _regularFont = pw.Font.ttf(regData.buffer.asByteData());
    } catch (e) {
      // fallback to built-in font if asset missing
      _regularFont = pw.Font.helvetica();
    }

    try {
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      _boldFont = pw.Font.ttf(boldData.buffer.asByteData());
    } catch (e) {
      _boldFont = pw.Font.helvetica();
    }

    final hasBalance = bill.previousBalance > 0 || bill.newBalance > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Theme(
            data: pw.ThemeData(defaultTextStyle: pw.TextStyle(font: _regularFont, fontSize: 10)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(settings.shopName, style: pw.TextStyle(font: _boldFont, fontSize: 24)),
                        if (settings.shopAddress.isNotEmpty)
                          pw.Text(settings.shopAddress, style: pw.TextStyle(font: _regularFont, fontSize: 10)),
                        if (settings.shopPhone.isNotEmpty)
                          pw.Text('Ph: ${settings.shopPhone}', style: pw.TextStyle(font: _regularFont, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE', style: pw.TextStyle(font: _boldFont, fontSize: 20)),
                        pw.Text('No: ${bill.billNumber}', style: pw.TextStyle(font: _regularFont, fontSize: 10)),
                        pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(bill.createdAt)}', style: pw.TextStyle(font: _regularFont, fontSize: 10)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Bill To / Balance badge
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Bill To:', style: pw.TextStyle(font: _boldFont, fontSize: 12)),
                          pw.Text(bill.customerName, style: pw.TextStyle(font: _regularFont, fontSize: 14)),
                          if (bill.customerCity != null)
                            pw.Text(bill.customerCity!, style: pw.TextStyle(font: _regularFont, fontSize: 10)),
                        ],
                      ),
                      if (hasBalance)
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.orange50,
                            border: pw.Border.all(color: PdfColors.orange),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text('BALANCE CUSTOMER', style: pw.TextStyle(font: _boldFont, fontSize: 10, color: PdfColors.orange900)),
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Items table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _buildTableCell('Item', isHeader: true),
                        _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                        _buildTableCell('Price', isHeader: true, align: pw.TextAlign.right),
                        _buildTableCell('Total', isHeader: true, align: pw.TextAlign.right),
                      ],
                    ),
                    ...items.map((item) => pw.TableRow(
                          children: [
                            _buildTableCell(item.productName),
                            _buildTableCell(item.quantity.toString(), align: pw.TextAlign.center),
                            _buildTableCell('₹${item.price.toStringAsFixed(2)}', align: pw.TextAlign.right),
                            _buildTableCell('₹${item.total.toStringAsFixed(2)}', align: pw.TextAlign.right),
                          ],
                        )),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Summary section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250,
                      child: pw.Column(
                        children: [
                          _buildSummaryRow('Subtotal:', '₹${bill.subtotal.toStringAsFixed(2)}'),
                          if (bill.discount > 0)
                            _buildSummaryRow('Discount:', '-₹${bill.discount.toStringAsFixed(2)}'),
                          pw.Divider(),
                          _buildSummaryRow('Bill Total:', '₹${bill.total.toStringAsFixed(2)}', bold: true),
                          if (hasBalance) ...[
                            pw.SizedBox(height: 10),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.orange50,
                                border: pw.Border.all(color: PdfColors.orange),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Column(
                                children: [
                                  if (bill.previousBalance > 0)
                                    _buildSummaryRow('Previous Balance:', '₹${bill.previousBalance.toStringAsFixed(2)}'),
                                  _buildSummaryRow('Grand Total:', '₹${bill.grandTotal.toStringAsFixed(2)}', bold: true),
                                  pw.Divider(color: PdfColors.orange),
                                  _buildSummaryRow('Amount Paid:', '₹${bill.amountPaid.toStringAsFixed(2)}', color: PdfColors.green),
                                  _buildSummaryRow('New Balance:', '₹${bill.newBalance.toStringAsFixed(2)}', bold: true, color: bill.newBalance > 0 ? PdfColors.red : PdfColors.green),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (bill.amountPaid > 0) ...[
                              pw.SizedBox(height: 10),
                              _buildSummaryRow('Amount Paid:', '₹${bill.amountPaid.toStringAsFixed(2)}', color: PdfColors.green),
                              if (bill.amountPaid < bill.total)
                                _buildSummaryRow('Balance Due:', '₹${(bill.total - bill.amountPaid).toStringAsFixed(2)}', color: PdfColors.red),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (hasBalance && bill.newBalance > 0)
                        pw.Text('Outstanding Balance: ₹${bill.newBalance.toStringAsFixed(2)}', style: pw.TextStyle(font: _boldFont, fontSize: 12, color: PdfColors.red)),
                      pw.SizedBox(height: 8),
                      pw.Text('Thank you for your business!', style: pw.TextStyle(font: _regularFont, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: isHeader ? _boldFont : _regularFont,
          fontSize: isHeader ? 11 : 10,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: bold ? _boldFont : _regularFont,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold ? _boldFont : _regularFont,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
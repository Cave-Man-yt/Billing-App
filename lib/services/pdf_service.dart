// lib/services/pdf_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:billing_app/models/bill_model.dart';
import 'package:billing_app/models/bill_item_model.dart';
import 'package:billing_app/providers/settings_provider.dart';

class PdfService {
  PdfService._();

  static Future<void> generateAndPrintBill(
    BuildContext context,
    Bill bill,
    List<BillItem> items,
  ) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final pdf = pw.Document();

    // Different PDF based on whether customer has balance
    final hasBalance = bill.previousBalance > 0 || bill.newBalance > 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settings.shopName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (settings.shopAddress.isNotEmpty)
                        pw.Text(settings.shopAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (settings.shopPhone.isNotEmpty)
                        pw.Text('Ph: ${settings.shopPhone}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('No: ${bill.billNumber}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(bill.createdAt)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Customer details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(bill.customerName, style: const pw.TextStyle(fontSize: 14)),
                        if (bill.customerCity != null)
                          pw.Text(bill.customerCity!, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (hasBalance)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange100,
                          border: pw.Border.all(color: PdfColors.orange),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'BALANCE CUSTOMER',
                          style: pw.TextStyle(
                            color: PdfColors.orange900,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
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
                        _buildSummaryRow(
                          'Bill Total:',
                          '₹${bill.total.toStringAsFixed(2)}',
                          bold: true,
                        ),
                        
                        // Balance section (only for balance customers)
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
                                  _buildSummaryRow(
                                    'Previous Balance:',
                                    '₹${bill.previousBalance.toStringAsFixed(2)}',
                                  ),
                                _buildSummaryRow(
                                  'Grand Total:',
                                  '₹${bill.grandTotal.toStringAsFixed(2)}',
                                  bold: true,
                                ),
                                pw.Divider(color: PdfColors.orange),
                                _buildSummaryRow(
                                  'Amount Paid:',
                                  '₹${bill.amountPaid.toStringAsFixed(2)}',
                                  color: PdfColors.green,
                                ),
                                _buildSummaryRow(
                                  'New Balance:',
                                  '₹${bill.newBalance.toStringAsFixed(2)}',
                                  bold: true,
                                  color: bill.newBalance > 0 ? PdfColors.red : PdfColors.green,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // For non-balance customers, show paid amount if any
                          if (bill.amountPaid > 0) ...[
                            pw.SizedBox(height: 10),
                            _buildSummaryRow(
                              'Amount Paid:',
                              '₹${bill.amountPaid.toStringAsFixed(2)}',
                              color: PdfColors.green,
                            ),
                            if (bill.amountPaid < bill.total)
                              _buildSummaryRow(
                                'Balance Due:',
                                '₹${(bill.total - bill.amountPaid).toStringAsFixed(2)}',
                                color: PdfColors.red,
                              ),
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
                      pw.Text(
                        'Outstanding Balance: ₹${bill.newBalance.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Thank you for your business!',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
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
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: bold ? 12 : 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
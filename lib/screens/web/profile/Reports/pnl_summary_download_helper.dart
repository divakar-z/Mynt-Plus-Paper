// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One script-wise (or date-wise) trade row for the P&L Summary export.
/// A plain data holder so the screen can map its aggregated rows into the
/// helper without exposing its private row type.
class PnlSummaryRow {
  final String symbol;
  final double buyQty;
  final double buyRate;
  final double sellQty;
  final double sellRate;
  final double netQty;
  final double closePrice;
  final double unrealisedPnl;
  final double realisedPnl;

  const PnlSummaryRow({
    required this.symbol,
    required this.buyQty,
    required this.buyRate,
    required this.sellQty,
    required this.sellRate,
    required this.netQty,
    required this.closePrice,
    this.unrealisedPnl = 0,
    required this.realisedPnl,
  });
}

/// Client-side P&L Summary download helper for web.
/// Generates PDF and Excel files from the calendar P&L summary totals and the
/// script-wise trade breakdown shown on screen.
class PnlSummaryDownloadHelper {
  static String _q(double v) => v.toStringAsFixed(0);
  static String _n(double v) => v.toStringAsFixed(2);

  /// Generate and download a PDF of the P&L summary.
  static Future<void> downloadPdf({
    required List<PnlSummaryRow> rows,
    required String segment,
    required String clientId,
    required String clientName,
    required String dateRange,
    required double realised,
    required double unrealised,
    required double charges,
    required double net,
    bool showUnrealised = false,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/icon/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    final headerStyle =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
    final titleStyle =
        pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 7);

    // Build table rows in the on-screen column order.
    final tableRows = rows
        .map((r) => [
              r.symbol,
              _q(r.buyQty),
              _n(r.buyRate),
              _q(r.sellQty),
              _n(r.sellRate),
              _q(r.netQty),
              _n(r.closePrice),
              if (showUnrealised) _n(r.unrealisedPnl),
              _n(r.realisedPnl),
            ])
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 60, height: 30)
                else
                  pw.SizedBox(width: 60),
                pw.Text('P&L Summary — $segment', style: titleStyle),
                pw.SizedBox(width: 60),
              ],
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Client Name  :  $clientName',
                          style: headerStyle),
                      pw.SizedBox(height: 2),
                      pw.Text('Client Code   :  $clientId',
                          style: headerStyle),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date  :  $dateStr', style: headerStyle),
                      pw.SizedBox(height: 2),
                      pw.Text('Time  :  $timeStr', style: headerStyle),
                      pw.SizedBox(height: 2),
                      pw.Text('Period  :  $dateRange', style: headerStyle),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            // Summary boxes
            pw.Row(
              children: [
                _summaryBox('Realised P&L', _n(realised),
                    color: realised >= 0 ? PdfColors.green : PdfColors.red),
                pw.SizedBox(width: 4),
                _summaryBox('Unrealised P&L', _n(unrealised),
                    color: unrealised >= 0 ? PdfColors.green : PdfColors.red),
                pw.SizedBox(width: 4),
                _summaryBox('Charges & Taxes', _n(charges)),
                pw.SizedBox(width: 4),
                _summaryBox('Net Realised P&L', _n(net),
                    color: net >= 0 ? PdfColors.green : PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 2),
            pw.Text(
              'Zebu Share And Wealth Management Private Limited',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Website Address: www.zebuetrade.com, Investor Grievances Email id: grievance@zebuetrade.com',
              style: const pw.TextStyle(fontSize: 5),
            ),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1F3465),
            ),
            cellStyle: valueStyle,
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: {0: pw.Alignment.centerLeft},
            headerAlignment: pw.Alignment.centerRight,
            headerAlignments: {0: pw.Alignment.centerLeft},
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              for (var i = 1; i < (showUnrealised ? 9 : 8); i++)
                i: const pw.FlexColumnWidth(1.0),
            },
            headers: [
              'Symbol',
              'Buy Qty',
              'Buy Rate',
              'Sell Qty',
              'Sell Rate',
              'Net Qty',
              'Close Price',
              if (showUnrealised) 'Unrealised P&L',
              'Realised P&L',
            ],
            data: tableRows,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      Uint8List.fromList(bytes),
      'PnL_Summary_${segment}_${DateFormat('dd-MM-yyyy').format(now)}.pdf',
      'application/pdf',
    );
  }

  /// Generate and download an Excel workbook of the P&L summary.
  static Future<void> downloadExcel({
    required List<PnlSummaryRow> rows,
    required String segment,
    required String clientId,
    required String clientName,
    required String dateRange,
    required double realised,
    required double unrealised,
    required double charges,
    required double net,
    bool showUnrealised = false,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'PnL Summary';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    final thinBorder = Border(borderStyle: BorderStyle.Thin);

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontFamily: getFontFamily(FontFamily.Arial),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final rightStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final summaryHeaderStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: getFontFamily(FontFamily.Arial),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final summaryValueStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      numberFormat: NumFormat.standard_2,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final colHeaderStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1F226B'),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final colHeaderRightStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1F226B'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final textStyle = CellStyle(
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final numStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      numberFormat: NumFormat.standard_2,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    void setCell(int col, int row, CellValue value, CellStyle style) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = value;
      cell.cellStyle = style;
    }

    // ── Title + client info ──
    setCell(0, 0, TextCellValue('P&L Summary — $segment'), titleStyle);
    setCell(5, 0, TextCellValue('Client ID'), rightStyle);
    setCell(6, 0, TextCellValue(clientId), rightStyle);
    setCell(5, 1, TextCellValue('Client Name'), rightStyle);
    setCell(6, 1, TextCellValue(clientName), rightStyle);
    setCell(5, 2, TextCellValue('Date'), rightStyle);
    setCell(6, 2, TextCellValue(dateStr), rightStyle);
    setCell(5, 3, TextCellValue('Period'), rightStyle);
    setCell(6, 3, TextCellValue(dateRange), rightStyle);

    // ── Summary row ──
    setCell(0, 5, TextCellValue('Realised P&L'), summaryHeaderStyle);
    setCell(1, 5, TextCellValue('Unrealised P&L'), summaryHeaderStyle);
    setCell(2, 5, TextCellValue('Charges & Taxes'), summaryHeaderStyle);
    setCell(3, 5, TextCellValue('Net Realised P&L'), summaryHeaderStyle);
    setCell(0, 6, DoubleCellValue(realised), summaryValueStyle);
    setCell(1, 6, DoubleCellValue(unrealised), summaryValueStyle);
    setCell(2, 6, DoubleCellValue(charges), summaryValueStyle);
    setCell(3, 6, DoubleCellValue(net), summaryValueStyle);

    // ── Column headers ──
    var row = 8;
    final headers = [
      'Symbol',
      'Buy Qty',
      'Buy Rate',
      'Sell Qty',
      'Sell Rate',
      'Net Qty',
      'Close Price',
      if (showUnrealised) 'Unrealised P&L',
      'Realised P&L',
    ];
    for (int i = 0; i < headers.length; i++) {
      setCell(i, row, TextCellValue(headers[i]),
          i == 0 ? colHeaderStyle : colHeaderRightStyle);
    }
    row++;

    // ── Data rows ──
    for (final r in rows) {
      var c = 0;
      setCell(c++, row, TextCellValue(r.symbol), textStyle);
      setCell(c++, row, DoubleCellValue(r.buyQty), numStyle);
      setCell(c++, row, DoubleCellValue(r.buyRate), numStyle);
      setCell(c++, row, DoubleCellValue(r.sellQty), numStyle);
      setCell(c++, row, DoubleCellValue(r.sellRate), numStyle);
      setCell(c++, row, DoubleCellValue(r.netQty), numStyle);
      setCell(c++, row, DoubleCellValue(r.closePrice), numStyle);
      if (showUnrealised) {
        setCell(c++, row, DoubleCellValue(r.unrealisedPnl), numStyle);
      }
      setCell(c++, row, DoubleCellValue(r.realisedPnl), numStyle);
      row++;
    }

    sheet.setColumnWidth(0, 26);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
    sheet.setColumnWidth(5, 16);
    sheet.setColumnWidth(6, 20);
    sheet.setRowHeight(0, 33);

    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadFile(
      Uint8List.fromList(bytes),
      'PnL_Summary_${segment}_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Helper: summary box for PDF.
  static pw.Widget _summaryBox(String label, String value, {PdfColor? color}) {
    final displayColor = color ?? PdfColors.black;
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style:
                    pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 8, color: displayColor)),
          ],
        ),
      ),
    );
  }

  /// Trigger browser download.
  static void _downloadFile(
      Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

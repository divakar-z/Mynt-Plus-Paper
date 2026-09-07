// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/desk_reports_model/tradebook_model.dart';

/// Client-side Tradebook download helper for web.
/// Generates PDF and Excel files from trade data.
///
/// Columns mirror the on-screen table (see `tradebook_screen_web.dart`):
/// Trade Date, Exchange, Scrip, Trade Type, Quantity, Price, Amount, Trade No.
/// The caller passes the already filtered + sorted list so the file matches
/// exactly what the user is looking at.
class TradebookDownloadHelper {
  static double _toDouble(String? val) => double.tryParse(val ?? '0') ?? 0;

  static String _formatNumber(String? val) {
    final num = _toDouble(val);
    return num.toStringAsFixed(2);
  }

  static String _formatQty(String? val) {
    final num = _toDouble(val);
    return num.toStringAsFixed(0);
  }

  /// Buy / sell split used by both the PDF and Excel summaries.
  static _Totals _totals(List<Trades> trades) {
    double buyValue = 0;
    double sellValue = 0;
    int buyCount = 0;
    int sellCount = 0;

    for (final t in trades) {
      final amount = _toDouble(t.showamt);
      final type = (t.showtype ?? '').toUpperCase();
      if (type.startsWith('B')) {
        buyValue += amount;
        buyCount++;
      } else if (type.startsWith('S')) {
        sellValue += amount;
        sellCount++;
      }
    }

    return _Totals(
      buyValue: buyValue,
      sellValue: sellValue,
      buyCount: buyCount,
      sellCount: sellCount,
    );
  }

  /// Generate and download a PDF file from Tradebook data.
  static Future<void> downloadPdf({
    required List<Trades> trades,
    required String clientId,
    required String clientName,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/icon/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    final totals = _totals(trades);

    final tableRows = trades
        .map((t) => [
              t.tRADEDATE ?? '',
              t.cOMPANYCODE ?? '',
              t.sCRIPNAME ?? '',
              t.showtype ?? '',
              _formatQty(t.showqnt),
              _formatNumber(t.showprice),
              _formatNumber(t.showamt),
              t.tRADENUMBER ?? '',
            ])
        .toList();

    final headerStyle = pw.TextStyle(
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
    );
    final valueStyle = const pw.TextStyle(fontSize: 6.5);
    final titleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo + Title row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 60, height: 30)
                else
                  pw.SizedBox(width: 60),
                pw.Text('Tradebook', style: titleStyle),
                pw.SizedBox(width: 60),
              ],
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            // Client info
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
                _summaryBox('Total Trades', '${trades.length}'),
                pw.SizedBox(width: 4),
                _summaryBox('Buy Trades', '${totals.buyCount}'),
                pw.SizedBox(width: 4),
                _summaryBox('Sell Trades', '${totals.sellCount}'),
                pw.SizedBox(width: 4),
                _summaryBox('Buy Value', totals.buyValue.toStringAsFixed(2)),
                pw.SizedBox(width: 4),
                _summaryBox('Sell Value', totals.sellValue.toStringAsFixed(2)),
                pw.SizedBox(width: 4),
                _summaryBox('Turnover', totals.turnover.toStringAsFixed(2)),
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
              style:
                  pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Correspondence Office: No: 301, 4th Main Road, Burma Colony, Perungudi, Chennai, Tamil Nadu 600 096. Phone No: 044-4855 7991',
              style: const pw.TextStyle(fontSize: 4),
            ),
            pw.Text(
              'TRADING MEMBER CODE: NSE-EQ,F&O,CDS,COM: 13179 , BSE-EQ,F&O,CD,COM: 6550, MSEI - EQ,F&O,CDS:83300 CIN NO: U67120TZ2013PTC019704',
              style: const pw.TextStyle(fontSize: 4),
            ),
            pw.Text(
              'Website Address: www.zebuetrade.com, Investor Grievances Email id: grievance@zebuetrade.com',
              style: const pw.TextStyle(fontSize: 4),
            ),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            border:
                pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1F3465),
            ),
            cellStyle: valueStyle,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              4: pw.Alignment.centerRight, // Quantity
              5: pw.Alignment.centerRight, // Price
              6: pw.Alignment.centerRight, // Amount
              7: pw.Alignment.centerRight, // Trade No
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Trade Date
              1: const pw.FlexColumnWidth(1.0), // Exchange
              2: const pw.FlexColumnWidth(2.5), // Scrip
              3: const pw.FlexColumnWidth(0.9), // Trade Type
              4: const pw.FlexColumnWidth(0.9), // Quantity
              5: const pw.FlexColumnWidth(1.2), // Price
              6: const pw.FlexColumnWidth(1.3), // Amount
              7: const pw.FlexColumnWidth(1.3), // Trade No
            },
            headers: [
              'Trade Date',
              'Exchange',
              'Scrip',
              'Trade Type',
              'Quantity',
              'Price',
              'Amount',
              'Trade No',
            ],
            data: tableRows,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      Uint8List.fromList(bytes),
      'Tradebook_${DateFormat('dd-MM-yyyy').format(now)}.pdf',
      'application/pdf',
    );
  }

  /// Generate and download an Excel file from Tradebook data.
  static Future<void> downloadExcel({
    required List<Trades> trades,
    required String clientId,
    required String clientName,
    required String dateRange,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Tradebook';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    // Track max content length per column for auto-fit
    final Map<int, int> colWidths = {};
    void trackWidth(int col, String value) {
      if (value.length > (colWidths[col] ?? 0)) {
        colWidths[col] = value.length;
      }
    }

    // ── Thin border for all cells ──
    final thinBorder = Border(borderStyle: BorderStyle.Thin);

    // ── Style definitions ──
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
      numberFormat: NumFormat.standard_4,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );
    final summaryValueStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      numberFormat: NumFormat.standard_4,
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
      numberFormat: NumFormat.standard_4,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    // ── Helpers ──
    void setCell(int col, int row, CellValue value, CellStyle style) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = value;
      cell.cellStyle = style;
    }

    void setTextCell(int col, int row, String value, CellStyle style) {
      if (value.isEmpty) return;
      setCell(col, row, TextCellValue(value), style);
      trackWidth(col, value);
    }

    void setNumCell(int col, int row, double value, CellStyle style) {
      setCell(col, row, DoubleCellValue(value), style);
      trackWidth(col, value.toStringAsFixed(2));
    }

    final totals = _totals(trades);

    // ════════════════════════════════════════════════════════════
    // ROW 0: Title + Client info
    // ════════════════════════════════════════════════════════════
    setTextCell(1, 0, 'Tradebook', titleStyle);
    setTextCell(6, 0, 'Client ID', rightStyle);
    setTextCell(7, 0, clientId, rightStyle);

    // ROW 1-3: Client info
    setTextCell(6, 1, 'Client Name', rightStyle);
    setTextCell(7, 1, clientName, rightStyle);
    setTextCell(6, 2, 'Date', rightStyle);
    setTextCell(7, 2, dateStr, rightStyle);
    setTextCell(6, 3, 'Period', rightStyle);
    setTextCell(7, 3, dateRange, rightStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 5: Summary headers
    // ROW 6: Summary values
    // ════════════════════════════════════════════════════════════
    setTextCell(0, 5, 'Total Trades', summaryHeaderStyle);
    setTextCell(1, 5, 'Buy Trades', summaryHeaderStyle);
    setTextCell(2, 5, 'Sell Trades', summaryHeaderStyle);
    setTextCell(3, 5, 'Buy Value', summaryHeaderStyle);
    setTextCell(4, 5, 'Sell Value', summaryHeaderStyle);
    setTextCell(5, 5, 'Turnover', summaryHeaderStyle);

    setNumCell(0, 6, trades.length.toDouble(), summaryValueStyle);
    setNumCell(1, 6, totals.buyCount.toDouble(), summaryValueStyle);
    setNumCell(2, 6, totals.sellCount.toDouble(), summaryValueStyle);
    setNumCell(3, 6, totals.buyValue, summaryValueStyle);
    setNumCell(4, 6, totals.sellValue, summaryValueStyle);
    setNumCell(5, 6, totals.turnover, summaryValueStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 8: Column headers
    // ════════════════════════════════════════════════════════════
    final headers = [
      'Trade Date',
      'Exchange',
      'Scrip',
      'Trade Type',
      'Quantity',
      'Price',
      'Amount',
      'Trade No',
    ];
    for (int i = 0; i < headers.length; i++) {
      final style = i >= 4 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 8, headers[i], style);
    }

    // ════════════════════════════════════════════════════════════
    // ROW 9+: Data rows
    // ════════════════════════════════════════════════════════════
    for (int r = 0; r < trades.length; r++) {
      final t = trades[r];
      final row = 9 + r;
      setTextCell(0, row, t.tRADEDATE ?? '', textStyle);
      setTextCell(1, row, t.cOMPANYCODE ?? '', textStyle);
      setTextCell(2, row, t.sCRIPNAME ?? '', textStyle);
      setTextCell(3, row, t.showtype ?? '', textStyle);
      setNumCell(4, row, _toDouble(t.showqnt), numStyle);
      setNumCell(5, row, _toDouble(t.showprice), numStyle);
      setNumCell(6, row, _toDouble(t.showamt), numStyle);
      // Trade numbers are identifiers, not quantities — keep them as text so
      // Excel doesn't reformat or round them.
      setTextCell(7, row, t.tRADENUMBER ?? '', rightStyle);
    }

    // ════════════════════════════════════════════════════════════
    // FOOTER rows
    // ════════════════════════════════════════════════════════════
    final footerStart = 9 + trades.length + 1;
    final footerLines = [
      'Zebu Share And Wealth Management Private Limited',
      'Correspondence Office: No: 301, 4th Main Road, Burma Colony, Perungudi, Chennai, Tamil Nadu 600 096.',
      'Phone No: 044-4855 7991, Fax: 044-4855 7991',
      'TRADING MEMBER CODE: NSE-EQ,F&O,CDS,COM: 13179 , BSE-EQ,F&O,CD,COM: 6550, MSEI - EQ,F&O,CDS:83300',
      'CIN NO: U67120TZ2013PTC019704 Website Address: www.zebuetrade.com, Investor Grievances Email id: grievance@zebuetrade.com',
    ];
    for (int i = 0; i < footerLines.length; i++) {
      setCell(
          0, footerStart + i, TextCellValue(footerLines[i]), textStyle);
    }

    // ════════════════════════════════════════════════════════════
    // AUTO-FIT COLUMN WIDTHS
    // ════════════════════════════════════════════════════════════
    for (final entry in colWidths.entries) {
      final w = entry.value < 10 ? 10.0 : (entry.value + 2).toDouble();
      sheet.setColumnWidth(entry.key, w);
    }

    // Scrip column: minimum 25
    if ((colWidths[2] ?? 0) < 25) {
      sheet.setColumnWidth(2, 25);
    }

    sheet.setRowHeight(0, 33);

    // Encode and download
    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadFile(
      Uint8List.fromList(bytes),
      'Tradebook_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Helper: summary box for PDF
  static pw.Widget _summaryBox(String label, String value,
      {PdfColor? color}) {
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
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 8, color: displayColor)),
          ],
        ),
      ),
    );
  }

  /// Trigger browser download
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

/// Buy / sell aggregates shared by the PDF and Excel summary blocks.
class _Totals {
  final double buyValue;
  final double sellValue;
  final int buyCount;
  final int sellCount;

  const _Totals({
    required this.buyValue,
    required this.sellValue,
    required this.buyCount,
    required this.sellCount,
  });

  double get turnover => buyValue + sellValue;
}

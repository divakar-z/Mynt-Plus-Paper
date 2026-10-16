// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../sharedWidget/functions.dart';

/// Client-side Positions download helper for web.
/// Generates PDF and Excel files from position data.
///
/// Columns mirror the on-screen table (see `position_screen.dart`):
/// Instrument, Qty, Avg Price, LTP, P&L, Buy Qty, Sell Qty, Buy Avg, Buy Amt,
/// Sell Avg, Sell Amt.
///
/// [showMtm] must match the screen's P&L / MTM toggle — the same row renders
/// different values in each mode, and the file has to agree with the table.
class PositionsDownloadHelper {
  static double _toDouble(dynamic val) =>
      double.tryParse(val?.toString() ?? '0') ?? 0;

  static String _formatNumber(dynamic val) => _toDouble(val).toStringAsFixed(2);

  static String _formatQty(dynamic val) => _toDouble(val).toStringAsFixed(0);

  /// Instrument label, built the same way the table builds it.
  static String _instrument(dynamic p) {
    final parsed = spilitTsym(value: p.tsym?.toString() ?? '');
    final symbolText = '${parsed["symbol"]}'.replaceAll('-EQ', '');
    final expText = '${parsed["expDate"]}';
    final optionText = '${parsed["option"]}';
    final displaySymbol = '$symbolText $expText $optionText'.trim();
    final exchange = p.exch?.toString() ?? '';
    return exchange.isNotEmpty ? '$displaySymbol $exchange' : displaySymbol;
  }

  static double _pnl(dynamic p, bool showMtm) =>
      showMtm ? _toDouble(p.rmtm) : _toDouble(p.rpnl);

  static dynamic _avgPrice(dynamic p, bool showMtm) =>
      showMtm ? p.netavgpricemtm : p.netAvgPrc;

  static dynamic _buyAvg(dynamic p, bool showMtm) =>
      showMtm ? p.buypricemtm : p.buyPrice;

  static dynamic _buyAmt(dynamic p, bool showMtm) =>
      showMtm ? p.buyvaluemtm : p.buyValue;

  static dynamic _sellAvg(dynamic p, bool showMtm) =>
      showMtm ? p.sellPricemtm : p.sellPrice;

  static dynamic _sellAmt(dynamic p, bool showMtm) =>
      showMtm ? p.sellValuemtm : p.sellValue;

  /// Aggregates shared by both the PDF and Excel summaries.
  static _Totals _totals(List<dynamic> positions, bool showMtm) {
    double totalPnl = 0;
    double buyValue = 0;
    double sellValue = 0;
    int openCount = 0;

    for (final p in positions) {
      totalPnl += _pnl(p, showMtm);
      buyValue += _toDouble(_buyAmt(p, showMtm));
      sellValue += _toDouble(_sellAmt(p, showMtm));
      if (_toDouble(p.netqty) != 0) openCount++;
    }

    return _Totals(
      totalPnl: totalPnl,
      buyValue: buyValue,
      sellValue: sellValue,
      openCount: openCount,
      closedCount: positions.length - openCount,
    );
  }

  /// Generate and download a PDF file from position data.
  static Future<void> downloadPdf({
    required List<dynamic> positions,
    required String clientId,
    required String clientName,
    required bool showMtm,
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

    final totals = _totals(positions, showMtm);
    final pnlLabel = showMtm ? 'MTM' : 'P&L';

    final tableRows = positions
        .map((p) => [
              _instrument(p),
              _formatQty(p.netqty),
              _formatNumber(_avgPrice(p, showMtm)),
              _formatNumber(p.ltp),
              _pnl(p, showMtm).toStringAsFixed(2),
              _formatQty(p.buyQuantity),
              _formatQty(p.sellQuantity),
              _formatNumber(_buyAvg(p, showMtm)),
              _formatNumber(_buyAmt(p, showMtm)),
              _formatNumber(_sellAvg(p, showMtm)),
              _formatNumber(_sellAmt(p, showMtm)),
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
        pageFormat: PdfPageFormat.a4.landscape,
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
                pw.Text('Positions', style: titleStyle),
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
                      pw.Text('Valuation  :  $pnlLabel', style: headerStyle),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            // Summary boxes
            pw.Row(
              children: [
                _summaryBox('Total $pnlLabel', totals.totalPnl.toStringAsFixed(2),
                    color: totals.totalPnl >= 0
                        ? PdfColors.green
                        : PdfColors.red),
                pw.SizedBox(width: 4),
                _summaryBox('Open', '${totals.openCount}'),
                pw.SizedBox(width: 4),
                _summaryBox('Closed', '${totals.closedCount}'),
                pw.SizedBox(width: 4),
                _summaryBox('Buy Value', totals.buyValue.toStringAsFixed(2)),
                pw.SizedBox(width: 4),
                _summaryBox('Sell Value', totals.sellValue.toStringAsFixed(2)),
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
              for (int i = 1; i <= 10; i++) i: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(2.8), // Instrument
              1: const pw.FlexColumnWidth(0.8), // Qty
              2: const pw.FlexColumnWidth(1.1), // Avg Price
              3: const pw.FlexColumnWidth(1.1), // LTP
              4: const pw.FlexColumnWidth(1.2), // P&L
              5: const pw.FlexColumnWidth(0.9), // Buy Qty
              6: const pw.FlexColumnWidth(0.9), // Sell Qty
              7: const pw.FlexColumnWidth(1.1), // Buy Avg
              8: const pw.FlexColumnWidth(1.2), // Buy Amt
              9: const pw.FlexColumnWidth(1.1), // Sell Avg
              10: const pw.FlexColumnWidth(1.2), // Sell Amt
            },
            headers: [
              'Instrument',
              'Qty',
              'Avg Price',
              'LTP',
              pnlLabel,
              'Buy Qty',
              'Sell Qty',
              'Buy Avg',
              'Buy Amt',
              'Sell Avg',
              'Sell Amt',
            ],
            data: tableRows,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      Uint8List.fromList(bytes),
      'Positions_${DateFormat('dd-MM-yyyy').format(now)}.pdf',
      'application/pdf',
    );
  }

  /// Generate and download an Excel file from position data.
  static Future<void> downloadExcel({
    required List<dynamic> positions,
    required String clientId,
    required String clientName,
    required bool showMtm,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Positions';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final pnlLabel = showMtm ? 'MTM' : 'P&L';

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

    final totals = _totals(positions, showMtm);

    // ════════════════════════════════════════════════════════════
    // ROW 0: Title + Client info
    // ════════════════════════════════════════════════════════════
    setTextCell(1, 0, 'Positions', titleStyle);
    setTextCell(8, 0, 'Client ID', rightStyle);
    setTextCell(9, 0, clientId, rightStyle);

    // ROW 1-3: Client info
    setTextCell(8, 1, 'Client Name', rightStyle);
    setTextCell(9, 1, clientName, rightStyle);
    setTextCell(8, 2, 'Date', rightStyle);
    setTextCell(9, 2, dateStr, rightStyle);
    setTextCell(8, 3, 'Valuation', rightStyle);
    setTextCell(9, 3, pnlLabel, rightStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 5: Summary headers
    // ROW 6: Summary values
    // ════════════════════════════════════════════════════════════
    setTextCell(0, 5, 'Total $pnlLabel', summaryHeaderStyle);
    setTextCell(1, 5, 'Open', summaryHeaderStyle);
    setTextCell(2, 5, 'Closed', summaryHeaderStyle);
    setTextCell(3, 5, 'Buy Value', summaryHeaderStyle);
    setTextCell(4, 5, 'Sell Value', summaryHeaderStyle);

    setNumCell(0, 6, totals.totalPnl, summaryValueStyle);
    setNumCell(1, 6, totals.openCount.toDouble(), summaryValueStyle);
    setNumCell(2, 6, totals.closedCount.toDouble(), summaryValueStyle);
    setNumCell(3, 6, totals.buyValue, summaryValueStyle);
    setNumCell(4, 6, totals.sellValue, summaryValueStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 8: Column headers
    // ════════════════════════════════════════════════════════════
    final headers = [
      'Instrument',
      'Qty',
      'Avg Price',
      'LTP',
      pnlLabel,
      'Buy Qty',
      'Sell Qty',
      'Buy Avg',
      'Buy Amt',
      'Sell Avg',
      'Sell Amt',
    ];
    for (int i = 0; i < headers.length; i++) {
      final style = i >= 1 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 8, headers[i], style);
    }

    // ════════════════════════════════════════════════════════════
    // ROW 9+: Data rows
    // ════════════════════════════════════════════════════════════
    for (int r = 0; r < positions.length; r++) {
      final p = positions[r];
      final row = 9 + r;
      setTextCell(0, row, _instrument(p), textStyle);
      setNumCell(1, row, _toDouble(p.netqty), numStyle);
      setNumCell(2, row, _toDouble(_avgPrice(p, showMtm)), numStyle);
      setNumCell(3, row, _toDouble(p.ltp), numStyle);
      setNumCell(4, row, _pnl(p, showMtm), numStyle);
      setNumCell(5, row, _toDouble(p.buyQuantity), numStyle);
      setNumCell(6, row, _toDouble(p.sellQuantity), numStyle);
      setNumCell(7, row, _toDouble(_buyAvg(p, showMtm)), numStyle);
      setNumCell(8, row, _toDouble(_buyAmt(p, showMtm)), numStyle);
      setNumCell(9, row, _toDouble(_sellAvg(p, showMtm)), numStyle);
      setNumCell(10, row, _toDouble(_sellAmt(p, showMtm)), numStyle);
    }

    // ════════════════════════════════════════════════════════════
    // FOOTER rows
    // ════════════════════════════════════════════════════════════
    final footerStart = 9 + positions.length + 1;
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

    // Instrument column: minimum 25
    if ((colWidths[0] ?? 0) < 25) {
      sheet.setColumnWidth(0, 25);
    }

    sheet.setRowHeight(0, 33);

    // Encode and download
    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadFile(
      Uint8List.fromList(bytes),
      'Positions_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
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

/// Aggregates shared by the PDF and Excel summary blocks.
class _Totals {
  final double totalPnl;
  final double buyValue;
  final double sellValue;
  final int openCount;
  final int closedCount;

  const _Totals({
    required this.totalPnl,
    required this.buyValue,
    required this.sellValue,
    required this.openCount,
    required this.closedCount,
  });
}

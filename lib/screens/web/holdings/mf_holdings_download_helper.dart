// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/mf_model/mf_demat_holding_model.dart';

/// Client-side Mutual Fund holdings download helper for web.
/// Generates PDF and Excel files from the demat MF holdings data shown in the
/// Holdings screen's "Mutual Fund" tab.
///
/// Mirrors [HoldingsDownloadHelper] (same header/footer/summary layout) but is
/// backed by [MfDematHoldingData] — NAV/units instead of price/qty, and there is
/// no live socket feed for MF, so every value comes straight from the model.
class MfHoldingsDownloadHelper {
  static double _toDouble(String? val) => double.tryParse(val ?? '0') ?? 0;

  static String _formatNumber(double val) => val.toStringAsFixed(2);

  /// Units and NAVs carry 4 decimals across the MF screens.
  static String _formatNav(double val) => val.toStringAsFixed(4);

  /// Rows are exported in the table's default order (alphabetical by fund
  /// name). Sorts a copy so the provider's list is never mutated.
  static List<MfDematHoldingData> _sorted(List<MfDematHoldingData> holdings) {
    return List.of(holdings)
      ..sort((a, b) => (a.scripName ?? '')
          .toLowerCase()
          .compareTo((b.scripName ?? '').toLowerCase()));
  }

  /// Generate and download a PDF file from mutual fund holdings data.
  static Future<void> downloadPdf({
    required List<MfDematHoldingData> holdings,
    required String clientId,
    required String clientName,
    required double totalInvested,
    required double totalCurrentValue,
    required double totalReturns,
    required double totalReturnsPercent,
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

    // Build table data rows
    final tableRows = _sorted(holdings).map((h) {
      final units = _toDouble(h.totalUnits);
      final avgNav = _toDouble(h.avgNav);
      final curNav = _toDouble(h.curNav);
      final invested = _toDouble(h.investedValue);
      final currentValue = _toDouble(h.currentValue);
      final pnl = _toDouble(h.profitLoss);
      final chgPercent = _toDouble(h.changeprofitLoss);

      return [
        h.scripName ?? 'N/A',
        _formatNav(units),
        _formatNav(avgNav),
        _formatNav(curNav),
        _formatNumber(invested),
        _formatNumber(currentValue),
        _formatNumber(pnl),
        '${chgPercent >= 0 ? "+" : ""}${_formatNumber(chgPercent)}%',
      ];
    }).toList();

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
                pw.Text('Mutual Fund Holdings', style: titleStyle),
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
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            // Summary boxes
            pw.Row(
              children: [
                _summaryBox('Total Funds', holdings.length.toString()),
                pw.SizedBox(width: 4),
                _summaryBox('Invested', _formatNumber(totalInvested)),
                pw.SizedBox(width: 4),
                _summaryBox(
                    'Current Value', _formatNumber(totalCurrentValue)),
                pw.SizedBox(width: 4),
                _summaryBox('Returns', _formatNumber(totalReturns),
                    color:
                        totalReturns >= 0 ? PdfColors.green : PdfColors.red),
                pw.SizedBox(width: 4),
                _summaryBox(
                    'Returns %', '${_formatNumber(totalReturnsPercent)}%',
                    color: totalReturnsPercent >= 0
                        ? PdfColors.green
                        : PdfColors.red),
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
            columnWidths: {
              0: const pw.FlexColumnWidth(4),   // Fund Name
              1: const pw.FlexColumnWidth(1.2), // Units
              2: const pw.FlexColumnWidth(1.2), // Avg NAV
              3: const pw.FlexColumnWidth(1.2), // Cur NAV
              4: const pw.FlexColumnWidth(1.2), // Invested
              5: const pw.FlexColumnWidth(1.2), // Current Value
              6: const pw.FlexColumnWidth(1.2), // P&L
              7: const pw.FlexColumnWidth(1),   // Chg %
            },
            headers: [
              'Fund Name',
              'Units',
              'Avg NAV',
              'Cur NAV',
              'Invested',
              'Current Value',
              'P&L',
              'Chg %',
            ],
            data: tableRows,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      Uint8List.fromList(bytes),
      'Mutual_Fund_Holdings_${DateFormat('dd-MM-yyyy').format(now)}.pdf',
      'application/pdf',
    );
  }

  /// Generate and download an Excel file from mutual fund holdings data.
  ///
  /// Built on Syncfusion xlsio rather than the `excel` package, because that
  /// package has no image support at all and the client asked for the logo in
  /// the Excel the way it already appears in the PDF. Everything else - the
  /// columns, their order, the styles, the summary block, the footer and the
  /// file name - is a like-for-like port of the previous version, which is
  /// kept commented out directly below for rollback.
  static Future<void> downloadExcel({
    required List<MfDematHoldingData> holdings,
    required String clientId,
    required String clientName,
    required double totalInvested,
    required double totalCurrentValue,
    required double totalReturns,
    required double totalReturnsPercent,
  }) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'MF Holdings';

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    // Track max content length per column for auto-fit. Columns stay 0-based
    // here and are converted on the way out, since xlsio indexes from 1.
    final Map<int, int> colWidths = {};
    void trackWidth(int col, String value) {
      if (value.length > (colWidths[col] ?? 0)) {
        colWidths[col] = value.length;
      }
    }

    // -- Style definitions --
    const numberFormat = '#,##0.00'; // was NumFormat.standard_4

    void addBorders(xlsio.Style style) {
      style.borders.all.lineStyle = xlsio.LineStyle.thin;
    }

    final titleStyle = workbook.styles.add('titleStyle');
    titleStyle.bold = true;
    titleStyle.fontSize = 14;
    titleStyle.fontName = 'Arial';
    addBorders(titleStyle);

    final rightStyle = workbook.styles.add('rightStyle');
    rightStyle.hAlign = xlsio.HAlignType.right;
    addBorders(rightStyle);

    final summaryHeaderStyle = workbook.styles.add('summaryHeaderStyle');
    summaryHeaderStyle.bold = true;
    summaryHeaderStyle.fontSize = 11;
    summaryHeaderStyle.fontName = 'Arial';
    summaryHeaderStyle.hAlign = xlsio.HAlignType.right;
    summaryHeaderStyle.numberFormat = numberFormat;
    addBorders(summaryHeaderStyle);

    final summaryValueStyle = workbook.styles.add('summaryValueStyle');
    summaryValueStyle.hAlign = xlsio.HAlignType.right;
    summaryValueStyle.numberFormat = numberFormat;
    addBorders(summaryValueStyle);

    final colHeaderStyle = workbook.styles.add('colHeaderStyle');
    colHeaderStyle.bold = true;
    colHeaderStyle.fontColor = '#FFFFFF';
    colHeaderStyle.backColor = '#1F226B';
    addBorders(colHeaderStyle);

    final colHeaderRightStyle = workbook.styles.add('colHeaderRightStyle');
    colHeaderRightStyle.bold = true;
    colHeaderRightStyle.fontColor = '#FFFFFF';
    colHeaderRightStyle.backColor = '#1F226B';
    colHeaderRightStyle.hAlign = xlsio.HAlignType.right;
    addBorders(colHeaderRightStyle);

    final textStyle = workbook.styles.add('textStyle');
    addBorders(textStyle);

    final numStyle = workbook.styles.add('numStyle');
    numStyle.hAlign = xlsio.HAlignType.right;
    numStyle.numberFormat = numberFormat;
    addBorders(numStyle);

    // -- Helpers (col/row stay 0-based to match the previous version) --
    void setTextCell(int col, int row, String value, xlsio.Style style) {
      if (value.isEmpty) return;
      sheet.getRangeByIndex(row + 1, col + 1)
        ..setText(value)
        ..cellStyle = style;
      trackWidth(col, value);
    }

    void setNumCell(int col, int row, double value, xlsio.Style style) {
      sheet.getRangeByIndex(row + 1, col + 1)
        ..setNumber(value)
        ..cellStyle = style;
      trackWidth(col, value.toStringAsFixed(2));
    }

    // ============================================================
    // ROW 0: Logo + Title + Client info
    // ============================================================
    // Logo sits in A1, the same asset and size the PDF header uses. The row
    // height set at the end reserves space for it.
    try {
      final logoBytes = await rootBundle.load('assets/icon/logo.png');
      // Pass the Uint8List itself, NOT .toList(). xlsio's Picture constructor
      // casts the data with `as Uint8List` before decoding the PNG, so a plain
      // List<int> throws a TypeError and the picture is silently dropped.
      final picture =
          sheet.pictures.addStream(1, 1, logoBytes.buffer.asUint8List());
      // The PDF's 60x30 are POINTS on an A4 page; in Excel they are pixels,
      // which rendered the logo smaller than the asset itself. Sized up on the
      // asset's own 106x50 aspect ratio instead. Row 1 height below follows.
      picture.width = 127;
      picture.height = 60;
    } catch (e) {
      // Logo is decoration - a missing asset must never fail the download.
      // Logged so a failure here is never silent again.
      debugPrint('[MfHoldingsDownload] Excel logo skipped: $e');
    }

    setTextCell(1, 0, 'Mutual Fund Holdings', titleStyle);
    setTextCell(6, 0, 'Client ID', rightStyle);
    setTextCell(7, 0, clientId, rightStyle);

    // ROW 1-2: Client info
    setTextCell(6, 1, 'Client Name', rightStyle);
    setTextCell(7, 1, clientName, rightStyle);
    setTextCell(6, 2, 'Date', rightStyle);
    setTextCell(7, 2, dateStr, rightStyle);

    // ============================================================
    // ROW 4: Summary headers
    // ROW 5: Summary values
    // ============================================================
    setTextCell(0, 4, 'Total Funds', summaryHeaderStyle);
    setTextCell(1, 4, 'Invested', summaryHeaderStyle);
    setTextCell(2, 4, 'Current Value', summaryHeaderStyle);
    setTextCell(3, 4, 'Returns', summaryHeaderStyle);
    setTextCell(4, 4, 'Returns %', summaryHeaderStyle);

    setNumCell(0, 5, holdings.length.toDouble(), summaryValueStyle);
    setNumCell(1, 5, totalInvested, summaryValueStyle);
    setNumCell(2, 5, totalCurrentValue, summaryValueStyle);
    setNumCell(3, 5, totalReturns, summaryValueStyle);
    setNumCell(4, 5, totalReturnsPercent, summaryValueStyle);

    // ============================================================
    // ROW 7: Column headers
    // ============================================================
    final headers = [
      'Fund Name',
      'ISIN',
      'Units',
      'Avg NAV',
      'Cur NAV',
      'Invested',
      'Current Value',
      'P&L',
      'Chg %',
    ];
    for (int i = 0; i < headers.length; i++) {
      final style = i >= 2 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 7, headers[i], style);
    }

    // ============================================================
    // ROW 8+: Data rows
    // ============================================================
    final rows = _sorted(holdings);
    for (int r = 0; r < rows.length; r++) {
      final h = rows[r];
      final row = 8 + r;

      setTextCell(0, row, h.scripName ?? 'N/A', textStyle);
      setTextCell(1, row, h.iSIN ?? '', textStyle);
      setNumCell(2, row, _toDouble(h.totalUnits), numStyle);
      setNumCell(3, row, _toDouble(h.avgNav), numStyle);
      setNumCell(4, row, _toDouble(h.curNav), numStyle);
      setNumCell(5, row, _toDouble(h.investedValue), numStyle);
      setNumCell(6, row, _toDouble(h.currentValue), numStyle);
      setNumCell(7, row, _toDouble(h.profitLoss), numStyle);
      setNumCell(8, row, _toDouble(h.changeprofitLoss), numStyle);
    }

    // ============================================================
    // FOOTER rows
    // ============================================================
    final footerStart = 8 + rows.length + 1;
    final footerLines = [
      'Zebu Share And Wealth Management Private Limited',
      'Correspondence Office: No: 301, 4th Main Road, Burma Colony, Perungudi, Chennai, Tamil Nadu 600 096.',
      'Phone No: 044-4855 7991, Fax: 044-4855 7991',
      'TRADING MEMBER CODE: NSE-EQ,F&O,CDS,COM: 13179 , BSE-EQ,F&O,CD,COM: 6550, MSEI - EQ,F&O,CDS:83300',
      'CIN NO: U67120TZ2013PTC019704 Website Address: www.zebuetrade.com, Investor Grievances Email id: grievance@zebuetrade.com',
    ];
    for (int i = 0; i < footerLines.length; i++) {
      // Footer text must not stretch column A, so it skips trackWidth.
      sheet.getRangeByIndex(footerStart + i + 1, 1)
        ..setText(footerLines[i])
        ..cellStyle = textStyle;
    }

    // ============================================================
    // AUTO-FIT COLUMN WIDTHS
    // ============================================================
    for (final entry in colWidths.entries) {
      final w = entry.value < 10 ? 10.0 : (entry.value + 2).toDouble();
      sheet.getRangeByIndex(1, entry.key + 1).columnWidth = w;
    }

    // Fund Name column: minimum 40 (scheme names are long)
    if ((colWidths[0] ?? 0) < 40) {
      sheet.getRangeByIndex(1, 1).columnWidth = 40;
    }

    // Row 1 height reserves space for the logo: 60px is 45pt, plus a little
    // breathing room so the logo does not touch the row border. Was 33 on the
    // `excel` version, which had no logo to make room for.
    sheet.getRangeByIndex(1, 1).rowHeight = 48;

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    _downloadFile(
      Uint8List.fromList(bytes),
      'Mutual_Fund_Holdings_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // -- Retired 2026-09-22: the `excel` package version. Kept for rollback.
  // It cannot carry a logo - that package has no image API at all - which is
  // the only reason it was replaced. A copy also sits in
  // mf_holdings_download_helper.dart.bak.
  /*
  /// Generate and download an Excel file from mutual fund holdings data.
  static Future<void> downloadExcel({
    required List<MfDematHoldingData> holdings,
    required String clientId,
    required String clientName,
    required double totalInvested,
    required double totalCurrentValue,
    required double totalReturns,
    required double totalReturnsPercent,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'MF Holdings';
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

    // ════════════════════════════════════════════════════════════
    // ROW 0: Title + Client info
    // ════════════════════════════════════════════════════════════
    setTextCell(1, 0, 'Mutual Fund Holdings', titleStyle);
    setTextCell(6, 0, 'Client ID', rightStyle);
    setTextCell(7, 0, clientId, rightStyle);

    // ROW 1-2: Client info
    setTextCell(6, 1, 'Client Name', rightStyle);
    setTextCell(7, 1, clientName, rightStyle);
    setTextCell(6, 2, 'Date', rightStyle);
    setTextCell(7, 2, dateStr, rightStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 4: Summary headers
    // ROW 5: Summary values
    // ════════════════════════════════════════════════════════════
    setTextCell(0, 4, 'Total Funds', summaryHeaderStyle);
    setTextCell(1, 4, 'Invested', summaryHeaderStyle);
    setTextCell(2, 4, 'Current Value', summaryHeaderStyle);
    setTextCell(3, 4, 'Returns', summaryHeaderStyle);
    setTextCell(4, 4, 'Returns %', summaryHeaderStyle);

    setNumCell(0, 5, holdings.length.toDouble(), summaryValueStyle);
    setNumCell(1, 5, totalInvested, summaryValueStyle);
    setNumCell(2, 5, totalCurrentValue, summaryValueStyle);
    setNumCell(3, 5, totalReturns, summaryValueStyle);
    setNumCell(4, 5, totalReturnsPercent, summaryValueStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 7: Column headers
    // ════════════════════════════════════════════════════════════
    final headers = [
      'Fund Name',
      'ISIN',
      'Units',
      'Avg NAV',
      'Cur NAV',
      'Invested',
      'Current Value',
      'P&L',
      'Chg %',
    ];
    for (int i = 0; i < headers.length; i++) {
      final style = i >= 2 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 7, headers[i], style);
    }

    // ════════════════════════════════════════════════════════════
    // ROW 8+: Data rows
    // ════════════════════════════════════════════════════════════
    final rows = _sorted(holdings);
    for (int r = 0; r < rows.length; r++) {
      final h = rows[r];
      final row = 8 + r;

      setTextCell(0, row, h.scripName ?? 'N/A', textStyle);
      setTextCell(1, row, h.iSIN ?? '', textStyle);
      setNumCell(2, row, _toDouble(h.totalUnits), numStyle);
      setNumCell(3, row, _toDouble(h.avgNav), numStyle);
      setNumCell(4, row, _toDouble(h.curNav), numStyle);
      setNumCell(5, row, _toDouble(h.investedValue), numStyle);
      setNumCell(6, row, _toDouble(h.currentValue), numStyle);
      setNumCell(7, row, _toDouble(h.profitLoss), numStyle);
      setNumCell(8, row, _toDouble(h.changeprofitLoss), numStyle);
    }

    // ════════════════════════════════════════════════════════════
    // FOOTER rows
    // ════════════════════════════════════════════════════════════
    final footerStart = 8 + rows.length + 1;
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

    // Fund Name column: minimum 40 (scheme names are long)
    if ((colWidths[0] ?? 0) < 40) {
      sheet.setColumnWidth(0, 40);
    }

    sheet.setRowHeight(0, 33);

    // Encode and download
    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadFile(
      Uint8List.fromList(bytes),
      'Mutual_Fund_Holdings_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
  */

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

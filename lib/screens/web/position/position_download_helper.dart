// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/portfolio_model/position_book_model.dart';

/// Client-side position download helper for web.
/// Generates PDF and Excel files from position data.
class PositionDownloadHelper {
  static double _toDouble(String? val) => double.tryParse(val ?? '0') ?? 0;

  static String _formatNumber(String? val) {
    final num = _toDouble(val);
    return num.toStringAsFixed(2);
  }

  /// Total traded quantity = today's plus whatever was carried forward.
  /// The API splits every position into day and cf halves; printing only the
  /// day half made rows that could not add up (buy 0, sell 65, net 0 — the
  /// 65 bought yesterday was simply missing).
  static String _totalQty(String? dayQty, String? cfQty) {
    final d = int.tryParse(dayQty?.toString() ?? '0') ?? 0;
    final c = int.tryParse(cfQty?.toString() ?? '0') ?? 0;
    return (d + c).toString();
  }

  /// Generate and download a PDF file from position data.
  static Future<void> downloadPdf({
    required List<PositionBookModel> positions,
    required String clientId,
    required String clientName,
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

    // Calculate totals
    double totalPnl = 0;
    double totalMtm = 0;
    for (final p in positions) {
      totalPnl += _toDouble(p.profitNloss);
      totalMtm += _toDouble(p.mTm);
    }

    // Build table data rows
    final tableRows = positions
        .asMap()
        .entries
        .map((entry) {
          final i = entry.key;
          final p = entry.value;
          return [
            '${i + 1}',
            p.exch ?? '',
            p.tsym ?? p.symbol ?? '',
            p.sPrdtAli ?? p.prd ?? '',
            // Was day-only: daybuyqty / daybuyavgprc / daysellqty /
            // daysellavgprc. Now the full traded figure — day plus carry
            // forward — so Buy minus Sell reconciles with Net Qty.
            // totbuyavgprc / totsellavgprc are the API's own blended averages
            // over both halves, so no average is recomputed here.
            _formatNumber(_totalQty(p.daybuyqty, p.cfbuyqty)),
            _formatNumber(p.totbuyavgprc),
            _formatNumber(_totalQty(p.daysellqty, p.cfsellqty)),
            _formatNumber(p.totsellavgprc),
            p.netqty ?? p.qty ?? '0',
            // Was: _formatNumber(p.netavgprc ?? p.avgPrc) — read the RAW net
            // average and so ignored the app's pick between netupldprc and
            // netavgprc, printing a different price from the screen on any
            // carry-forward position. avgPrc is what positionCal stores and
            // what the table's Act Avg cell shows, so use it first.
            _formatNumber(p.avgPrc ?? p.netavgprc),
            _formatNumber(p.lp),
            _formatNumber(p.profitNloss),
          ];
        })
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
            // Retired: client info sat inside the logo/title row and the
            // header carried no Date/Time (TC_255). Kept for rollback.
            // pw.Row(
            //   crossAxisAlignment: pw.CrossAxisAlignment.center,
            //   children: [
            //     if (logoImage != null)
            //       pw.Image(logoImage, width: 60, height: 30)
            //     else
            //       pw.SizedBox(width: 60),
            //     pw.Expanded(
            //       child: pw.Center(
            //         child: pw.Text('Position Book', style: titleStyle),
            //       ),
            //     ),
            //     pw.Column(
            //       crossAxisAlignment: pw.CrossAxisAlignment.end,
            //       children: [
            //         pw.Text('Client Name  :  $clientName',
            //             style: headerStyle),
            //         pw.SizedBox(height: 2),
            //         pw.Text('Client Code   :  $clientId',
            //             style: headerStyle),
            //       ],
            //     ),
            //   ],
            // ),
            // Logo + Title row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 60, height: 30)
                else
                  pw.SizedBox(width: 60),
                pw.Text('Position Book', style: titleStyle),
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
                _summaryBox('Total P&L', totalPnl.toStringAsFixed(2),
                    color: totalPnl >= 0 ? PdfColors.green : PdfColors.red),
                pw.SizedBox(width: 4),
                _summaryBox('Total MTM', totalMtm.toStringAsFixed(2),
                    color: totalMtm >= 0 ? PdfColors.green : PdfColors.red),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 2),
            // Retired: Date/Time moved up into the header to match Orders,
            // Holdings and MF Holdings, whose footers carry the address only.
            // pw.Row(
            //   mainAxisAlignment: pw.MainAxisAlignment.end,
            //   children: [
            //     pw.Text('Date: $dateStr  |  Time: $timeStr',
            //         style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
            //   ],
            // ),
            // pw.SizedBox(height: 4),
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
              0: const pw.FlexColumnWidth(0.6),  // S.No
              1: const pw.FlexColumnWidth(1),    // Exchange
              2: const pw.FlexColumnWidth(2),    // Symbol
              3: const pw.FlexColumnWidth(1),    // Product
              4: const pw.FlexColumnWidth(1),    // Buy Qty
              5: const pw.FlexColumnWidth(1.2),  // Buy Price
              6: const pw.FlexColumnWidth(1),    // Sell Qty
              7: const pw.FlexColumnWidth(1.2),  // Sell Price
              8: const pw.FlexColumnWidth(1),    // Net Qty
              9: const pw.FlexColumnWidth(1.2),  // Net Price
              10: const pw.FlexColumnWidth(1.2), // LTP
              11: const pw.FlexColumnWidth(1.2), // P&L
            },
            headers: [
              'S.No',
              'Exchange',
              'Symbol',
              'Product',
              'Buy Qty',
              'Buy Price',
              'Sell Qty',
              'Sell Price',
              'Net Qty',
              'Net Price',
              'LTP',
              'P&L',
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
  ///
  /// Built on Syncfusion xlsio rather than the `excel` package, because that
  /// package has no image support at all and the client asked for the logo in
  /// the Excel the way it already appears in the PDF. Everything else - the
  /// columns, their order, the styles, the summary block, the footer and the
  /// file name - is a like-for-like port of the previous version, which is
  /// kept commented out directly below for rollback.
  static Future<void> downloadExcel({
    required List<PositionBookModel> positions,
    required String clientId,
    required String clientName,
  }) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Positions';

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
      debugPrint('[PositionDownload] Excel logo skipped: $e');
    }

    setTextCell(1, 0, 'Position Book', titleStyle);
    setTextCell(9, 0, 'Client ID', rightStyle);
    setTextCell(10, 0, clientId, rightStyle);

    // ROW 1-2: Client info
    setTextCell(9, 1, 'Client Name', rightStyle);
    setTextCell(10, 1, clientName, rightStyle);
    setTextCell(9, 2, 'Date', rightStyle);
    setTextCell(10, 2, dateStr, rightStyle);

    // ============================================================
    // ROW 4: Summary headers
    // ROW 5: Summary values
    // ============================================================
    double totalPnl = 0;
    double totalMtm = 0;
    for (final p in positions) {
      totalPnl += _toDouble(p.profitNloss);
      totalMtm += _toDouble(p.mTm);
    }

    setTextCell(0, 4, 'Total Positions', summaryHeaderStyle);
    setTextCell(1, 4, 'Total P&L', summaryHeaderStyle);
    setTextCell(2, 4, 'Total MTM', summaryHeaderStyle);

    setNumCell(0, 5, positions.length.toDouble(), summaryValueStyle);
    setNumCell(1, 5, totalPnl, summaryValueStyle);
    setNumCell(2, 5, totalMtm, summaryValueStyle);

    // ============================================================
    // ROW 7: Column headers - same set and order as the PDF
    // ============================================================
    final headers = [
      'S.No',
      'Exchange',
      'Symbol',
      'Product',
      'Buy Qty',
      'Buy Price',
      'Sell Qty',
      'Sell Price',
      'Net Qty',
      'Net Price',
      'LTP',
      'P&L',
    ];
    for (int i = 0; i < headers.length; i++) {
      // First four are text columns, the rest are numeric.
      final style = i >= 4 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 7, headers[i], style);
    }

    // ============================================================
    // ROW 8+: Data rows
    // ============================================================
    for (int r = 0; r < positions.length; r++) {
      final p = positions[r];
      final row = 8 + r;
      setTextCell(0, row, '${r + 1}', textStyle);
      setTextCell(1, row, p.exch ?? '', textStyle);
      setTextCell(2, row, p.tsym ?? p.symbol ?? '', textStyle);
      setTextCell(3, row, p.sPrdtAli ?? p.prd ?? '', textStyle);
      setNumCell(
          4, row, _toDouble(_totalQty(p.daybuyqty, p.cfbuyqty)), numStyle);
      setNumCell(5, row, _toDouble(p.totbuyavgprc), numStyle);
      setNumCell(
          6, row, _toDouble(_totalQty(p.daysellqty, p.cfsellqty)), numStyle);
      setNumCell(7, row, _toDouble(p.totsellavgprc), numStyle);
      setNumCell(8, row, _toDouble(p.netqty ?? p.qty), numStyle);
      setNumCell(9, row, _toDouble(p.avgPrc ?? p.netavgprc), numStyle);
      setNumCell(10, row, _toDouble(p.lp), numStyle);
      setNumCell(11, row, _toDouble(p.profitNloss), numStyle);
    }

    // ============================================================
    // FOOTER rows
    // ============================================================
    final footerStart = 8 + positions.length + 1;
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

    // Instrument column: minimum 25
    if ((colWidths[0] ?? 0) < 25) {
      sheet.getRangeByIndex(1, 1).columnWidth = 25;
    }

    // Row 1 height reserves space for the logo: 60px is 45pt, plus a little
    // breathing room so the logo does not touch the row border.
    sheet.getRangeByIndex(1, 1).rowHeight = 48;

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    _downloadFile(
      Uint8List.fromList(bytes),
      'Positions_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // -- Retired 2026-09-22: the `excel` package version. Kept for rollback.
  // It cannot carry a logo - that package has no image API at all - which is
  // the only reason it was replaced. A copy also sits in
  // position_download_helper.dart.bak.
  /*
  /// Generate and download an Excel file from position data.
  static Future<void> downloadExcel({
    required List<PositionBookModel> positions,
    required String clientId,
    required String clientName,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Positions';
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
    setTextCell(1, 0, 'Position Book', titleStyle);
    setTextCell(9, 0, 'Client ID', rightStyle);
    setTextCell(10, 0, clientId, rightStyle);

    // ROW 1-2: Client info
    setTextCell(9, 1, 'Client Name', rightStyle);
    setTextCell(10, 1, clientName, rightStyle);
    setTextCell(9, 2, 'Date', rightStyle);
    setTextCell(10, 2, dateStr, rightStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 4: Summary headers
    // ROW 5: Summary values
    // ════════════════════════════════════════════════════════════
    double totalPnl = 0;
    double totalMtm = 0;
    for (final p in positions) {
      totalPnl += _toDouble(p.profitNloss);
      totalMtm += _toDouble(p.mTm);
    }

    setTextCell(0, 4, 'Total Positions', summaryHeaderStyle);
    setTextCell(1, 4, 'Total P&L', summaryHeaderStyle);
    setTextCell(2, 4, 'Total MTM', summaryHeaderStyle);

    setNumCell(0, 5, positions.length.toDouble(), summaryValueStyle);
    setNumCell(1, 5, totalPnl, summaryValueStyle);
    setNumCell(2, 5, totalMtm, summaryValueStyle);

    // ════════════════════════════════════════════════════════════
    // ROW 7: Column headers
    // ════════════════════════════════════════════════════════════
    // Excel was left on the original column set when commit dfa0f530 rewrote
    // the PDF's, so the two exports drifted apart. Now aligned to the PDF.
    // Retired list:
    // final headers = [
    //   'Instrument', 'Exchange', 'Product', 'Qty', 'Avg Price', 'LTP',
    //   'P&L', 'MTM', 'Buy Qty', 'Sell Qty', 'Buy Avg', 'Sell Avg',
    // ];
    final headers = [
      'S.No',
      'Exchange',
      'Symbol',
      'Product',
      'Buy Qty',
      'Buy Price',
      'Sell Qty',
      'Sell Price',
      'Net Qty',
      'Net Price',
      'LTP',
      'P&L',
    ];
    for (int i = 0; i < headers.length; i++) {
      // First four are text columns, the rest are numeric.
      final style = i >= 4 ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 7, headers[i], style);
    }

    // ════════════════════════════════════════════════════════════
    // ROW 8+: Data rows
    // ════════════════════════════════════════════════════════════
    for (int r = 0; r < positions.length; r++) {
      final p = positions[r];
      final row = 8 + r;
      // Reordered to the PDF's layout. Every expression below is the same one
      // the PDF row builder uses, so the two files cannot disagree on a value.
      // Per-row MTM is dropped — the PDF has no such column. Total MTM is
      // still in the summary block above.
      setTextCell(0, row, '${r + 1}', textStyle);
      setTextCell(1, row, p.exch ?? '', textStyle);
      setTextCell(2, row, p.tsym ?? p.symbol ?? '', textStyle);
      setTextCell(3, row, p.sPrdtAli ?? p.prd ?? '', textStyle);
      setNumCell(4, row, _toDouble(_totalQty(p.daybuyqty, p.cfbuyqty)), numStyle);
      setNumCell(5, row, _toDouble(p.totbuyavgprc), numStyle);
      setNumCell(6, row, _toDouble(_totalQty(p.daysellqty, p.cfsellqty)), numStyle);
      setNumCell(7, row, _toDouble(p.totsellavgprc), numStyle);
      setNumCell(8, row, _toDouble(p.netqty ?? p.qty), numStyle);
      setNumCell(9, row, _toDouble(p.avgPrc ?? p.netavgprc), numStyle);
      setNumCell(10, row, _toDouble(p.lp), numStyle);
      setNumCell(11, row, _toDouble(p.profitNloss), numStyle);
    }

    // ════════════════════════════════════════════════════════════
    // FOOTER rows
    // ════════════════════════════════════════════════════════════
    final footerStart = 8 + positions.length + 1;
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

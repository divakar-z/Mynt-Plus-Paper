// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

// ignore: unused_import  (kept for the commented-out `excel` version below)
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../../models/order_book_model/order_book_model.dart';
import '../../../models/order_book_model/trade_book_model.dart';

/// Client-side Orders download helper for web.
/// Generates PDF and Excel files from order/trade book data.
class OrdersDownloadHelper {
  static double _toDouble(String? val) => double.tryParse(val ?? '0') ?? 0;
  static String _fmt(double val) => val.toStringAsFixed(2);

  /// Resolve LTP from WebSocket data first, then model ltp, then model close price.
  static String _resolveLtp(String? token, String? modelLtp, String? closePrice, Map? socketData) {
    // 1. Try WebSocket live data
    if (token != null && socketData != null && socketData.containsKey(token)) {
      final tokenData = socketData[token];
      final wsLtp = (tokenData is Map) ? tokenData['lp']?.toString() : null;
      if (wsLtp != null && wsLtp != '0.00' && wsLtp != '0' && wsLtp != 'null') {
        return wsLtp;
      }
    }
    // 2. Try model ltp
    if (modelLtp != null && modelLtp != 'null' && modelLtp.isNotEmpty) {
      final parsed = double.tryParse(modelLtp);
      if (parsed != null && parsed != 0) return modelLtp;
    }
    // 3. Try close price
    if (closePrice != null && closePrice != 'null') {
      final parsed = double.tryParse(closePrice);
      if (parsed != null && parsed != 0) return closePrice;
    }
    return '0.00';
  }

  // ════════════════════════════════════════════════════════════════════
  // OPEN ORDERS
  // ════════════════════════════════════════════════════════════════════

  static Future<void> downloadOpenOrdersPdf({
    required List<OrderBookModel> orders,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final tableRows = orders.map((o) => [
      o.norentm ?? '',
      o.trantype ?? '',
      (o.tsym ?? o.symbol ?? '').replaceAll('-EQ', '').trim(),
      o.exch ?? '',
      o.sPrdtAli ?? o.prd ?? '',
      o.qty ?? '0',
      _fmt(_toDouble(_resolveLtp(o.token, o.ltp, o.c, socketData))),
      _fmt(_toDouble(o.prc)),
      o.status ?? '',
    ]).toList();

    await _generatePdf(
      title: 'Open Orders',
      clientId: clientId,
      clientName: clientName,
      headers: ['Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Price', 'Status'],
      data: tableRows,
      fileName: 'Open_Orders',
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(1),
        7: const pw.FlexColumnWidth(1),
        8: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  static Future<void> downloadOpenOrdersExcel({
    required List<OrderBookModel> orders,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final headers = ['Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Price', 'Status'];

    await _generateExcel(
      title: 'Open Orders',
      clientId: clientId,
      clientName: clientName,
      headers: headers,
      numericFromIndex: 5,
      fileName: 'Open_Orders',
      rowBuilder: (int r) {
        final o = orders[r];
        return <dynamic>[
          o.norentm ?? '',
          o.trantype ?? '',
          (o.tsym ?? o.symbol ?? '').replaceAll('-EQ', '').trim(),
          o.exch ?? '',
          o.sPrdtAli ?? o.prd ?? '',
          _toDouble(o.qty),
          _toDouble(_resolveLtp(o.token, o.ltp, o.c, socketData)),
          _toDouble(o.prc),
          o.status ?? '',
        ];
      },
      rowCount: orders.length,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // EXECUTED ORDERS
  // ════════════════════════════════════════════════════════════════════

  static Future<void> downloadExecutedOrdersPdf({
    required List<OrderBookModel> orders,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final tableRows = orders.map((o) => [
      o.norentm ?? '',
      o.trantype ?? '',
      (o.tsym ?? o.symbol ?? '').replaceAll('-EQ', '').trim(),
      o.exch ?? '',
      o.sPrdtAli ?? o.prd ?? '',
      o.qty ?? '0',
      _fmt(_toDouble(_resolveLtp(o.token, o.ltp, o.c, socketData))),
      _fmt(_toDouble(o.avgprc)),
      o.status ?? '',
    ]).toList();

    await _generatePdf(
      title: 'Executed Orders',
      clientId: clientId,
      clientName: clientName,
      headers: ['Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Avg Price', 'Status'],
      data: tableRows,
      fileName: 'Executed_Orders',
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(0.8),
        6: const pw.FlexColumnWidth(1),
        7: const pw.FlexColumnWidth(1),
        8: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  static Future<void> downloadExecutedOrdersExcel({
    required List<OrderBookModel> orders,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final headers = ['Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Avg Price', 'Status'];

    await _generateExcel(
      title: 'Executed Orders',
      clientId: clientId,
      clientName: clientName,
      headers: headers,
      numericFromIndex: 5,
      fileName: 'Executed_Orders',
      rowBuilder: (int r) {
        final o = orders[r];
        return <dynamic>[
          o.norentm ?? '',
          o.trantype ?? '',
          (o.tsym ?? o.symbol ?? '').replaceAll('-EQ', '').trim(),
          o.exch ?? '',
          o.sPrdtAli ?? o.prd ?? '',
          _toDouble(o.qty),
          _toDouble(_resolveLtp(o.token, o.ltp, o.c, socketData)),
          _toDouble(o.avgprc),
          o.status ?? '',
        ];
      },
      rowCount: orders.length,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // TRADE BOOK
  // ════════════════════════════════════════════════════════════════════

  static Future<void> downloadTradeBookPdf({
    required List<TradeBookModel> trades,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final tableRows = trades.map((t) => [
      t.flid ?? '',
      t.fltm ?? '',
      t.trantype ?? '',
      (t.tsym ?? t.symbol ?? '').replaceAll('-EQ', '').trim(),
      t.exch ?? '',
      t.sPrdtAli ?? t.prd ?? '',
      t.flqty ?? t.qty ?? '0',
      _fmt(_toDouble(_resolveLtp(t.token, t.ltp, null, socketData))),
      _fmt(_toDouble(t.flprc)),
    ]).toList();

    await _generatePdf(
      title: 'Trade Book',
      clientId: clientId,
      clientName: clientName,
      headers: ['Trade ID', 'Fill Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Avg Price'],
      data: tableRows,
      fileName: 'Trade_Book',
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(0.7),
        3: const pw.FlexColumnWidth(2.5),
        4: const pw.FlexColumnWidth(0.8),
        5: const pw.FlexColumnWidth(1),
        6: const pw.FlexColumnWidth(0.8),
        7: const pw.FlexColumnWidth(1),
        8: const pw.FlexColumnWidth(1),
      },
    );
  }

  static Future<void> downloadTradeBookExcel({
    required List<TradeBookModel> trades,
    required String clientId,
    required String clientName,
    Map? socketData,
  }) async {
    final headers = ['Trade ID', 'Fill Time', 'Type', 'Instrument', 'Exchange', 'Product', 'Qty', 'LTP', 'Avg Price'];

    await _generateExcel(
      title: 'Trade Book',
      clientId: clientId,
      clientName: clientName,
      headers: headers,
      numericFromIndex: 6,
      fileName: 'Trade_Book',
      rowBuilder: (int r) {
        final t = trades[r];
        return <dynamic>[
          t.flid ?? '',
          t.fltm ?? '',
          t.trantype ?? '',
          (t.tsym ?? t.symbol ?? '').replaceAll('-EQ', '').trim(),
          t.exch ?? '',
          t.sPrdtAli ?? t.prd ?? '',
          _toDouble(t.flqty ?? t.qty),
          _toDouble(_resolveLtp(t.token, t.ltp, null, socketData)),
          _toDouble(t.flprc),
        ];
      },
      rowCount: trades.length,
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED PDF GENERATOR
  // ════════════════════════════════════════════════════════════════════

  static Future<void> _generatePdf({
    required String title,
    required String clientId,
    required String clientName,
    required List<String> headers,
    required List<List<String>> data,
    required String fileName,
    required Map<int, pw.TableColumnWidth> columnWidths,
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

    final headerStyle = pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold);
    final valueStyle = const pw.TextStyle(fontSize: 6.5);
    final titleStyle = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);

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
                pw.Text(title, style: titleStyle),
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
                      pw.Text('Client Name  :  $clientName', style: headerStyle),
                      pw.SizedBox(height: 2),
                      pw.Text('Client Code   :  $clientId', style: headerStyle),
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
            pw.SizedBox(height: 4),
            _summaryBox('Total Records', data.length.toString()),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 2),
            pw.Text('Zebu Share And Wealth Management Private Limited',
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
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
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1F3465)),
            cellStyle: valueStyle,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: columnWidths,
            headers: headers,
            data: data,
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    _downloadFile(
      Uint8List.fromList(bytes),
      '${fileName}_${DateFormat('dd-MM-yyyy').format(now)}.pdf',
      'application/pdf',
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED EXCEL GENERATOR
  // ════════════════════════════════════════════════════════════════════

  /// Builds and downloads the Excel file for all three order tables
  /// (Open Orders, Executed Orders and Trade Book).
  ///
  /// Built on Syncfusion xlsio rather than the `excel` package, because that
  /// package has no image support at all and the client asked for the logo in
  /// the Excel the way it already appears in the PDF. Everything else - the
  /// columns, their order, the styles, the client block, the footer and the
  /// file name - is a like-for-like port of the previous version, which is
  /// kept commented out directly below for rollback.
  static Future<void> _generateExcel({
    required String title,
    required String clientId,
    required String clientName,
    required List<String> headers,
    required int numericFromIndex,
    required String fileName,
    required List<dynamic> Function(int index) rowBuilder,
    required int rowCount,
  }) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = title;

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    // Track max content length per column for auto-fit. Columns stay 0-based
    // here and are converted on the way out, since xlsio indexes from 1.
    final Map<int, int> colWidths = {};
    void trackWidth(int col, String value) {
      if (value.length > (colWidths[col] ?? 0)) colWidths[col] = value.length;
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
    // Logo sits in A1, the same asset the PDF header uses. The row height set
    // at the end reserves space for it.
    try {
      final logoBytes = await rootBundle.load('assets/icon/logo.png');
      // Pass the Uint8List itself, NOT .toList(). xlsio's Picture constructor
      // casts the data with `as Uint8List` before decoding the PNG, so a plain
      // List<int> throws a TypeError and the picture is silently dropped.
      final picture =
          sheet.pictures.addStream(1, 1, logoBytes.buffer.asUint8List());
      // The PDF's 60x30 are POINTS on an A4 page; in Excel they are pixels,
      // which renders the logo smaller than the asset itself. Sized on the
      // asset's own 106x50 aspect ratio instead, matching Positions.
      picture.width = 127;
      picture.height = 60;
    } catch (e) {
      // Logo is decoration - a missing asset must never fail the download.
      debugPrint('[OrdersDownload] Excel logo skipped: $e');
    }

    setTextCell(1, 0, title, titleStyle);
    final lastCol = headers.length - 2;
    setTextCell(lastCol, 0, 'Client ID', rightStyle);
    setTextCell(lastCol + 1, 0, clientId, rightStyle);
    setTextCell(lastCol, 1, 'Client Name', rightStyle);
    setTextCell(lastCol + 1, 1, clientName, rightStyle);
    setTextCell(lastCol, 2, 'Date', rightStyle);
    setTextCell(lastCol + 1, 2, dateStr, rightStyle);

    // Column headers (row 4)
    for (int i = 0; i < headers.length; i++) {
      final style = i >= numericFromIndex ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 4, headers[i], style);
    }

    // Data rows (row 5+)
    for (int r = 0; r < rowCount; r++) {
      final values = rowBuilder(r);
      final row = 5 + r;
      for (int c = 0; c < values.length; c++) {
        if (values[c] is double) {
          setNumCell(c, row, values[c] as double, numStyle);
        } else {
          setTextCell(c, row, values[c].toString(), textStyle);
        }
      }
    }

    // Footer
    final footerStart = 5 + rowCount + 1;
    final footerLines = [
      'Zebu Share And Wealth Management Private Limited',
      'Correspondence Office: No: 301, 4th Main Road, Burma Colony, Perungudi, Chennai, Tamil Nadu 600 096.',
      'Phone No: 044-4855 7991',
      'TRADING MEMBER CODE: NSE-EQ,F&O,CDS,COM: 13179 , BSE-EQ,F&O,CD,COM: 6550, MSEI - EQ,F&O,CDS:83300',
      'CIN NO: U67120TZ2013PTC019704 Website: www.zebuetrade.com, Email: grievance@zebuetrade.com',
    ];
    for (int i = 0; i < footerLines.length; i++) {
      // Footer text must not stretch column A, so it skips trackWidth.
      sheet.getRangeByIndex(footerStart + i + 1, 1)
        ..setText(footerLines[i])
        ..cellStyle = textStyle;
    }

    // Auto-fit column widths
    for (final entry in colWidths.entries) {
      final w = entry.value < 10 ? 10.0 : (entry.value + 2).toDouble();
      sheet.getRangeByIndex(1, entry.key + 1).columnWidth = w;
    }
    // Column A must stay at least as wide as the logo, or the picture spills
    // out of A1 and sits on top of the title in B1. The logo is 127px and a
    // width of 19 characters is 138px, which clears it. Trade Book is the case
    // that exposed this: its first column is Trade ID, whose short values left
    // column A narrower than the logo. Was 15.
    if ((colWidths[0] ?? 0) < 19) {
      sheet.getRangeByIndex(1, 1).columnWidth = 19;
    }
    // Instrument column wider
    final instrCol = headers.indexOf('Instrument');
    if (instrCol >= 0 && (colWidths[instrCol] ?? 0) < 25) {
      sheet.getRangeByIndex(1, instrCol + 1).columnWidth = 25;
    }
    // Row 1 height reserves space for the logo: 60px is 45pt, plus a little
    // breathing room so the logo does not touch the row border. Was 33.
    sheet.getRangeByIndex(1, 1).rowHeight = 48;

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    _downloadFile(
      Uint8List.fromList(bytes),
      '${fileName}_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // -- Retired 2026-09-23: the `excel` package version of the shared Excel
  // generator. Kept for rollback. It cannot carry a logo - that package has no
  // image API at all - which is the only reason it was replaced. A copy also
  // sits in orders_download_helper.dart.bak.
  /*
  // ════════════════════════════════════════════════════════════════════
  // SHARED EXCEL GENERATOR
  // ════════════════════════════════════════════════════════════════════

  static Future<void> _generateExcel({
    required String title,
    required String clientId,
    required String clientName,
    required List<String> headers,
    required int numericFromIndex,
    required String fileName,
    required List<dynamic> Function(int index) rowBuilder,
    required int rowCount,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', title);
    final sheet = excel[title];

    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    final Map<int, int> colWidths = {};
    void trackWidth(int col, String value) {
      if (value.length > (colWidths[col] ?? 0)) colWidths[col] = value.length;
    }

    final thinBorder = Border(borderStyle: BorderStyle.Thin);

    final titleStyle = CellStyle(
      bold: true, fontSize: 14, fontFamily: getFontFamily(FontFamily.Arial),
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );
    final rightStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );
    final colHeaderStyle = CellStyle(
      bold: true, fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1F226B'),
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );
    final colHeaderRightStyle = CellStyle(
      bold: true, fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1F226B'),
      horizontalAlign: HorizontalAlign.Right,
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );
    final textStyle = CellStyle(
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );
    final numStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right, numberFormat: NumFormat.standard_4,
      leftBorder: thinBorder, rightBorder: thinBorder, topBorder: thinBorder, bottomBorder: thinBorder,
    );

    void setCell(int col, int row, CellValue value, CellStyle style) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
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

    // Title + client info
    setTextCell(1, 0, title, titleStyle);
    final lastCol = headers.length - 2;
    setTextCell(lastCol, 0, 'Client ID', rightStyle);
    setTextCell(lastCol + 1, 0, clientId, rightStyle);
    setTextCell(lastCol, 1, 'Client Name', rightStyle);
    setTextCell(lastCol + 1, 1, clientName, rightStyle);
    setTextCell(lastCol, 2, 'Date', rightStyle);
    setTextCell(lastCol + 1, 2, dateStr, rightStyle);

    // Column headers (row 4)
    for (int i = 0; i < headers.length; i++) {
      final style = i >= numericFromIndex ? colHeaderRightStyle : colHeaderStyle;
      setTextCell(i, 4, headers[i], style);
    }

    // Data rows (row 5+)
    for (int r = 0; r < rowCount; r++) {
      final values = rowBuilder(r);
      final row = 5 + r;
      for (int c = 0; c < values.length; c++) {
        if (values[c] is double) {
          setNumCell(c, row, values[c] as double, numStyle);
        } else {
          setTextCell(c, row, values[c].toString(), textStyle);
        }
      }
    }

    // Footer
    final footerStart = 5 + rowCount + 1;
    final footerLines = [
      'Zebu Share And Wealth Management Private Limited',
      'Correspondence Office: No: 301, 4th Main Road, Burma Colony, Perungudi, Chennai, Tamil Nadu 600 096.',
      'Phone No: 044-4855 7991',
      'TRADING MEMBER CODE: NSE-EQ,F&O,CDS,COM: 13179 , BSE-EQ,F&O,CD,COM: 6550, MSEI - EQ,F&O,CDS:83300',
      'CIN NO: U67120TZ2013PTC019704 Website: www.zebuetrade.com, Email: grievance@zebuetrade.com',
    ];
    for (int i = 0; i < footerLines.length; i++) {
      setCell(0, footerStart + i, TextCellValue(footerLines[i]), textStyle);
    }

    // Auto-fit column widths
    for (final entry in colWidths.entries) {
      final w = entry.value < 10 ? 10.0 : (entry.value + 2).toDouble();
      sheet.setColumnWidth(entry.key, w);
    }
    if ((colWidths[0] ?? 0) < 15) sheet.setColumnWidth(0, 15);
    // Instrument column wider
    final instrCol = headers.indexOf('Instrument');
    if (instrCol >= 0 && (colWidths[instrCol] ?? 0) < 25) {
      sheet.setColumnWidth(instrCol, 25);
    }
    sheet.setRowHeight(0, 33);

    final bytes = excel.encode();
    if (bytes == null) return;

    _downloadFile(
      Uint8List.fromList(bytes),
      '${fileName}_${DateFormat('dd-MM-yyyy').format(now)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
  */

  /// Helper: summary box for PDF
  static pw.Widget _summaryBox(String label, String value, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, color: color ?? PdfColors.black)),
        ],
      ),
    );
  }

  /// Trigger browser download
  static void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

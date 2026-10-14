import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

/// Builds an .xlsx from the rows a results table is **currently showing** and
/// hands it to the browser.
///
/// The scanner export endpoint (`/scanners/{code}/export`) takes only a
/// scanner code, so it always returns that scanner's own unfiltered rows. Any
/// view that has moved away from those rows — an edited predicate, an index
/// filter, an ad-hoc custom run — has to export itself, or the file and the
/// screen disagree with no warning. That is what this does.
///
/// Values are written with their own type: numbers land as numbers so Excel
/// can sort and sum them, everything else as text. Nulls are left blank
/// rather than written as "—", since a blank cell is what a spreadsheet
/// treats as missing.
Future<void> exportScanRowsXlsx({
  required List<ScanColumn> columns,
  required List<ScanRow> rows,
  required String fileName,
  String sheetName = 'Results',
  bool includeSymbol = true,
  bool includeExch = true,
}) async {
  final workbook = xlsio.Workbook();
  try {
    final sheet = workbook.worksheets[0];
    // Excel rejects sheet names over 31 chars and the characters below.
    sheet.name = _safeSheetName(sheetName);

    final headerStyle = workbook.styles.add('scanHeader');
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#1F226B';

    // Column order mirrors the on-screen table: Stock Name, Symbol, Exch,
    // then the data columns left to right.
    final headers = <String>[
      'Stock Name',
      if (includeSymbol) 'Symbol',
      if (includeExch) 'Exchange',
      for (final c in columns) c.label,
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1)
        ..setText(headers[i])
        ..cellStyle = headerStyle;
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final excelRow = r + 2; // 1 = header, and xlsio indexes from 1.
      var col = 1;
      sheet.getRangeByIndex(excelRow, col++).setText(row.name);
      if (includeSymbol) {
        sheet.getRangeByIndex(excelRow, col++).setText(row.ticker);
      }
      if (includeExch) {
        sheet.getRangeByIndex(excelRow, col++).setText('NSE');
      }
      for (final c in columns) {
        final cell = sheet.getRangeByIndex(excelRow, col++);
        final v = row.values[c.key];
        if (v == null) continue; // leave the cell genuinely empty
        if (v is num) {
          cell.setNumber(v.toDouble());
        } else if (v is bool) {
          cell.setText(v ? 'Yes' : 'No');
        } else {
          cell.setText(v.toString());
        }
      }
    }

    for (var i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    triggerXlsxDownload(
      bytes: Uint8List.fromList(workbook.saveAsStream()),
      filename: fileName,
      fallbackName: 'scan_results.xlsx',
    );
  } finally {
    // xlsio holds native-ish buffers; not disposing leaks them on every
    // export, and the web build keeps the tab alive for hours.
    workbook.dispose();
  }
}

/// Excel forbids `[ ] : * ? / \` in a sheet name and caps it at 31 chars.
String _safeSheetName(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (cleaned.isEmpty) return 'Results';
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

/// Filename-safe slug of a scanner / scan name, for the downloaded file.
String scanFileSlug(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.isEmpty ? 'scan' : cleaned;
}

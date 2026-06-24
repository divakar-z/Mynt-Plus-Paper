import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart' as model;

ApiExporter get _api => locator<ApiExporter>();

/// All built-in scanners (fetched once, filtered client-side).
final scannerListProvider = FutureProvider<model.ScannerListResponse>(
    (_) => _api.fetchScanners(pageSize: 2000));

final scannerDetailProvider = FutureProvider.family<model.Scanner, String>(
    (_, code) => _api.fetchScanner(code));

/// Key for `scannerResultsProvider` — couples the scanner code with the
/// active index filter so each (code, indices) combination caches its own
/// result set. Pass an empty list when no filter is active so the family
/// dedupes back to the unfiltered universe across sub-pages.
class ScannerResultsKey {
  final String code;
  final List<String> indices;

  const ScannerResultsKey({required this.code, this.indices = const []});

  @override
  bool operator ==(Object other) {
    if (other is! ScannerResultsKey) return false;
    if (other.code != code) return false;
    if (other.indices.length != indices.length) return false;
    for (var i = 0; i < indices.length; i++) {
      if (other.indices[i] != indices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(code, Object.hashAll(indices));

  @override
  String toString() => 'ScannerResultsKey($code, indices=$indices)';
}

final scannerResultsProvider =
    FutureProvider.family<ScanResultsDetail, ScannerResultsKey>(
        (_, key) => _api.fetchScannerResults(
              key.code,
              detail: true,
              limit: 5000,
              indices: key.indices.isEmpty ? null : key.indices,
            ));

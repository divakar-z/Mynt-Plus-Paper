import 'package:mynt_plus/models/scanner_model/scan_result.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';

/// One built-in scanner that a symbol currently matches — self-contained:
/// catalog metadata (name/group/sentiment) plus the scanner's own result
/// `columns` and this symbol's computed `values` for those columns.
///
/// Backs an expandable row in the symbol's "Scans" tab. The active-scan set and
/// the values come from the same trading day, so they are internally
/// consistent. Returned by `GET /symbols/{ticker}/scan-details`.
class ScanDetail {
  final String code;
  final String displayName;
  final String groupName;
  final String? subGroup;

  /// Directional bias for the BULLISH/BEARISH/NEUTRAL grouping. May be null on
  /// older data — such scans fall into an "Other" section.
  final ScannerSentiment? sentiment;

  /// Short layman tagline. May be null on older data.
  final String? description;

  /// Column profile for this scanner (label + fmt + description), rendered
  /// verbatim. Same shape as `/scanners/{code}/results?detail=true`, so the
  /// shared [ScanResultColumn] model parses it.
  final List<ScanResultColumn> columns;

  /// This symbol's computed value per column `key`. Values may be missing.
  final Map<String, dynamic> values;

  /// Hint that the `/scanners/{code}/explain/{ticker}` drill-down exists.
  final bool explainAvailable;

  const ScanDetail({
    required this.code,
    required this.displayName,
    required this.groupName,
    required this.subGroup,
    required this.sentiment,
    required this.description,
    required this.columns,
    required this.values,
    required this.explainAvailable,
  });

  factory ScanDetail.fromJson(Map<String, dynamic> j) => ScanDetail(
        code: j['code'] as String,
        displayName: (j['display_name'] ?? j['code']) as String,
        groupName: (j['group_name'] ?? '') as String,
        subGroup: j['sub_group'] as String?,
        sentiment: _parseSentiment(j['sentiment']),
        description: j['description'] as String?,
        columns: ((j['columns'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanResultColumn.fromJson)
            .toList(),
        values: (j['values'] is Map)
            ? Map<String, dynamic>.from(j['values'] as Map)
            : const {},
        explainAvailable: (j['explain_available'] ?? false) as bool,
      );
}

/// All scanners a symbol matches on a given day. Returned by
/// `GET /symbols/{ticker}/scan-details`.
class ScanDetailsResponse {
  final String ticker;
  final String asOf;
  final int total;
  final List<ScanDetail> scans;

  const ScanDetailsResponse({
    required this.ticker,
    required this.asOf,
    required this.total,
    required this.scans,
  });

  factory ScanDetailsResponse.fromJson(Map<String, dynamic> j) =>
      ScanDetailsResponse(
        ticker: (j['ticker'] ?? '') as String,
        asOf: (j['as_of'] ?? '') as String,
        total: (j['total'] ?? 0) as int,
        scans: ((j['scans'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanDetail.fromJson)
            .toList(),
      );
}

ScannerSentiment? _parseSentiment(Object? raw) {
  if (raw is! String) return null;
  switch (raw.toLowerCase()) {
    case 'bullish':
      return ScannerSentiment.bullish;
    case 'bearish':
      return ScannerSentiment.bearish;
    case 'neutral':
      return ScannerSentiment.neutral;
    default:
      return null;
  }
}

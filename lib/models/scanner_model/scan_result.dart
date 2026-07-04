class ScanResultColumn {
  final String key;
  final String label;
  final String fmt;
  final String? description;

  const ScanResultColumn({
    required this.key,
    required this.label,
    required this.fmt,
    this.description,
  });

  factory ScanResultColumn.fromJson(Map<String, dynamic> j) =>
      ScanResultColumn(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        fmt: (j['fmt'] ?? 'raw') as String,
        description: j['description'] as String?,
      );
}

class ScanResultRow {
  final String ticker;
  final String name;
  final Map<String, dynamic> values;

  const ScanResultRow({
    required this.ticker,
    required this.name,
    required this.values,
  });

  factory ScanResultRow.fromJson(Map<String, dynamic> j) => ScanResultRow(
        ticker: j['ticker'] as String,
        name: (j['name'] ?? '') as String,
        values: (j['values'] is Map)
            ? Map<String, dynamic>.from(j['values'] as Map)
            : const {},
      );
}

class ScanResultsDetail {
  final String code;
  final String asOf;
  final int total;
  final List<ScanResultColumn> columns;
  final List<ScanResultRow> matches;
  /// Per-index match counts when `include_index_counts=true` was requested.
  /// Map keys are index names from `/indices/market` (e.g. `"NIFTY 50"`).
  /// Empty when the backend hasn't shipped the feature yet — the dropdown
  /// falls back to showing universe size in that case.
  final Map<String, int> indexCounts;

  const ScanResultsDetail({
    required this.code,
    required this.asOf,
    required this.total,
    required this.columns,
    required this.matches,
    this.indexCounts = const {},
  });

  factory ScanResultsDetail.fromJson(Map<String, dynamic> j) => ScanResultsDetail(
        code: j['code'] as String,
        asOf: (j['as_of'] ?? '') as String,
        total: (j['total'] ?? 0) as int,
        columns: ((j['columns'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanResultColumn.fromJson)
            .toList(),
        matches: ((j['matches'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ScanResultRow.fromJson)
            .toList(),
        indexCounts: _parseIndexCounts(j['index_counts']),
      );
}

Map<String, int> _parseIndexCounts(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  raw.forEach((k, v) {
    if (v is num) out[k.toString()] = v.toInt();
  });
  return out;
}

class FundamentalFilter {
  final String field;
  final String op;
  /// Single number/string/list — serialized as-is.
  final dynamic value;
  /// Optional: median-over-N-years (2..15).
  final int? years;

  const FundamentalFilter({
    required this.field,
    required this.op,
    this.value,
    this.years,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'op': op,
        if (value != null) 'value': value,
        if (years != null) 'years': years,
      };
}

class FundamentalColumnLabel {
  final String field;
  final String label;
  const FundamentalColumnLabel({required this.field, required this.label});

  factory FundamentalColumnLabel.fromJson(Map<String, dynamic> j) =>
      FundamentalColumnLabel(
        field: j['field'] as String,
        label: (j['label'] ?? j['field']) as String,
      );
}

class FundamentalMatch {
  final String ticker;
  final String name;
  final String? sector;
  final String? industry;
  final double? marketCap;
  final Map<String, dynamic> values;

  const FundamentalMatch({
    required this.ticker,
    required this.name,
    required this.sector,
    required this.industry,
    required this.marketCap,
    required this.values,
  });

  factory FundamentalMatch.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return FundamentalMatch(
      ticker: j['ticker'] as String,
      name: (j['name'] ?? '') as String,
      sector: j['sector'] as String?,
      industry: j['industry'] as String?,
      marketCap: d(j['market_cap']),
      values: (j['values'] is Map)
          ? Map<String, dynamic>.from(j['values'] as Map)
          : const {},
    );
  }
}

class FundamentalScanResponse {
  final int total;
  final int returned;
  final List<FundamentalColumnLabel> columnLabels;
  final List<FundamentalMatch> matches;

  const FundamentalScanResponse({
    required this.total,
    required this.returned,
    required this.columnLabels,
    required this.matches,
  });

  factory FundamentalScanResponse.fromJson(Map<String, dynamic> j) =>
      FundamentalScanResponse(
        total: (j['total'] ?? 0) as int,
        returned: (j['returned'] ?? 0) as int,
        columnLabels: ((j['column_labels'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FundamentalColumnLabel.fromJson)
            .toList(),
        matches: ((j['matches'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FundamentalMatch.fromJson)
            .toList(),
      );
}

class FundamentalScanRequest {
  final List<FundamentalFilter> filters;
  final String treatNullAs; // 'fail' | 'pass'
  final String orderBy;
  final String orderDir; // 'asc' | 'desc'
  final int limit;
  final int offset;

  const FundamentalScanRequest({
    required this.filters,
    this.treatNullAs = 'fail',
    this.orderBy = 'market_cap',
    this.orderDir = 'desc',
    this.limit = 100,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() => {
        'filters': filters.map((f) => f.toJson()).toList(),
        'treat_null_as': treatNullAs,
        'order_by': orderBy,
        'order_dir': orderDir,
        'limit': limit,
        'offset': offset,
      };
}

class FundamentalPreset {
  final String id;
  final String name;
  final String description;
  final List<FundamentalFilter> filters;
  final String treatNullAs;

  const FundamentalPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.filters,
    required this.treatNullAs,
  });

  factory FundamentalPreset.fromJson(Map<String, dynamic> j) {
    final filters = ((j['filters'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((f) => FundamentalFilter(
              field: f['field'] as String,
              op: f['op'] as String,
              value: f['value'],
              years: f['years'] as int?,
            ))
        .toList();
    return FundamentalPreset(
      id: (j['id'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      description: (j['description'] ?? '') as String,
      filters: filters,
      treatNullAs: (j['treat_null_as'] ?? 'fail') as String,
    );
  }
}

/// One per-symbol row inside `GET /buildup/symbols` (README §8.13).
class BuildupSymbol {
  final String symbol;
  final double prevClose;
  final double ltp;
  final double changePct;
  final int newOi;
  final int oldOi;
  final int oiChange;
  final double oiChangePct;

  const BuildupSymbol({
    required this.symbol,
    required this.prevClose,
    required this.ltp,
    required this.changePct,
    required this.newOi,
    required this.oldOi,
    required this.oiChange,
    required this.oiChangePct,
  });

  factory BuildupSymbol.fromJson(Map<String, dynamic> json) {
    return BuildupSymbol(
      symbol: json['symbol'] as String? ?? '',
      prevClose: (json['prev_close'] as num?)?.toDouble() ?? 0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
      newOi: (json['new_oi'] as num?)?.toInt() ?? 0,
      oldOi: (json['old_oi'] as num?)?.toInt() ?? 0,
      oiChange: (json['oi_change'] as num?)?.toInt() ?? 0,
      oiChangePct: (json['oi_change_pct'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Server-classified bucket — one card per value in the 2×2 quadrant grid.
enum BuildupBucket {
  longBuildup('long_buildup', 'Long Buildup'),
  shortBuildup('short_buildup', 'Short Buildup'),
  shortCovering('short_covering', 'Short Covering'),
  longUnwinding('long_unwinding', 'Long Unwinding');

  final String jsonKey;
  final String display;
  const BuildupBucket(this.jsonKey, this.display);
}

/// Parsed response from `GET /buildup/symbols` — four pre-classified lists.
class BuildupSymbolsResponse {
  final Map<BuildupBucket, List<BuildupSymbol>> rowsByBucket;

  const BuildupSymbolsResponse(this.rowsByBucket);

  static const BuildupSymbolsResponse empty = BuildupSymbolsResponse({});

  List<BuildupSymbol> rowsFor(BuildupBucket b) =>
      rowsByBucket[b] ?? const <BuildupSymbol>[];

  bool get isAllEmpty =>
      BuildupBucket.values.every((b) => rowsFor(b).isEmpty);

  factory BuildupSymbolsResponse.fromJson(Map<String, dynamic> json) {
    final out = <BuildupBucket, List<BuildupSymbol>>{};
    for (final b in BuildupBucket.values) {
      final raw = json[b.jsonKey] as List<dynamic>? ?? const [];
      out[b] = raw
          .map((e) => BuildupSymbol.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    return BuildupSymbolsResponse(out);
  }
}

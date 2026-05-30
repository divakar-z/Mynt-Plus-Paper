/// Single payload from `GET /market/snapshot` (README §8.15).
///
/// Powers the Markets Dashboard (§10.1): index ticker tiles + Open Market
/// counters, Index table, and per-index Stocks tables.
class MarketSnapshot {
  final int advances;
  final int declines;
  final int unchanged;
  final List<IndexQuote> indices;
  final Map<String, List<StockGapRow>> perIndex;

  const MarketSnapshot({
    required this.advances,
    required this.declines,
    required this.unchanged,
    required this.indices,
    required this.perIndex,
  });

  static const MarketSnapshot empty = MarketSnapshot(
    advances: 0,
    declines: 0,
    unchanged: 0,
    indices: [],
    perIndex: {},
  );

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    final rawIndices = json['indices'] as List<dynamic>? ?? const [];
    final rawPerIndex = json['per_index'] as Map<String, dynamic>? ?? const {};
    final perIndex = <String, List<StockGapRow>>{};
    rawPerIndex.forEach((key, value) {
      final bucket = value as Map<String, dynamic>?;
      final stocks = bucket?['stocks'] as List<dynamic>? ?? const [];
      perIndex[key] = stocks
          .map((e) => StockGapRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    });
    return MarketSnapshot(
      advances: (json['advances'] as num?)?.toInt() ?? 0,
      declines: (json['declines'] as num?)?.toInt() ?? 0,
      unchanged: (json['unchanged'] as num?)?.toInt() ?? 0,
      indices: rawIndices
          .map((e) => IndexQuote.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      perIndex: perIndex,
    );
  }
}

/// Single index quote inside `MarketSnapshot.indices`.
class IndexQuote {
  final String name;
  final double todayOpen;
  final double yesterdayClose;
  final double changePct;
  final double ltp;

  const IndexQuote({
    required this.name,
    required this.todayOpen,
    required this.yesterdayClose,
    required this.changePct,
    required this.ltp,
  });

  factory IndexQuote.fromJson(Map<String, dynamic> json) {
    return IndexQuote(
      name: json['name'] as String? ?? '',
      todayOpen: (json['today_open'] as num?)?.toDouble() ?? 0,
      yesterdayClose: (json['yesterday_close'] as num?)?.toDouble() ?? 0,
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One row inside `per_index.<KEY>.stocks[]` — drives Open Market Stocks table.
class StockGapRow {
  final String name;
  final double todayOpen;
  final double yesterdayClose;
  final double gapPct;
  final double changePct;
  final double ltp;

  const StockGapRow({
    required this.name,
    required this.todayOpen,
    required this.yesterdayClose,
    required this.gapPct,
    required this.changePct,
    required this.ltp,
  });

  factory StockGapRow.fromJson(Map<String, dynamic> json) {
    return StockGapRow(
      name: json['name'] as String? ?? '',
      todayOpen: (json['today_open'] as num?)?.toDouble() ?? 0,
      yesterdayClose: (json['yesterday_close'] as num?)?.toDouble() ?? 0,
      gapPct: (json['gap_pct'] as num?)?.toDouble() ?? 0,
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
    );
  }
}

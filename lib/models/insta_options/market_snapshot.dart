/// Single payload from `GET /market/snapshot` (README §8.15).
///
/// Powers the Markets Dashboard's index ticker tiles + advances/declines
/// counters. The `per_index` map (per-constituent stock lists) is not used
/// by §10.1 in v1 — we deliberately drop it from the parsed model.
class MarketSnapshot {
  final int advances;
  final int declines;
  final int unchanged;
  final List<IndexQuote> indices;

  const MarketSnapshot({
    required this.advances,
    required this.declines,
    required this.unchanged,
    required this.indices,
  });

  static const MarketSnapshot empty = MarketSnapshot(
    advances: 0,
    declines: 0,
    unchanged: 0,
    indices: [],
  );

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['indices'] as List<dynamic>? ?? const [];
    return MarketSnapshot(
      advances: (json['advances'] as num?)?.toInt() ?? 0,
      declines: (json['declines'] as num?)?.toInt() ?? 0,
      unchanged: (json['unchanged'] as num?)?.toInt() ?? 0,
      indices: raw
          .map((e) => IndexQuote.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
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

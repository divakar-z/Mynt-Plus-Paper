import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';

/// One per-stock row inside `buildup_sentiment.rows` — the detail behind the
/// quadrant counts. `lastClose` / `priceChangePct` / `oiChangePct` nullable →
/// render `—`.
class BuildupRow {
  final String symbol;
  final double? lastClose;
  final int oi;
  final double? priceChangePct;
  final double? oiChangePct;
  final BuildupCategory category;

  const BuildupRow({
    required this.symbol,
    required this.lastClose,
    required this.oi,
    required this.priceChangePct,
    required this.oiChangePct,
    required this.category,
  });

  /// Overlay the socket-live LTP (`lastClose` column) + price%; OI / OIΔ% /
  /// category stay the API snapshot.
  BuildupRow copyWith({double? lastClose, double? priceChangePct}) => BuildupRow(
        symbol: symbol,
        lastClose: lastClose ?? this.lastClose,
        oi: oi,
        priceChangePct: priceChangePct ?? this.priceChangePct,
        oiChangePct: oiChangePct,
        category: category,
      );

  factory BuildupRow.fromJson(Map<String, dynamic> json) => BuildupRow(
        symbol: json['symbol'] as String? ?? '',
        lastClose: (json['last_close'] as num?)?.toDouble(),
        oi: (json['oi'] as num?)?.toInt() ?? 0,
        priceChangePct: (json['price_change_pct'] as num?)?.toDouble(),
        oiChangePct: (json['oi_change_pct'] as num?)?.toDouble(),
        category: BuildupCategory.fromWire(json['category'] as String?),
      );
}

/// Buildup summary shared by `buildup_sentiment` on `GET /dashboard`. Holds the
/// quadrant counts plus the per-stock [rows].
///
/// bullish = long_buildup + short_covering; bearish = short_buildup +
/// long_covering (the backend pre-computes both).
class BuildupSentiment {
  final int longBuildup;
  final int shortBuildup;
  final int shortCovering;
  final int longCovering;
  final int na;
  final int total;
  final int bullish;
  final int bearish;
  final List<BuildupRow> rows;

  const BuildupSentiment({
    required this.longBuildup,
    required this.shortBuildup,
    required this.shortCovering,
    required this.longCovering,
    required this.na,
    required this.total,
    required this.bullish,
    required this.bearish,
    required this.rows,
  });

  static const BuildupSentiment empty = BuildupSentiment(
    longBuildup: 0,
    shortBuildup: 0,
    shortCovering: 0,
    longCovering: 0,
    na: 0,
    total: 0,
    bullish: 0,
    bearish: 0,
    rows: [],
  );

  bool get isEmpty => total == 0;

  /// Overlay the live-priced [rows]; the quadrant counts stay the API snapshot.
  BuildupSentiment copyWith({List<BuildupRow>? rows}) => BuildupSentiment(
        longBuildup: longBuildup,
        shortBuildup: shortBuildup,
        shortCovering: shortCovering,
        longCovering: longCovering,
        na: na,
        total: total,
        bullish: bullish,
        bearish: bearish,
        rows: rows ?? this.rows,
      );

  /// Count for a quadrant (drives the filter chips).
  int countFor(BuildupCategory c) {
    switch (c) {
      case BuildupCategory.longBuildup:
        return longBuildup;
      case BuildupCategory.shortBuildup:
        return shortBuildup;
      case BuildupCategory.shortCovering:
        return shortCovering;
      case BuildupCategory.longCovering:
        return longCovering;
      case BuildupCategory.na:
        return na;
    }
  }

  factory BuildupSentiment.fromJson(Map<String, dynamic> json) =>
      BuildupSentiment(
        longBuildup: (json['long_buildup'] as num?)?.toInt() ?? 0,
        shortBuildup: (json['short_buildup'] as num?)?.toInt() ?? 0,
        shortCovering: (json['short_covering'] as num?)?.toInt() ?? 0,
        longCovering: (json['long_covering'] as num?)?.toInt() ?? 0,
        na: (json['na'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        bullish: (json['bullish'] as num?)?.toInt() ?? 0,
        bearish: (json['bearish'] as num?)?.toInt() ?? 0,
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map((e) => BuildupRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

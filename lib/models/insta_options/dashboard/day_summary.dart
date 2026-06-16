/// `summary` block of `GET /api/v1/dashboard` — the day's header KPIs across
/// all F&O stocks. `marketPcr` / `oiChangePct` are nullable → render `—`.
class DaySummary {
  final String tradeDate;
  final int total;
  final int advances;
  final int declines;
  final int unchanged;
  final int bullish;
  final int bearish;
  final double? marketPcr;
  final double? oiChangePct;

  const DaySummary({
    required this.tradeDate,
    required this.total,
    required this.advances,
    required this.declines,
    required this.unchanged,
    required this.bullish,
    required this.bearish,
    required this.marketPcr,
    required this.oiChangePct,
  });

  static const DaySummary empty = DaySummary(
    tradeDate: '',
    total: 0,
    advances: 0,
    declines: 0,
    unchanged: 0,
    bullish: 0,
    bearish: 0,
    marketPcr: null,
    oiChangePct: null,
  );

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        tradeDate: json['trade_date'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        advances: (json['advances'] as num?)?.toInt() ?? 0,
        declines: (json['declines'] as num?)?.toInt() ?? 0,
        unchanged: (json['unchanged'] as num?)?.toInt() ?? 0,
        bullish: (json['bullish'] as num?)?.toInt() ?? 0,
        bearish: (json['bearish'] as num?)?.toInt() ?? 0,
        marketPcr: (json['market_pcr'] as num?)?.toDouble(),
        oiChangePct: (json['oi_change_pct'] as num?)?.toDouble(),
      );
}

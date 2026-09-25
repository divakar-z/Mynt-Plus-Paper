/// One sector row from `GET /sector-performance` `sectors[]` and the
/// `sector_performance[]` array on `GET /overview` — drives the Sector
/// Performance heatmap (§10.7), coloured by [avgChangePct].
class SectorPerformanceRow {
  final String sector;
  final int stocks;
  final int advances;
  final int declines;
  final int bullish;
  final int bearish;
  final double avgChangePct;
  final int netOi;

  const SectorPerformanceRow({
    required this.sector,
    required this.stocks,
    required this.advances,
    required this.declines,
    required this.bullish,
    required this.bearish,
    required this.avgChangePct,
    required this.netOi,
  });

  factory SectorPerformanceRow.fromJson(Map<String, dynamic> json) =>
      SectorPerformanceRow(
        sector: json['sector'] as String? ?? '',
        stocks: (json['stocks'] as num?)?.toInt() ?? 0,
        advances: (json['advances'] as num?)?.toInt() ?? 0,
        declines: (json['declines'] as num?)?.toInt() ?? 0,
        bullish: (json['bullish'] as num?)?.toInt() ?? 0,
        bearish: (json['bearish'] as num?)?.toInt() ?? 0,
        avgChangePct: (json['avg_change_pct'] as num?)?.toDouble() ?? 0,
        netOi: (json['net_oi'] as num?)?.toInt() ?? 0,
      );
}

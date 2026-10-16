/// One macro sector's summed point contribution to the index move
/// (an element of `sector_contribution`, sorted by point_contribution desc).
class SectorContribution {
  final String sector;
  final int stocks;
  final double? weightPct;
  final double? pointContribution;
  final int advances;
  final int declines;

  const SectorContribution({
    required this.sector,
    required this.stocks,
    required this.weightPct,
    required this.pointContribution,
    required this.advances,
    required this.declines,
  });

  /// Re-summed sector totals from live constituent points; stocks / weight stay
  /// the API snapshot.
  SectorContribution copyWith({
    double? pointContribution,
    int? advances,
    int? declines,
  }) =>
      SectorContribution(
        sector: sector,
        stocks: stocks,
        weightPct: weightPct,
        pointContribution: pointContribution ?? this.pointContribution,
        advances: advances ?? this.advances,
        declines: declines ?? this.declines,
      );

  factory SectorContribution.fromJson(Map<String, dynamic> j) =>
      SectorContribution(
        sector: (j['sector'] ?? '').toString(),
        stocks: (j['stocks'] as num?)?.toInt() ?? 0,
        weightPct: (j['weight_pct'] as num?)?.toDouble(),
        pointContribution: (j['point_contribution'] as num?)?.toDouble(),
        advances: (j['advances'] as num?)?.toInt() ?? 0,
        declines: (j['declines'] as num?)?.toInt() ?? 0,
      );
}

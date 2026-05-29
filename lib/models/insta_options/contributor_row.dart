/// One constituent row from `GET /contributors/{index}` (README §8.16).
///
/// `index_points = (ltp - prev_close) * weight / divisor` is computed server-
/// side; the frontend renders it verbatim. Server sorts descending by
/// `|index_points|` already; the UI may re-sort by header tap.
class ContributorRow {
  final String stock;
  final String sector;
  final double ltp;
  final double changePct;
  final double weight;
  final double divisor;
  final double indexPoints;

  const ContributorRow({
    required this.stock,
    required this.sector,
    required this.ltp,
    required this.changePct,
    required this.weight,
    required this.divisor,
    required this.indexPoints,
  });

  factory ContributorRow.fromJson(Map<String, dynamic> json) {
    return ContributorRow(
      stock: json['stock'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      divisor: (json['divisor'] as num?)?.toDouble() ?? 0,
      indexPoints: (json['index_points'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Aggregated sector row derived client-side from a list of ContributorRows.
class SectorAggregate {
  final String sector;
  final double avgChangePct;
  final double totalIndexPoints;
  final int constituentCount;

  const SectorAggregate({
    required this.sector,
    required this.avgChangePct,
    required this.totalIndexPoints,
    required this.constituentCount,
  });

  static List<SectorAggregate> from(Iterable<ContributorRow> rows) {
    final byKey = <String, List<ContributorRow>>{};
    for (final r in rows) {
      byKey.putIfAbsent(r.sector, () => []).add(r);
    }
    final out = <SectorAggregate>[];
    byKey.forEach((sector, list) {
      final total = list.fold<double>(0, (s, r) => s + r.indexPoints);
      final avg = list.isEmpty
          ? 0.0
          : list.fold<double>(0, (s, r) => s + r.changePct) / list.length;
      out.add(SectorAggregate(
        sector: sector.isEmpty ? '—' : sector,
        avgChangePct: avg,
        totalIndexPoints: total,
        constituentCount: list.length,
      ));
    });
    return out;
  }
}

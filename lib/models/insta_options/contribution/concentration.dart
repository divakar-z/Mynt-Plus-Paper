/// Breadth / concentration of the index's move (`concentration` block).
class Concentration {
  final double? top3SharePct;
  final double? top5SharePct;
  final double? hhi; // Herfindahl — higher = more concentrated
  final String? breadth; // "narrow" | "broad"
  final int advances;
  final int declines;
  final int unchanged;
  final double? adRatio;

  const Concentration({
    required this.top3SharePct,
    required this.top5SharePct,
    required this.hhi,
    required this.breadth,
    required this.advances,
    required this.declines,
    required this.unchanged,
    required this.adRatio,
  });

  bool get isNarrow => breadth == 'narrow';
  int get total => advances + declines + unchanged;

  factory Concentration.fromJson(Map<String, dynamic> j) => Concentration(
        top3SharePct: (j['top3_share_pct'] as num?)?.toDouble(),
        top5SharePct: (j['top5_share_pct'] as num?)?.toDouble(),
        hhi: (j['hhi'] as num?)?.toDouble(),
        breadth: j['breadth'] as String?,
        advances: (j['advances'] as num?)?.toInt() ?? 0,
        declines: (j['declines'] as num?)?.toInt() ?? 0,
        unchanged: (j['unchanged'] as num?)?.toInt() ?? 0,
        adRatio: (j['ad_ratio'] as num?)?.toDouble(),
      );
}

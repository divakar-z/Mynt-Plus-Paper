/// One entry in `indices[]` — merges an index's price + day change, option
/// PCR, max-pain, and F&O advance/decline. Every numeric field is nullable
/// (render `—`); A/D is null for BSE indices (SENSEX/BANKEX), so those hide
/// the breadth bar.
class IndexCard {
  final String index;
  final String underlyingId;
  final double? level;
  final double? changePct;
  final double? pcr;
  final String? expiry;
  final double? maxPain;
  final int? advances;
  final int? declines;
  final int? unchanged;

  const IndexCard({
    required this.index,
    required this.underlyingId,
    required this.level,
    required this.changePct,
    required this.pcr,
    required this.expiry,
    required this.maxPain,
    required this.advances,
    required this.declines,
    required this.unchanged,
  });

  /// `true` when the index has an NSE breadth source (so the A/D bar renders).
  bool get hasBreadth =>
      advances != null && declines != null && unchanged != null;

  factory IndexCard.fromJson(Map<String, dynamic> json) => IndexCard(
        index: json['index'] as String? ?? '',
        underlyingId: json['underlying_id'] as String? ?? '',
        level: (json['level'] as num?)?.toDouble(),
        changePct: (json['change_pct'] as num?)?.toDouble(),
        pcr: (json['pcr'] as num?)?.toDouble(),
        expiry: json['expiry'] as String?,
        maxPain: (json['max_pain'] as num?)?.toDouble(),
        advances: (json['advances'] as num?)?.toInt(),
        declines: (json['declines'] as num?)?.toInt(),
        unchanged: (json['unchanged'] as num?)?.toInt(),
      );
}

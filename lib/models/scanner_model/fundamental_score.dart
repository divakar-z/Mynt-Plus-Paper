class FundamentalScore {
  final String ticker;
  final double? valuation, growth, profitability, quality, solvency, efficiency;
  final double? composite;
  final List<String> notes;

  const FundamentalScore({
    required this.ticker,
    required this.valuation,
    required this.growth,
    required this.profitability,
    required this.quality,
    required this.solvency,
    required this.efficiency,
    required this.composite,
    required this.notes,
  });

  factory FundamentalScore.fromJson(Map<String, dynamic> j) {
    double? d(String k) {
      final v = j[k];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return FundamentalScore(
      ticker: j['ticker'] as String,
      valuation: d('valuation'),
      growth: d('growth'),
      profitability: d('profitability'),
      quality: d('quality'),
      solvency: d('solvency'),
      efficiency: d('efficiency'),
      composite: d('composite'),
      notes: (j['notes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

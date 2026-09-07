class TechnicalsResponse {
  final String ticker;
  final String asOf;
  /// `key → value` map of ~25 indicators. Values may be null when data is
  /// insufficient (e.g. SMA(200) before 200 bars exist).
  final Map<String, num?> indicators;

  const TechnicalsResponse({
    required this.ticker,
    required this.asOf,
    required this.indicators,
  });

  factory TechnicalsResponse.fromJson(Map<String, dynamic> j) {
    final raw = (j['indicators'] as Map?) ?? const {};
    final ind = <String, num?>{};
    raw.forEach((k, v) {
      if (v == null) {
        ind[k.toString()] = null;
      } else if (v is num) {
        ind[k.toString()] = v;
      } else {
        ind[k.toString()] = num.tryParse(v.toString());
      }
    });
    return TechnicalsResponse(
      ticker: j['ticker'] as String,
      asOf: (j['as_of'] ?? '') as String,
      indicators: ind,
    );
  }
}

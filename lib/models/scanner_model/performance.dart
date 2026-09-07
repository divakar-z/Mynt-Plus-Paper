class PerformanceResponse {
  final String ticker;
  final String asOf;
  final Map<String, double?> returns;
  final Map<String, double?>? relative;

  const PerformanceResponse({
    required this.ticker,
    required this.asOf,
    required this.returns,
    required this.relative,
  });

  factory PerformanceResponse.fromJson(Map<String, dynamic> j) {
    Map<String, double?> parseMap(dynamic raw) {
      if (raw is! Map) return const {};
      final out = <String, double?>{};
      raw.forEach((k, v) {
        if (v == null) {
          out[k.toString()] = null;
        } else if (v is num) {
          out[k.toString()] = v.toDouble();
        } else {
          out[k.toString()] = double.tryParse(v.toString());
        }
      });
      return out;
    }

    return PerformanceResponse(
      ticker: j['ticker'] as String,
      asOf: (j['as_of'] ?? '') as String,
      returns: parseMap(j['returns']),
      relative: j['relative'] == null ? null : parseMap(j['relative']),
    );
  }
}

class FinancialsResponse {
  final String ticker;
  final String periodType; // "quarterly" | "annual"
  final String statement; // "income" | "balance" | "cashflow"
  final String basis; // "standalone" | "consolidated"
  final List<String> periods;
  final List<String> lineItems;
  /// `lineItem → period → value`. Values may be null.
  final Map<String, Map<String, num?>> values;

  const FinancialsResponse({
    required this.ticker,
    required this.periodType,
    required this.statement,
    required this.basis,
    required this.periods,
    required this.lineItems,
    required this.values,
  });

  factory FinancialsResponse.fromJson(Map<String, dynamic> j) {
    final rawVals = (j['values'] as Map?) ?? const {};
    final values = <String, Map<String, num?>>{};
    rawVals.forEach((lineItem, periodMap) {
      final inner = <String, num?>{};
      if (periodMap is Map) {
        periodMap.forEach((period, v) {
          if (v == null) {
            inner[period.toString()] = null;
          } else if (v is num) {
            inner[period.toString()] = v;
          } else {
            inner[period.toString()] = num.tryParse(v.toString());
          }
        });
      }
      values[lineItem.toString()] = inner;
    });
    return FinancialsResponse(
      ticker: j['ticker'] as String,
      periodType: j['period_type'] as String,
      statement: j['statement'] as String,
      basis: (j['basis'] ?? 'standalone') as String,
      periods: (j['periods'] as List).map((e) => e.toString()).toList(),
      lineItems: (j['line_items'] as List).map((e) => e.toString()).toList(),
      values: values,
    );
  }
}

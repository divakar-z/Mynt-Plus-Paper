class FundamentalField {
  final String key;
  final String label;
  final String group;
  /// number | pct | currency_inr | string
  final String dtype;
  final String description;

  const FundamentalField({
    required this.key,
    required this.label,
    required this.group,
    required this.dtype,
    required this.description,
  });

  factory FundamentalField.fromJson(Map<String, dynamic> j) => FundamentalField(
        key: j['key'] as String,
        label: (j['label'] ?? j['key']) as String,
        group: (j['group'] ?? '') as String,
        dtype: (j['dtype'] ?? 'number') as String,
        description: (j['description'] ?? '') as String,
      );

  /// Fields that support the `years` sidecar (median-over-N-years comparison).
  static const Set<String> multiYearCapable = {
    'revenue_growth', 'earnings_growth', 'return_on_equity', 'return_on_assets',
    'profit_margins', 'operating_margins', 'current_ratio', 'quick_ratio',
    'debt_to_equity',
  };
}

/// Response of `GET /oi/aggregate` (README §8.10).
///
/// When [ready] is false the aggregator worker has not produced a snapshot yet
/// and every numeric field is meaningless — the OI Statistics screen shows a
/// "warming up" placeholder for the cumulative panel.
class OiAggregate {
  final String symbol;
  final String expiry;
  final bool ready;
  final int totalCeOi;
  final int totalPeOi;
  final int totalCeOiChange;
  final int totalPeOiChange;
  final double pcr;
  final DateTime? computedAt;

  const OiAggregate({
    required this.symbol,
    required this.expiry,
    required this.ready,
    required this.totalCeOi,
    required this.totalPeOi,
    required this.totalCeOiChange,
    required this.totalPeOiChange,
    required this.pcr,
    required this.computedAt,
  });

  factory OiAggregate.fromJson(Map<String, dynamic> json) {
    final ts = json['computed_at'] as String?;
    return OiAggregate(
      symbol: json['symbol'] as String? ?? '',
      expiry: json['expiry'] as String? ?? '',
      ready: json['ready'] as bool? ?? false,
      totalCeOi: (json['total_ce_oi'] as num?)?.toInt() ?? 0,
      totalPeOi: (json['total_pe_oi'] as num?)?.toInt() ?? 0,
      totalCeOiChange: (json['total_ce_oi_change'] as num?)?.toInt() ?? 0,
      totalPeOiChange: (json['total_pe_oi_change'] as num?)?.toInt() ?? 0,
      pcr: (json['pcr'] as num?)?.toDouble() ?? 0,
      computedAt: ts == null ? null : DateTime.tryParse(ts),
    );
  }
}

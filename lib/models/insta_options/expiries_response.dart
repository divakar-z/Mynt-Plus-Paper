/// `GET /expiries?exchange=NFO&symbol=NIFTY` response.
class ExpiriesResponse {
  final String exchange;
  final String symbol;
  final List<String> expiries;

  const ExpiriesResponse({
    required this.exchange,
    required this.symbol,
    required this.expiries,
  });

  factory ExpiriesResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['expiries'] as List?) ?? const [];
    return ExpiriesResponse(
      exchange: json['exchange'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      expiries: raw.map((e) => e.toString()).toList(growable: false),
    );
  }
}

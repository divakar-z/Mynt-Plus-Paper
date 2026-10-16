/// `GET /symbols?exchange=NFO` response.
class SymbolsResponse {
  final String exchange;
  final int count;
  final List<String> symbols;

  const SymbolsResponse({
    required this.exchange,
    required this.count,
    required this.symbols,
  });

  factory SymbolsResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['symbols'] as List?) ?? const [];
    return SymbolsResponse(
      exchange: json['exchange'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? raw.length,
      symbols: raw.map((e) => e.toString()).toList(growable: false),
    );
  }
}

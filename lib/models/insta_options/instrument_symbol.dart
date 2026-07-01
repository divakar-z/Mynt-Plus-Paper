/// One entry from the global `GET /api/v1/symbols` list — an index or an F&O
/// stock usable as an option-chain underlying.
///
/// [underlyingId] is the value passed to the option-chain API as `underlying=`.
/// [token] + [exchange] are the Noren spot/index token for the underlying's live
/// price (the canonical token source for every underlying across the screens).
class InstrumentSymbol {
  final String underlyingId;
  final String name;
  final String type; // "index" | "stock"
  final String? exchange;
  final String? token;
  final String? sector;
  final int? lotSize;
  final bool hasOptions;
  final bool hasFutures;
  final List<String> memberOf;

  const InstrumentSymbol({
    required this.underlyingId,
    required this.name,
    required this.type,
    this.exchange,
    this.token,
    this.sector,
    this.lotSize,
    this.hasOptions = false,
    this.hasFutures = false,
    this.memberOf = const [],
  });

  bool get isIndex => type.toLowerCase() == 'index';

  /// `exchange|token` subscription key for the underlying's spot/index price,
  /// or null if untokenised.
  String? get tickKey =>
      (token != null && exchange != null) ? '$exchange|$token' : null;

  factory InstrumentSymbol.fromJson(Map<String, dynamic> json) {
    final id = (json['underlying_id'] ?? json['symbol'] ?? '').toString();
    return InstrumentSymbol(
      underlyingId: id,
      name: (json['name'] as String?) ?? id,
      type: (json['type'] as String?) ?? 'stock',
      exchange: json['exchange'] as String?,
      token: json['token']?.toString(),
      sector: json['sector'] as String?,
      lotSize: (json['lot_size'] as num?)?.toInt(),
      hasOptions: json['has_options'] as bool? ?? false,
      hasFutures: json['has_futures'] as bool? ?? false,
      memberOf: (json['member_of'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

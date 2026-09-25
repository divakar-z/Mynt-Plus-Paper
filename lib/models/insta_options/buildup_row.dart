/// One row from `/oi/buildup`. Carries the server's pre-classified `buildup`
/// label — do NOT re-classify on the client.
class BuildupRow {
  final int token;
  final double strike;
  final String optionType;
  final String tradingSymbol;
  final double openPrice;
  final double closePrice;
  final double priceChange;
  final int openOi;
  final int closeOi;
  final int oiChange;
  final BuildupKind buildup;

  const BuildupRow({
    required this.token,
    required this.strike,
    required this.optionType,
    required this.tradingSymbol,
    required this.openPrice,
    required this.closePrice,
    required this.priceChange,
    required this.openOi,
    required this.closeOi,
    required this.oiChange,
    required this.buildup,
  });

  bool get isCe => optionType == 'CE';
  bool get isPe => optionType == 'PE';
  bool get isFut => optionType == 'FUT';

  double get priceChangePct =>
      openPrice == 0 ? 0 : (priceChange / openPrice) * 100;

  factory BuildupRow.fromJson(Map<String, dynamic> json) {
    return BuildupRow(
      token: (json['token'] as num?)?.toInt() ?? 0,
      strike: (json['strike'] as num?)?.toDouble() ?? 0,
      optionType: json['option_type'] as String? ?? '',
      tradingSymbol: json['trading_symbol'] as String? ?? '',
      openPrice: (json['open_price'] as num?)?.toDouble() ?? 0,
      closePrice: (json['close_price'] as num?)?.toDouble() ?? 0,
      priceChange: (json['price_change'] as num?)?.toDouble() ?? 0,
      openOi: (json['open_oi'] as num?)?.toInt() ?? 0,
      closeOi: (json['close_oi'] as num?)?.toInt() ?? 0,
      oiChange: (json['oi_change'] as num?)?.toInt() ?? 0,
      buildup: BuildupKind.fromString(json['buildup'] as String?),
    );
  }
}

/// Classification produced by the backend. Includes a `display` label that
/// matches the README §8.12 contract exactly.
enum BuildupKind {
  longBuildup('Long Buildup'),
  shortBuildup('Short Buildup'),
  shortCovering('Short Covering'),
  longUnwinding('Long Unwinding'),
  neutral('Neutral');

  final String display;
  const BuildupKind(this.display);

  static BuildupKind fromString(String? raw) {
    if (raw == null) return BuildupKind.neutral;
    for (final v in BuildupKind.values) {
      if (v.display == raw) return v;
    }
    return BuildupKind.neutral;
  }
}

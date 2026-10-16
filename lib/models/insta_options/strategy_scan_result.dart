/// One row of the `POST /strategy/scan` response (README §8.20).
class StrategyScanResult {
  final String templateName;
  final double maxPl;
  final double maxLoss;
  final List<double> breakeven;
  final List<StrategyLeg> legs;

  const StrategyScanResult({
    required this.templateName,
    required this.maxPl,
    required this.maxLoss,
    required this.breakeven,
    required this.legs,
  });

  factory StrategyScanResult.fromJson(Map<String, dynamic> json) {
    final beRaw = json['breakeven'] as List<dynamic>? ?? const [];
    final legsRaw = json['legs'] as List<dynamic>? ?? const [];
    return StrategyScanResult(
      templateName: json['template_name'] as String? ?? '',
      maxPl: (json['max_pl'] as num?)?.toDouble() ?? 0,
      maxLoss: (json['max_loss'] as num?)?.toDouble() ?? 0,
      breakeven: beRaw.map((e) => (e as num).toDouble()).toList(growable: false),
      legs: legsRaw
          .map((e) => StrategyLeg.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// One leg inside a [StrategyScanResult].
///
/// `side` is the only direction-bearing field in our backend response — the
/// OptionZ "Direction" column does not map to a field we receive.
class StrategyLeg {
  final String side;
  final String tradingSymbol;
  final double strike;
  final String optionType;
  final int lot;
  final double ltp;
  final int oi;

  const StrategyLeg({
    required this.side,
    required this.tradingSymbol,
    required this.strike,
    required this.optionType,
    required this.lot,
    required this.ltp,
    required this.oi,
  });

  bool get isBuy => side.toUpperCase() == 'BUY';
  bool get isSell => side.toUpperCase() == 'SELL';

  factory StrategyLeg.fromJson(Map<String, dynamic> json) {
    return StrategyLeg(
      side: json['side'] as String? ?? '',
      tradingSymbol: json['trading_symbol'] as String? ?? '',
      strike: (json['strike'] as num?)?.toDouble() ?? 0,
      optionType: json['option_type'] as String? ?? '',
      lot: (json['lot'] as num?)?.toInt() ?? 0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      oi: (json['oi'] as num?)?.toInt() ?? 0,
    );
  }
}

enum StrategyDirection {
  positive('Positive'),
  negative('Negative'),
  neutral('Neutral');

  final String wire;
  const StrategyDirection(this.wire);
}

enum StrategyMinRewardType {
  inr('INR', '₹'),
  pct('PCT', '%');

  final String wire;
  final String symbol;
  const StrategyMinRewardType(this.wire, this.symbol);
}

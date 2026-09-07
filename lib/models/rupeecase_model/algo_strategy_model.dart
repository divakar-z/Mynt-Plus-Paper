/// Data models for the RupeeCase **algo** (automated) strategy baskets.
///
/// Source: `GET https://agg.zebuetrade.com/rupeecase/api/v1/algo-strategies`
///
/// These power the "Algo" tab of the dashboard Strategies section and reuse the
/// exact same [StrategyCard] visual as the curated strategies. Parsing is
/// intentionally defensive — every numeric field is coerced through
/// [_asDouble] / [_asInt] and strings through [_asString] so a partial or
/// slightly-changed payload never throws at the dashboard boundary.
library;

class AlgoStrategiesResponse {
  final String statusCode;
  final int count;
  final bool stale;
  final List<AlgoStrategy> strategies;

  const AlgoStrategiesResponse({
    required this.statusCode,
    required this.count,
    required this.stale,
    required this.strategies,
  });

  bool get isSuccess => statusCode.toUpperCase() == 'SUCCESS';

  factory AlgoStrategiesResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    final meta = json['meta'] as Map<String, dynamic>?;
    final rawList = (json['strategies'] as List<dynamic>?) ?? const [];

    final strategies = rawList
        .whereType<Map<String, dynamic>>()
        .map(AlgoStrategy.fromJson)
        .toList();

    return AlgoStrategiesResponse(
      statusCode: _asString(status?['code']),
      count: _asInt(meta?['count'], fallback: strategies.length),
      stale: meta?['stale'] == true,
      strategies: strategies,
    );
  }
}

class AlgoStrategy {
  final String basketId;
  final String title;
  final String description;

  /// e.g. `CONSERVATIVE`, `AGGRESSIVE`, `MOMENTUM`.
  final String category;

  /// e.g. `LOW`, `MEDIUM`, `HIGH`.
  final String riskLevel;

  /// Number of underlying strategies bundled into the basket.
  final int strategiesCount;
  final int subscriberCount;

  /// Minimum capital the basket needs, in ₹.
  final double capitalRequired;

  /// Annualised back-test return (%).
  final double cagr;

  /// Cumulative back-test return over the whole window (%).
  final double totalReturn;
  final double winRate;
  final double sharpeRatio;

  /// Worst peak-to-trough equity drop over the back-test, in ₹ (absolute).
  final double maxDrawdown;
  final List<String> tags;

  const AlgoStrategy({
    required this.basketId,
    required this.title,
    required this.description,
    required this.category,
    required this.riskLevel,
    required this.strategiesCount,
    required this.subscriberCount,
    required this.capitalRequired,
    required this.cagr,
    required this.totalReturn,
    required this.winRate,
    required this.sharpeRatio,
    required this.maxDrawdown,
    required this.tags,
  });

  /// Max drawdown as a percentage of the capital required to run the basket.
  /// The API only returns the drawdown as an absolute ₹ figure ([maxDrawdown]),
  /// so dividing by [capitalRequired] gives the worst equity dip relative to the
  /// money deployed — the percentage the strategy cards display. Returns 0 when
  /// either input is non-positive.
  double get maxDrawdownPct {
    if (capitalRequired <= 0 || maxDrawdown <= 0) return 0;
    return (maxDrawdown / capitalRequired) * 100;
  }

  factory AlgoStrategy.fromJson(Map<String, dynamic> json) {
    return AlgoStrategy(
      basketId: _asString(json['basket_id']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      category: _asString(json['category']),
      riskLevel: _asString(json['risk_level']),
      strategiesCount: _asInt(json['strategies_count']),
      subscriberCount: _asInt(json['subscriber_count']),
      capitalRequired: _asDouble(json['capital_required']),
      cagr: _asDouble(json['backtest_cagr']),
      totalReturn: _asDouble(json['backtest_total_return']),
      winRate: _asDouble(json['backtest_win_rate']),
      sharpeRatio: _asDouble(json['backtest_sharpe_ratio']),
      maxDrawdown: _asDouble(json['backtest_max_drawdown']),
      tags: ((json['tags'] as List<dynamic>?) ?? const [])
          .map(_asString)
          .where((t) => t.isNotEmpty)
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Safe primitive coercion helpers.
// ---------------------------------------------------------------------------

double _asDouble(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

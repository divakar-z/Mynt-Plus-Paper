/// Data models for the RupeeCase curated-strategies marketplace.
///
/// Source: `GET https://agg.zebuetrade.com/rupeecase/api/v1/strategies`
///
/// Parsing is intentionally defensive — every numeric field is coerced through
/// [_asDouble] / [_asInt] and strings through [_asString] so a partial or
/// slightly-changed payload never throws at the dashboard boundary.
library;

class RupeeCaseStrategiesResponse {
  final String statusCode;
  final int count;
  final bool stale;
  final List<RupeeCaseStrategy> strategies;

  const RupeeCaseStrategiesResponse({
    required this.statusCode,
    required this.count,
    required this.stale,
    required this.strategies,
  });

  bool get isSuccess => statusCode.toUpperCase() == 'SUCCESS';

  factory RupeeCaseStrategiesResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    final meta = json['meta'] as Map<String, dynamic>?;
    final rawList = (json['strategies'] as List<dynamic>?) ?? const [];

    final strategies = rawList
        .whereType<Map<String, dynamic>>()
        .map(RupeeCaseStrategy.fromJson)
        .toList();

    return RupeeCaseStrategiesResponse(
      statusCode: _asString(status?['code']),
      count: _asInt(meta?['count'], fallback: strategies.length),
      stale: meta?['stale'] == true,
      strategies: strategies,
    );
  }
}

class RupeeCaseStrategy {
  final int id;
  final String name;
  final String description;
  final String owner;

  /// `static` or `dynamic`.
  final String type;
  final String benchmark;
  final int totalStocks;

  /// Annualised return (%).
  final double cagr;
  final double alpha;
  final double benchmarkReturn;

  /// Cumulative net return over the back-test window (%).
  final double netReturn;
  final double minInvest;
  final String riskLevel;
  final int rebalanceWeeks;

  /// Marketplace deep-link the card navigates to on tap.
  final String marketplaceUrl;
  final List<RupeeCaseAsset> assets;

  /// Extra allocation detail present only on `dynamic` strategies (`null` for
  /// static ones). Carries the rotating group config plus the live composition.
  final RupeeCaseDynamic? dynamicConfig;

  const RupeeCaseStrategy({
    required this.id,
    required this.name,
    required this.description,
    required this.owner,
    required this.type,
    required this.benchmark,
    required this.totalStocks,
    required this.cagr,
    required this.alpha,
    required this.benchmarkReturn,
    required this.netReturn,
    required this.minInvest,
    required this.riskLevel,
    required this.rebalanceWeeks,
    required this.marketplaceUrl,
    required this.assets,
    this.dynamicConfig,
  });

  bool get isDynamic => type.toLowerCase() == 'dynamic';

  /// Asset split to render on the card: the live [RupeeCaseDynamic.currentComposition]
  /// for dynamic strategies (falling back to [assets] if absent), otherwise the
  /// static [assets] list.
  List<RupeeCaseAsset> get composition {
    final live = dynamicConfig?.currentComposition;
    if (live != null && live.isNotEmpty) return live;
    return assets;
  }

  factory RupeeCaseStrategy.fromJson(Map<String, dynamic> json) {
    final dyn = json['dynamic'];
    return RupeeCaseStrategy(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      owner: _asString(json['strategy_owner']),
      type: _asString(json['strategy_type']),
      benchmark: _asString(json['benchmark']),
      totalStocks: _asInt(json['total_stocks']),
      cagr: _asDouble(json['cagr']),
      alpha: _asDouble(json['alpha']),
      benchmarkReturn: _asDouble(json['benchmark_return']),
      netReturn: _asDouble(json['net_return']),
      minInvest: _asDouble(json['min_invest']),
      riskLevel: _asString(json['risk_level']),
      rebalanceWeeks: _asInt(json['rebalance_weeks']),
      marketplaceUrl: _asString(json['marketplace_url']),
      assets: _assetList(json['assets']),
      dynamicConfig: dyn is Map<String, dynamic>
          ? RupeeCaseDynamic.fromJson(dyn)
          : null,
    );
  }
}

/// Rotating-allocation detail attached to `dynamic` strategies.
///
/// Mirrors the nested `dynamic` object: a set of [groups] that each rank an
/// eligible universe into a target weight, a [fixed] core sleeve that never
/// rotates, and the [currentComposition] the engine is holding right now.
class RupeeCaseDynamic {
  final List<RupeeCaseDynamicGroup> groups;
  final List<RupeeCaseAsset> fixed;
  final List<RupeeCaseAsset> currentComposition;

  const RupeeCaseDynamic({
    required this.groups,
    required this.fixed,
    required this.currentComposition,
  });

  factory RupeeCaseDynamic.fromJson(Map<String, dynamic> json) {
    final rawGroups = (json['groups'] as List<dynamic>?) ?? const [];
    return RupeeCaseDynamic(
      groups: rawGroups
          .whereType<Map<String, dynamic>>()
          .map(RupeeCaseDynamicGroup.fromJson)
          .toList(),
      fixed: _assetList(json['fixed']),
      currentComposition: _assetList(json['current_composition']),
    );
  }
}

class RupeeCaseDynamicGroup {
  final String name;
  final List<RupeeCaseAsset> eligibleUniverses;
  final List<RupeeCaseRankEntry> rankTable;

  const RupeeCaseDynamicGroup({
    required this.name,
    required this.eligibleUniverses,
    required this.rankTable,
  });

  factory RupeeCaseDynamicGroup.fromJson(Map<String, dynamic> json) {
    final rawRanks = (json['rank_table'] as List<dynamic>?) ?? const [];
    return RupeeCaseDynamicGroup(
      name: _asString(json['name']),
      eligibleUniverses: _assetList(json['eligible_universes']),
      rankTable: rawRanks
          .whereType<Map<String, dynamic>>()
          .map(RupeeCaseRankEntry.fromJson)
          .toList(),
    );
  }
}

class RupeeCaseRankEntry {
  final int rank;
  final double allocationPct;

  const RupeeCaseRankEntry({
    required this.rank,
    required this.allocationPct,
  });

  factory RupeeCaseRankEntry.fromJson(Map<String, dynamic> json) {
    return RupeeCaseRankEntry(
      rank: _asInt(json['rank']),
      allocationPct: _asDouble(json['allocation_pct']),
    );
  }
}

class RupeeCaseAsset {
  final String name;
  final int stockCount;
  final double allocationPct;

  const RupeeCaseAsset({
    required this.name,
    required this.stockCount,
    required this.allocationPct,
  });

  factory RupeeCaseAsset.fromJson(Map<String, dynamic> json) {
    return RupeeCaseAsset(
      name: _asString(json['name']),
      stockCount: _asInt(json['stock_count']),
      allocationPct: _asDouble(json['allocation_pct']),
    );
  }
}

// ---------------------------------------------------------------------------
// Safe primitive coercion helpers.
// ---------------------------------------------------------------------------

/// Coerces a raw JSON list into [RupeeCaseAsset]s, silently dropping any entry
/// that is not an object. Shared by every `{name, stock_count, allocation_pct}`
/// list on the payload (assets, fixed, eligible_universes, current_composition).
List<RupeeCaseAsset> _assetList(dynamic raw) =>
    ((raw as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RupeeCaseAsset.fromJson)
        .toList();

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

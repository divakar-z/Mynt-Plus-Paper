/// One index constituent's contribution to the index's point move for a day,
/// with a positioning overlay (OI buildup). An element of the `constituents`
/// array in `GET /api/v1/contribution`.
class Constituent {
  final String symbol;
  final String name;
  final String sector;
  final String? token; // Zebu spot token (optional live LTP)
  final String? exchange;
  final double? weightPct;
  final double? ltp;
  final double? change; // absolute ₹ move
  final double? priceChangePct;
  final double? marketCap;
  final double? pointContribution; // signed index points added
  final double? sharePct; // signed % of the move's magnitude
  final String direction; // contributor | detractor | flat
  final int? oi;
  final double? oiChangePct;
  final String? category; // OI-buildup wire value; null if outside F&O universe

  const Constituent({
    required this.symbol,
    required this.name,
    required this.sector,
    required this.token,
    required this.exchange,
    required this.weightPct,
    required this.ltp,
    required this.change,
    required this.priceChangePct,
    required this.marketCap,
    required this.pointContribution,
    required this.sharePct,
    required this.direction,
    required this.oi,
    required this.oiChangePct,
    required this.category,
  });

  bool get isContributor => direction == 'contributor';
  bool get isDetractor => direction == 'detractor';

  /// `exchange|token` subscription key for the constituent's live spot price.
  String? get tickKey =>
      (token != null && exchange != null) ? '$exchange|$token' : null;

  /// Overlay live fields. Price fields (ltp / change / price%) come straight
  /// from the socket; point-contribution / share / direction carry the exact
  /// live recompute (see [IndexContribution.recomputeLive]). Weight / OI /
  /// buildup always stay the API snapshot.
  Constituent copyWith({
    double? ltp,
    double? change,
    double? priceChangePct,
    double? pointContribution,
    double? sharePct,
    String? direction,
  }) =>
      Constituent(
        symbol: symbol,
        name: name,
        sector: sector,
        token: token,
        exchange: exchange,
        weightPct: weightPct,
        ltp: ltp ?? this.ltp,
        change: change ?? this.change,
        priceChangePct: priceChangePct ?? this.priceChangePct,
        marketCap: marketCap,
        pointContribution: pointContribution ?? this.pointContribution,
        sharePct: sharePct ?? this.sharePct,
        direction: direction ?? this.direction,
        oi: oi,
        oiChangePct: oiChangePct,
        category: category,
      );

  factory Constituent.fromJson(Map<String, dynamic> j) => Constituent(
        symbol: (j['symbol'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        sector: (j['sector'] ?? '').toString(),
        token: j['token']?.toString(),
        exchange: j['exchange']?.toString(),
        weightPct: (j['weight_pct'] as num?)?.toDouble(),
        ltp: (j['ltp'] as num?)?.toDouble(),
        change: (j['change'] as num?)?.toDouble(),
        priceChangePct: (j['price_change_pct'] as num?)?.toDouble(),
        marketCap: (j['market_cap'] as num?)?.toDouble(),
        pointContribution: (j['point_contribution'] as num?)?.toDouble(),
        sharePct: (j['share_pct'] as num?)?.toDouble(),
        direction: (j['direction'] ?? 'flat').toString(),
        oi: (j['oi'] as num?)?.toInt(),
        oiChangePct: (j['oi_change_pct'] as num?)?.toDouble(),
        category: j['category'] as String?,
      );
}

/// One index constituent's contribution to the index's point move for a day,
/// with a positioning overlay (OI buildup + PCR). An element of the
/// `constituents` array in `GET /api/v1/contribution`.
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
  final double? pcr;

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
    required this.pcr,
  });

  bool get isContributor => direction == 'contributor';
  bool get isDetractor => direction == 'detractor';

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
        pcr: (j['pcr'] as num?)?.toDouble(),
      );
}

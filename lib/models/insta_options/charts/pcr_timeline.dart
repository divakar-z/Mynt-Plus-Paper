import 'package:mynt_plus/models/insta_options/freshness.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';

/// One intraday bucket of chain-wide PCR (`GET /api/v1/charts/pcr-timeline`
/// point). [t] is the bucket start, anchored to the 09:15 session open.
class PcrPoint {
  final DateTime? t;
  final double? pcr;
  final int totalCeOi;
  final int totalPeOi;

  const PcrPoint({
    required this.t,
    required this.pcr,
    required this.totalCeOi,
    required this.totalPeOi,
  });

  factory PcrPoint.fromJson(Map<String, dynamic> j) => PcrPoint(
        t: DateTime.tryParse((j['t'] ?? '').toString()),
        pcr: (j['pcr'] as num?)?.toDouble(),
        totalCeOi: (j['total_ce_oi'] as num?)?.toInt() ?? 0,
        totalPeOi: (j['total_pe_oi'] as num?)?.toInt() ?? 0,
      );
}

/// Full `GET /api/v1/charts/pcr-timeline?underlying=&date=&expiry=&interval=`
/// payload: chain-wide PCR per intraday bucket for one underlying + expiry.
class PcrTimeline {
  final String underlying;
  final String tradeDate;
  final String? expiry;
  final String interval;
  final List<ExpiryOption> availableExpiries;
  final double? openPcr;
  final double? closePcr;
  final List<PcrPoint> points; // chronological
  final Freshness freshness;

  const PcrTimeline({
    required this.underlying,
    required this.tradeDate,
    required this.expiry,
    required this.interval,
    required this.availableExpiries,
    required this.openPcr,
    required this.closePcr,
    required this.points,
    required this.freshness,
  });

  bool get isEmpty => points.isEmpty;

  factory PcrTimeline.fromJson(Map<String, dynamic> j) => PcrTimeline(
        underlying: (j['underlying'] ?? '').toString(),
        tradeDate: (j['trade_date'] ?? '').toString(),
        expiry: j['expiry'] as String?,
        interval: (j['interval'] ?? '').toString(),
        availableExpiries:
            (j['available_expiries'] as List<dynamic>? ?? const [])
                .map((e) => ExpiryOption.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        openPcr: (j['open_pcr'] as num?)?.toDouble(),
        closePcr: (j['close_pcr'] as num?)?.toDouble(),
        points: (j['points'] as List<dynamic>? ?? const [])
            .map((e) => PcrPoint.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        freshness: Freshness.fromJson(j['freshness'] as Map<String, dynamic>?),
      );
}

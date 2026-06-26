import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';

/// One intraday bucket of a strike-leg's OI + LTP (`oi-timeline` series point).
class OiTimePoint {
  final DateTime? t;
  final int? oi;
  final double? ltp;

  const OiTimePoint({required this.t, required this.oi, required this.ltp});

  factory OiTimePoint.fromJson(Map<String, dynamic> j) => OiTimePoint(
        t: DateTime.tryParse((j['t'] ?? '').toString()),
        oi: (j['oi'] as num?)?.toInt(),
        ltp: (j['ltp'] as num?)?.toDouble(),
      );
}

/// Intraday OI/LTP series for one (strike, leg) — one entry per selected strike
/// + option type.
class OiSeries {
  final double strike;
  final String optType; // CE | PE
  final List<OiTimePoint> points;

  const OiSeries({
    required this.strike,
    required this.optType,
    required this.points,
  });

  factory OiSeries.fromJson(Map<String, dynamic> j) => OiSeries(
        strike: (j['strike'] as num?)?.toDouble() ?? 0,
        optType: (j['opt_type'] ?? '').toString(),
        points: (j['points'] as List<dynamic>? ?? const [])
            .map((e) => OiTimePoint.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Per-strike-leg OI + sentiment snapshot (`oi-timeline` table cell). `category`
/// is the buildup quadrant; `bias` is the underlying-directional read (already
/// option-type aware — use it directly).
class OiLegSentiment {
  final double? ltp;
  final double? changePct;
  final int? oi;
  final int? oiChange;
  final double? oiChangePct;
  final int? volume;
  final String? category; // long_buildup | short_buildup | short_covering | long_covering | na
  final String? bias; // bullish | bearish | neutral

  const OiLegSentiment({
    required this.ltp,
    required this.changePct,
    required this.oi,
    required this.oiChange,
    required this.oiChangePct,
    required this.volume,
    required this.category,
    required this.bias,
  });

  factory OiLegSentiment.fromJson(Map<String, dynamic> j) => OiLegSentiment(
        ltp: (j['ltp'] as num?)?.toDouble(),
        changePct: (j['change_pct'] as num?)?.toDouble(),
        oi: (j['oi'] as num?)?.toInt(),
        oiChange: (j['oi_change'] as num?)?.toInt(),
        oiChangePct: (j['oi_change_pct'] as num?)?.toDouble(),
        volume: (j['volume'] as num?)?.toInt(),
        category: j['category'] as String?,
        bias: j['bias'] as String?,
      );
}

/// One strike's OI + sentiment row in the `oi-timeline` table (all listed
/// strikes; `ce`/`pe` may be null).
class OiTimelineRow {
  final double strike;
  final bool isAtm;
  final double? pcr;
  final OiLegSentiment? ce;
  final OiLegSentiment? pe;

  const OiTimelineRow({
    required this.strike,
    required this.isAtm,
    required this.pcr,
    required this.ce,
    required this.pe,
  });

  factory OiTimelineRow.fromJson(Map<String, dynamic> j) => OiTimelineRow(
        strike: (j['strike'] as num?)?.toDouble() ?? 0,
        isAtm: j['is_atm'] == true,
        pcr: (j['pcr'] as num?)?.toDouble(),
        ce: j['ce'] == null
            ? null
            : OiLegSentiment.fromJson(j['ce'] as Map<String, dynamic>),
        pe: j['pe'] == null
            ? null
            : OiLegSentiment.fromJson(j['pe'] as Map<String, dynamic>),
      );
}

/// A selectable strike (`available_strikes` entry).
class StrikeOption {
  final double strike;
  final bool isAtm;

  const StrikeOption({required this.strike, required this.isAtm});

  factory StrikeOption.fromJson(Map<String, dynamic> j) => StrikeOption(
        strike: (j['strike'] as num?)?.toDouble() ?? 0,
        isAtm: j['is_atm'] == true,
      );
}

/// Full `GET /api/v1/charts/oi-timeline?...&strikes=` payload: intraday OI/LTP
/// [series] for the selected strikes + a per-strike OI/sentiment [table] for
/// every listed strike.
class OiTimeline {
  final String underlying;
  final String tradeDate;
  final String? expiry;
  final String interval;
  final List<ExpiryOption> availableExpiries;
  final double? underlyingValue;
  final double? atmStrike;
  final List<StrikeOption> availableStrikes;
  final List<double> selectedStrikes;
  final List<OiSeries> series;
  final List<OiTimelineRow> table;

  const OiTimeline({
    required this.underlying,
    required this.tradeDate,
    required this.expiry,
    required this.interval,
    required this.availableExpiries,
    required this.underlyingValue,
    required this.atmStrike,
    required this.availableStrikes,
    required this.selectedStrikes,
    required this.series,
    required this.table,
  });

  bool get isEmpty => series.isEmpty && table.isEmpty;

  factory OiTimeline.fromJson(Map<String, dynamic> j) => OiTimeline(
        underlying: (j['underlying'] ?? '').toString(),
        tradeDate: (j['trade_date'] ?? '').toString(),
        expiry: j['expiry'] as String?,
        interval: (j['interval'] ?? '').toString(),
        availableExpiries:
            (j['available_expiries'] as List<dynamic>? ?? const [])
                .map((e) => ExpiryOption.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        underlyingValue: (j['underlying_value'] as num?)?.toDouble(),
        atmStrike: (j['atm_strike'] as num?)?.toDouble(),
        availableStrikes: (j['available_strikes'] as List<dynamic>? ?? const [])
            .map((e) => StrikeOption.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        selectedStrikes: (j['selected_strikes'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(growable: false),
        series: (j['series'] as List<dynamic>? ?? const [])
            .map((e) => OiSeries.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        table: (j['table'] as List<dynamic>? ?? const [])
            .map((e) => OiTimelineRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

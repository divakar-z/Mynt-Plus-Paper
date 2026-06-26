import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';

/// One strike's CE/PE open interest and its day-over-day change
/// (`GET /api/v1/charts/oi-by-strike` row).
class OiStrikeRow {
  final double strike;
  final bool isAtm;
  final int ceOi;
  final int peOi;
  final int ceOiChange; // absolute Δ vs the leg's prior available day
  final int peOiChange;
  final double? ceOiChangePct; // null on the leg's first/earliest day
  final double? peOiChangePct;

  const OiStrikeRow({
    required this.strike,
    required this.isAtm,
    required this.ceOi,
    required this.peOi,
    required this.ceOiChange,
    required this.peOiChange,
    required this.ceOiChangePct,
    required this.peOiChangePct,
  });

  factory OiStrikeRow.fromJson(Map<String, dynamic> j) => OiStrikeRow(
        strike: (j['strike'] as num?)?.toDouble() ?? 0,
        isAtm: j['is_atm'] == true,
        ceOi: (j['ce_oi'] as num?)?.toInt() ?? 0,
        peOi: (j['pe_oi'] as num?)?.toInt() ?? 0,
        ceOiChange: (j['ce_oi_change'] as num?)?.toInt() ?? 0,
        peOiChange: (j['pe_oi_change'] as num?)?.toInt() ?? 0,
        ceOiChangePct: (j['ce_oi_change_pct'] as num?)?.toDouble(),
        peOiChangePct: (j['pe_oi_change_pct'] as num?)?.toDouble(),
      );
}

/// Full `GET /api/v1/charts/oi-by-strike?underlying=&date=&expiry=` payload:
/// per-strike CE/PE OI + change for one underlying + expiry on one day.
class OiByStrike {
  final String underlying;
  final String tradeDate;
  final String? expiry;
  final List<ExpiryOption> availableExpiries;
  final double? underlyingValue;
  final double? atmStrike;
  final int totalCeOi;
  final int totalPeOi;
  final double? pcr;
  final double? maxPain;
  final List<OiStrikeRow> rows; // sorted by strike ascending

  const OiByStrike({
    required this.underlying,
    required this.tradeDate,
    required this.expiry,
    required this.availableExpiries,
    required this.underlyingValue,
    required this.atmStrike,
    required this.totalCeOi,
    required this.totalPeOi,
    required this.pcr,
    required this.maxPain,
    required this.rows,
  });

  bool get isEmpty => rows.isEmpty;

  factory OiByStrike.fromJson(Map<String, dynamic> j) => OiByStrike(
        underlying: (j['underlying'] ?? '').toString(),
        tradeDate: (j['trade_date'] ?? '').toString(),
        expiry: j['expiry'] as String?,
        availableExpiries:
            (j['available_expiries'] as List<dynamic>? ?? const [])
                .map((e) => ExpiryOption.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
        underlyingValue: (j['underlying_value'] as num?)?.toDouble(),
        atmStrike: (j['atm_strike'] as num?)?.toDouble(),
        totalCeOi: (j['total_ce_oi'] as num?)?.toInt() ?? 0,
        totalPeOi: (j['total_pe_oi'] as num?)?.toInt() ?? 0,
        pcr: (j['pcr'] as num?)?.toDouble(),
        maxPain: (j['max_pain'] as num?)?.toDouble(),
        rows: (j['rows'] as List<dynamic>? ?? const [])
            .map((e) => OiStrikeRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

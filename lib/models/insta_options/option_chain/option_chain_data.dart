import 'package:mynt_plus/models/insta_options/option_chain/chain_strike_row.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/models/insta_options/option_chain/oi_wall.dart';

/// Full `GET /api/v1/option-chain` payload for one underlying + trading day +
/// expiry. `rows` are sorted by strike ascending.
class OptionChainData {
  final String underlying;
  final String tradeDate;
  final String? expiry;
  final List<ExpiryOption> availableExpiries;
  final double? underlyingValue; // spot (index) / near-future close (stock)
  final double? atmStrike;
  final int totalCeOi;
  final int totalPeOi;
  final double? pcr;
  final double? maxPain;
  final List<OiWall> support;
  final List<OiWall> resistance;
  final List<ChainStrikeRow> rows;

  const OptionChainData({
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
    required this.support,
    required this.resistance,
    required this.rows,
  });

  bool get isEmpty => rows.isEmpty;

  /// Index of the ATM row within [rows], or null if none is flagged.
  int? get atmIndex {
    final i = rows.indexWhere((r) => r.isAtm);
    return i < 0 ? null : i;
  }

  /// Largest CE/PE OI across all rows — scales the mirrored OI bars.
  int get maxOiInView {
    var m = 0;
    for (final r in rows) {
      final ce = r.ce?.oi ?? 0;
      final pe = r.pe?.oi ?? 0;
      if (ce > m) m = ce;
      if (pe > m) m = pe;
    }
    return m;
  }

  factory OptionChainData.fromJson(Map<String, dynamic> json) {
    List<OiWall> walls(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => OiWall.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
    return OptionChainData(
      underlying: (json['underlying'] ?? '').toString(),
      tradeDate: (json['trade_date'] ?? '').toString(),
      expiry: json['expiry'] as String?,
      availableExpiries:
          (json['available_expiries'] as List<dynamic>? ?? const [])
              .map((e) => ExpiryOption.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      underlyingValue: (json['underlying_value'] as num?)?.toDouble(),
      atmStrike: (json['atm_strike'] as num?)?.toDouble(),
      totalCeOi: (json['total_ce_oi'] as num?)?.toInt() ?? 0,
      totalPeOi: (json['total_pe_oi'] as num?)?.toInt() ?? 0,
      pcr: (json['pcr'] as num?)?.toDouble(),
      maxPain: (json['max_pain'] as num?)?.toDouble(),
      support: walls('support'),
      resistance: walls('resistance'),
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map((e) => ChainStrikeRow.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

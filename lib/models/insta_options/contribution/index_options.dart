import 'package:mynt_plus/models/insta_options/option_chain/oi_wall.dart';

/// Index options snapshot (`options` block): PCR, max-pain, ATM, and the
/// support/resistance OI walls. Comes from our own data, so it populates even
/// when the weightage feed is unavailable.
class IndexOptions {
  final double? pcr;
  final String? expiry;
  final double? maxPain;
  final double? atmStrike;
  final int? totalCeOi;
  final int? totalPeOi;
  final List<OiWall> resistance; // peak CALL-OI strikes
  final List<OiWall> support; // peak PUT-OI strikes

  const IndexOptions({
    required this.pcr,
    required this.expiry,
    required this.maxPain,
    required this.atmStrike,
    required this.totalCeOi,
    required this.totalPeOi,
    required this.resistance,
    required this.support,
  });

  factory IndexOptions.fromJson(Map<String, dynamic> j) {
    List<OiWall> walls(String key) => (j[key] as List<dynamic>? ?? const [])
        .map((e) => OiWall.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return IndexOptions(
      pcr: (j['pcr'] as num?)?.toDouble(),
      expiry: j['expiry'] as String?,
      maxPain: (j['max_pain'] as num?)?.toDouble(),
      atmStrike: (j['atm_strike'] as num?)?.toDouble(),
      totalCeOi: (j['total_ce_oi'] as num?)?.toInt(),
      totalPeOi: (j['total_pe_oi'] as num?)?.toInt(),
      resistance: walls('resistance'),
      support: walls('support'),
    );
  }
}

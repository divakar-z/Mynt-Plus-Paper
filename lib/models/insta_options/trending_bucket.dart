/// One per-bucket row from `GET /oi/trending` (Ticket 3, README §10.5).
///
/// Server computes everything on its side — the frontend renders verbatim.
/// `dir_spot` / `dir_oi` are signed integers (`-1`, `0`, `+1`).
class TrendingBucket {
  final DateTime time;
  final double sentiment;
  final int cumCeOi;
  final int cumPeOi;
  final int deltaCeOi;
  final int deltaPeOi;
  final double pcr;
  final double ltp;
  final double ltpPct;
  final int dirSpot;
  final int dirOi;

  const TrendingBucket({
    required this.time,
    required this.sentiment,
    required this.cumCeOi,
    required this.cumPeOi,
    required this.deltaCeOi,
    required this.deltaPeOi,
    required this.pcr,
    required this.ltp,
    required this.ltpPct,
    required this.dirSpot,
    required this.dirOi,
  });

  /// `deltaPeOi − deltaCeOi`. Spec §10.5 BucketTable's "DiffOI" column.
  int get diffOi => deltaPeOi - deltaCeOi;

  factory TrendingBucket.fromJson(Map<String, dynamic> json) {
    final raw = json['time'] as String? ?? '';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return TrendingBucket(
      time: parsed,
      sentiment: (json['sentiment'] as num?)?.toDouble() ?? 0,
      cumCeOi: (json['cum_ce_oi'] as num?)?.toInt() ?? 0,
      cumPeOi: (json['cum_pe_oi'] as num?)?.toInt() ?? 0,
      deltaCeOi: (json['delta_ce_oi'] as num?)?.toInt() ?? 0,
      deltaPeOi: (json['delta_pe_oi'] as num?)?.toInt() ?? 0,
      pcr: (json['pcr'] as num?)?.toDouble() ?? 0,
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0,
      ltpPct: (json['ltp_pct'] as num?)?.toDouble() ?? 0,
      dirSpot: (json['dir_spot'] as num?)?.toInt() ?? 0,
      dirOi: (json['dir_oi'] as num?)?.toInt() ?? 0,
    );
  }
}

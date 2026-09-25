/// Index-future OI buildup + basis (`index_oi` block). Comes from our own data,
/// so it populates even when the weightage feed is unavailable. All nullable.
class IndexFutureOi {
  final int? futureOi;
  final double? oiChangePct;
  final String? buildup; // OI-buildup wire value (long_buildup, …)
  final double? basis; // future − spot
  final double? basisPct;
  final double? rolloverPct; // next-month OI as share of (near + next)

  const IndexFutureOi({
    required this.futureOi,
    required this.oiChangePct,
    required this.buildup,
    required this.basis,
    required this.basisPct,
    required this.rolloverPct,
  });

  factory IndexFutureOi.fromJson(Map<String, dynamic> j) => IndexFutureOi(
        futureOi: (j['future_oi'] as num?)?.toInt(),
        oiChangePct: (j['oi_change_pct'] as num?)?.toDouble(),
        buildup: j['buildup'] as String?,
        basis: (j['basis'] as num?)?.toDouble(),
        basisPct: (j['basis_pct'] as num?)?.toDouble(),
        rolloverPct: (j['rollover_pct'] as num?)?.toDouble(),
      );
}

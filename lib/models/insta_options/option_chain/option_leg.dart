/// One side (CE or PE) of a strike row. Greeks/IV are `null` from the backend
/// today, so they are intentionally not modelled. A whole leg can be absent —
/// the row's `ce`/`pe` is then `null` (see `ChainStrikeRow`).
class OptionLeg {
  final double? ltp;
  final double? change; // absolute LTP change vs prior day
  final double? changePct; // LTP change %
  final int? volume;
  final int oi;
  final double? oiChangePct;

  const OptionLeg({
    this.ltp,
    this.change,
    this.changePct,
    this.volume,
    required this.oi,
    this.oiChangePct,
  });

  factory OptionLeg.fromJson(Map<String, dynamic> json) => OptionLeg(
        ltp: (json['ltp'] as num?)?.toDouble(),
        change: (json['change'] as num?)?.toDouble(),
        changePct: (json['change_pct'] as num?)?.toDouble(),
        volume: (json['volume'] as num?)?.toInt(),
        oi: (json['oi'] as num?)?.toInt() ?? 0,
        oiChangePct: (json['oi_change_pct'] as num?)?.toDouble(),
      );
}

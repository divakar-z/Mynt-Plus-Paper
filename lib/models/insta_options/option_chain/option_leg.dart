/// One side (CE or PE) of a strike row. Greeks/IV are `null` from the backend
/// today, so they are intentionally not modelled. A whole leg can be absent —
/// the row's `ce`/`pe` is then `null` (see `ChainStrikeRow`).
///
/// [token] + [exchange] (NFO) identify the option contract for the live LTP over
/// the Noren socket; the snapshot [ltp]/[change]/[changePct] hold until a tick
/// arrives. OI / OIΔ% are never live (the socket can't produce them).
class OptionLeg {
  final double? ltp;
  final double? change; // absolute LTP change vs prior day
  final double? changePct; // LTP change %
  final int? volume;
  final int oi;
  final double? oiChangePct;
  final String? token;
  final String? exchange;

  const OptionLeg({
    this.ltp,
    this.change,
    this.changePct,
    this.volume,
    required this.oi,
    this.oiChangePct,
    this.token,
    this.exchange,
  });

  /// `exchange|token` subscription key for the socket, or null if untokenised.
  String? get tickKey =>
      (token != null && exchange != null) ? '$exchange|$token' : null;

  factory OptionLeg.fromJson(Map<String, dynamic> json) => OptionLeg(
        ltp: (json['ltp'] as num?)?.toDouble(),
        change: (json['change'] as num?)?.toDouble(),
        changePct: (json['change_pct'] as num?)?.toDouble(),
        volume: (json['volume'] as num?)?.toInt(),
        oi: (json['oi'] as num?)?.toInt() ?? 0,
        oiChangePct: (json['oi_change_pct'] as num?)?.toDouble(),
        token: json['token']?.toString(),
        exchange: json['exchange']?.toString(),
      );
}

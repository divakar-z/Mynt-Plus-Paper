/// The `freshness` block carried by every live-capable payload (dashboard,
/// option-chain, OI charts, contribution).
///
/// [isLive] is true only when this is today's intraday snapshot. On a
/// `?live=true` request that returns `is_live:false`, the server had no live
/// data and **fell back to the latest finalized day** — render it as historical
/// for [tradeDate], not as an error.
class Freshness {
  final bool isLive;

  /// IST "as of" wall-clock the snapshot was built — kept as the raw
  /// `YYYY-MM-DD HH:MM:SS` string (the API has no timezone offset, so we never
  /// reinterpret it through the browser's local zone).
  final String? asOf;
  final String tradeDate;

  const Freshness({
    required this.isLive,
    required this.asOf,
    required this.tradeDate,
  });

  static const Freshness empty =
      Freshness(isLive: false, asOf: null, tradeDate: '');

  factory Freshness.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return Freshness(
      isLive: j['is_live'] == true,
      asOf: j['as_of'] as String?,
      tradeDate: (j['trade_date'] ?? '').toString(),
    );
  }

  /// `HH:mm` slice of [asOf] for the "as of 10:05" label (timezone-safe).
  String? get hm =>
      (asOf != null && asOf!.length >= 16) ? asOf!.substring(11, 16) : null;
}

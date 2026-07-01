/// `GET /api/v1/dates` — the global trading-day calendar shared by every
/// date-based screen.
///
/// [dates] are FINALIZED (immutable, EOD-swept) days only — **today is never in
/// [dates]** until it finalizes (~15:40 IST). Default the historical picker to
/// [latest]. [live] is non-null only while the backend holds today's intraday
/// data; surface it as a separate "Live / Today" option.
class DatesResponse {
  final List<String> dates;
  final String? latest;
  final LiveChannel? live;

  const DatesResponse({required this.dates, required this.latest, this.live});

  static const DatesResponse empty =
      DatesResponse(dates: [], latest: null, live: null);

  bool get isEmpty => dates.isEmpty;

  /// The backend currently holds today's intraday data (show + default to a
  /// "Live / Today" option).
  bool get hasLive => live != null;

  factory DatesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['dates'] as List<dynamic>? ?? const [];
    final live = json['live'] as Map<String, dynamic>?;
    return DatesResponse(
      dates: raw.map((e) => e as String).toList(growable: false),
      latest: json['latest'] as String?,
      live: live == null ? null : LiveChannel.fromJson(live),
    );
  }
}

/// The `live` channel on `/dates`: today's trade date + the snapshot time the
/// backend last refreshed it.
class LiveChannel {
  final String date;
  final String? asOf; // raw IST "YYYY-MM-DD HH:MM:SS"

  const LiveChannel({required this.date, required this.asOf});

  factory LiveChannel.fromJson(Map<String, dynamic> j) => LiveChannel(
        date: (j['date'] ?? '').toString(),
        asOf: j['as_of'] as String?,
      );

  /// `HH:mm` slice of [asOf] (timezone-safe — no local-zone reinterpretation).
  String? get hm =>
      (asOf != null && asOf!.length >= 16) ? asOf!.substring(11, 16) : null;
}

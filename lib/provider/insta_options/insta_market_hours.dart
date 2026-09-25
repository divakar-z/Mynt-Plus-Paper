/// IST market-hours helpers shared by every polling provider.
///
/// NSE/BSE equity + F&O regular session is Mon–Fri **09:15 IST → 15:30 IST**.
/// We treat anything outside that window as closed and skip the polling
/// timer entirely (one-shot mount fetch + manual Refresh button only). The
/// per-provider tick interval during market hours stays at the spec value
/// (`tickIntervalInsideHours`) for the screens that opted into 4 s polling.
class InstaMarketHours {
  InstaMarketHours._();

  /// REST tick cadence inside market hours, matching README §10.x Refresh.
  static const Duration tickIntervalInsideHours = Duration(seconds: 4);

  /// Returns the current wall-clock time interpreted as IST (UTC + 5:30).
  static DateTime nowIst() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  /// `true` when [now] (defaulting to [nowIst]) is inside the regular IST
  /// equity / F&O session (Mon–Fri 09:15 → 15:30 inclusive).
  ///
  /// Public holidays are not honoured — the polling waste on a holiday is
  /// bounded by one mount fetch per screen, so the extra calendar lookup
  /// isn't worth it.
  static bool isOpen({DateTime? now}) {
    final t = now ?? nowIst();
    final isWeekday = t.weekday >= DateTime.monday && t.weekday <= DateTime.friday;
    final minutes = t.hour * 60 + t.minute;
    const openMinutes = 9 * 60 + 15;
    const closeMinutes = 15 * 60 + 30;
    return isWeekday && minutes >= openMinutes && minutes <= closeMinutes;
  }
}

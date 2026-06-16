/// `GET /api/v1/dashboard/dates` — the calendar of available trading days.
///
/// Only these dates are selectable in the date picker; default to [latest].
class DatesResponse {
  final List<String> dates;
  final String? latest;

  const DatesResponse({required this.dates, required this.latest});

  static const DatesResponse empty = DatesResponse(dates: [], latest: null);

  bool get isEmpty => dates.isEmpty;

  factory DatesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['dates'] as List<dynamic>? ?? const [];
    return DatesResponse(
      dates: raw.map((e) => e as String).toList(growable: false),
      latest: json['latest'] as String?,
    );
  }
}

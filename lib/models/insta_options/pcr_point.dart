/// One bucket from `GET /oi/pcr/timeseries` (README §8.11).
class PcrPoint {
  final DateTime time;
  final double pcr;
  final double spot;

  const PcrPoint({
    required this.time,
    required this.pcr,
    required this.spot,
  });

  factory PcrPoint.fromJson(Map<String, dynamic> json) {
    final raw = json['time'] as String? ?? '';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return PcrPoint(
      time: parsed,
      pcr: (json['pcr'] as num?)?.toDouble() ?? 0,
      spot: (json['spot'] as num?)?.toDouble() ?? 0,
    );
  }
}

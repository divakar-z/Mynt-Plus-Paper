/// One 1-min OHLC spot bar from `GET /spot/timeseries` (README §8.4).
class SpotTimeseriesPoint {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  const SpotTimeseriesPoint({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  factory SpotTimeseriesPoint.fromJson(Map<String, dynamic> json) {
    final raw = json['time'] as String? ?? '';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return SpotTimeseriesPoint(
      time: parsed,
      open: (json['open'] as num?)?.toDouble() ?? 0,
      high: (json['high'] as num?)?.toDouble() ?? 0,
      low: (json['low'] as num?)?.toDouble() ?? 0,
      close: (json['close'] as num?)?.toDouble() ?? 0,
    );
  }
}

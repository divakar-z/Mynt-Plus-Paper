/// One 1-min bucket from `GET /oi/timeseries` (README §8.9).
class OiTimeseriesPoint {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final int oi;
  final int oiChange;

  const OiTimeseriesPoint({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.oi,
    required this.oiChange,
  });

  factory OiTimeseriesPoint.fromJson(Map<String, dynamic> json) {
    final raw = json['time'] as String? ?? '';
    final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return OiTimeseriesPoint(
      time: parsed,
      open: (json['open'] as num?)?.toDouble() ?? 0,
      high: (json['high'] as num?)?.toDouble() ?? 0,
      low: (json['low'] as num?)?.toDouble() ?? 0,
      close: (json['close'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      oi: (json['oi'] as num?)?.toInt() ?? 0,
      oiChange: (json['oi_change'] as num?)?.toInt() ?? 0,
    );
  }
}

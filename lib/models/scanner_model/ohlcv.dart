class OhlcvBar {
  final String date;
  final double? open, high, low, close, adjclose;
  final int? volume;

  const OhlcvBar({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.adjclose,
    required this.volume,
  });

  factory OhlcvBar.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    final close = d(j['close']);
    return OhlcvBar(
      date: j['date'] as String,
      open: d(j['open']),
      high: d(j['high']),
      low: d(j['low']),
      close: close,
      adjclose: d(j['adjclose']) ?? close,
      volume: (j['volume'] is num) ? (j['volume'] as num).toInt() : null,
    );
  }

  /// True only when all OHLC values are present (used to drop NaN rows from
  /// charts and tables).
  bool get hasData =>
      open != null && high != null && low != null && close != null;
}

class OhlcvResponse {
  final String ticker;
  final bool adjusted;
  final List<OhlcvBar> bars;

  const OhlcvResponse({
    required this.ticker,
    required this.adjusted,
    required this.bars,
  });

  factory OhlcvResponse.fromJson(Map<String, dynamic> j) => OhlcvResponse(
        ticker: j['ticker'] as String,
        adjusted: (j['adjusted'] ?? true) as bool,
        bars: (j['bars'] as List)
            .cast<Map<String, dynamic>>()
            .map(OhlcvBar.fromJson)
            .where((b) => b.hasData) // drop incomplete bars
            .toList(),
      );
}

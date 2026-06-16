/// Buildup summary counts shared by `GET /buildup-sentiment`, the `summary`
/// block on `GET /fno-buildup`, and `buildup_sentiment` on `GET /overview`.
///
/// bullish = long_buildup + short_covering; bearish = short_buildup +
/// long_covering (the backend pre-computes both).
class BuildupSentiment {
  final int longBuildup;
  final int shortBuildup;
  final int shortCovering;
  final int longCovering;
  final int na;
  final int total;
  final int bullish;
  final int bearish;

  const BuildupSentiment({
    required this.longBuildup,
    required this.shortBuildup,
    required this.shortCovering,
    required this.longCovering,
    required this.na,
    required this.total,
    required this.bullish,
    required this.bearish,
  });

  static const BuildupSentiment empty = BuildupSentiment(
    longBuildup: 0,
    shortBuildup: 0,
    shortCovering: 0,
    longCovering: 0,
    na: 0,
    total: 0,
    bullish: 0,
    bearish: 0,
  );

  bool get isEmpty => total == 0;

  factory BuildupSentiment.fromJson(Map<String, dynamic> json) =>
      BuildupSentiment(
        longBuildup: (json['long_buildup'] as num?)?.toInt() ?? 0,
        shortBuildup: (json['short_buildup'] as num?)?.toInt() ?? 0,
        shortCovering: (json['short_covering'] as num?)?.toInt() ?? 0,
        longCovering: (json['long_covering'] as num?)?.toInt() ?? 0,
        na: (json['na'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        bullish: (json['bullish'] as num?)?.toInt() ?? 0,
        bearish: (json['bearish'] as num?)?.toInt() ?? 0,
      );
}

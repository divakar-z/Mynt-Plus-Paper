import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';

/// One mover from `gainers_losers.gainers[]` / `.losers[]` — top by %change.
/// `priceChangePct` / `lastClose` nullable → render `—`.
class GainerLoserRow {
  final String symbol;
  final double? priceChangePct;
  final double? lastClose;
  final BuildupCategory category;

  const GainerLoserRow({
    required this.symbol,
    required this.priceChangePct,
    required this.lastClose,
    required this.category,
  });

  /// Overlay the socket-live LTP (`lastClose` column) + price%; the buildup
  /// category stays the API snapshot.
  GainerLoserRow copyWith({double? lastClose, double? priceChangePct}) =>
      GainerLoserRow(
        symbol: symbol,
        priceChangePct: priceChangePct ?? this.priceChangePct,
        lastClose: lastClose ?? this.lastClose,
        category: category,
      );

  factory GainerLoserRow.fromJson(Map<String, dynamic> json) => GainerLoserRow(
        symbol: json['symbol'] as String? ?? '',
        priceChangePct: (json['price_change_pct'] as num?)?.toDouble(),
        lastClose: (json['last_close'] as num?)?.toDouble(),
        category: BuildupCategory.fromWire(json['category'] as String?),
      );
}

/// `gainers_losers` block — top movers up and down for the day.
class GainersLosers {
  final List<GainerLoserRow> gainers;
  final List<GainerLoserRow> losers;

  const GainersLosers({required this.gainers, required this.losers});

  static const GainersLosers empty = GainersLosers(gainers: [], losers: []);

  factory GainersLosers.fromJson(Map<String, dynamic> json) {
    List<GainerLoserRow> parse(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => GainerLoserRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
    return GainersLosers(gainers: parse('gainers'), losers: parse('losers'));
  }
}

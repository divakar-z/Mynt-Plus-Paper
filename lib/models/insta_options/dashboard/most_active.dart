import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';

/// Which "most active" list to show.
enum MostActiveBy {
  volume('Volume'),
  oiChange('OI Change');

  final String label;
  const MostActiveBy(this.label);
}

/// One row from `most_active.by_volume[]` or `.by_oi_change[]`. Fields absent
/// for a given list stay null: `volume` only on by_volume; `oiChangePct` /
/// `priceChangePct` / `category` only on by_oi_change.
class MostActiveRow {
  final String symbol;
  final int oi;
  final int? volume;
  final double? oiChangePct;
  final double? priceChangePct;
  final BuildupCategory? category;

  const MostActiveRow({
    required this.symbol,
    required this.oi,
    required this.volume,
    required this.oiChangePct,
    required this.priceChangePct,
    required this.category,
  });

  factory MostActiveRow.fromJson(Map<String, dynamic> json) => MostActiveRow(
        symbol: json['symbol'] as String? ?? '',
        oi: (json['oi'] as num?)?.toInt() ?? 0,
        volume: (json['volume'] as num?)?.toInt(),
        oiChangePct: (json['oi_change_pct'] as num?)?.toDouble(),
        priceChangePct: (json['price_change_pct'] as num?)?.toDouble(),
        category: json['category'] == null
            ? null
            : BuildupCategory.fromWire(json['category'] as String?),
      );
}

/// `most_active` block — top by futures volume and by |OI change|.
class MostActive {
  final List<MostActiveRow> byVolume;
  final List<MostActiveRow> byOiChange;

  const MostActive({required this.byVolume, required this.byOiChange});

  static const MostActive empty = MostActive(byVolume: [], byOiChange: []);

  List<MostActiveRow> rowsFor(MostActiveBy by) =>
      by == MostActiveBy.volume ? byVolume : byOiChange;

  factory MostActive.fromJson(Map<String, dynamic> json) {
    List<MostActiveRow> parse(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => MostActiveRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
    return MostActive(
      byVolume: parse('by_volume'),
      byOiChange: parse('by_oi_change'),
    );
  }
}

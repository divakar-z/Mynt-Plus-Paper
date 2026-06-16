import 'package:mynt_plus/models/insta_options/dashboard/dashboard_enums.dart';

/// One per-stock PCR row from `stock_pcr.bullish[]` / `stock_pcr.bearish[]`.
/// Grouped by the stock's buildup [category]. `pcr` nullable → render `—`.
class StockPcrRow {
  final String symbol;
  final double? pcr;
  final int peOi;
  final int ceOi;
  final BuildupCategory category;

  const StockPcrRow({
    required this.symbol,
    required this.pcr,
    required this.peOi,
    required this.ceOi,
    required this.category,
  });

  factory StockPcrRow.fromJson(Map<String, dynamic> json) => StockPcrRow(
        symbol: json['symbol'] as String? ?? '',
        pcr: (json['pcr'] as num?)?.toDouble(),
        peOi: (json['pe_oi'] as num?)?.toInt() ?? 0,
        ceOi: (json['ce_oi'] as num?)?.toInt() ?? 0,
        category: BuildupCategory.fromWire(json['category'] as String?),
      );
}

/// `stock_pcr` block — every F&O stock's PCR split into bullish / bearish by
/// buildup quadrant.
class StockPcr {
  final List<StockPcrRow> bullish;
  final List<StockPcrRow> bearish;

  const StockPcr({required this.bullish, required this.bearish});

  static const StockPcr empty = StockPcr(bullish: [], bearish: []);

  factory StockPcr.fromJson(Map<String, dynamic> json) {
    List<StockPcrRow> parse(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => StockPcrRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
    return StockPcr(bullish: parse('bullish'), bearish: parse('bearish'));
  }
}

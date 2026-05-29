import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/market_snapshot.dart';
import 'package:mynt_plus/models/insta_options/spot_timeseries_point.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// One index ticker tile in the Markets Dashboard top row (README §10.1).
///
/// Renders name + LTP + change% + a sparkline from `/spot/timeseries`. When
/// the quote is null or the sparkline is empty, falls back to placeholders so
/// the layout stays stable across loading / partial-data states.
class IndexTickerTile extends StatelessWidget {
  final String indexName;
  final IndexQuote? quote;
  final List<SpotTimeseriesPoint> bars;

  const IndexTickerTile({
    super.key,
    required this.indexName,
    required this.quote,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final changePct = quote?.changePct ?? 0;
    final tone = changePct == 0
        ? tokens.textSecondary
        : (changePct > 0 ? tokens.profit : tokens.loss);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            indexName,
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                InstaOptionsFormat.price(quote?.ltp),
                style: MyntWebTextStyles.title(
                  context,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                InstaOptionsFormat.changePct(changePct),
                style: MyntWebTextStyles.caption(
                  context,
                  color: tone,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: _Sparkline(bars: bars, color: tone),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<SpotTimeseriesPoint> bars;
  final Color color;

  const _Sparkline({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    if (bars.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    var lo = bars.first.close;
    var hi = bars.first.close;
    for (var i = 0; i < bars.length; i++) {
      final c = bars[i].close;
      spots.add(FlSpot(i.toDouble(), c));
      if (c < lo) lo = c;
      if (c > hi) hi = c;
    }
    final pad = (hi - lo) * 0.1;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (bars.length - 1).toDouble(),
        minY: lo - pad,
        maxY: hi + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 1.4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

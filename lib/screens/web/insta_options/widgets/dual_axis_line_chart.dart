import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/oi_timeseries_point.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';

/// Two `LineChart` widgets stacked with shared x range — workaround for
/// fl_chart's single-axis limitation. LTP (left axis) sits in back, OI
/// (right axis, with gradient fill) sits on top and owns hit-testing.
///
/// Spec: README §10.7 DualAxisLineChart.
class DualAxisLineChart extends StatelessWidget {
  final List<OiTimeseriesPoint> points;
  final Color oiColor;

  const DualAxisLineChart({
    super.key,
    required this.points,
    required this.oiColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No bars yet — backfill in progress',
          style: MyntWebTextStyles.body(
            context,
            color: tokens.textSecondary,
          ),
        ),
      );
    }

    final ltpSpots = <FlSpot>[];
    final oiSpots = <FlSpot>[];
    double ltpMin = double.infinity;
    double ltpMax = -double.infinity;
    double oiMin = double.infinity;
    double oiMax = -double.infinity;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      ltpSpots.add(FlSpot(i.toDouble(), p.close));
      oiSpots.add(FlSpot(i.toDouble(), p.oi.toDouble()));
      if (p.close < ltpMin) ltpMin = p.close;
      if (p.close > ltpMax) ltpMax = p.close;
      if (p.oi < oiMin) oiMin = p.oi.toDouble();
      if (p.oi > oiMax) oiMax = p.oi.toDouble();
    }
    if (ltpMin == ltpMax) {
      ltpMin -= 1;
      ltpMax += 1;
    }
    if (oiMin == oiMax) {
      oiMin -= 1;
      oiMax += 1;
    }

    final maxX = (points.length - 1).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        // LTP behind, left axis labels.
        LineChart(
          LineChartData(
            minY: ltpMin,
            maxY: ltpMax,
            minX: 0,
            maxX: maxX,
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: (ltpMax - ltpMin) / 4,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      v.toStringAsFixed(1),
                      style: MyntWebTextStyles.caption(
                        context,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: ltpSpots,
                color: tokens.textPrimary,
                barWidth: 2,
                isCurved: false,
                dotData: const FlDotData(show: false),
              ),
            ],
            lineTouchData: const LineTouchData(enabled: false),
          ),
        ),
        // OI on top, right axis labels + tooltip + gradient fill below.
        LineChart(
          LineChartData(
            minY: oiMin,
            maxY: oiMax,
            minX: 0,
            maxX: maxX,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (oiMax - oiMin) / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: tokens.border.withValues(alpha: 0.3),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false, reservedSize: 40),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  interval: (oiMax - oiMin) / 4,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      InstaOptionsFormat.oi(v),
                      style: MyntWebTextStyles.caption(
                        context,
                        color: oiColor,
                      ),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: _xTickInterval(points.length),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        InstaOptionsFormat.time(points[i].time),
                        style: MyntWebTextStyles.caption(
                          context,
                          color: tokens.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: oiSpots,
                color: oiColor,
                barWidth: 2,
                isCurved: false,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      oiColor.withValues(alpha: 0.35),
                      oiColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => tokens.bgTertiary,
                tooltipBorder: BorderSide(color: tokens.border),
                getTooltipItems: (touched) {
                  if (touched.isEmpty) return [];
                  final i = touched.first.x.toInt();
                  if (i < 0 || i >= points.length) return [];
                  final p = points[i];
                  return [
                    LineTooltipItem(
                      '${InstaOptionsFormat.time(p.time)}  ·  LTP ${p.close.toStringAsFixed(2)}  ·  OI ${InstaOptionsFormat.oi(p.oi)}',
                      MyntWebTextStyles.caption(
                        context,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ];
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _xTickInterval(int count) {
    // ~30-min ticks given 1-min buckets.
    if (count <= 30) return 5;
    if (count <= 90) return 15;
    return 30;
  }
}

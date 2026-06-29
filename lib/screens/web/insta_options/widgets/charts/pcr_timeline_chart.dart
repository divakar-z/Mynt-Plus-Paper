import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/charts/pcr_timeline.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Intraday chain-wide PCR as a zoomable time-series line, with bearish (< 0.70)
/// / neutral / bullish (> 1.30) reference zones. Mouse-wheel / pinch zoom + pan
/// along time; the hover tooltip surfaces the CE/PE OI totals behind each PCR
/// bucket.
class PcrTimelineChart extends StatelessWidget {
  final PcrTimeline data;

  const PcrTimelineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final pts = data.points
        .where((p) => p.t != null && p.pcr != null)
        .toList(growable: false);

    final line = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final axisText = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final grid = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final threshold = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);

    // Pad the Y range so the 0.70 / 1.30 reference lines are always on-screen,
    // even on a quiet day where PCR barely moves around 1.0.
    var lo = 0.7, hi = 1.3;
    for (final p in pts) {
      if (p.pcr! < lo) lo = p.pcr!;
      if (p.pcr! > hi) hi = p.pcr!;
    }
    final yMin = (lo - 0.1).clamp(0.0, double.infinity).toDouble();
    final yMax = hi + 0.1;

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(2, 6, 10, 0),
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat.Hm(),
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0.5, color: grid),
        majorTickLines: const MajorTickLines(size: 0),
      ),
      primaryYAxis: NumericAxis(
        minimum: yMin,
        maximum: yMax,
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: MajorGridLines(width: 0.5, color: grid),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        axisLabelFormatter: (AxisLabelRenderDetails d) =>
            ChartAxisLabel(d.value.toStringAsFixed(2), d.textStyle),
        plotBands: <PlotBand>[
          // Bearish / bullish zone tints.
          PlotBand(
              isVisible: true,
              start: yMin,
              end: 0.7,
              color: loss.withValues(alpha: 0.05)),
          PlotBand(
              isVisible: true,
              start: 1.3,
              end: yMax,
              color: profit.withValues(alpha: 0.05)),
          // Threshold lines.
          _refLine(0.7, threshold),
          _refLine(1.3, threshold),
          PlotBand(
              isVisible: true,
              start: 1.0,
              end: 1.0,
              borderColor: threshold.withValues(alpha: 0.5),
              borderWidth: 0.5,
              dashArray: const <double>[3, 4]),
        ],
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
        zoomMode: ZoomMode.x,
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.textPrimary),
        builder: (data, point, series, pointIndex, seriesIndex) =>
            _tooltip(context, data as PcrPoint),
      ),
      series: <CartesianSeries<PcrPoint, DateTime>>[
        LineSeries<PcrPoint, DateTime>(
          dataSource: pts,
          xValueMapper: (p, _) => p.t!,
          yValueMapper: (p, _) => p.pcr,
          name: 'PCR',
          color: line,
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            height: 4,
            width: 4,
            color: line,
            borderWidth: 0,
          ),
        ),
      ],
    );
  }

  PlotBand _refLine(double y, Color color) => PlotBand(
        isVisible: true,
        start: y,
        end: y,
        borderColor: color,
        borderWidth: 1,
        dashArray: const <double>[5, 4],
      );

  Widget _tooltip(BuildContext context, PcrPoint p) {
    final pcrColor = p.pcr == null
        ? Colors.white
        : (p.pcr! <= 0.7
            ? const Color(0xFFFF6B6B)
            : (p.pcr! > 1.3 ? const Color(0xFF4ADE80) : Colors.white));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.textPrimary),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(InstaOptionsFormat.time(p.t),
              style: MyntWebTextStyles.caption(context, color: Colors.white)
                  .copyWith(fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 2),
          Text('PCR ${InstaOptionsFormat.pcr(p.pcr)}',
              style: MyntWebTextStyles.caption(context, color: pcrColor)
                  .copyWith(fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 1),
          Text(
            'CE ${InstaOptionsFormat.oi(p.totalCeOi)}   '
            'PE ${InstaOptionsFormat.oi(p.totalPeOi)}',
            style: MyntWebTextStyles.caption(context,
                color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

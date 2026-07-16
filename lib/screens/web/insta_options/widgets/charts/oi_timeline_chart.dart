import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Calls = greens, Puts = reds. The leg is read from the hue family at a glance;
/// the strike is the shade within the family (keyed by its position in the
/// sorted selected-strike list, so the legend and lines always agree).
const List<Color> _kCallPalette = <Color>[
  Color(0xFF16A34A), // green
  Color(0xFF0D9488), // teal
  Color(0xFF15803D), // dark green
  Color(0xFF059669), // emerald
  Color(0xFF4D7C0F), // olive
  Color(0xFF14B8A6), // light teal
  Color(0xFF65A30D), // lime
  Color(0xFF047857), // deep emerald
  Color(0xFF22C55E), // bright green
  Color(0xFF0EA5A0), // cyan-teal
];
const List<Color> _kPutPalette = <Color>[
  Color(0xFFDC2626), // red
  Color(0xFFEA580C), // orange
  Color(0xFFDB2777), // pink
  Color(0xFFE11D48), // rose
  Color(0xFFB91C1C), // dark red
  Color(0xFFF97316), // amber-orange
  Color(0xFFBE123C), // crimson
  Color(0xFFEF4444), // light red
  Color(0xFFC026D3), // fuchsia
  Color(0xFFF43F5E), // bright rose
];

/// Stable line colour for a (strike, leg): Calls draw from the green family,
/// Puts from the red family, both indexed by the strike's slot in
/// [orderedStrikes].
Color oiLegColor(List<double> orderedStrikes, double strike, bool isCall) {
  final i = orderedStrikes.indexOf(strike);
  final palette = isCall ? _kCallPalette : _kPutPalette;
  if (i < 0) return palette.first;
  return palette[i % palette.length];
}

/// Intraday OI per selected (strike, leg) as a zoomable multi-line chart, with
/// an optional spot/future price overlay on a second (left) axis. OI lives on
/// the right axis; Calls are greens, Puts are reds; the price line is a neutral
/// high-contrast stroke. Mouse-wheel / pinch zoom + pan along time.
class OiTimelineChart extends StatelessWidget {
  final List<OiSeries> series; // already leg-filtered by the caller
  final List<double> orderedStrikes;
  final List<PriceTick> priceLine; // the resolved spot/future line (or empty)
  final bool showPrice;
  final String priceLabel; // 'Spot' | 'Future'
  final String underlyingLabel;

  const OiTimelineChart({
    super.key,
    required this.series,
    required this.orderedStrikes,
    this.priceLine = const [],
    this.showPrice = false,
    this.priceLabel = 'Spot',
    this.underlyingLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final axisText = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final grid = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final priceColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final pricePts = !showPrice
        ? const <PriceTick>[]
        : priceLine
            .where((p) => p.t != null && p.ltp != null)
            .toList(growable: false);
    final hasPrice = pricePts.isNotEmpty;

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(2, 6, 6, 0),
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat.Hm(),
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0.5, color: grid),
        majorTickLines: const MajorTickLines(size: 0),
      ),
      // OI axis — on the right when a price axis shares the chart, else left.
      primaryYAxis: NumericAxis(
        name: 'oi',
        opposedPosition: hasPrice,
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: MajorGridLines(width: 0.5, color: grid),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        title: AxisTitle(
            text: 'Open Interest',
            textStyle: MyntWebTextStyles.body(context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.medium)),
        axisLabelFormatter: (AxisLabelRenderDetails d) =>
            ChartAxisLabel(InstaOptionsFormat.oi(d.value), d.textStyle),
      ),
      axes: hasPrice
          ? <ChartAxis>[
              NumericAxis(
                name: 'price',
                opposedPosition: false,
                rangePadding: ChartRangePadding.additional,
                labelStyle: MyntWebTextStyles.caption(context, color: axisText),
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                title: AxisTitle(
                    text: underlyingLabel.isEmpty ? priceLabel : underlyingLabel,
                    textStyle: MyntWebTextStyles.body(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium)),
                axisLabelFormatter: (AxisLabelRenderDetails d) =>
                    ChartAxisLabel(InstaOptionsFormat.price(d.value), d.textStyle),
              ),
            ]
          : const <ChartAxis>[],
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
        builder: (data, point, s, pointIndex, seriesIndex) =>
            _tooltip(context, data, s.name ?? ''),
      ),
      series: <CartesianSeries>[
        for (final leg in series)
          LineSeries<OiTimePoint, DateTime>(
            dataSource:
                leg.points.where((p) => p.t != null).toList(growable: false),
            xValueMapper: (p, _) => p.t!,
            yValueMapper: (p, _) => p.oi?.toDouble(),
            name: '${leg.strike.toInt()} ${leg.optType}',
            yAxisName: 'oi',
            color: oiLegColor(orderedStrikes, leg.strike, leg.optType == 'CE'),
            width: 2,
            // No per-point markers — at fine intervals (1m ≈ 375 points) the
            // dots swamp the line and it reads as scattered specks. A clean
            // solid stroke stays legible at any interval.
            markerSettings: const MarkerSettings(isVisible: false),
            // No draw-in/morph animation on load or when the strikes /
            // leg / interval selection swaps the data.
            animationDuration: 0,
          ),
        if (hasPrice)
          LineSeries<PriceTick, DateTime>(
            dataSource: pricePts,
            xValueMapper: (p, _) => p.t!,
            yValueMapper: (p, _) => p.ltp,
            name: priceLabel,
            yAxisName: 'price',
            color: priceColor,
            width: 2.2,
            dashArray: const <double>[6, 3],
            markerSettings: const MarkerSettings(isVisible: false),
            animationDuration: 0,
          ),
      ],
    );
  }

  Widget _tooltip(BuildContext context, dynamic data, String seriesName) {
    String line2;
    DateTime? t;
    if (data is PriceTick) {
      t = data.t;
      line2 = InstaOptionsFormat.price(data.ltp) +
          (data.oi == null ? '' : '   OI ${InstaOptionsFormat.oi(data.oi)}');
    } else if (data is OiTimePoint) {
      t = data.t;
      line2 = 'OI ${InstaOptionsFormat.oi(data.oi)}'
          '${data.ltp == null ? '' : '   LTP ${InstaOptionsFormat.price(data.ltp)}'}';
    } else {
      line2 = '';
    }
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
          Text('$seriesName · ${InstaOptionsFormat.time(t)}',
              style: MyntWebTextStyles.caption(context, color: Colors.white)
                  .copyWith(fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 1),
          Text(line2,
              style: MyntWebTextStyles.caption(context,
                  color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

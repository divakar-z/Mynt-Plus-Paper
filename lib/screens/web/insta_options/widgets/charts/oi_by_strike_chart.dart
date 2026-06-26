import 'package:flutter/material.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_by_strike.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

enum OiChartMode { oi, change }

/// Per-strike CE/PE open interest (or its day change) as a zoomable vertical
/// column chart — CE green / PE red, evenly-spaced bars (strikes are indexed,
/// so the irregular far-OTM gaps don't distort them), a dashed spot line at the
/// true spot, mouse-wheel / pinch zoom + pan, and a compact hover tooltip. The
/// default view is zoomed to the strikes around the spot.
class OiByStrikeChart extends StatelessWidget {
  final OiByStrike data;
  final OiChartMode mode;

  const OiByStrikeChart({super.key, required this.data, required this.mode});

  bool get _isChange => mode == OiChartMode.change;

  @override
  Widget build(BuildContext context) {
    final rows = data.rows;
    final n = rows.length;
    final ceColor = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit); // CE = green
    final peColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss); // PE = red
    final axisText = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final grid = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final spotColor = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    final spot = data.underlyingValue ?? data.atmStrike;

    // ATM index anchors the default zoom; the spot sits at a fractional index.
    var atmIdx = rows.indexWhere((r) => r.isAtm);
    if (atmIdx < 0 && spot != null && n > 0) atmIdx = _nearest(rows, spot);

    const window = 12; // ± strikes shown by default; zoom out for the rest.
    double? visMin, visMax;
    if (n > window * 2 + 1 && atmIdx >= 0) {
      visMin = (atmIdx - window).clamp(0, n - 1).toDouble();
      visMax = (atmIdx + window).clamp(0, n - 1).toDouble();
    }

    final spotIdx = (spot != null && n > 1) ? _spotIndex(rows, spot) : null;

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(2, 6, 10, 0),
      plotAreaBorderWidth: 0,
      primaryXAxis: NumericAxis(
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(width: 0.5, color: grid),
        majorTickLines: const MajorTickLines(size: 0),
        minimum: -0.6,
        maximum: n - 0.4,
        interval: 3,
        initialVisibleMinimum: visMin,
        initialVisibleMaximum: visMax,
        axisLabelFormatter: (AxisLabelRenderDetails d) {
          final i = d.value.round();
          final label = (i < 0 || i >= n) ? '' : rows[i].strike.toInt().toString();
          return ChartAxisLabel(label, d.textStyle);
        },
        plotBands: spotIdx == null
            ? const <PlotBand>[]
            : <PlotBand>[
                PlotBand(
                  isVisible: true,
                  start: spotIdx,
                  end: spotIdx,
                  borderColor: spotColor,
                  borderWidth: 1.5,
                  dashArray: const <double>[5, 4],
                  shouldRenderAboveSeries: true,
                ),
              ],
      ),
      primaryYAxis: NumericAxis(
        labelStyle: MyntWebTextStyles.caption(context, color: axisText),
        majorGridLines: MajorGridLines(width: 0.5, color: grid),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        axisLabelFormatter: (AxisLabelRenderDetails d) =>
            ChartAxisLabel(InstaOptionsFormat.oi(d.value), d.textStyle),
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
            _tooltip(context, data as OiStrikeRow, series.name ?? ''),
      ),
      series: <CartesianSeries<OiStrikeRow, num>>[
        ColumnSeries<OiStrikeRow, num>(
          dataSource: rows,
          xValueMapper: (r, idx) => idx,
          yValueMapper: (r, _) =>
              (_isChange ? r.ceOiChange : r.ceOi).toDouble(),
          name: 'CE OI',
          color: ceColor,
          width: 0.82,
          spacing: 0.12,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
        ColumnSeries<OiStrikeRow, num>(
          dataSource: rows,
          xValueMapper: (r, idx) => idx,
          yValueMapper: (r, _) =>
              (_isChange ? r.peOiChange : r.peOi).toDouble(),
          name: 'PE OI',
          color: peColor,
          width: 0.82,
          spacing: 0.12,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ],
    );
  }

  Widget _tooltip(BuildContext context, OiStrikeRow r, String seriesName) {
    final isCe = seriesName.startsWith('CE');
    final val = _isChange
        ? (isCe ? r.ceOiChange : r.peOiChange)
        : (isCe ? r.ceOi : r.peOi);
    final pct = isCe ? r.ceOiChangePct : r.peOiChangePct;
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
          Text('${r.strike.toStringAsFixed(0)} · $seriesName',
              style: MyntWebTextStyles.caption(context, color: Colors.white)
                  .copyWith(fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 1),
          Text(
            '${_isChange ? 'Δ ' : ''}${InstaOptionsFormat.oi(val)}'
            '${pct == null ? '' : '  (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)'}',
            style: MyntWebTextStyles.caption(context,
                color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  int _nearest(List<OiStrikeRow> rows, double v) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < rows.length; i++) {
      final dd = (rows[i].strike - v).abs();
      if (dd < bestD) {
        bestD = dd;
        best = i;
      }
    }
    return best;
  }

  /// Fractional index of [spot] between the two strikes that bracket it, so the
  /// spot line lands at its true position (not snapped to a strike).
  double _spotIndex(List<OiStrikeRow> rows, double spot) {
    for (var i = 0; i < rows.length - 1; i++) {
      if (spot >= rows[i].strike && spot <= rows[i + 1].strike) {
        final span = rows[i + 1].strike - rows[i].strike;
        return span <= 0 ? i.toDouble() : i + (spot - rows[i].strike) / span;
      }
    }
    return spot < rows.first.strike ? 0 : (rows.length - 1).toDouble();
  }
}

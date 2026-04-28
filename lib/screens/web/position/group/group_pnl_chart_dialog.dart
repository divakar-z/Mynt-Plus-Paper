import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../models/portfolio_model/group_pnl_chart_model.dart';
import '../../../../provider/group_pnl_chart_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';

final _numFmt = NumberFormat("##,##,##,##,##0.00", "hi");
final _timeFmt = DateFormat('HH:mm');

void showGroupPnlChartDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String groupName,
  required List groupList,
}) {
  final portfolio = ref.read(portfolioProvider);

  // Initial load with 5-min interval
  ref.read(groupPnlChartProvider).loadGroupChart(
        groupName: groupName,
        groupList: groupList,
        isDay: portfolio.isDay,
        isNetPnl: portfolio.isNetPnl,
      );

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: resolveThemeColor(
      context,
      dark: MyntColors.modalBarrierDark,
      light: MyntColors.modalBarrierLight,
    ),
    builder: (_) => _GroupPnlChartDialog(
      groupName: groupName,
      groupList: groupList,
    ),
  );
}

class _GroupPnlChartDialog extends ConsumerStatefulWidget {
  final String groupName;
  final List groupList;

  const _GroupPnlChartDialog({
    required this.groupName,
    required this.groupList,
  });

  @override
  ConsumerState<_GroupPnlChartDialog> createState() =>
      _GroupPnlChartDialogState();
}

class _GroupPnlChartDialogState extends ConsumerState<_GroupPnlChartDialog> {
  String get groupName => widget.groupName;
  List get groupList => widget.groupList;

  @override
  void dispose() {
    ref.read(groupPnlChartProvider).markDialogClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chartProv = ref.watch(groupPnlChartProvider);
    final portfolio = ref.watch(portfolioProvider);

    final bgColor = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(context, ref, chartProv, portfolio),
              Divider(
                height: 1,
                thickness: 1,
                color: resolveThemeColor(context,
                    dark: MyntColors.dividerDark, light: MyntColors.divider),
              ),
              // Body
              Expanded(
                child: chartProv.loading
                    ? const Center(child: CircularProgressIndicator())
                    : chartProv.error != null
                        ? _buildError(context, chartProv.error!)
                        : chartProv.dataPoints.isEmpty
                            ? _buildEmpty(context)
                            : _buildCharts(context, chartProv, portfolio),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref,
      GroupPnlChartProvider chartProv, PortfolioProvider portfolio) {
    final secColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Group name
          Expanded(
            child: Text(
              '$groupName — ${portfolio.isNetPnl ? "P&L" : "MTM"} Chart',
              style: MyntWebTextStyles.title(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
          ),
          // Interval toggle
          _IntervalChip(
            label: '5m',
            selected: chartProv.interval == '5',
            onTap: () => _onIntervalSwitch(ref, '5', portfolio),
          ),
          const SizedBox(width: 6),
          _IntervalChip(
            label: '1m',
            selected: chartProv.interval == '1',
            onTap: () => _onIntervalSwitch(ref, '1', portfolio),
          ),
          const SizedBox(width: 12),
          // Close
          IconButton(
            icon: Icon(Icons.close, size: 20, color: secColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onIntervalSwitch(
      WidgetRef ref, String interval, PortfolioProvider portfolio) {
    ref.read(groupPnlChartProvider).switchInterval(
          newInterval: interval,
          isDay: portfolio.isDay,
          isNetPnl: portfolio.isNetPnl,
        );
  }

  Widget _buildError(BuildContext context, String msg) {
    return Center(
      child: Text(
        msg,
        style: MyntWebTextStyles.body(
          context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Text(
        'No chart data available',
        style: MyntWebTextStyles.body(
          context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCharts(BuildContext context, GroupPnlChartProvider chartProv,
      PortfolioProvider portfolio) {
    final data = chartProv.dataPoints;
    final label = portfolio.isNetPnl ? 'P&L' : 'MTM';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // P&L summary row
          _buildSummaryRow(context, chartProv, data, label),
          const SizedBox(height: 12),
          // P&L Chart
          Expanded(
            flex: 3,
            child: _PnlChart(data: data, label: label),
          ),
          const SizedBox(height: 16),
          // Drawdown Chart
          Expanded(
            flex: 2,
            child: _DrawdownChart(data: data),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context,
      GroupPnlChartProvider chartProv, List<GroupPnlDataPoint> data, String label) {
    if (data.isEmpty) return const SizedBox.shrink();
    final current = chartProv.currentPnl;
    final peak = chartProv.peak;
    final dd = chartProv.drawdown;

    Color pnlColor(double v) {
      if (v > 0) {
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      } else if (v < 0) {
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      }
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }

    return Row(
      children: [
        _SummaryItem(
            title: 'Current $label',
            value: _numFmt.format(current),
            color: pnlColor(current)),
        const SizedBox(width: 24),
        _SummaryItem(
            title: 'Peak',
            value: _numFmt.format(peak),
            color: pnlColor(peak)),
        const SizedBox(width: 24),
        _SummaryItem(
            title: 'Drawdown',
            value: _numFmt.format(dd),
            color: pnlColor(dd)),
      ],
    );
  }
}

// ─── P&L Chart ──────────────────────────────────────────────

class _PnlChart extends StatelessWidget {
  final List<GroupPnlDataPoint> data;
  final String label;

  const _PnlChart({required this.data, required this.label});

  @override
  Widget build(BuildContext context) {
    final profitColor = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final gridColor = resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider)
        .withValues(alpha: 0.5);
    final axisLabelColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final trackballLineColor = resolveThemeColor(context,
        dark: const Color(0xFF9CA3AF), light: const Color(0xFF6B7280));

    // Compute Y-axis range: auto-scale to data with padding, always include 0
    final pnlValues = data.map((d) => d.pnl).toList();
    final dataMin = pnlValues.reduce(math.min);
    final dataMax = pnlValues.reduce(math.max);
    final rangeMin = math.min(dataMin, 0.0);
    final rangeMax = math.max(dataMax, 0.0);
    final span = rangeMax - rangeMin;
    final padding = span == 0 ? 100.0 : span * 0.1;

    final axisLabelStyle = TextStyle(
      fontFamily: MyntFonts.fontFamily,
      fontSize: MyntFonts.caption,
      fontWeight: MyntFonts.regular,
      color: axisLabelColor,
    );

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(right: 8),
      primaryXAxis: DateTimeAxis(
        majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
        axisLine: const AxisLine(width: 0),
        labelStyle: axisLabelStyle,
        dateFormat: _timeFmt,
        intervalType: DateTimeIntervalType.minutes,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
        axisLine: const AxisLine(width: 0),
        labelStyle: axisLabelStyle,
        numberFormat: _numFmt,
        minimum: rangeMin - padding,
        maximum: rangeMax + padding,
        plotBands: <PlotBand>[
          PlotBand(
            start: 0,
            end: 0,
            borderWidth: 1,
            borderColor: axisLabelColor.withValues(alpha: 0.6),
            dashArray: const <double>[4, 4],
          ),
        ],
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        shouldAlwaysShow: true,
        canShowMarker: true,
        header: '',
        format: '$label: point.y',
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
        borderColor: resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider),
        borderWidth: 1,
        textStyle: TextStyle(
          fontFamily: MyntFonts.fontFamily,
          fontSize: MyntFonts.para,
          fontWeight: MyntFonts.medium,
          color: resolveThemeColor(context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary),
        ),
      ),
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: CrosshairLineType.vertical,
        lineColor: trackballLineColor,
        lineDashArray: const <double>[4, 4],
        lineWidth: 1,
        shouldAlwaysShow: true,
      ),
      series: <CartesianSeries>[
        // Green area: profit region (P&L > 0, fills between 0 and P&L)
        RangeAreaSeries<GroupPnlDataPoint, DateTime>(
          dataSource: data,
          xValueMapper: (d, _) => d.time,
          highValueMapper: (d, _) => d.pnl > 0 ? d.pnl : 0,
          lowValueMapper: (d, _) => 0,
          name: '$label (Profit)',
          color: profitColor.withValues(alpha: 0.1),
          borderColor: Colors.transparent,
          enableTooltip: false,
        ),
        // Red area: loss region (P&L < 0, fills between P&L and 0)
        RangeAreaSeries<GroupPnlDataPoint, DateTime>(
          dataSource: data,
          xValueMapper: (d, _) => d.time,
          highValueMapper: (d, _) => 0,
          lowValueMapper: (d, _) => d.pnl < 0 ? d.pnl : 0,
          name: '$label (Loss)',
          color: lossColor.withValues(alpha: 0.1),
          borderColor: Colors.transparent,
          enableTooltip: false,
        ),
        // P&L line — green in profit, red in loss
        LineSeries<GroupPnlDataPoint, DateTime>(
          dataSource: data,
          xValueMapper: (d, _) => d.time,
          yValueMapper: (d, _) => d.pnl,
          name: label,
          enableTooltip: true,
          width: 1.5,
          pointColorMapper: (d, _) =>
              d.pnl >= 0 ? profitColor : lossColor,
          markerSettings: const MarkerSettings(isVisible: false),
        ),
      ],
    );
  }
}

// ─── Drawdown Chart ──────────────────────────────────────────

class _DrawdownChart extends StatelessWidget {
  final List<GroupPnlDataPoint> data;

  const _DrawdownChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final lossColor = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final gridColor = resolveThemeColor(context,
            dark: MyntColors.dividerDark, light: MyntColors.divider)
        .withValues(alpha: 0.5);
    final axisLabelColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final trackballLineColor = resolveThemeColor(context,
        dark: const Color(0xFF9CA3AF), light: const Color(0xFF6B7280));

    final axisLabelStyle = TextStyle(
      fontFamily: MyntFonts.fontFamily,
      fontSize: MyntFonts.caption,
      fontWeight: MyntFonts.regular,
      color: axisLabelColor,
    );

    // Compute Y-axis range for drawdown
    final ddValues = data.map((d) => d.drawdown).toList();
    final ddMin = ddValues.reduce(math.min);
    // If all drawdown is 0, show a small range so it's not empty
    final yMin = ddMin == 0 ? -100.0 : ddMin * 1.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drawdown',
          style: MyntWebTextStyles.body(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            margin: const EdgeInsets.only(right: 8),
            primaryXAxis: DateTimeAxis(
              majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
              axisLine: const AxisLine(width: 0),
              labelStyle: axisLabelStyle,
              dateFormat: _timeFmt,
              intervalType: DateTimeIntervalType.minutes,
              edgeLabelPlacement: EdgeLabelPlacement.shift,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
              axisLine: const AxisLine(width: 0),
              labelStyle: axisLabelStyle,
              numberFormat: _numFmt,
              maximum: 0,
              minimum: yMin,
              plotBands: <PlotBand>[
                PlotBand(
                  start: 0,
                  end: 0,
                  borderWidth: 1,
                  borderColor: axisLabelColor.withValues(alpha: 0.4),
                ),
              ],
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
              shouldAlwaysShow: true,
              canShowMarker: true,
              header: '',
              format: 'DD: point.y',
              color: resolveThemeColor(context,
                  dark: MyntColors.cardDark, light: MyntColors.card),
              borderColor: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
              borderWidth: 1,
              textStyle: TextStyle(
                fontFamily: MyntFonts.fontFamily,
                fontSize: MyntFonts.para,
                fontWeight: MyntFonts.medium,
                color: lossColor,
              ),
            ),
            crosshairBehavior: CrosshairBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
              lineType: CrosshairLineType.vertical,
              lineColor: trackballLineColor,
              lineDashArray: const <double>[4, 4],
              lineWidth: 1,
              shouldAlwaysShow: true,
            ),
            series: <CartesianSeries>[
              AreaSeries<GroupPnlDataPoint, DateTime>(
                dataSource: data,
                xValueMapper: (d, _) => d.time,
                yValueMapper: (d, _) => d.drawdown,
                name: 'Drawdown',
                enableTooltip: true,
                color: lossColor.withValues(alpha: 0.15),
                borderColor: lossColor,
                borderWidth: 1.5,
                markerSettings: const MarkerSettings(
                  isVisible: false,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final inactiveBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final activeFg = Colors.white;
    final inactiveFg = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? activeBg : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MyntFonts.fontFamily,
            fontSize: MyntFonts.para,
            fontWeight: MyntFonts.medium,
            color: selected ? activeFg : inactiveFg,
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MyntWebTextStyles.caption(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
            fontWeight: MyntFonts.medium,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: MyntWebTextStyles.body(
            context,
            color: color,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
      ],
    );
  }
}

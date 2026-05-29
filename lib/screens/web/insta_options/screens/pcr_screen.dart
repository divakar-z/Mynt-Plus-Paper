import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/pcr_point.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_pcr_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/bucket_minutes_selector.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/kpi_card.dart';

/// PCR Ratio screen (README §10.6). Chain-level PCR over time + spot overlay.
class PcrScreen extends ConsumerStatefulWidget {
  const PcrScreen({super.key});

  @override
  ConsumerState<PcrScreen> createState() => _PcrScreenState();
}

class _PcrScreenState extends ConsumerState<PcrScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsPcrProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsPcrProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final pcr = ref.watch(instaOptionsPcrProvider);

    if (selection.expiry.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load PCR.',
        tokens: tokens,
      );
    }
    if (pcr.loading && pcr.points.isEmpty) {
      return Container(
        color: tokens.bgPrimary,
        child: Center(child: CircularProgressIndicator(color: tokens.accent)),
      );
    }
    if (pcr.error != null && pcr.points.isEmpty) {
      return _ErrorState(
        message: pcr.error!,
        tokens: tokens,
        onRetry: pcr.refresh,
      );
    }
    if (pcr.points.isEmpty) {
      return _EmptyState(
        icon: Icons.show_chart,
        title: 'No PCR data yet',
        message: 'PCR series will appear once the aggregator runs.',
        tokens: tokens,
      );
    }

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ControlsBar(pcr: pcr, tokens: tokens),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: _KpiRow(pcr: pcr),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.bgSecondary,
                  border: Border.all(color: tokens.border, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(24),
                child: _PcrChart(tokens: tokens, points: pcr.points),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsBar extends StatelessWidget {
  final InstaOptionsPcrProvider pcr;
  final InstaOptionsTokens tokens;

  const _ControlsBar({required this.pcr, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          BucketMinutesSelector(
            value: pcr.bucketMinutes,
            options: InstaOptionsPcrProvider.bucketMinutesOptions,
            onChanged: pcr.setBucketMinutes,
            tokens: tokens,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: pcr.loading ? null : pcr.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final InstaOptionsPcrProvider pcr;
  const _KpiRow({required this.pcr});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'Current PCR',
            value: InstaOptionsFormat.pcr(pcr.currentPcr),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiCard(
            label: 'Day High',
            value: InstaOptionsFormat.pcr(pcr.dayHigh),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiCard(
            label: 'Day Low',
            value: InstaOptionsFormat.pcr(pcr.dayLow),
          ),
        ),
      ],
    );
  }
}

class _PcrChart extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final List<PcrPoint> points;

  const _PcrChart({required this.tokens, required this.points});

  @override
  Widget build(BuildContext context) {
    final pcrSpots = <FlSpot>[];
    final spotSpots = <FlSpot>[];
    double pcrMin = double.infinity;
    double pcrMax = -double.infinity;
    double spotMin = double.infinity;
    double spotMax = -double.infinity;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      pcrSpots.add(FlSpot(i.toDouble(), p.pcr));
      spotSpots.add(FlSpot(i.toDouble(), p.spot));
      if (p.pcr < pcrMin) pcrMin = p.pcr;
      if (p.pcr > pcrMax) pcrMax = p.pcr;
      if (p.spot < spotMin) spotMin = p.spot;
      if (p.spot > spotMax) spotMax = p.spot;
    }
    // PCR axis: clamp to spec floor 0.5 / ceiling 1.5 unless data exceeds.
    final pcrYMin = pcrMin < 0.5 ? pcrMin - 0.05 : 0.5;
    final pcrYMax = pcrMax > 1.5 ? pcrMax + 0.05 : 1.5;
    // Project spot onto PCR axis so both fit in fl_chart's single y-axis.
    final spotRange = (spotMax - spotMin).abs();
    final pcrRange = pcrYMax - pcrYMin;
    final spotScale = spotRange == 0 ? 1.0 : pcrRange / spotRange;
    final scaledSpotSpots = spotSpots
        .map((s) => FlSpot(s.x, pcrYMin + (s.y - spotMin) * spotScale))
        .toList(growable: false);

    final lastPcr = points.last.pcr;
    final pcrColor = lastPcr > 1.0
        ? tokens.profit
        : (lastPcr < 0.7 ? tokens.loss : tokens.textSecondary);

    return LineChart(
      LineChartData(
        minY: pcrYMin,
        maxY: pcrYMax,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: tokens.border.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: (pcrYMax - pcrYMin) / 4,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  v.toStringAsFixed(2),
                  style: MyntWebTextStyles.caption(
                    context,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: (pcrYMax - pcrYMin) / 4,
              getTitlesWidget: (v, _) {
                if (spotRange == 0) return const SizedBox.shrink();
                final spotVal = spotMin + (v - pcrYMin) / spotScale;
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    spotVal.toStringAsFixed(0),
                    style: MyntWebTextStyles.caption(
                      context,
                      color: tokens.accent,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 6).clamp(1, points.length).toDouble(),
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
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 1.0,
              color: tokens.textMuted.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: const [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textMuted,
                ),
                labelResolver: (_) => '1.00',
              ),
            ),
            HorizontalLine(
              y: 0.7,
              color: tokens.textMuted.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: const [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textMuted,
                ),
                labelResolver: (_) => '0.70',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: pcrSpots,
            color: pcrColor,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: scaledSpotSpots,
            color: tokens.accent.withValues(alpha: 0.7),
            barWidth: 1.5,
            isCurved: false,
            dotData: const FlDotData(show: false),
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
                  '${InstaOptionsFormat.time(p.time)}  ·  PCR ${InstaOptionsFormat.pcr(p.pcr)}  ·  Spot ${p.spot.toStringAsFixed(2)}',
                  MyntWebTextStyles.caption(
                    context,
                    color: tokens.textPrimary,
                  ),
                ),
                // Hide the second tooltip for the spot series.
                const LineTooltipItem('', TextStyle()),
              ];
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final InstaOptionsTokens tokens;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.tokens,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bgPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.loss.withValues(alpha: 0.1),
            border: Border.all(color: tokens.loss, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: tokens.loss, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Failed to load PCR',
                    style: MyntWebTextStyles.body(
                      context,
                      color: tokens.loss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final InstaOptionsTokens tokens;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: MyntWebTextStyles.head(context, color: tokens.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: MyntWebTextStyles.body(
                context,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

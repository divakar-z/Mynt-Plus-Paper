import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/trending_bucket.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_chain_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_trending_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/bucket_minutes_selector.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/strike_multi_picker.dart';

/// Trending OI screen (README §10.5). Sentiment + cumulative OI charts side
/// by side over a top half, per-bucket DataTable2 underneath.
class TrendingOiScreen extends ConsumerStatefulWidget {
  const TrendingOiScreen({super.key});

  @override
  ConsumerState<TrendingOiScreen> createState() => _TrendingOiScreenState();
}

class _TrendingOiScreenState extends ConsumerState<TrendingOiScreen> {
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsTrendingProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsTrendingProvider).stop();
    super.dispose();
  }

  void _seedAtmIfNeeded(List<double> strikes, double? atm) {
    if (_seeded || atm == null || strikes.isEmpty) return;
    _seeded = true;
    // Default to ATM ± 3 strikes (7 total), centred on ATM.
    int atmIdx = 0;
    for (var i = 0; i < strikes.length; i++) {
      if (strikes[i] == atm) {
        atmIdx = i;
        break;
      }
    }
    final lo = (atmIdx - 3).clamp(0, strikes.length - 1);
    final hi = (atmIdx + 3).clamp(0, strikes.length - 1);
    final picked = strikes.sublist(lo, hi + 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsTrendingProvider).setStrikes(picked);
    });
  }

  Future<void> _changeStrikes(List<double> all, double? atm) async {
    final provider = ref.read(instaOptionsTrendingProvider);
    final picked = await StrikeMultiPicker.show(
      context: context,
      allStrikes: all,
      initial: provider.strikes,
      atmStrike: atm,
    );
    if (picked != null) provider.setStrikes(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final chain = ref.watch(instaOptionsChainProvider);
    final trending = ref.watch(instaOptionsTrendingProvider);

    if (selection.expiry.isEmpty) {
      return _Empty(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load Trending OI.',
        tokens: tokens,
      );
    }
    if (chain.loading && chain.strikes.isEmpty) {
      return Container(
        color: tokens.bgPrimary,
        child: Center(child: CircularProgressIndicator(color: tokens.accent)),
      );
    }
    if (chain.strikes.isEmpty) {
      return _Empty(
        icon: Icons.trending_up,
        title: 'No strikes available',
        message: 'The chain has not loaded yet — retry once data is available.',
        tokens: tokens,
      );
    }

    _seedAtmIfNeeded(chain.strikes, chain.atmStrike);

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Controls(
            trending: trending,
            tokens: tokens,
            onChangeStrikes: () =>
                _changeStrikes(chain.strikes, chain.atmStrike),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 320,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ChartCard(
                            title: 'Trending Sentiment',
                            tokens: tokens,
                            child: _SentimentChart(
                              buckets: trending.buckets,
                              tokens: tokens,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChartCard(
                            title: 'Cumulative OI',
                            tokens: tokens,
                            child: _CumulativeOiChart(
                              buckets: trending.buckets,
                              tokens: tokens,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _ChartCard(
                      title: 'Per-bucket detail',
                      tokens: tokens,
                      child: _BucketTable(
                        buckets: trending.buckets,
                        tokens: tokens,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final InstaOptionsTrendingProvider trending;
  final InstaOptionsTokens tokens;
  final VoidCallback onChangeStrikes;

  const _Controls({
    required this.trending,
    required this.tokens,
    required this.onChangeStrikes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onChangeStrikes,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Change strikes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.textPrimary,
              side: BorderSide(color: tokens.border, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          for (final s in trending.strikes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.bgTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border, width: 1),
              ),
              child: Text(
                s.toStringAsFixed(0),
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          BucketMinutesSelector(
            value: trending.bucketMinutes,
            options: InstaOptionsTrendingProvider.bucketMinutesOptions,
            onChanged: trending.setBucketMinutes,
            tokens: tokens,
          ),
          TextButton.icon(
            onPressed: trending.loading ? null : trending.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final InstaOptionsTokens tokens;

  const _ChartCard({
    required this.title,
    required this.child,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SentimentChart extends StatelessWidget {
  final List<TrendingBucket> buckets;
  final InstaOptionsTokens tokens;

  const _SentimentChart({required this.buckets, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return _emptyChart(context, tokens);

    final sentimentSpots = <FlSpot>[];
    for (var i = 0; i < buckets.length; i++) {
      sentimentSpots.add(FlSpot(i.toDouble(), buckets[i].sentiment.clamp(-1.0, 1.0)));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (buckets.length - 1).toDouble(),
        minY: -1,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (v) => FlLine(
            color: tokens.border,
            strokeWidth: v == 0 ? 1 : 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: ((buckets.length - 1) / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    InstaOptionsFormat.time(buckets[i].time),
                    style: MyntWebTextStyles.caption(
                      context,
                      color: tokens.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.5,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textMuted,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.bgTertiary,
            getTooltipItems: (spots) => spots.map((s) {
              final b = buckets[s.x.toInt()];
              return LineTooltipItem(
                '${InstaOptionsFormat.time(b.time)}  ·  Sentiment '
                    '${b.sentiment >= 0 ? '+' : ''}${b.sentiment.toStringAsFixed(2)}'
                    '  ·  PCR ${b.pcr.toStringAsFixed(2)}',
                MyntWebTextStyles.caption(context, color: tokens.textPrimary),
              );
            }).toList(growable: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: sentimentSpots,
            isCurved: true,
            color: tokens.accent,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              cutOffY: 0,
              applyCutOffY: true,
              color: tokens.profit.withValues(alpha: 0.25),
            ),
            aboveBarData: BarAreaData(
              show: true,
              cutOffY: 0,
              applyCutOffY: true,
              color: tokens.loss.withValues(alpha: 0.25),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: 0,
            color: tokens.textMuted,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ]),
      ),
    );
  }
}

class _CumulativeOiChart extends StatelessWidget {
  final List<TrendingBucket> buckets;
  final InstaOptionsTokens tokens;

  const _CumulativeOiChart({required this.buckets, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return _emptyChart(context, tokens);

    final ceSpots = <FlSpot>[];
    final peSpots = <FlSpot>[];
    var minOi = double.infinity;
    var maxOi = -double.infinity;
    for (var i = 0; i < buckets.length; i++) {
      final ce = buckets[i].cumCeOi.toDouble();
      final pe = buckets[i].cumPeOi.toDouble();
      ceSpots.add(FlSpot(i.toDouble(), ce));
      peSpots.add(FlSpot(i.toDouble(), pe));
      if (ce < minOi) minOi = ce;
      if (pe < minOi) minOi = pe;
      if (ce > maxOi) maxOi = ce;
      if (pe > maxOi) maxOi = pe;
    }
    final pad = (maxOi - minOi).abs() * 0.05;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (buckets.length - 1).toDouble(),
        minY: (minOi - pad).clamp(0, double.infinity),
        maxY: maxOi + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: tokens.border,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: ((buckets.length - 1) / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    InstaOptionsFormat.time(buckets[i].time),
                    style: MyntWebTextStyles.caption(
                      context,
                      color: tokens.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) => Text(
                InstaOptionsFormat.oi(v),
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.textMuted,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.bgTertiary,
            getTooltipItems: (spots) {
              if (spots.isEmpty) return [];
              final b = buckets[spots.first.x.toInt()];
              return [
                LineTooltipItem(
                  '${InstaOptionsFormat.time(b.time)}  ·  '
                      'CE ${InstaOptionsFormat.oi(b.cumCeOi)}  ·  '
                      'PE ${InstaOptionsFormat.oi(b.cumPeOi)}  ·  '
                      'PCR ${b.pcr.toStringAsFixed(2)}',
                  MyntWebTextStyles.caption(context, color: tokens.textPrimary),
                ),
                ...List.generate(spots.length - 1, (_) => null),
              ];
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ceSpots,
            isCurved: true,
            color: tokens.profit,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: peSpots,
            isCurved: true,
            color: tokens.loss,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

Widget _emptyChart(BuildContext context, InstaOptionsTokens tokens) {
  return Center(
    child: Text(
      'No buckets yet — backfill in progress',
      style: MyntWebTextStyles.body(context, color: tokens.textSecondary),
    ),
  );
}

class _BucketTable extends StatelessWidget {
  final List<TrendingBucket> buckets;
  final InstaOptionsTokens tokens;

  const _BucketTable({required this.buckets, required this.tokens});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return Center(
        child: Text(
          'No buckets yet',
          style: MyntWebTextStyles.body(context, color: tokens.textSecondary),
        ),
      );
    }
    // Sorted desc by time per spec.
    final sorted = [...buckets]..sort((a, b) => b.time.compareTo(a.time));
    final pcrByTime = {for (final b in buckets) b.time: b.pcr};
    final timesAsc = buckets.map((b) => b.time).toList()
      ..sort((a, b) => a.compareTo(b));
    final prevPcrByTime = <DateTime, double?>{};
    for (var i = 0; i < timesAsc.length; i++) {
      prevPcrByTime[timesAsc[i]] = i == 0 ? null : pcrByTime[timesAsc[i - 1]];
    }

    return DataTable2(
      columnSpacing: 8,
      horizontalMargin: 12,
      dataRowHeight: 32,
      headingRowHeight: 40,
      minWidth: 900,
      headingTextStyle: MyntWebTextStyles.para(
        context,
        color: tokens.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      headingRowColor: WidgetStateProperty.all(tokens.bgTertiary),
      dataTextStyle:
          MyntWebTextStyles.tableCell(context, color: tokens.textPrimary),
      dividerThickness: 0.5,
      columns: const [
        DataColumn2(label: Text('Time'), fixedWidth: 80),
        DataColumn2(label: Text('LTP'), fixedWidth: 90, numeric: true),
        DataColumn2(label: Text('ΔCallOI'), fixedWidth: 110, numeric: true),
        DataColumn2(label: Text('ΔPutOI'), fixedWidth: 110, numeric: true),
        DataColumn2(label: Text('DiffOI'), fixedWidth: 110, numeric: true),
        DataColumn2(label: Text('Dir'), fixedWidth: 50),
        DataColumn2(label: Text('ΔDir'), fixedWidth: 90, numeric: true),
        DataColumn2(label: Text('Dir %'), fixedWidth: 70, numeric: true),
        DataColumn2(label: Text('PCR'), fixedWidth: 60, numeric: true),
      ],
      rows: sorted
          .map((b) => _row(context, b, prevPcrByTime[b.time]))
          .toList(growable: false),
    );
  }

  DataRow2 _row(BuildContext context, TrendingBucket b, double? prevPcr) {
    Color signColor(num v) => v == 0
        ? tokens.textSecondary
        : (v > 0 ? tokens.profit : tokens.loss);
    String signedInt(int v) =>
        v == 0 ? '0' : '${v > 0 ? '+' : '−'}${InstaOptionsFormat.oi(v.abs())}';
    final pcrDelta = prevPcr == null ? null : b.pcr - prevPcr;
    final pcrDeltaPct = (prevPcr == null || prevPcr == 0)
        ? null
        : (b.pcr - prevPcr) / prevPcr * 100;
    final dirIcon = pcrDelta == null
        ? '—'
        : (pcrDelta > 0 ? '▲' : (pcrDelta < 0 ? '▼' : '—'));
    final dirColor = pcrDelta == null
        ? tokens.textMuted
        : signColor(pcrDelta);
    return DataRow2(
      cells: [
        DataCell(Text(InstaOptionsFormat.time(b.time))),
        DataCell(Text(InstaOptionsFormat.price(b.ltp))),
        DataCell(
          Text(
            signedInt(b.deltaCeOi),
            style: MyntWebTextStyles.tableCell(
              context,
              color: signColor(b.deltaCeOi),
            ),
          ),
        ),
        DataCell(
          Text(
            signedInt(b.deltaPeOi),
            style: MyntWebTextStyles.tableCell(
              context,
              color: signColor(b.deltaPeOi),
            ),
          ),
        ),
        DataCell(
          Text(
            signedInt(b.diffOi),
            style: MyntWebTextStyles.tableCell(
              context,
              color: signColor(b.diffOi),
            ),
          ),
        ),
        DataCell(
          Center(
            child: Text(
              dirIcon,
              style: MyntWebTextStyles.tableCell(
                context,
                color: dirColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            pcrDelta == null
                ? '—'
                : '${pcrDelta > 0 ? '+' : (pcrDelta < 0 ? '−' : '')}${pcrDelta.abs().toStringAsFixed(2)}',
            style: MyntWebTextStyles.tableCell(context, color: dirColor),
          ),
        ),
        DataCell(
          Text(
            pcrDeltaPct == null
                ? '—'
                : InstaOptionsFormat.changePct(pcrDeltaPct),
            style: MyntWebTextStyles.tableCell(context, color: dirColor),
          ),
        ),
        DataCell(Text(b.pcr.toStringAsFixed(2))),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final InstaOptionsTokens tokens;

  const _Empty({
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

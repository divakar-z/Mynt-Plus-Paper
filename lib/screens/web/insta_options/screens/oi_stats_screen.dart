import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/oi_aggregate.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_aggregate_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/kpi_card.dart';

/// OI Statistics screen (README §10.4). Cumulative CE/PE panel +
/// per-strike OI bars with CE up / PE down and an ATM marker.
class OiStatsScreen extends ConsumerStatefulWidget {
  const OiStatsScreen({super.key});

  @override
  ConsumerState<OiStatsScreen> createState() => _OiStatsScreenState();
}

class _OiStatsScreenState extends ConsumerState<OiStatsScreen> {
  bool _showChangeOverlay = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsAggregateProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsAggregateProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final agg = ref.watch(instaOptionsAggregateProvider);

    if (selection.expiry.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load OI statistics.',
        tokens: tokens,
      );
    }
    if (agg.loading && agg.aggregate == null && agg.chain.isEmpty) {
      return Container(
        color: tokens.bgPrimary,
        child: Center(child: CircularProgressIndicator(color: tokens.accent)),
      );
    }
    if (agg.error != null && agg.aggregate == null && agg.chain.isEmpty) {
      return _ErrorState(
        message: agg.error!,
        tokens: tokens,
        onRetry: agg.refresh,
      );
    }

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ControlBar(
            tokens: tokens,
            showOverlay: _showChangeOverlay,
            onToggle: (v) => setState(() => _showChangeOverlay = v),
            computedAt: agg.aggregate?.computedAt,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 280,
                    child: _CumulativePanel(
                      tokens: tokens,
                      aggregate: agg.aggregate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PerStrikeBars(
                      tokens: tokens,
                      strikes: agg.perStrike,
                      spot: agg.spot,
                      showChangeOverlay: _showChangeOverlay,
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

class _ControlBar extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final bool showOverlay;
  final ValueChanged<bool> onToggle;
  final DateTime? computedAt;

  const _ControlBar({
    required this.tokens,
    required this.showOverlay,
    required this.onToggle,
    required this.computedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Switch(
            value: showOverlay,
            onChanged: onToggle,
            activeThumbColor: tokens.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'Show OI change overlay',
            style: MyntWebTextStyles.body(context, color: tokens.textSecondary),
          ),
          const Spacer(),
          Text(
            'Last computed: ${InstaOptionsFormat.tooltipTime(computedAt)}',
            style: MyntWebTextStyles.caption(
              context,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CumulativePanel extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final OiAggregate? aggregate;

  const _CumulativePanel({required this.tokens, required this.aggregate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cumulative OI',
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: aggregate == null || !aggregate!.ready
                ? _NotReadyPlaceholder(tokens: tokens)
                : _StackedBar(tokens: tokens, aggregate: aggregate!),
          ),
          const SizedBox(height: 12),
          _KpiRow(tokens: tokens, aggregate: aggregate),
        ],
      ),
    );
  }
}

class _NotReadyPlaceholder extends StatelessWidget {
  final InstaOptionsTokens tokens;
  const _NotReadyPlaceholder({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: tokens.textMuted, size: 32),
            const SizedBox(height: 8),
            Text(
              'Aggregator warming up',
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.body(
                context,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try again in a minute.',
              textAlign: TextAlign.center,
              style: MyntWebTextStyles.caption(
                context,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final OiAggregate aggregate;

  const _StackedBar({required this.tokens, required this.aggregate});

  @override
  Widget build(BuildContext context) {
    final ce = aggregate.totalCeOi.toDouble();
    final pe = aggregate.totalPeOi.toDouble();
    final ceChange = aggregate.totalCeOiChange.toDouble();
    final peChange = aggregate.totalPeOiChange.toDouble();
    return LayoutBuilder(
      builder: (context, c) {
        return CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _StackedBarPainter(
            tokens: tokens,
            ceOi: ce,
            peOi: pe,
            ceChange: ceChange,
            peChange: peChange,
            labelStyle: MyntWebTextStyles.caption(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _StackedBarPainter extends CustomPainter {
  final InstaOptionsTokens tokens;
  final double ceOi;
  final double peOi;
  final double ceChange;
  final double peChange;
  final TextStyle labelStyle;

  _StackedBarPainter({
    required this.tokens,
    required this.ceOi,
    required this.peOi,
    required this.ceChange,
    required this.peChange,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 80.0;
    final total = ceOi + peOi;
    if (total <= 0) return;
    final barX = (size.width - barWidth) / 2;
    final cePart = ceOi / total;
    final peHeight = size.height * (1 - cePart);
    final ceHeight = size.height - peHeight;

    // PE segment (top)
    final pePaint = Paint()..color = tokens.barPe;
    canvas.drawRect(Rect.fromLTWH(barX, 0, barWidth, peHeight), pePaint);

    // CE segment (bottom)
    final cePaint = Paint()..color = tokens.barCe;
    canvas.drawRect(
      Rect.fromLTWH(barX, peHeight, barWidth, ceHeight),
      cePaint,
    );

    // ΔOI overlay tints: green if positive, red if negative,
    // height = |change| / segmentOi * segmentHeight (clamped).
    if (peOi > 0 && peChange != 0) {
      final tintFrac = (peChange.abs() / peOi).clamp(0.0, 1.0);
      final tintHeight = peHeight * tintFrac;
      final tintPaint = Paint()
        ..color = (peChange > 0 ? tokens.profit : tokens.loss).withValues(
          alpha: 0.35,
        );
      canvas.drawRect(
        Rect.fromLTWH(
          barX,
          peHeight - tintHeight,
          barWidth,
          tintHeight,
        ),
        tintPaint,
      );
    }
    if (ceOi > 0 && ceChange != 0) {
      final tintFrac = (ceChange.abs() / ceOi).clamp(0.0, 1.0);
      final tintHeight = ceHeight * tintFrac;
      final tintPaint = Paint()
        ..color = (ceChange > 0 ? tokens.profit : tokens.loss).withValues(
          alpha: 0.35,
        );
      canvas.drawRect(
        Rect.fromLTWH(
          barX,
          peHeight + ceHeight - tintHeight,
          barWidth,
          tintHeight,
        ),
        tintPaint,
      );
    }

    // Numeric labels next to each segment.
    _drawLabel(
      canvas,
      'PE  ${InstaOptionsFormat.oi(peOi)}',
      Offset(barX + barWidth + 8, peHeight / 2 - 6),
    );
    _drawLabel(
      canvas,
      'CE  ${InstaOptionsFormat.oi(ceOi)}',
      Offset(barX + barWidth + 8, peHeight + ceHeight / 2 - 6),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) {
    return old.ceOi != ceOi ||
        old.peOi != peOi ||
        old.ceChange != ceChange ||
        old.peChange != peChange;
  }
}

class _KpiRow extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final OiAggregate? aggregate;

  const _KpiRow({required this.tokens, required this.aggregate});

  @override
  Widget build(BuildContext context) {
    final ce = aggregate?.totalCeOi ?? 0;
    final pe = aggregate?.totalPeOi ?? 0;
    final ceCh = aggregate?.totalCeOiChange ?? 0;
    final peCh = aggregate?.totalPeOiChange ?? 0;
    final pcr = aggregate?.pcr ?? 0.0;
    return Row(
      children: [
        Expanded(
          child: KpiCard(
            label: 'Total CE OI',
            value: InstaOptionsFormat.oi(ce),
            delta: ceCh == 0
                ? null
                : '${ceCh > 0 ? '+' : ''}${InstaOptionsFormat.oi(ceCh.abs())}',
            deltaTone: ceCh > 0
                ? KpiDeltaTone.profit
                : (ceCh < 0 ? KpiDeltaTone.loss : KpiDeltaTone.neutral),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiCard(
            label: 'Total PE OI',
            value: InstaOptionsFormat.oi(pe),
            delta: peCh == 0
                ? null
                : '${peCh > 0 ? '+' : ''}${InstaOptionsFormat.oi(peCh.abs())}',
            deltaTone: peCh > 0
                ? KpiDeltaTone.profit
                : (peCh < 0 ? KpiDeltaTone.loss : KpiDeltaTone.neutral),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KpiCard(
            label: 'PCR',
            value: InstaOptionsFormat.pcr(pcr),
          ),
        ),
      ],
    );
  }
}

class _PerStrikeBars extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final List<({double strike, int ceOi, int peOi})> strikes;
  final double spot;
  final bool showChangeOverlay;

  const _PerStrikeBars({
    required this.tokens,
    required this.strikes,
    required this.spot,
    required this.showChangeOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSecondary,
        border: Border.all(color: tokens.border, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: strikes.isEmpty
          ? Center(
              child: Text(
                'No per-strike OI yet.',
                style: MyntWebTextStyles.body(
                  context,
                  color: tokens.textSecondary,
                ),
              ),
            )
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final maxOi = _maxOi();
    if (maxOi <= 0) {
      return Center(
        child: Text(
          'No OI on any strike yet.',
          style: MyntWebTextStyles.body(
            context,
            color: tokens.textSecondary,
          ),
        ),
      );
    }
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < strikes.length; i++) {
      final s = strikes[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: 0,
              toY: s.ceOi.toDouble(),
              color: tokens.profit,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
            BarChartRodData(
              fromY: -s.peOi.toDouble(),
              toY: 0,
              color: tokens.loss,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    final atmIndex = _atmIndex();
    final atmStrike = atmIndex == null ? null : strikes[atmIndex].strike;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Per-strike OI',
              style: MyntWebTextStyles.bodyMedium(
                context,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (atmStrike != null)
              Text(
                'ATM ${atmStrike.toStringAsFixed(0)}',
                style: MyntWebTextStyles.caption(
                  context,
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              groupsSpace: 6,
              maxY: maxOi,
              minY: -maxOi,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxOi / 4,
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
                    reservedSize: 56,
                    interval: maxOi / 4,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        InstaOptionsFormat.oi(v.abs()),
                        style: MyntWebTextStyles.caption(
                          context,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= strikes.length) {
                        return const SizedBox.shrink();
                      }
                      if (i % 5 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          strikes[i].strike.toStringAsFixed(0),
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
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                verticalLines: atmIndex == null
                    ? []
                    : [
                        VerticalLine(
                          x: atmIndex.toDouble(),
                          color: tokens.accent,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                      ],
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => tokens.bgTertiary,
                  tooltipBorder: BorderSide(color: tokens.border),
                  getTooltipItem: (group, _, rod, __) {
                    final s = strikes[group.x];
                    return BarTooltipItem(
                      'Strike ${s.strike.toStringAsFixed(0)}\n'
                      'CE OI ${InstaOptionsFormat.oi(s.ceOi)}\n'
                      'PE OI ${InstaOptionsFormat.oi(s.peOi)}',
                      MyntWebTextStyles.caption(
                        context,
                        color: tokens.textPrimary,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (showChangeOverlay)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'ΔOI overlay enabled — live deltas land with the WS rollout.',
              style: MyntWebTextStyles.caption(context, color: tokens.textMuted),
            ),
          ),
      ],
    );
  }

  double _maxOi() {
    var m = 0.0;
    for (final s in strikes) {
      if (s.ceOi > m) m = s.ceOi.toDouble();
      if (s.peOi > m) m = s.peOi.toDouble();
    }
    return m;
  }

  int? _atmIndex() {
    if (spot <= 0 || strikes.isEmpty) return null;
    var best = 0;
    var bestDelta = (strikes[0].strike - spot).abs();
    for (var i = 1; i < strikes.length; i++) {
      final d = (strikes[i].strike - spot).abs();
      if (d < bestDelta) {
        best = i;
        bestDelta = d;
      }
    }
    return best;
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
                    'Failed to load OI statistics',
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

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/oi_timeseries_point.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_chain_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_selection_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_options_strike_provider.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_theme.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/bs_badges.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dual_axis_line_chart.dart';

/// Per-Strike Options Chart (README §10.7).
class PerStrikeScreen extends ConsumerStatefulWidget {
  const PerStrikeScreen({super.key});

  @override
  ConsumerState<PerStrikeScreen> createState() => _PerStrikeScreenState();
}

class _PerStrikeScreenState extends ConsumerState<PerStrikeScreen> {
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsStrikeProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(instaOptionsStrikeProvider).stop();
    super.dispose();
  }

  void _seedDefaultStrikeIfNeeded(double? atm) {
    if (_seeded || atm == null) return;
    _seeded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(instaOptionsStrikeProvider).setStrike(atm);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = InstaOptionsTokens.of(context);
    final selection = ref.watch(instaOptionsSelectionProvider).selection;
    final chain = ref.watch(instaOptionsChainProvider);
    final strikeP = ref.watch(instaOptionsStrikeProvider);

    if (selection.expiry.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy,
        title: 'Pick an expiry',
        message: 'Choose an expiry from the bar above to load the per-strike view.',
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
      return _EmptyState(
        icon: Icons.candlestick_chart,
        title: 'No strikes available',
        message: 'The chain has not loaded yet — retry once data is available.',
        tokens: tokens,
      );
    }

    _seedDefaultStrikeIfNeeded(chain.atmStrike);
    final strike = strikeP.strike ?? chain.atmStrike ?? chain.strikes.first;
    final atm = chain.atmStrike;
    final stepFromAtm = atm == null
        ? null
        : ((strike - atm) / _strikeSpacing(chain.strikes)).round();

    return Container(
      color: tokens.bgPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            tokens: tokens,
            strike: strike,
            strikes: chain.strikes,
            stepFromAtm: stepFromAtm,
            onChange: (s) => ref
                .read(instaOptionsStrikeProvider)
                .setStrike(s),
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
                          child: _CallOrPutCard(
                            tokens: tokens,
                            title: 'Call OI Analysis',
                            points: strikeP.cePoints,
                            oiColor: tokens.profit,
                            optionType: 'CE',
                            strike: strike,
                            expiry: selection.expiry,
                            loading: strikeP.loading,
                            error: strikeP.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CallOrPutCard(
                            tokens: tokens,
                            title: 'Put OI Analysis',
                            points: strikeP.pePoints,
                            oiColor: tokens.loss,
                            optionType: 'PE',
                            strike: strike,
                            expiry: selection.expiry,
                            loading: strikeP.loading,
                            error: strikeP.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: _CallVsPutCard(
                      tokens: tokens,
                      cePoints: strikeP.cePoints,
                      pePoints: strikeP.pePoints,
                      loading: strikeP.loading,
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

  double _strikeSpacing(List<double> strikes) {
    if (strikes.length < 2) return 1;
    return (strikes[1] - strikes[0]).abs();
  }
}

class _Header extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final double strike;
  final List<double> strikes;
  final int? stepFromAtm;
  final ValueChanged<double> onChange;

  const _Header({
    required this.tokens,
    required this.strike,
    required this.strikes,
    required this.stepFromAtm,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Strike ${strike.toStringAsFixed(0)}',
            style: MyntWebTextStyles.hero(
              context,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          if (stepFromAtm != null)
            Text(
              stepFromAtm == 0
                  ? 'ATM'
                  : 'ATM ${stepFromAtm! > 0 ? '+' : ''}$stepFromAtm',
              style: MyntWebTextStyles.caption(
                context,
                color: tokens.textSecondary,
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 140,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: strike,
                isDense: true,
                isExpanded: true,
                dropdownColor: tokens.bgSecondary,
                icon: Icon(
                  Icons.expand_more,
                  color: tokens.textSecondary,
                  size: 16,
                ),
                items: strikes
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.toStringAsFixed(0)),
                        ))
                    .toList(growable: false),
                onChanged: (v) {
                  if (v != null) onChange(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallOrPutCard extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final String title;
  final List<OiTimeseriesPoint> points;
  final Color oiColor;
  final String optionType;
  final double strike;
  final String expiry;
  final bool loading;
  final String? error;

  const _CallOrPutCard({
    required this.tokens,
    required this.title,
    required this.points,
    required this.oiColor,
    required this.optionType,
    required this.strike,
    required this.expiry,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final entryPrice = points.isEmpty ? 0.0 : points.last.close;
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
          Row(
            children: [
              Text(
                title,
                style: MyntWebTextStyles.bodyMedium(
                  context,
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              BSBadges(
                expiry: expiry,
                strike: strike,
                optionType: optionType,
                entryPrice: entryPrice,
                tradingSymbol: '$expiry $optionType ${strike.toStringAsFixed(0)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading && points.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: tokens.accent))
                : (error != null && points.isEmpty
                    ? _InlineError(message: error!, tokens: tokens)
                    : DualAxisLineChart(
                        points: points,
                        oiColor: oiColor,
                      )),
          ),
        ],
      ),
    );
  }
}

class _CallVsPutCard extends StatelessWidget {
  final InstaOptionsTokens tokens;
  final List<OiTimeseriesPoint> cePoints;
  final List<OiTimeseriesPoint> pePoints;
  final bool loading;

  const _CallVsPutCard({
    required this.tokens,
    required this.cePoints,
    required this.pePoints,
    required this.loading,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Call vs Put OI Analysis',
            style: MyntWebTextStyles.bodyMedium(
              context,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildChart(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    if (loading && cePoints.isEmpty && pePoints.isEmpty) {
      return Center(child: CircularProgressIndicator(color: tokens.accent));
    }
    if (cePoints.isEmpty && pePoints.isEmpty) {
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

    final len = cePoints.length < pePoints.length
        ? cePoints.length
        : pePoints.length;
    final ceSpots = <FlSpot>[];
    final peSpots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (var i = 0; i < len; i++) {
      final cv = cePoints[i].oi.toDouble();
      final pv = pePoints[i].oi.toDouble();
      ceSpots.add(FlSpot(i.toDouble(), cv));
      peSpots.add(FlSpot(i.toDouble(), pv));
      if (cv < minY) minY = cv;
      if (cv > maxY) maxY = cv;
      if (pv < minY) minY = pv;
      if (pv > maxY) maxY = pv;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (len - 1).toDouble(),
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
              reservedSize: 56,
              interval: (maxY - minY) / 4,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  InstaOptionsFormat.oi(v),
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
              interval: (len / 6).clamp(1, len).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= len) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    InstaOptionsFormat.time(cePoints[i].time),
                    style: MyntWebTextStyles.caption(
                      context,
                      color: tokens.textSecondary,
                    ),
                  ),
                );
              },
            ),
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
            spots: ceSpots,
            color: tokens.profit,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: peSpots,
            color: tokens.loss,
            barWidth: 2,
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
              if (i < 0 || i >= len) return [];
              return [
                LineTooltipItem(
                  '${InstaOptionsFormat.time(cePoints[i].time)}  ·  CE ${InstaOptionsFormat.oi(cePoints[i].oi)}  ·  PE ${InstaOptionsFormat.oi(pePoints[i].oi)}',
                  MyntWebTextStyles.caption(
                    context,
                    color: tokens.textPrimary,
                  ),
                ),
                const LineTooltipItem('', TextStyle()),
              ];
            },
          ),
        ),
      ),
    );
  }

}

class _InlineError extends StatelessWidget {
  final String message;
  final InstaOptionsTokens tokens;
  const _InlineError({required this.message, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.caption(
            context,
            color: tokens.loss,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/charts/pcr_timeline.dart';
import 'package:mynt_plus/provider/insta_options/charts/oi_charts_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/charts_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/pcr_timeline_chart.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// PCR Ratio — chain-wide Put/Call OI ratio over the trading session as a
/// zoomable line, on the date-based charts backend.
class PcrScreen extends ConsumerStatefulWidget {
  const PcrScreen({super.key});

  @override
  ConsumerState<PcrScreen> createState() => _PcrScreenState();
}

class _PcrScreenState extends ConsumerState<PcrScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(oiChartsProvider).activate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(oiChartsProvider).openPcr();
    });
  }

  @override
  void dispose() {
    ref.read(oiChartsProvider).deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(oiChartsProvider);
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark,
        light: MyntColors.backgroundColor);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChartsAppBar(showInterval: true),
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, OiChartsProvider p) {
    if (p.isPcrInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      );
    }
    if (p.isPcrFatal) {
      return _ErrorState(
        message: p.pcrError ?? 'Failed to load PCR.',
        onRetry: () => ref.read(oiChartsProvider).refresh(),
      );
    }
    final data = p.pcrTimeline;
    if (data == null || data.isEmpty) return const _EmptyState();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryTiles(data: data),
          const SizedBox(height: 14),
          Expanded(child: _chartCard(context, data)),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, PcrTimeline data) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return shadcn.OutlinedContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Intraday PCR',
                    style: MyntWebTextStyles.title(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold)),
                const SizedBox(width: 10),
                Icon(Icons.zoom_in, size: 14, color: muted),
                const SizedBox(width: 3),
                Text('scroll / drag to zoom',
                    style: MyntWebTextStyles.caption(context, color: muted)),
                const Spacer(),
                Text('${data.interval} buckets',
                    style: MyntWebTextStyles.caption(context, color: muted)),
              ],
            ),
            const SizedBox(height: 10),
            _legend(context),
            const SizedBox(height: 6),
            Expanded(child: PcrTimelineChart(data: data)),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context) {
    final profit = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    Widget swatch(Color c) => Container(
        width: 14,
        height: 8,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));
    Widget item(Widget mark, String label) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          mark,
          const SizedBox(width: 5),
          Text(label, style: MyntWebTextStyles.caption(context, color: muted)),
        ]);
    return Row(
      children: [
        item(swatch(profit.withValues(alpha: 0.35)), 'Bullish > 1.30'),
        const SizedBox(width: 16),
        item(swatch(loss.withValues(alpha: 0.35)), 'Bearish < 0.70'),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Summary tiles
// ----------------------------------------------------------------------------
class _SummaryTiles extends StatelessWidget {
  final PcrTimeline data;

  const _SummaryTiles({required this.data});

  @override
  Widget build(BuildContext context) {
    final withPcr =
        data.points.where((p) => p.pcr != null).toList(growable: false);
    double? high, low;
    for (final p in withPcr) {
      high = high == null ? p.pcr : (p.pcr! > high ? p.pcr : high);
      low = low == null ? p.pcr : (p.pcr! < low ? p.pcr : low);
    }
    final current = data.closePcr ?? (withPcr.isNotEmpty ? withPcr.last.pcr : null);
    final last = data.points.isNotEmpty ? data.points.last : null;

    final ce = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final pe = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);

    final tiles = <Widget>[
      _tile(context, 'Open PCR', InstaOptionsFormat.pcr(data.openPcr)),
      _tile(context, 'Current PCR', InstaOptionsFormat.pcr(current),
          color: _pcrColor(context, current)),
      _tile(context, 'Day High', InstaOptionsFormat.pcr(high)),
      _tile(context, 'Day Low', InstaOptionsFormat.pcr(low)),
      _tile(context, 'CE OI', InstaOptionsFormat.oi(last?.totalCeOi),
          color: ce),
      _tile(context, 'PE OI', InstaOptionsFormat.oi(last?.totalPeOi),
          color: pe),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i != tiles.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, String label, String value,
      {Color? color}) {
    final border = resolveThemeColor(context,
        dark: MyntColors.cardBorderDark, light: MyntColors.cardBorder);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.caption(context, color: muted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.head(context,
                  color: color,
                  darkColor: color ?? MyntColors.textPrimaryDark,
                  lightColor: color ?? MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold)),
        ],
      ),
    );
  }

  Color _pcrColor(BuildContext context, double? pcr) {
    if (pcr == null) {
      return resolveThemeColor(context,
          dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    }
    if (pcr <= 0.7) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    }
    if (pcr > 1.3) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
    return kDashOrange;
  }
}

// ----------------------------------------------------------------------------
// States
// ----------------------------------------------------------------------------
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: loss.withValues(alpha: 0.1),
            border: Border.all(color: loss, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off, color: loss, size: 20),
                  const SizedBox(width: 8),
                  Text('PCR failed to load',
                      style: MyntWebTextStyles.body(context,
                          color: loss, fontWeight: MyntFonts.semiBold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(message,
                  style: MyntWebTextStyles.caption(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary)),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 44, color: muted),
          const SizedBox(height: 12),
          Text('No PCR data',
              style: MyntWebTextStyles.title(context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 4),
          Text('Try another underlying, date, or expiry.',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ],
      ),
    );
  }
}

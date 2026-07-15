import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_by_strike.dart';
import 'package:mynt_plus/provider/insta_options/charts/oi_charts_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/charts_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/oi_by_strike_chart.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// OI Statistics — per-strike CE/PE open interest as a zoomable column chart,
/// with an OI ⇄ OI-change toggle, on the date-based charts backend.
class OiStatsScreen extends ConsumerStatefulWidget {
  const OiStatsScreen({super.key});

  @override
  ConsumerState<OiStatsScreen> createState() => _OiStatsScreenState();
}

class _OiStatsScreenState extends ConsumerState<OiStatsScreen> {
  OiChartMode _mode = OiChartMode.oi;

  @override
  void initState() {
    super.initState();
    ref.read(oiChartsProvider).activate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(oiChartsProvider).openOiByStrike();
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
          const ChartsAppBar(),
          Expanded(child: _body(context, p)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, OiChartsProvider p) {
    if (p.isOiByStrikeInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      );
    }
    if (p.isOiByStrikeFatal) {
      return _ErrorState(
        message: p.oiByStrikeError ?? 'Failed to load OI statistics.',
        onRetry: () => ref.read(oiChartsProvider).refresh(),
      );
    }
    final data = p.oiByStrike;
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

  Widget _chartCard(BuildContext context, OiByStrike data) {
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
                Text('OI by strike',
                    style: MyntWebTextStyles.title(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold)),
                const Spacer(),
                _modeToggle(context),
              ],
            ),
            const SizedBox(height: 10),
            // Legend left; the zoom hint sits opposite it on the same row.
            Row(
              children: [
                _legend(context, data),
                const Spacer(),
                
                Text('scroll / drag to zoom',
                    style: MyntWebTextStyles.caption(context, color: muted)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: OiByStrikeChart(data: data, mode: _mode)),
          ],
        ),
      ),
    );
  }

  /// Segmented toggle matching the scanner Financials pickers: selected =
  /// solid brand-blue fill + white text.
  Widget _modeToggle(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    Widget seg(String label, OiChartMode m,
        {required bool isFirst, required bool isLast}) {
      final selected = _mode == m;
      // Selected segment's outer corners round to match the container (5).
      const r = Radius.circular(5);
      final radius = BorderRadius.only(
        topLeft: isFirst ? r : Radius.zero,
        bottomLeft: isFirst ? r : Radius.zero,
        topRight: isLast ? r : Radius.zero,
        bottomRight: isLast ? r : Radius.zero,
      );
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _mode = m),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? resolveThemeColor(context,
                      dark: MyntColors.secondary, light: MyntColors.primary)
                  : Colors.transparent,
              borderRadius: radius,
            ),
            child: Text(label,
                style: MyntWebTextStyles.para(context,
                    fontWeight:
                        selected ? MyntFonts.semiBold : MyntFonts.medium,
                    color: selected ? Colors.white : textSecondary)),
          ),
        ),
      );
    }

    return Container(
      // Fixed 36 to line up with the underlying dropdown / date pill.
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          seg('OI', OiChartMode.oi, isFirst: true, isLast: false),
          seg('OI change', OiChartMode.change, isFirst: false, isLast: true),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, OiByStrike data) {
    final ce = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit); // CE = green
    final pe = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss); // PE = red
    final spot = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    Widget dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));
    Widget item(Widget mark, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          mark,
          const SizedBox(width: 5),
          Text(label, style: MyntWebTextStyles.para(context, color: muted)),
        ]);
    return Row(
      children: [
        item(dot(ce), 'CE OI'),
        const SizedBox(width: 16),
        item(dot(pe), 'PE OI'),
        const SizedBox(width: 16),
        item(
            SizedBox(
                width: 14,
                child: Divider(color: spot, thickness: 1.5, height: 1)),
            'Spot  ${InstaOptionsFormat.price(data.underlyingValue)}'),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Summary tiles
// ----------------------------------------------------------------------------
class _SummaryTiles extends StatelessWidget {
  final OiByStrike data;

  const _SummaryTiles({required this.data});

  @override
  Widget build(BuildContext context) {
    final pcrColor = _pcrColor(context, data.pcr);
    final ce = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final pe = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final tiles = <Widget>[
      _tile(context, 'Spot', InstaOptionsFormat.price(data.underlyingValue)),
      _tile(context, 'ATM', InstaOptionsFormat.price(data.atmStrike)),
      _tile(context, 'PCR', InstaOptionsFormat.pcr(data.pcr), color: pcrColor),
      _tile(context, 'Max pain', InstaOptionsFormat.price(data.maxPain)),
      _tile(context, 'Total CE OI', InstaOptionsFormat.oi(data.totalCeOi),
          color: ce),
      _tile(context, 'Total PE OI', InstaOptionsFormat.oi(data.totalPeOi),
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

  /// Same mini-card as the Index Contribution header tiles (PCR / Rollover):
  /// light tertiary border, caption label over a semiBold value.
  Widget _tile(BuildContext context, String label, String value,
      {Color? color}) {
    final border = resolveThemeColor(context,
            dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary)
        .withValues(alpha: 0.2);
    final bg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.body(
                context,
                darkColor: MyntColors.textTertiaryDark,
                lightColor: MyntColors.textTertiary,
                fontWeight: MyntFonts.regular,
              )),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.body(context,
                  color: color,
                  darkColor: color ?? MyntColors.textPrimaryDark,
                  lightColor: color ?? MyntColors.textPrimary,
                  fontWeight: MyntFonts.medium)),
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
                  Text('OI statistics failed to load',
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
          Icon(Icons.bar_chart_rounded, size: 44, color: muted),
          const SizedBox(height: 12),
          Text('No OI data',
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

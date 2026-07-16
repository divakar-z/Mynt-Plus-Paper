import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/provider/insta_options/charts/oi_charts_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/insta_options_format.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/charts_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/oi_sentiment_table.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/oi_timeline_chart.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/charts/strike_multi_select.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

enum _Leg { both, ce, pe }

/// Trending OI — intraday OI per selected strike (multi-line, zoomable, with an
/// optional spot/future price overlay) plus a per-strike buildup-sentiment
/// table, on the date-based charts backend.
class TrendingOiScreen extends ConsumerStatefulWidget {
  const TrendingOiScreen({super.key});

  @override
  ConsumerState<TrendingOiScreen> createState() => _TrendingOiScreenState();
}

class _TrendingOiScreenState extends ConsumerState<TrendingOiScreen> {
  _Leg _leg = _Leg.both;
  bool _priceFuture = false;
  final ScrollController _tableScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.read(oiChartsProvider).activate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(oiChartsProvider).openOiTimeline();
    });
  }

  @override
  void dispose() {
    _tableScroll.dispose();
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
    if (p.isOiTimelineInitialLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: resolveThemeColor(context,
              dark: MyntColors.primaryDark, light: MyntColors.primary),
        ),
      );
    }
    if (p.isOiTimelineFatal) {
      return _ErrorState(
        message: p.oiTimelineError ?? 'Failed to load Trending OI.',
        onRetry: () => ref.read(oiChartsProvider).refresh(),
      );
    }
    final data = p.oiTimeline;
    if (data == null || data.isEmpty) return const _EmptyState();

    // Pinned controls + chart, only the table scrolls — so the mouse wheel
    // zooms the chart instead of scrolling the page past it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _controls(context, data),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(
              builder: (context, c) {
                final chartH = (c.maxHeight * 0.56).clamp(320.0, 600.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: chartH, child: _chartCard(context, data)),
                    const SizedBox(height: 12),
                    Expanded(
                      // Always-visible scrollbar, same as the Market Depth
                      // panel (RawScrollbar with a permanent thumb + track).
                      child: RawScrollbar(
                        controller: _tableScroll,
                        thumbVisibility: true,
                        trackVisibility: true,
                        trackColor: Colors.grey.withValues(alpha: 0.1),
                        thumbColor: Colors.grey.withValues(alpha: 0.3),
                        thickness: 6,
                        radius: const Radius.circular(3),
                        interactive: true,
                        child: SingleChildScrollView(
                          controller: _tableScroll,
                          child: DashSectionCard(
                            title: 'Strike sentiment',
                            subtitle: '(Day OI change + buildup per strike)',
                            child: OiSentimentTable(data: data),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, OiTimeline data) {
    final priceAvailable = data.hasSpotSeries || data.hasFutureSeries;
    return Row(
      children: [
        StrikeMultiSelect(
          available: data.availableStrikes,
          selected: data.selectedStrikes,
          onChanged: (s) => ref.read(oiChartsProvider).setStrikes(s),
        ),
        const SizedBox(width: 12),
        _legToggle(context),
        if (priceAvailable) ...[
          const SizedBox(width: 12),
          _priceToggle(context, data),
        ],
      ],
    );
  }

  Widget _legToggle(BuildContext context) {
    return _Segmented(
      items: const [
        _SegItem('Both', _Leg.both),
        _SegItem('CE', _Leg.ce),
        _SegItem('PE', _Leg.pe),
      ],
      selected: _leg,
      onSelect: (v) => setState(() => _leg = v as _Leg),
    );
  }

  Widget _priceToggle(BuildContext context, OiTimeline data) {
    return _Segmented(
      items: [
        _SegItem('Spot', false, enabled: data.hasSpotSeries),
        _SegItem('Future', true, enabled: data.hasFutureSeries),
      ],
      selected: _priceFuture,
      onSelect: (v) => setState(() => _priceFuture = v as bool),
    );
  }

  Widget _chartCard(BuildContext context, OiTimeline data) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final ordered = data.selectedStrikes.isNotEmpty
        ? (List<double>.from(data.selectedStrikes)..sort())
        : (data.series.map((s) => s.strike).toSet().toList()..sort());
    final series = data.series.where((s) {
      switch (_leg) {
        case _Leg.both:
          return true;
        case _Leg.ce:
          return s.optType == 'CE';
        case _Leg.pe:
          return s.optType == 'PE';
      }
    }).toList(growable: false);

    final hasSpot = data.hasSpotSeries;
    final hasFuture = data.hasFutureSeries;
    final priceAvailable = hasSpot || hasFuture;
    final priceIsFuture = priceAvailable && hasFuture && (_priceFuture || !hasSpot);
    final priceLine = priceIsFuture ? data.futureSeries : data.spotSeries;
    final priceLabel = priceIsFuture ? 'Future' : 'Spot';

    return  Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Intraday OI',
                    style: MyntWebTextStyles.title(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Spot ${InstaOptionsFormat.price(data.underlyingValue)}'
                    '  ·  ATM ${InstaOptionsFormat.price(data.atmStrike)}'
                    '  ·  ${data.interval}',
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.para(context, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Legend left; the zoom hint pinned to the right of the same row.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _legend(
                        context, ordered, priceAvailable, priceIsFuture)),
                const SizedBox(width: 8),                
                Text('scroll / drag to zoom',
                    style: MyntWebTextStyles.para(context, color: muted)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: series.isEmpty
                  ? _chartPlaceholder(context)
                  : OiTimelineChart(
                      series: series,
                      orderedStrikes: ordered,
                      priceLine: priceLine,
                      showPrice: priceAvailable,
                      priceLabel: priceLabel,
                      underlyingLabel: data.underlying,
                    ),
            ),
          ],
        );
  }

  Widget _legend(BuildContext context, List<double> ordered,
      bool priceShown, bool priceIsFuture) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final priceColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    // Each swatch+strike pair is its own wrap item, so a long strike
    // selection flows onto extra lines instead of overflowing (one giant Row
    // per group can't be broken by the Wrap).
    List<Widget> group(String label, bool isCall) => [
          Text(label,
              style: MyntWebTextStyles.body(context, color: priceColor)
                  .copyWith(fontWeight: MyntFonts.bold)),
          for (final s in ordered)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: oiLegColor(ordered, s, isCall),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 3),
                Text('${s.toInt()}',
                    style: MyntWebTextStyles.para(context, color: muted)),
              ],
            ),
        ];

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_leg != _Leg.pe) ...group('Calls', true),
        if (_leg != _Leg.ce) ...group('Puts', false),
        if (priceShown)
          Row(mainAxisSize: MainAxisSize.min, children: [
            _DashedKey(color: priceColor),
            const SizedBox(width: 5),
            Text(priceIsFuture ? 'Future' : 'Spot',
                style: MyntWebTextStyles.body(context, color: resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary))
                    .copyWith(fontWeight: MyntFonts.bold)),
          ]),
      ],
    );
  }

  Widget _chartPlaceholder(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 36, color: muted),
          const SizedBox(height: 8),
          Text('Select strikes to plot intraday OI',
              style: MyntWebTextStyles.caption(context, color: muted)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Small segmented toggle (Both/CE/PE and Spot/Future)
// ----------------------------------------------------------------------------
class _SegItem {
  final String label;
  final Object value;
  final bool enabled;
  const _SegItem(this.label, this.value, {this.enabled = true});
}

class _Segmented extends StatelessWidget {
  final List<_SegItem> items;
  final Object selected;
  final ValueChanged<Object> onSelect;

  const _Segmented({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Scanner-style segmented toggle (same as the OI Statistics and Most
    // Active toggles): selected = solid brand-blue fill + white text.
    final border = shadcn.Theme.of(context).colorScheme.border;

    return Container(
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
          for (var i = 0; i < items.length; i++)
            _seg(context, items[i],
                isFirst: i == 0, isLast: i == items.length - 1),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, _SegItem it,
      {required bool isFirst, required bool isLast}) {
    final active = it.value == selected;
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final disabled = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    // Selected segment's outer corners round to match the container (5).
    const r = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: isFirst ? r : Radius.zero,
      bottomLeft: isFirst ? r : Radius.zero,
      topRight: isLast ? r : Radius.zero,
      bottomRight: isLast ? r : Radius.zero,
    );
    return MouseRegion(
      cursor:
          it.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: it.enabled ? () => onSelect(it.value) : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? resolveThemeColor(context,
                    dark: MyntColors.secondary, light: MyntColors.primary)
                : Colors.transparent,
            borderRadius: radius,
          ),
          child: Text(it.label,
              style: MyntWebTextStyles.para(context,
                  color: !it.enabled
                      ? disabled
                      : (active ? Colors.white : muted),
                  fontWeight:
                      active ? MyntFonts.semiBold : MyntFonts.medium)),
        ),
      ),
    );
  }
}

class _DashedKey extends StatelessWidget {
  final Color color;
  const _DashedKey({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(width: 5, height: 2, color: color),
          if (i != 2) const SizedBox(width: 2),
        ],
      ],
    );
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
                  Text('Trending OI failed to load',
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
          Icon(Icons.trending_up, size: 44, color: muted),
          const SizedBox(height: 12),
          Text('No trending OI data',
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

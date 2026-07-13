import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/insta_options/dashboard/buildup_sentiment.dart';
import 'package:mynt_plus/models/insta_options/dashboard/gainers_losers.dart';
import 'package:mynt_plus/models/insta_options/dashboard/index_card.dart';
import 'package:mynt_plus/provider/insta_options/dashboard/markets_dashboard_provider.dart';
import 'package:mynt_plus/provider/insta_options/insta_live_ticks.dart';
import 'package:mynt_plus/provider/insta_options/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/buildup_table_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/gainers_losers_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/index_strip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/most_active_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/sector_performance_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/sentiment_gauge.dart';

/// Markets Dashboard (Screen 1) — date-based, one call per day. Composes the
/// eight sections of INSTAOPTIONS dashboard v2 from [marketsDashboardProvider].
class MarketsDashboardScreen extends ConsumerStatefulWidget {
  const MarketsDashboardScreen({super.key});

  @override
  ConsumerState<MarketsDashboardScreen> createState() =>
      _MarketsDashboardScreenState();
}

class _MarketsDashboardScreenState
    extends ConsumerState<MarketsDashboardScreen> {
  Set<String> _lastSubKeys = const <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(marketsDashboardProvider).start();
    });
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(marketsDashboardProvider);
    ref.watch(instaLiveTicksProvider); // rebuild overlay on each socket tick
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor);

    if (p.isInitialLoading) {
      return Container(
        color: bg,
        child: Center(
          child: CircularProgressIndicator(
            color: resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary),
          ),
        ),
      );
    }

    if (p.isFatalError) {
      return _ErrorState(message: p.error ?? 'Failed to load.', onRetry: p.refresh);
    }

    const gap = SizedBox(height: 16);
    final live = _applyLive(context, p);

    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          DashboardAppBar(
            tradeDate: p.tradeDate,
            selectedDate: p.selectedDateTime,
            availableDates: p.availableDates,
            liveMode: p.liveMode,
            liveChannel: p.liveChannel,
            freshnessHm: p.freshnessHm,
            loading: p.loadingData,
            onSelectLive: () => ref.read(marketsDashboardProvider).selectLive(),
            onDateSelected: (d) =>
                ref.read(marketsDashboardProvider).selectDate(_iso(d)),
            onRefresh: () => ref.read(marketsDashboardProvider).refresh(),
          ),
          const SizedBox(height: 16),
          IndexStrip(indices: live.indices),
          gap,
          SentimentGauge(sentiment: live.sentiment),
          gap,
          BuildupTableSection(sentiment: live.sentiment),
          gap,
          SectorPerformanceSection(sectors: p.sectorPerformance),
          gap,
          MostActiveSection(mostActive: p.mostActive),
          gap,
          GainersLosersSection(data: live.gl),
        ],
      ),
    );
  }

  /// Live-tick overlay: index-card level/change% (index token) + gainer/loser/
  /// buildup LTP + price% (stock token via /symbols) take the socket value once
  /// a tick arrives; OI / breadth / sentiment counts / most-active / buildup
  /// category stay the API snapshot. Also keeps subscriptions in sync.
  ({List<IndexCard> indices, GainersLosers gl, BuildupSentiment sentiment})
      _applyLive(BuildContext context, MarketsDashboardProvider p) {
    final symbols = ref.read(symbolsProvider);
    final t = ref.read(instaLiveTicksProvider);
    final keys = <String>{};
    final tokenById = <String, String?>{};
    String? resolve(String id) {
      if (tokenById.containsKey(id)) return tokenById[id];
      final s = symbols.byId(id);
      if (s?.tickKey != null) keys.add(s!.tickKey!);
      return tokenById[id] = s?.token;
    }

    for (final c in p.indices) {
      resolve(c.underlyingId);
    }
    for (final r in p.gainersLosers.gainers) {
      resolve(r.symbol);
    }
    for (final r in p.gainersLosers.losers) {
      resolve(r.symbol);
    }
    for (final r in p.sentiment.rows) {
      resolve(r.symbol);
    }
    _syncSubs(context, p.liveMode ? keys : const <String>{});

    if (!p.liveMode) {
      return (indices: p.indices, gl: p.gainersLosers, sentiment: p.sentiment);
    }

    double? ltp(String id, double? f) => t.ltpOr(tokenById[id], f);
    double? pct(String id, double? f) => t.liveChangePct(tokenById[id]) ?? f;
    GainerLoserRow gRow(GainerLoserRow r) => r.copyWith(
        lastClose: ltp(r.symbol, r.lastClose),
        priceChangePct: pct(r.symbol, r.priceChangePct));
    return (
      indices: [
        for (final c in p.indices)
          c.copyWith(
              level: ltp(c.underlyingId, c.level),
              changePct: pct(c.underlyingId, c.changePct))
      ],
      gl: GainersLosers(
        gainers: [for (final r in p.gainersLosers.gainers) gRow(r)],
        losers: [for (final r in p.gainersLosers.losers) gRow(r)],
      ),
      sentiment: p.sentiment.copyWith(rows: [
        for (final r in p.sentiment.rows)
          r.copyWith(
              lastClose: ltp(r.symbol, r.lastClose),
              priceChangePct: pct(r.symbol, r.priceChangePct))
      ]),
    );
  }

  void _syncSubs(BuildContext context, Set<String> keys) {
    if (keys.length == _lastSubKeys.length && keys.containsAll(_lastSubKeys)) {
      return;
    }
    _lastSubKeys = keys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(instaLiveTicksProvider).setActive(keys, context);
    });
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bg = resolveThemeColor(context,
        dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    return Container(
      color: bg,
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
                  Text(
                    'Dashboard failed to load',
                    style: MyntWebTextStyles.body(context,
                        color: loss, fontWeight: MyntFonts.semiBold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: MyntWebTextStyles.caption(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
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

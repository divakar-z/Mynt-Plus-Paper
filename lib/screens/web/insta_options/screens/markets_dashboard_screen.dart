import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/insta_options/dashboard/markets_dashboard_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/buildup_table_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/dashboard_app_bar.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/gainers_losers_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/index_strip.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/most_active_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/sector_performance_section.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/sentiment_gauge.dart';
import 'package:mynt_plus/screens/web/insta_options/widgets/dashboard/stock_pcr_section.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(marketsDashboardProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(marketsDashboardProvider).stop();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(marketsDashboardProvider);
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

    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          DashboardAppBar(
            tradeDate: p.tradeDate,
            selectedDate: p.selectedDateTime,
            availableDates: p.availableDates,
            loading: p.loadingData,
            onDateSelected: (d) =>
                ref.read(marketsDashboardProvider).selectDate(_iso(d)),
            onRefresh: () => ref.read(marketsDashboardProvider).refresh(),
          ),
          const SizedBox(height: 16),
          IndexStrip(indices: p.indices),
          gap,
          SentimentGauge(sentiment: p.sentiment),
          gap,
          BuildupTableSection(sentiment: p.sentiment),
          gap,
          StockPcrSection(stockPcr: p.stockPcr),
          gap,
          SectorPerformanceSection(sectors: p.sectorPerformance),
          gap,
          MostActiveSection(mostActive: p.mostActive),
          gap,
          GainersLosersSection(data: p.gainersLosers),
        ],
      ),
    );
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

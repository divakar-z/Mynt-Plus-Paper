import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/models/scanner_model/scanner_exception.dart';
import 'package:mynt_plus/provider/scanner/scan_explain_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/chart_engine/widgets/lite_chart_iframe_host.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scan_predicate_panel.dart';
import 'symbols_tabs/financials_tab.dart';
import 'symbols_tabs/fundamental_tab.dart';
import 'symbols_tabs/performance_tab.dart';
import 'symbols_tabs/scans_tab.dart';
import 'symbols_tabs/technicals_tab.dart';

/// The Scanner-Details screen (opened from a results row). Header shows
/// the scanner name + ticker; below it a tab strip:
///   Explanation | Scans | Technicals | Performance | Fundamentals
/// The Explanation tab hosts the lite chart (matched-bar shading +
/// server indicators) and the predicate panel; the other tabs reuse the
/// per-symbol widgets from the Symbols detail page.
class ScanExplainScreen extends ConsumerStatefulWidget {
  final ExplainKey args;
  const ScanExplainScreen({super.key, required this.args});

  @override
  ConsumerState<ScanExplainScreen> createState() => _ScanExplainScreenState();
}

class _ScanExplainScreenState extends ConsumerState<ScanExplainScreen>
    with TickerProviderStateMixin {
  static const _tabs = [
    'Explanation', 'Scans', 'Technicals', 'Performance', 'Fundamentals',
    'Financials',
  ];
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    // The tab body is a plain index switch (not TabBarView) so the chart
    // iframe is fully disposed when the user leaves the Explanation tab —
    // keeping hidden iframes mounted invites the ghost-hit-region bug.
    // Rebuild on every index change to swap the body.
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncResp = ref.watch(scanExplainProvider(widget.args));
    return asyncResp.when(
      loading: () => Center(child: MyntLoader.branded()),
      error: (e, _) => _errorView(context, e),
      data: (r) => _layout(context, r),
    );
  }

  Widget _layout(BuildContext context, ScanExplainResponse r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, r),
          const SizedBox(height: 12),
          // Top tab strip styled like the Watchlist tabs (shadcn underline).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _topTabs(context),
          ),
          const SizedBox(height: 16),
          Expanded(child: _activeTabBody(context, r)),
        ],
      ),
    );
  }

  /// Top tab strip styled like the Positions page tabs: each tab is a pill
  /// with a subtle rounded background on active, plain-text on inactive.
  Widget _topTabs(BuildContext context) {
    final isDark = isDarkMode(context);
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final foreground = shadcn.Theme.of(context).colorScheme.foreground;
    final mutedForeground =
        shadcn.Theme.of(context).colorScheme.mutedForeground;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _tabs.length; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (i != _tab.index) _tab.animateTo(i);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      i == _tab.index ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tabs[i],
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: i == _tab.index
                        ? MyntFonts.semiBold
                        : MyntFonts.medium,
                  ).copyWith(
                    color:
                        i == _tab.index ? foreground : mutedForeground,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _activeTabBody(BuildContext context, ScanExplainResponse r) {
    final ticker = widget.args.ticker;
    switch (_tab.index) {
      case 1:
        return ScansTab(ticker: ticker);
      case 2:
        return TechnicalsTab(ticker: ticker);
      case 3:
        return PerformanceTab(ticker: ticker);
      case 4:
        return FundamentalTab(ticker: ticker);
      case 5:
        return FinancialsTab(ticker: ticker);
      case 0:
      default:
        return _explanationTab(context, r);
    }
  }

  Widget _explanationTab(BuildContext context, ScanExplainResponse r) {
    return LayoutBuilder(builder: (ctx, c) {
      // Predicate panel renders next to the chart on a standard desktop
      // viewport; below 900 the right column would crush both sides —
      // stack vertically instead.
      if (c.maxWidth >= 900) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _chartArea(r)),
            const SizedBox(width: 16),
            SizedBox(
              width: 320,
              child: ScanPredicatePanel(node: r.explanation),
            ),
          ],
        );
      }
      return Column(children: [
        Expanded(flex: 3, child: _chartArea(r)),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: ScanPredicatePanel(node: r.explanation),
        ),
      ]);
    });
  }

  Widget _header(BuildContext context, ScanExplainResponse r) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + "(as of …)" inline on the first line.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(r.scannerName,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Text('(as of ${r.asOf})',
                style: MyntWebTextStyles.caption(context, color: secondary)),
          ],
        ),
        // const SizedBox(height: 2),
        // Text(r.ticker,
        //     style: MyntWebTextStyles.caption(context, color: secondary)
        //         .copyWith(fontFamily: 'monospace')),
      ],
    );
  }

  Widget _chartArea(ScanExplainResponse r) {
    // The iframe host needs concrete bounds; wrap in a bordered card so
    // the chart visually anchors next to the predicate panel.
    return Builder(builder: (context) {
      final border = Theme.of(context).dividerColor;
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: LiteChartIframeHost(response: r),
        ),
      );
    });
  }

  Widget _errorView(BuildContext context, Object error) {
    final mapped = _mapError(error);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyState(
        kind: EmptyStateKind.error,
        title: mapped.title,
        message: mapped.message,
        onRetry: () => ref.invalidate(scanExplainProvider(widget.args)),
      ),
    );
  }

  /// Maps the backend's structured error envelope to a user-presentable
  /// title + message. See spec §4.6 for the full envelope shape.
  _MappedError _mapError(Object e) {
    if (e is StockScannerException) {
      switch (e.errorCode) {
        case 'symbol_not_found':
          return const _MappedError(
            title: 'Symbol not found',
            message:
                "We don't have data for this ticker — it may have been removed since the scan ran.",
          );
        case 'scanner_not_found':
        case 'custom_not_found':
          return const _MappedError(
            title: 'Scanner not found',
            message: 'This scanner no longer exists or was renamed.',
          );
        case 'no_prices':
          return _MappedError(
            title: 'No price history',
            message:
                'No price data available for ${widget.args.ticker} in the required window.',
          );
        case 'benchmark_required':
          return const _MappedError(
            title: 'Benchmark unavailable',
            message:
                'This scanner depends on a benchmark series (NIFTY) that we can\'t compute the explanation against yet.',
          );
        default:
          return _MappedError(
            title: 'Could not load explanation',
            message: e.message,
          );
      }
    }
    return _MappedError(
      title: 'Could not load explanation',
      message: e.toString(),
    );
  }
}

class _MappedError {
  final String title;
  final String message;
  const _MappedError({required this.title, required this.message});
}

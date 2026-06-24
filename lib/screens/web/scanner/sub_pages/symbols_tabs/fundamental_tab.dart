import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_score.dart';
import 'package:mynt_plus/models/scanner_model/symbol_info.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/metric_card.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/score_progress_bar.dart';

class FundamentalTab extends ConsumerWidget {
  final String ticker;
  const FundamentalTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(symbolInfoProvider(ticker));
    final score = ref.watch(fundamentalScoreProvider(ticker));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview',
              style:
                  MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold)),
          const SizedBox(height: 8),
          info.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load company info',
              message: e.toString(),
              onRetry: () => ref.invalidate(symbolInfoProvider(ticker)),
            ),
            data: (i) => _overviewGrid(i),
          ),
          const SizedBox(height: 24),
          score.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load score',
              message: e.toString(),
              onRetry: () => ref.invalidate(fundamentalScoreProvider(ticker)),
            ),
            data: (s) => _scoreSection(context, s),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid(SymbolInfo i) {
    // Order + field set mirror the product's reference Fundamental view.
    // 52-week high/low are intentionally excluded — the backend returns
    // them null for most symbols, so they'd only ever render as "—".
    return Wrap(spacing: 12, runSpacing: 12, children: [
      MetricCard(label: 'Sector', value: i.sector ?? kEmDash),
      MetricCard(label: 'Industry', value: i.industry ?? kEmDash),
      MetricCard(label: 'Market Cap', value: formatCurrencyINR(i.marketCap)),
      MetricCard(
          label: 'Enterprise Value',
          value: formatCurrencyINR(i.enterpriseValue)),
      MetricCard(label: 'P/E Ratio (TTM)', value: _num(i.peTrailing)),
      MetricCard(label: 'P/E Ratio (FWD)', value: _num(i.peForward)),
      MetricCard(label: 'PEG Ratio', value: _num(i.pegRatio)),
      MetricCard(label: 'Book Value / Share', value: _rupee(i.bookValue)),
      MetricCard(label: 'Price to Book', value: _num(i.pbRatio)),
      MetricCard(label: 'EPS (TTM)', value: _rupee(i.epsTrailing)),
      MetricCard(label: 'Beta', value: _num(i.beta)),
      MetricCard(
          label: 'Dividend Yield', value: formatPercent(i.dividendYield)),
      MetricCard(
          label: 'Return on Equity', value: formatPercent(i.returnOnEquity)),
      MetricCard(label: 'Debt / Equity', value: _num(i.debtToEquity)),
      MetricCard(label: 'Current Ratio', value: _num(i.currentRatio)),
      MetricCard(label: 'Profit Margin', value: formatPercent(i.profitMargins)),
      MetricCard(label: 'EBITDA', value: formatCurrencyINR(i.ebitda)),
    ]);
  }

  Widget _scoreSection(BuildContext context, FundamentalScore s) {
    final composite = s.composite;
    final scoreColor = _scoreColor(composite);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline composite — large coloured number, matching the
        // reference design (no separate "Composite" progress bar).
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Fundamental Score:  ',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold)),
            Text(
              composite == null ? kEmDash : composite.round().toString(),
              style: MyntWebTextStyles.head(context,
                  fontWeight: MyntFonts.bold, color: scoreColor),
            ),
            Text(' / 100',
                style: MyntWebTextStyles.body(context, color: secondary)),
          ],
        ),
        const SizedBox(height: 16),
        ScoreProgressBar(label: 'Valuation', score: s.valuation),
        const SizedBox(height: 12),
        ScoreProgressBar(label: 'Growth', score: s.growth),
        const SizedBox(height: 12),
        ScoreProgressBar(label: 'Profitability', score: s.profitability),
        const SizedBox(height: 12),
        ScoreProgressBar(label: 'Quality', score: s.quality),
        const SizedBox(height: 12),
        ScoreProgressBar(label: 'Solvency', score: s.solvency),
        const SizedBox(height: 12),
        ScoreProgressBar(label: 'Efficiency', score: s.efficiency),
      ],
    );
  }

  Color _scoreColor(double? s) {
    if (s == null) return MyntColors.warning;
    if (s >= 80) return MyntColors.success;
    if (s >= 60) return const Color(0xFF10B981);
    if (s >= 40) return MyntColors.warning;
    return MyntColors.error;
  }
}

/// Plain 2-decimal ratio, or em-dash when null.
String _num(double? v) => v == null ? kEmDash : v.toStringAsFixed(2);

/// Rupee-prefixed 2-decimal value (per-share figures), or em-dash.
String _rupee(double? v) => v == null ? kEmDash : '₹ ${v.toStringAsFixed(2)}';

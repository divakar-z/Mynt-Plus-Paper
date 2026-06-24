import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class FinancialsTab extends ConsumerStatefulWidget {
  final String ticker;
  const FinancialsTab({super.key, required this.ticker});

  @override
  ConsumerState<FinancialsTab> createState() => _FinancialsTabState();
}

class _FinancialsTabState extends ConsumerState<FinancialsTab> {
  String _statement = 'income';
  String _basis = 'standalone';
  String _period = 'quarterly';

  ({String ticker, String period, String statement, String basis}) get _key => (
        ticker: widget.ticker,
        period: _period,
        statement: _statement,
        basis: _basis,
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financialsProvider(_key));
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Statement picker — primary-filled selected, matching the
        // screenshot's purple pill.
        _Segmented(
          options: const ['income', 'balance', 'cashflow'],
          labels: const ['Income Statement', 'Balance Sheet', 'Cash Flow'],
          value: _statement,
          primary: true,
          onChanged: (v) => setState(() => _statement = v),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _Segmented(
            options: const ['standalone', 'consolidated'],
            labels: const ['Standalone', 'Consolidated'],
            value: _basis,
            onChanged: (v) => setState(() => _basis = v),
          ),
          _Segmented(
            options: const ['quarterly', 'annual'],
            labels: const ['Quarterly', 'Annual'],
            value: _period,
            onChanged: (v) => setState(() => _period = v),
          ),
        ]),
        const SizedBox(height: 6),
        Text('All values in ₹ Cr',
            style: MyntWebTextStyles.caption(context, color: secondary)),
        const SizedBox(height: 10),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load financials',
              message: e.toString(),
              onRetry: () => ref.invalidate(financialsProvider(_key)),
            ),
            data: (resp) {
              if (resp.lineItems.isEmpty || resp.periods.isEmpty) {
                // Empty is the normal case for consolidated on companies
                // that only report standalone — give that a clear message
                // rather than a generic "no data".
                return EmptyState(
                  kind: EmptyStateKind.insufficientData,
                  title: _basis == 'consolidated'
                      ? 'No consolidated statements'
                      : 'No financial statements available',
                  message: _basis == 'consolidated'
                      ? 'This company reports on a standalone basis only. '
                          'Switch to Standalone to view its financials.'
                      : null,
                );
              }
              return _FinancialsTable(
                period: resp.periodType,
                periods: resp.periods,
                lineItems: resp.lineItems,
                values: resp.values,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bordered table: LINE ITEM column (left-aligned, sticky on horizontal
/// scroll) + one column per reporting period (newest first), values in
/// ₹ Cr with negatives in red. Mirrors the styling of the scanner results
/// table so the two read as one product.
class _FinancialsTable extends StatelessWidget {
  final String period; // 'quarterly' | 'annual'
  final List<String> periods;
  final List<String> lineItems;
  final Map<String, Map<String, num?>> values;
  const _FinancialsTable({
    required this.period,
    required this.periods,
    required this.lineItems,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    // Newest period first — matches how users read recent-quarter-first.
    final cols = periods.reversed.toList();
    const labelW = 220.0;
    const valW = 110.0;

    Widget headerCell(String text, {required bool numeric}) => SizedBox(
          width: numeric ? valW : labelW,
          child: Text(
            text,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: MyntWebTextStyles.caption(context,
                    fontWeight: MyntFonts.semiBold, color: secondary)
                .copyWith(letterSpacing: 0.6),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: labelW + valW * cols.length + 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: headerBg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  headerCell('LINE ITEM', numeric: false),
                  for (final p in cols)
                    headerCell(_periodLabel(p, period), numeric: true),
                ]),
              ),
              Divider(height: 1, color: border),
              Expanded(
                child: ListView.separated(
                  itemCount: lineItems.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: border.withValues(alpha: 0.4)),
                  itemBuilder: (_, i) {
                    final li = lineItems[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        SizedBox(
                          width: labelW,
                          child: Text(li,
                              style: MyntWebTextStyles.body(context,
                                  fontWeight: MyntFonts.medium, color: primary)),
                        ),
                        for (final p in cols)
                          SizedBox(
                            width: valW,
                            child: _ValueCell(value: values[li]?[p]),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final num? value;
  const _ValueCell({required this.value});

  @override
  Widget build(BuildContext context) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    if (value == null) {
      return Text(kEmDash,
          textAlign: TextAlign.right,
          style: MyntWebTextStyles.body(context, color: secondary));
    }
    final cr = value! / 1e7;
    final color = cr < 0 ? MyntColors.error : primary;
    return Text(
      cr.toStringAsFixed(2),
      textAlign: TextAlign.right,
      style: MyntWebTextStyles.body(context,
          fontWeight: MyntFonts.medium, color: color),
    );
  }
}

/// FY-quarter / FY-year label from an ISO period-end date.
/// Indian fiscal year: Apr–Mar. Quarter ending Jun=Q1, Sep=Q2, Dec=Q3,
/// Mar=Q4. FY for a quarter is the calendar year of the following March
/// (so the quarter ending Jun 2025 is Q1 FY26; the quarter ending Mar
/// 2026 is Q4 FY26).
String _periodLabel(String iso, String period) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final fy = d.month <= 3 ? d.year : d.year + 1;
  final yy = (fy % 100).toString().padLeft(2, '0');
  if (period == 'annual') return 'FY$yy';
  final q = switch (d.month) {
    >= 4 && <= 6 => 1,
    >= 7 && <= 9 => 2,
    >= 10 && <= 12 => 3,
    _ => 4, // Jan–Mar
  };
  return 'Q$q FY$yy';
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;
  /// When true the selected segment uses the brand-primary fill (used for
  /// the statement row); otherwise a subtle neutral fill (basis/period).
  final bool primary;
  const _Segmented({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final neutralSel = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.listItemBg);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < options.length; i++)
          _seg(
            context,
            label: labels[i],
            selected: value == options[i],
            primary: primary,
            neutralSel: neutralSel,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            onTap: () => onChanged(options[i]),
          ),
      ]),
    );
  }

  Widget _seg(
    BuildContext context, {
    required String label,
    required bool selected,
    required bool primary,
    required Color neutralSel,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    final Color bg;
    final Color fg;
    if (selected) {
      bg = primary ? MyntColors.primary : neutralSel;
      fg = primary ? Colors.white : textPrimary;
    } else {
      bg = Colors.transparent;
      fg = textSecondary;
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: bg,
        child: Text(label,
            style: MyntWebTextStyles.caption(context,
                fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
                color: fg)),
      ),
    );
  }
}

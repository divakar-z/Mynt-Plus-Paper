import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
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
        // const SizedBox(height: 12),
        // Pickers on the left; the unit note sits opposite them on the right of
        // the same row (it read as orphaned on its own line before).
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(spacing: 16, runSpacing: 8, children: [
                _Segmented(
                  options: const ['income', 'balance', 'cashflow'],
                  labels: const [
                    'Income Statement',
                    'Balance Sheet',
                    'Cash Flow'
                  ],
                  value: _statement,
                  onChanged: (v) => setState(() => _statement = v),
                ),
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
            ),
            const SizedBox(width: 12),
            Text('All values in ₹ Cr',
                style: MyntWebTextStyles.caption(context, color: secondary)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: async.when(
            loading: () => Center(child: MyntLoader.simple()),
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

/// Bordered `shadcn.Table` (the component the Positions / Holdings tables use):
/// a LINE ITEM column + one column per reporting period (newest first), values
/// in ₹ Cr with negatives in red. A fixed header table sits above a vertically
/// scrolling body of per-row tables; horizontal scroll handles the many period
/// columns. The LINE ITEM column grows to fill spare width when there are few
/// periods.
class _FinancialsTable extends StatefulWidget {
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
  State<_FinancialsTable> createState() => _FinancialsTableState();
}

class _FinancialsTableState extends State<_FinancialsTable> {
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final thumb = secondary.withValues(alpha: 0.5);

    // Newest period first — matches how users read recent-quarter-first.
    final cols = widget.periods.reversed.toList();
    const minLabelW = 220.0;
    const valW = 120.0;

    return LayoutBuilder(builder: (context, constraints) {
      // OutlinedContainer draws a 1px border on each side.
      final available =
          (constraints.maxWidth - 2).clamp(0.0, double.infinity);
      final valsW = valW * cols.length;
      // Grow LINE ITEM to absorb spare width (so the table fills when there are
      // few periods); otherwise keep it at min and scroll horizontally.
      final labelW =
          (minLabelW + valsW) < available ? available - valsW : minLabelW;
      final totalWidth = labelW + valsW;
      final needsHScroll = totalWidth > available + 0.5;

      final colWidths = {
        0: shadcn.FixedTableSize(labelW),
        for (int i = 0; i < cols.length; i++)
          i + 1: const shadcn.FixedTableSize(valW),
      };

      final headerTable = shadcn.Table(
        columnWidths: colWidths,
        defaultRowHeight: const shadcn.FixedTableSize(40),
        rows: [
          shadcn.TableHeader(
            cells: [
              _cell(
                background: headerBg,
                child: Text('Line Item',
                    style: MyntWebTextStyles.tableHeader(context,
                        fontWeight: MyntFonts.semiBold, color: secondary)),
              ),
              for (final p in cols)
                _cell(
                  background: headerBg,
                  alignment: Alignment.centerRight,
                  child: Text(_periodLabel(p, widget.period),
                      style: MyntWebTextStyles.tableHeader(context,
                          fontWeight: MyntFonts.semiBold, color: secondary)),
                ),
            ],
          ),
        ],
      );

      final rowDividerColor = border.withValues(alpha: 0.4);
      final bodyList = ListView.separated(
        controller: _vCtrl,
        itemCount: widget.lineItems.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: rowDividerColor),
        itemBuilder: (context, i) {
          final li = widget.lineItems[i];
          return shadcn.Table(
            columnWidths: colWidths,
            defaultRowHeight: const shadcn.FixedTableSize(40),
            rows: [
              shadcn.TableRow(
                cells: [
                  _cell(
                    child: Text(li,
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.medium, color: primary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  for (final p in cols)
                    _cell(
                      alignment: Alignment.centerRight,
                      child: _ValueCell(value: widget.values[li]?[p]),
                    ),
                ],
              ),
            ],
          );
        },
      );

      final tableBody = SizedBox(
        width: totalWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerTable,
            Divider(height: 1, color: border),
            Expanded(
              child: RawScrollbar(
                controller: _vCtrl,
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(8),
                thumbColor: thumb,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: bodyList,
              ),
            ),
          ],
        ),
      );

      return shadcn.OutlinedContainer(
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          behavior:
              const MaterialScrollBehavior().copyWith(scrollbars: false),
          child: RawScrollbar(
            controller: _hCtrl,
            thumbVisibility: needsHScroll,
            thickness: 6,
            radius: const Radius.circular(8),
            thumbColor: thumb,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _hCtrl,
              scrollDirection: Axis.horizontal,
              physics: needsHScroll
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: tableBody,
            ),
          ),
        ),
      );
    });
  }

  /// Borderless [shadcn.TableCell] — the [shadcn.OutlinedContainer] supplies the
  /// frame. [background] paints the header band.
  shadcn.TableCell _cell({
    required Widget child,
    AlignmentGeometry alignment = Alignment.centerLeft,
    Color? background,
  }) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        color: background,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
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
    const tabular = [FontFeature.tabularFigures()];
    if (value == null) {
      return Text(kEmDash,
          textAlign: TextAlign.right,
          style: MyntWebTextStyles.body(context, color: secondary)
              .copyWith(fontFeatures: tabular));
    }
    final cr = value! / 1e7;
    final color = cr < 0
        ? resolveThemeColor(context,
            dark: MyntColors.errorDark, light: MyntColors.error)
        : primary;
    return Text(
      cr.toStringAsFixed(2),
      textAlign: TextAlign.right,
      style: MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.medium, color: color)
          .copyWith(fontFeatures: tabular),
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
  const _Segmented({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < options.length; i++)
          _seg(
            context,
            label: labels[i],
            selected: value == options[i],
            isFirst: i == 0,
            isLast: i == options.length - 1,
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
    required bool isFirst,
    required bool isLast,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    // Selected = brand-blue fill + white text. Its outer corners round to match
    // the container (5) so the first/last segment respects the border radius.
    const r = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: isFirst ? r : Radius.zero,
      bottomLeft: isFirst ? r : Radius.zero,
      topRight: isLast ? r : Radius.zero,
      bottomRight: isLast ? r : Radius.zero,
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)
       : Colors.transparent,
          borderRadius: radius,
        ),
        child: Text(label,
            style: MyntWebTextStyles.para(context,
                fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
                color: selected ? Colors.white : textSecondary)),
      ),
    );
  }
}

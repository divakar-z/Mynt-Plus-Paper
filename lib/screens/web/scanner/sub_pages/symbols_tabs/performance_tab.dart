import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/performance.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

const _periodOrder = [
  '1D', '1W', '1M', '3M', '6M', '1Y', '2Y', '5Y', '10Y', 'MAX',
];

class PerformanceTab extends ConsumerWidget {
  final String ticker;
  const PerformanceTab({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(performanceProvider(ticker));
    return async.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load performance',
        message: e.toString(),
        onRetry: () => ref.invalidate(performanceProvider(ticker)),
      ),
      data: (resp) {
        if (resp.returns.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No performance data',
          );
        }
        final maxAbs = resp.returns.values
            .where((v) => v != null)
            .map((v) => v!.abs())
            .fold<double>(0, (acc, v) => v > acc ? v : acc);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final wide = c.maxWidth >= 700;
              if (!wide) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _table(context, resp),
                      const SizedBox(height: 16),
                      _bars(context, resp, maxAbs),
                    ],
                  ),
                );
              }
              // Wide: table on the left half, chart on the right half (50/50).
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _table(context, resp)),
                  const SizedBox(width: 24),
                  Expanded(child: _bars(context, resp, maxAbs)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The returns table as a `shadcn.Table` (the Positions / Holdings component):
  /// Period | Return | vs NIFTY, filling its half of the row.
  Widget _table(BuildContext context, PerformanceResponse resp) {
    final hasRelative = resp.relative != null;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final periods =
        _periodOrder.where((p) => resp.returns.containsKey(p)).toList();

    return LayoutBuilder(builder: (ctx, c) {
      // OutlinedContainer draws a 1px border on each side.
      final available = (c.maxWidth - 2).clamp(0.0, double.infinity);
      const periodW = 80.0;
      final dataCols = hasRelative ? 2 : 1;
      final dataW =
          ((available - periodW) / dataCols).clamp(80.0, double.infinity);

      final colWidths = {
        0: const shadcn.FixedTableSize(periodW),
        1: shadcn.FixedTableSize(dataW),
        if (hasRelative) 2: shadcn.FixedTableSize(dataW),
      };

      return shadcn.OutlinedContainer(
        clipBehavior: Clip.antiAlias,
        child: shadcn.Table(
          columnWidths: colWidths,
          defaultRowHeight: const shadcn.FixedTableSize(40),
          rows: [
            shadcn.TableHeader(
              cells: [
                _cell(context,
                    background: headerBg,
                    child: Text('Period',
                        style: MyntWebTextStyles.tableHeader(context,
                            fontWeight: MyntFonts.semiBold, color: secondary))),
                _cell(context,
                    background: headerBg,
                    alignment: Alignment.centerRight,
                    child: Text('Return',
                        style: MyntWebTextStyles.tableHeader(context,
                            fontWeight: MyntFonts.semiBold, color: secondary))),
                if (hasRelative)
                  _cell(context,
                      background: headerBg,
                      alignment: Alignment.centerRight,
                      child: Text('vs NIFTY',
                          style: MyntWebTextStyles.tableHeader(context,
                              fontWeight: MyntFonts.semiBold,
                              color: secondary))),
              ],
            ),
            for (final p in periods)
              shadcn.TableRow(
                cells: [
                  _cell(context,
                      child: Text(p,
                          style: MyntWebTextStyles.tableCell(context,
                              color: primary))),
                  _cell(context,
                      alignment: Alignment.centerRight,
                      child: _pctText(context, resp.returns[p])),
                  if (hasRelative)
                    _cell(context,
                        alignment: Alignment.centerRight,
                        child: _pctText(context, resp.relative?[p])),
                ],
              ),
          ],
        ),
      );
    });
  }

  /// Borderless [shadcn.TableCell] — the [shadcn.OutlinedContainer] supplies the
  /// frame. [background] paints the header band.
  shadcn.TableCell _cell(
    BuildContext context, {
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: child,
      ),
    );
  }

  Widget _pctText(BuildContext ctx, double? v) => Text(
        formatPercent(v == null ? null : v / 100, signed: true),
        style: MyntWebTextStyles.tableCell(ctx,
            fontWeight: MyntFonts.medium, color: signedColor(ctx, v)),
      );

  Widget _bars(
      BuildContext context, PerformanceResponse resp, double maxAbs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in _periodOrder)
          if (resp.returns.containsKey(p))
            _barRow(context, p, resp.returns[p] ?? 0, maxAbs),
      ],
    );
  }

  Widget _barRow(BuildContext ctx, String label, double v, double maxAbs) {
    final color = v >= 0
        ? resolveThemeColor(ctx,
            dark: MyntColors.successDark, light: MyntColors.success)
        : resolveThemeColor(ctx,
            dark: MyntColors.errorDark, light: MyntColors.error);
    final widthFactor =
        maxAbs == 0 ? 0.0 : (v.abs() / maxAbs).clamp(0.0, 1.0);
    final bg = resolveThemeColor(ctx,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 36,
              child: Text(label, style: MyntWebTextStyles.para(ctx))),
          Expanded(
            child: Stack(children: [
              Container(height: 18, color: bg),
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(height: 18, color: color),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(formatPercent(v / 100, signed: true),
                textAlign: TextAlign.right,
                style: MyntWebTextStyles.para(ctx, color: color)),
          ),
        ],
      ),
    );
  }
}

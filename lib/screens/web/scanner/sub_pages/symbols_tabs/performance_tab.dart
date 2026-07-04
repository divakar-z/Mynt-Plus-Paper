import 'package:flutter/material.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
              final tableW = wide ? 360.0 : c.maxWidth;
              final children = <Widget>[
                SizedBox(width: tableW, child: _table(context, resp)),
                if (wide) const SizedBox(width: 24),
                Expanded(child: _bars(context, resp, maxAbs)),
              ];
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children)
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
            },
          ),
        );
      },
    );
  }

  Widget _table(BuildContext context, PerformanceResponse resp) {
    final hasRelative = resp.relative != null;
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      children: [
        TableRow(children: [
          _hd(context, 'Period'),
          _hd(context, 'Return'),
          if (hasRelative) _hd(context, 'vs NIFTY'),
        ]),
        for (final p in _periodOrder)
          if (resp.returns.containsKey(p))
            TableRow(children: [
              _cell(context, p),
              _pctCell(context, resp.returns[p]),
              if (hasRelative)
                _pctCell(context, resp.relative?[p]),
            ]),
      ],
    );
  }

  Widget _hd(BuildContext ctx, String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t,
            style:
                MyntWebTextStyles.caption(ctx, fontWeight: MyntFonts.semiBold)),
      );

  Widget _cell(BuildContext ctx, String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t, style: MyntWebTextStyles.body(ctx)),
      );

  Widget _pctCell(BuildContext ctx, double? v) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          formatPercent(v == null ? null : v / 100, signed: true),
          style: MyntWebTextStyles.body(ctx,
              fontWeight: MyntFonts.medium, color: signedColor(ctx, v)),
        ),
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
    final color = v >= 0 ? MyntColors.success : MyntColors.error;
    final widthFactor =
        maxAbs == 0 ? 0.0 : (v.abs() / maxAbs).clamp(0.0, 1.0);
    final bg = resolveThemeColor(ctx,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 36,
              child: Text(label, style: MyntWebTextStyles.caption(ctx))),
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
                style: MyntWebTextStyles.caption(ctx, color: color)),
          ),
        ],
      ),
    );
  }
}

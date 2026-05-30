// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

import '../../../state/chart_engine_store.dart';

class PositionsPanel extends ConsumerWidget {
  final ValueChanged<ChartScrip> onSymbolPick;

  const PositionsPanel({super.key, required this.onSymbolPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);
    final all = portfolio.postionBookModel ?? const <PositionBookModel>[];

    final open = all.where((p) {
      if (p.stat == 'Not_Ok') return false;
      final qty = int.tryParse(p.netqty ?? '0') ?? 0;
      return qty != 0;
    }).toList();

    final divider = resolveThemeColor(
      context,
      dark: MyntColors.dividerDark,
      light: MyntColors.divider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: 'Positions',
          subtitle: open.isEmpty ? null : '${open.length} open',
        ),
        Divider(height: 1, color: divider),
        if (open.isNotEmpty) _TotalPnlCard(positions: open),
        if (open.isNotEmpty) Divider(height: 1, color: divider),
        if (open.isNotEmpty)
          _ExitAllButton(
            positions: open,
            onExitAll: () => _exitAllPositions(context, ref, open),
          ),
        if (open.isNotEmpty) Divider(height: 1, color: divider),
        Expanded(
          child: open.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  itemCount: open.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: divider),
                  itemBuilder: (ctx, i) {
                    final p = open[i];
                    return _PositionTile(
                      position: p,
                      onTap: () => onSymbolPick(_chartScripFor(p)),
                      onExit: () => _confirmExitOne(context, ref, p),
                    );
                  },
                ),
        ),
      ],
    );
  }

  ChartScrip _chartScripFor(PositionBookModel p) => ChartScrip(
        exch: p.exch ?? 'NSE',
        token: p.token ?? '',
        tsym: p.tsym ?? '',
        dispName: p.dname ?? p.tsym ?? '',
        ls: int.tryParse(p.ls ?? '') ?? 1,
        ti: double.tryParse(p.ti ?? '') ?? 0.05,
        instname: '',
      );

  Future<void> _confirmExitOne(
    BuildContext context,
    WidgetRef ref,
    PositionBookModel p,
  ) async {
    final symbol = p.dname ?? p.tsym ?? 'this position';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit position'),
        content: Text('Exit $symbol?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MyntColors.loss),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _exitSingle(context, ref, p);
  }

  Future<void> _exitAllPositions(
    BuildContext context,
    WidgetRef ref,
    List<PositionBookModel> positions,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit all positions'),
        content: Text(
            'Square off all ${positions.length} open position(s) at market?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: MyntColors.loss),
            child: const Text('Exit All'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final p in positions) {
      await _exitSingle(context, ref, p);
    }
  }

  Future<void> _exitSingle(
    BuildContext context,
    WidgetRef ref,
    PositionBookModel p,
  ) async {
    final qtyInt = int.tryParse(p.netqty ?? '0') ?? 0;
    if (qtyInt == 0) return;

    final ls = int.tryParse(p.ls ?? '1') ?? 1;
    final frz = int.tryParse(p.frzqty ?? '0') ?? 0;
    final frzqty = ls > 0 ? (frz ~/ ls) * ls : frz;

    final deviceInfo = ref.read(authProvider).deviceInfo;
    final channel = defaultTargetPlatform == TargetPlatform.android
        ? '${deviceInfo["brand"]}'
        : '${deviceInfo["model"]}';

    final input = PlaceOrderInput(
      exch: p.exch ?? '',
      tsym: p.tsym ?? '',
      qty: (p.netqty ?? '0').replaceAll('-', ''),
      prc: '0',
      prctype: 'MKT',
      trantype: qtyInt < 0 ? 'B' : 'S',
      prd: p.prd ?? '',
      ret: 'DAY',
      trgprc: '',
      blprc: '',
      bpprc: '',
      dscqty: '',
      amo: '',
      trailprc: '',
      mktProt: '',
      channel: channel,
      frzqty: frzqty,
    );

    await ref
        .read(portfolioProvider)
        .fetchExitPosition(context, input, true, true);
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _PanelHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Text(
          title,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.semiBold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            '· $subtitle',
            style: MyntWebTextStyles.caption(context),
          ),
        ],
      ]),
    );
  }
}

class _TotalPnlCard extends ConsumerWidget {
  final List<PositionBookModel> positions;
  const _TotalPnlCard({required this.positions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(websocketProvider);
    double total = 0;
    for (final p in positions) {
      if (p.stat == 'Not_Ok') continue;
      total += double.tryParse(p.profitNloss ?? '') ?? 0;
    }
    final color = total >= 0 ? MyntColors.profit : MyntColors.loss;

    return SizedBox(
      height: 70,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              total.toStringAsFixed(2),
              style: MyntWebTextStyles.head(
                context,
                fontWeight: MyntFonts.bold,
                darkColor: color,
                lightColor: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Total P&L',
              style: MyntWebTextStyles.caption(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitAllButton extends StatelessWidget {
  final List<PositionBookModel> positions;
  final VoidCallback onExitAll;
  const _ExitAllButton({required this.positions, required this.onExitAll});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExitAll,
          child: Center(
            child: Text(
              'Exit All Positions',
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.semiBold,
                darkColor: MyntColors.loss,
                lightColor: MyntColors.loss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No open positions',
          style: MyntWebTextStyles.caption(context),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PositionTile extends ConsumerStatefulWidget {
  final PositionBookModel position;
  final VoidCallback onTap;
  final VoidCallback onExit;

  const _PositionTile({
    required this.position,
    required this.onTap,
    required this.onExit,
  });

  @override
  ConsumerState<_PositionTile> createState() => _PositionTileState();
}

class _PositionTileState extends ConsumerState<_PositionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    final ws = ref.watch(websocketProvider);
    final socket = ws.socketDatas[p.token];

    final liveLpStr = socket?['lp']?.toString() ?? socket?['ltp']?.toString();
    final lp = (liveLpStr != null &&
            liveLpStr.isNotEmpty &&
            liveLpStr != 'null' &&
            liveLpStr != '0' &&
            liveLpStr != '0.0' &&
            liveLpStr != '0.00')
        ? liveLpStr
        : (p.lp ?? '-');

    final netqty = int.tryParse(p.netqty ?? '0') ?? 0;
    final isLong = netqty > 0;
    final sideColor = isLong ? MyntColors.profit : MyntColors.loss;
    final sideLabel = isLong ? 'LONG' : 'SHORT';

    final pnl = double.tryParse(p.profitNloss ?? '') ?? 0;
    final pnlColor = pnl >= 0 ? MyntColors.profit : MyntColors.loss;

    final hoverBg = resolveThemeColor(
      context,
      dark: MyntColors.cardHoverDark,
      light: MyntColors.cardHover,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 76,
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _ExchChip(p.exch ?? ''),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.dname ?? p.tsym ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _SidePill(label: sideLabel, color: sideColor),
              ]),
              Text(
                'Qty ${netqty.abs()} · Avg ${p.avgPrc ?? '-'} · LP $lp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.caption(context),
              ),
              Row(children: [
                Expanded(
                  child: Text(
                    pnl.toStringAsFixed(2),
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: pnlColor,
                      lightColor: pnlColor,
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: widget.onExit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MyntColors.loss,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: MyntColors.loss.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'Exit',
                      style: MyntWebTextStyles.caption(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        darkColor: MyntColors.loss,
                        lightColor: MyntColors.loss,
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchChip extends StatelessWidget {
  final String exch;
  const _ExchChip(this.exch);

  @override
  Widget build(BuildContext context) {
    final upper = exch.toUpperCase();
    final color = (upper == 'NFO' || upper == 'BFO' || upper == 'MCX')
        ? MyntColors.warning
        : MyntColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        exch,
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.semiBold,
          darkColor: color,
          lightColor: color,
        ),
      ),
    );
  }
}

class _SidePill extends StatelessWidget {
  final String label;
  final Color color;
  const _SidePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.bold,
          darkColor: Colors.white,
          lightColor: Colors.white,
        ),
      ),
    );
  }
}

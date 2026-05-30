import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/portfolio_model/holdings_model.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import '../../../state/chart_engine_store.dart';

class HoldingsPanel extends ConsumerWidget {
  final ValueChanged<ChartScrip> onSymbolPick;

  const HoldingsPanel({super.key, required this.onSymbolPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);
    final ws = ref.watch(websocketProvider);
    final all = portfolio.holdingsModel ?? <HoldingsModel>[];
    final rows = all
        .where((h) =>
            h.stat != 'Not_Ok' && (h.exchTsym?.isNotEmpty ?? false))
        .toList();

    final totals = _computeTotals(rows, ws.socketDatas);

    final dividerColor = Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(count: rows.length),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: _SummaryCard(totals: totals),
        ),
        Divider(height: 1, color: dividerColor),
        if (rows.isEmpty)
          const _EmptyState()
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: dividerColor),
              itemBuilder: (ctx, i) {
                final h = rows[i];
                return _HoldingTile(
                  holding: h,
                  socketLtp: _socketLtp(ws.socketDatas, h.exchTsym![0].token),
                  onTap: () {
                    final ex = h.exchTsym![0];
                    onSymbolPick(ChartScrip(
                      exch: ex.exch ?? 'NSE',
                      token: ex.token ?? '',
                      tsym: ex.tsym ?? '',
                      dispName: ex.tsym ?? ex.symbol ?? '',
                      ls: int.tryParse(ex.ls ?? '') ?? 1,
                      ti: double.tryParse(ex.ti ?? '') ?? 0.05,
                      instname: '',
                    ));
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  static _Totals _computeTotals(
      List<HoldingsModel> rows, Map socketDatas) {
    double invested = 0;
    double current = 0;
    double totalPnl = 0;
    double oneDay = 0;

    for (final h in rows) {
      final ex = h.exchTsym![0];
      final qty = double.tryParse(h.holdqty ?? '0') ?? 0;
      final upld = double.tryParse(h.upldprc ?? '0') ?? 0;
      final inv = upld * qty;

      final liveLp = _socketLtp(socketDatas, ex.token);
      final lp = liveLp ?? double.tryParse(ex.lp ?? '0') ?? 0;
      final curStored = double.tryParse(h.currentValue ?? '0') ?? 0;
      final cur = (curStored != 0) ? curStored : lp * qty;

      final pnl = double.tryParse(h.totalPnL ?? '') ??
          double.tryParse(ex.profitNloss ?? '') ??
          (cur - inv);
      final dayChg = double.tryParse(ex.oneDayChg ?? '') ?? 0;

      invested += inv;
      current += cur;
      totalPnl += pnl;
      oneDay += dayChg;
    }

    final pnlPct = invested > 0 ? (totalPnl / invested) * 100 : 0.0;
    final dayPct = current > 0 ? (oneDay / current) * 100 : 0.0;

    return _Totals(
      invested: invested,
      current: current,
      totalPnl: totalPnl,
      totalPnlPct: pnlPct,
      oneDayChange: oneDay,
      oneDayChangePct: dayPct,
    );
  }

  static double? _socketLtp(Map socketDatas, String? token) {
    if (token == null || token.isEmpty) return null;
    final s = socketDatas[token];
    if (s == null) return null;
    final raw = s['lp'] ?? s['ltp'];
    if (raw == null) return null;
    final n = double.tryParse(raw.toString());
    if (n == null || n == 0) return null;
    return n;
  }
}

class _Totals {
  final double invested;
  final double current;
  final double totalPnl;
  final double totalPnlPct;
  final double oneDayChange;
  final double oneDayChangePct;
  const _Totals({
    required this.invested,
    required this.current,
    required this.totalPnl,
    required this.totalPnlPct,
    required this.oneDayChange,
    required this.oneDayChangePct,
  });
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('Holdings',
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold)),
          const SizedBox(width: 8),
          Text(
            count == 0
                ? ''
                : '$count ${count == 1 ? 'stock' : 'stocks'}',
            style: MyntWebTextStyles.caption(context),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _Totals totals;
  const _SummaryCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    final border = resolveThemeColor(
      context,
      dark: Colors.white.withValues(alpha: 0.08),
      light: Colors.black.withValues(alpha: 0.08),
    );
    final bg = resolveThemeColor(
      context,
      dark: Colors.white.withValues(alpha: 0.03),
      light: Colors.black.withValues(alpha: 0.02),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryCell(
                  label: '1D Change',
                  value: _fmtSigned(totals.oneDayChange),
                  pct: _fmtPct(totals.oneDayChangePct),
                  color: _signColor(totals.oneDayChange),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCell(
                  label: 'Total P&L',
                  value: _fmtSigned(totals.totalPnl),
                  pct: _fmtPct(totals.totalPnlPct),
                  color: _signColor(totals.totalPnl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'Invested',
                  value: _fmt(totals.invested),
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCell(
                  label: 'Current',
                  value: _fmt(totals.current),
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _signColor(double v) {
    if (v > 0) return MyntColors.profit;
    if (v < 0) return MyntColors.loss;
    return MyntColors.textSecondary;
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final String? pct;
  final Color color;
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
    this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.caption(context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              )),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.semiBold,
              darkColor: color,
              lightColor: color),
        ),
        if (pct != null) ...[
          const SizedBox(height: 2),
          Text(
            pct!,
            style: MyntWebTextStyles.caption(context,
                darkColor: color, lightColor: color),
          ),
        ],
      ],
    );
  }
}

class _HoldingTile extends StatefulWidget {
  final HoldingsModel holding;
  final double? socketLtp;
  final VoidCallback onTap;

  const _HoldingTile({
    required this.holding,
    required this.socketLtp,
    required this.onTap,
  });

  @override
  State<_HoldingTile> createState() => _HoldingTileState();
}

class _HoldingTileState extends State<_HoldingTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.holding;
    final ex = h.exchTsym![0];

    final qty = double.tryParse(h.holdqty ?? '0') ?? 0;
    final avg = double.tryParse(h.avgPrc ?? '') ??
        double.tryParse(h.upldprc ?? '0') ??
        0;
    final upld = double.tryParse(h.upldprc ?? '0') ?? 0;
    final invested = upld * qty;

    final lp = widget.socketLtp ?? double.tryParse(ex.lp ?? '0') ?? 0;

    final pnl = double.tryParse(h.totalPnL ?? '') ??
        double.tryParse(ex.profitNloss ?? '') ??
        ((lp - avg) * qty);
    final pctRaw = double.tryParse(ex.perChange ?? '');
    final pct = pctRaw ?? (avg > 0 ? ((lp - avg) / avg) * 100 : 0);

    final pnlColor =
        pnl > 0 ? MyntColors.profit : (pnl < 0 ? MyntColors.loss : MyntColors.textSecondary);

    final pledged = _isPledged(h);

    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 74,
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _ExchChip(ex.exch ?? ''),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ex.tsym ?? ex.symbol ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold),
                          ),
                        ),
                        if (pledged) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'QTY ${_intStr(qty)}  AVG ${avg.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.caption(context),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'INV ${invested.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.caption(context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtSigned(pnl),
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.semiBold,
                        darkColor: pnlColor,
                        lightColor: pnlColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtPct(pct.toDouble()),
                    style: MyntWebTextStyles.caption(context,
                        darkColor: pnlColor, lightColor: pnlColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LTP ${lp.toStringAsFixed(2)}',
                    style: MyntWebTextStyles.caption(context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary,
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPledged(HoldingsModel h) {
    final dp = double.tryParse(h.dpQty ?? '');
    final cur = h.currentQty?.toDouble();
    if (dp == null || cur == null) return false;
    return dp != cur;
  }

  String _intStr(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _ExchChip extends StatelessWidget {
  final String exch;
  const _ExchChip(this.exch);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: MyntColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        exch,
        style: MyntWebTextStyles.caption(context,
            fontWeight: MyntFonts.semiBold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No holdings',
            style: MyntWebTextStyles.caption(context),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

String _fmt(double v) => v.toStringAsFixed(2);

String _fmtSigned(double v) {
  if (v > 0) return '+${v.toStringAsFixed(2)}';
  return v.toStringAsFixed(2);
}

String _fmtPct(double v) {
  final sign = v > 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(2)}%';
}

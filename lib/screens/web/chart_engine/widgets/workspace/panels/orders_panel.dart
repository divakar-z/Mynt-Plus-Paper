// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

import '../../../state/chart_engine_store.dart';

const Set<String> _kOpenStatuses = {'OPEN', 'TRIGGER_PENDING', 'OPEN_PARTIAL'};
const Set<String> _kExecutedStatuses = {
  'COMPLETE',
  'CANCELED',
  'CANCELLED',
  'REJECTED',
  'EXPIRED',
};

class OrdersPanel extends ConsumerStatefulWidget {
  final ValueChanged<ChartScrip> onSymbolPick;
  const OrdersPanel({super.key, required this.onSymbolPick});

  @override
  ConsumerState<OrdersPanel> createState() => _OrdersPanelState();
}

class _OrdersPanelState extends ConsumerState<OrdersPanel> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final ordp = ref.watch(orderProvider);
    final orders = ordp.orderBookModel ?? const <OrderBookModel>[];

    final open = <OrderBookModel>[];
    final executed = <OrderBookModel>[];
    for (final o in orders) {
      final s = (o.status ?? '').toUpperCase();
      if (_kOpenStatuses.contains(s)) {
        open.add(o);
      } else if (_kExecutedStatuses.contains(s)) {
        executed.add(o);
      }
    }

    final border = Theme.of(context).dividerColor;
    final List<OrderBookModel> active = _activeTab == 0 ? open : executed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(total: open.length + executed.length),
        Container(height: 1, color: border),
        _TabStrip(
          openCount: open.length,
          executedCount: executed.length,
          activeIndex: _activeTab,
          onTap: (i) {
            if (i == _activeTab) return;
            setState(() => _activeTab = i);
          },
        ),
        Container(height: 1, color: border),
        if (active.isEmpty)
          _EmptyPanel(
            message: _activeTab == 0
                ? 'No open orders'
                : 'No executed orders',
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: active.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: border, thickness: 0.5),
              itemBuilder: (ctx, i) => _OrderTile(
                order: active[i],
                isOpenTab: _activeTab == 0,
                onPick: widget.onSymbolPick,
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int total;
  const _Header({required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(
              'Orders',
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '· $total total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.caption(
                context,
                darkColor: MyntColors.textSecondaryDark,
                lightColor: MyntColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final int openCount;
  final int executedCount;
  final int activeIndex;
  final ValueChanged<int> onTap;
  const _TabStrip({
    required this.openCount,
    required this.executedCount,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = resolveThemeColor(
      context,
      dark: MyntColors.primaryDark,
      light: MyntColors.primary,
    );
    final muted = resolveThemeColor(
      context,
      dark: MyntColors.textSecondaryDark,
      light: MyntColors.textSecondary,
    );

    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _TabChip(
              label: 'Open',
              count: openCount,
              selected: activeIndex == 0,
              accent: accent,
              muted: muted,
              onTap: () => onTap(0),
            ),
            _TabChip(
              label: 'Executed',
              count: executedCount,
              selected: activeIndex == 1,
              accent: accent,
              muted: muted,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(
      context,
      dark: MyntColors.cardHoverDark,
      light: MyntColors.cardHover,
    );
    final color = widget.selected ? widget.accent : widget.muted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hover && !widget.selected ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text(
                '${widget.label} ${widget.count}',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: widget.selected
                      ? MyntFonts.semiBold
                      : MyntFonts.medium,
                  darkColor: color,
                  lightColor: color,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: widget.selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;
  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.caption(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends ConsumerStatefulWidget {
  final OrderBookModel order;
  final bool isOpenTab;
  final ValueChanged<ChartScrip> onPick;
  const _OrderTile({
    required this.order,
    required this.isOpenTab,
    required this.onPick,
  });

  @override
  ConsumerState<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends ConsumerState<_OrderTile> {
  bool _hover = false;
  bool _cancelling = false;

  Future<void> _confirmAndCancel() async {
    if (_cancelling) return;
    final o = widget.order;
    final ordno = o.norenordno ?? '';
    if (ordno.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final bg = resolveThemeColor(
          ctx,
          dark: MyntColors.cardDark,
          light: MyntColors.card,
        );
        return AlertDialog(
          backgroundColor: bg,
          title: Text(
            'Cancel order?',
            style: MyntWebTextStyles.body(
              ctx,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          content: Text(
            '${o.dname ?? o.tsym ?? ''}\n${o.trantype == 'B' ? 'Buy' : 'Sell'} ${o.qty ?? ''} @ ${o.prc ?? ''}',
            style: MyntWebTextStyles.bodySmall(ctx),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Cancel order',
                style: TextStyle(color: MyntColors.loss),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _cancelling = true);
    try {
      final ordp = ref.read(orderProvider);
      await ordp.fetchOrderCancel(ordno, context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel order')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _stubModify() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modify from main Orders screen'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _timeStr() {
    final raw = widget.order.exchTm ?? widget.order.norentm ?? '';
    if (raw.isEmpty) return '';
    final parts = raw.split(' ');
    for (final p in parts) {
      if (p.contains(':')) {
        final segs = p.split(':');
        if (segs.length >= 2) return '${segs[0]}:${segs[1]}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final token = o.token ?? '';
    final dispName = o.dname ?? o.tsym ?? '';
    final isBuy = (o.trantype ?? '').toUpperCase() == 'B';
    final sideColor = isBuy ? MyntColors.profit : MyntColors.loss;

    final socket = ref.watch(websocketProvider).socketDatas[token]
        as Map<dynamic, dynamic>?;
    final ltp = _str(socket?['lp'] ?? o.ltp ?? '');

    final filled = o.fillshares ?? '0';
    final qty = o.qty ?? '0';
    final price = o.prc ?? '0';
    final prctyp = o.prctyp ?? '';
    final prd = o.prd ?? '';
    final exch = o.exch ?? '';
    final timeStr = _timeStr();

    final status = (o.status ?? '').toUpperCase();

    final hoverBg = resolveThemeColor(
      context,
      dark: MyntColors.cardHoverDark,
      light: MyntColors.cardHover,
    );

    final mutedDark = MyntColors.textSecondaryDark;
    final mutedLight = MyntColors.textSecondary;

    final captionParts = <String>[
      if (exch.isNotEmpty) exch,
      if (prd.isNotEmpty) prd,
      if (prctyp.isNotEmpty) prctyp,
      if (timeStr.isNotEmpty) timeStr,
    ];
    final caption = captionParts.join(' · ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onPick(
          ChartScrip(
            exch: o.exch ?? 'NSE',
            token: o.token ?? '',
            tsym: o.tsym ?? '',
            dispName: o.dname ?? o.tsym ?? '',
            ls: int.tryParse(o.ls ?? '') ?? 1,
            ti: double.tryParse(o.ti ?? '') ?? 0.05,
            instname: o.instname ?? '',
          ),
        ),
        child: Container(
          height: 76,
          color: _hover ? hoverBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _SideChip(isBuy: isBuy, color: sideColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dispName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(status: status),
                ],
              ),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.caption(
                    context,
                    darkColor: mutedDark,
                    lightColor: mutedLight,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Qty $filled/$qty · @${_fmt(price)}${ltp.isNotEmpty ? '  LTP ${_fmt(ltp)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.caption(
                        context,
                        darkColor: mutedDark,
                        lightColor: mutedLight,
                      ),
                    ),
                  ),
                  if (widget.isOpenTab) ...[
                    _ActionIcon(
                      icon: _cancelling
                          ? Icons.hourglass_top
                          : Icons.close_rounded,
                      tooltip: 'Cancel',
                      color: MyntColors.loss,
                      onTap: _cancelling ? null : _confirmAndCancel,
                    ),
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Modify',
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ),
                      onTap: _stubModify,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();

  static String _fmt(String v) {
    if (v.isEmpty || v == 'null') return '0.00';
    final n = double.tryParse(v);
    return n == null ? v : n.toStringAsFixed(2);
  }
}

class _SideChip extends StatelessWidget {
  final bool isBuy;
  final Color color;
  const _SideChip({required this.isBuy, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        isBuy ? 'B' : 'S',
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color base;
    String label = status;
    switch (status) {
      case 'COMPLETE':
        base = MyntColors.profit;
        label = 'COMPLETE';
        break;
      case 'CANCELED':
      case 'CANCELLED':
        base = MyntColors.loss;
        label = 'CANCELLED';
        break;
      case 'REJECTED':
        base = MyntColors.loss;
        break;
      case 'EXPIRED':
        base = resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary,
        );
        break;
      case 'OPEN':
      case 'OPEN_PARTIAL':
      case 'TRIGGER_PENDING':
        base = const Color(0xFFD89614);
        break;
      default:
        base = resolveThemeColor(
          context,
          dark: MyntColors.textSecondaryDark,
          light: MyntColors.textSecondary,
        );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: MyntWebTextStyles.caption(
          context,
          fontWeight: MyntFonts.semiBold,
          darkColor: base,
          lightColor: base,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor:
            disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hover && !disabled
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 16,
              color: disabled
                  ? widget.color.withValues(alpha: 0.4)
                  : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

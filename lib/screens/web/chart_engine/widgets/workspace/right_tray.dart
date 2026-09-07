import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import '../../state/chart_engine_store.dart';
import 'dom_panel.dart';
import 'panels/holdings_panel.dart';
import 'panels/option_chain_panel.dart';
import 'panels/orders_panel.dart';
import 'panels/positions_panel.dart';
import 'panels/watchlist_panel.dart';

enum RightTrayTab { watchlist, positions, holdings, orders, dom, optionChain }

class RightTray extends ConsumerWidget {
  final RightTrayTab? openTab;
  final ValueChanged<RightTrayTab> onTabTap;
  final ValueChanged<ChartScrip> onSymbolPick;

  const RightTray({
    super.key,
    required this.openTab,
    required this.onTabTap,
    required this.onSymbolPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = Theme.of(context).dividerColor;
    final bg = resolveThemeColor(
      context,
      dark: MyntColors.cardDark,
      light: MyntColors.card,
    );

    return Row(children: [
      if (openTab != null)
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: bg,
            border: Border(left: BorderSide(color: border)),
          ),
          child: _buildPanel(openTab!),
        ),
      Container(
        width: 40,
        decoration: BoxDecoration(
          color: bg,
          border: Border(left: BorderSide(color: border)),
        ),
        child: Column(children: [
          _trayIcon(
              context, RightTrayTab.watchlist, Icons.list_alt, 'Watchlist'),
          _trayIcon(context, RightTrayTab.positions,
              Icons.account_balance_wallet_outlined, 'Positions'),
          _trayIcon(context, RightTrayTab.holdings,
              Icons.inventory_2_outlined, 'Holdings'),
          _trayIcon(context, RightTrayTab.orders,
              Icons.receipt_long_outlined, 'Orders'),
          _trayIcon(
              context, RightTrayTab.dom, Icons.view_agenda_outlined, 'DOM'),
          _trayIcon(context, RightTrayTab.optionChain,
              Icons.candlestick_chart_outlined, 'Option chain'),
        ]),
      ),
    ]);
  }

  Widget _trayIcon(
    BuildContext context,
    RightTrayTab tab,
    IconData icon,
    String tooltip,
  ) {
    final active = openTab == tab;
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onTabTap(tab),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: active
                ? Border(right: BorderSide(color: accent, width: 2))
                : null,
          ),
          child: Icon(icon, size: 18, color: active ? accent : muted),
        ),
      ),
    );
  }

  Widget _buildPanel(RightTrayTab tab) {
    switch (tab) {
      case RightTrayTab.watchlist:
        return WatchlistPanel(onSymbolPick: onSymbolPick);
      case RightTrayTab.positions:
        return PositionsPanel(onSymbolPick: onSymbolPick);
      case RightTrayTab.holdings:
        return HoldingsPanel(onSymbolPick: onSymbolPick);
      case RightTrayTab.orders:
        return OrdersPanel(onSymbolPick: onSymbolPick);
      case RightTrayTab.dom:
        return DomPanel(onSymbolPick: onSymbolPick);
      case RightTrayTab.optionChain:
        return OptionChainPanel(onSymbolPick: onSymbolPick);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'symbols_tabs/deliveries_tab.dart';
import 'symbols_tabs/financials_tab.dart';
import 'symbols_tabs/fundamental_tab.dart';
import 'symbols_tabs/holders_tab.dart';
import 'symbols_tabs/peers_tab.dart';
import 'symbols_tabs/performance_tab.dart';
import 'symbols_tabs/prices_tab.dart';
import 'symbols_tabs/scans_tab.dart';
import 'symbols_tabs/technicals_tab.dart';

class SymbolsDetailPane extends ConsumerStatefulWidget {
  final String ticker;
  final VoidCallback onBack;
  final ValueChanged<String> onPeerTap;

  const SymbolsDetailPane({
    super.key,
    required this.ticker,
    required this.onBack,
    required this.onPeerTap,
  });

  @override
  ConsumerState<SymbolsDetailPane> createState() => _SymbolsDetailPaneState();
}

class _SymbolsDetailPaneState extends ConsumerState<SymbolsDetailPane>
    with TickerProviderStateMixin {
  late TabController _tab;
  static const _tabs = [
    'Prices', 'Scans', 'Technicals', 'Performance',
    'Fundamental', 'Financials', 'Peers', 'Holders', 'Deliveries',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(ticker: widget.ticker, onBack: widget.onBack),
        const SizedBox(height: 12),
        _buildTabBar(),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              PricesTab(ticker: widget.ticker),
              ScansTab(ticker: widget.ticker),
              TechnicalsTab(ticker: widget.ticker),
              PerformanceTab(ticker: widget.ticker),
              FundamentalTab(ticker: widget.ticker),
              FinancialsTab(ticker: widget.ticker),
              PeersTab(ticker: widget.ticker, onPeerTap: widget.onPeerTap),
              HoldersTab(ticker: widget.ticker),
              DeliveriesTab(ticker: widget.ticker),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tab,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: MyntColors.primary,
      labelColor: MyntColors.primary,
      unselectedLabelColor: resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
      tabs: [for (final t in _tabs) Tab(text: t)],
    );
  }
}

class _Header extends ConsumerWidget {
  final String ticker;
  final VoidCallback onBack;
  const _Header({required this.ticker, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(symbolMetaProvider(ticker));
    final ohlcv = ref.watch(ohlcvProvider((ticker: ticker, from: null)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(shadcn.LucideIcons.arrowLeft,
                    size: 18,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary)),
                tooltip: 'Back to search',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                ticker,
                style: MyntWebTextStyles.hero(context,
                    fontWeight: MyntFonts.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: resolveThemeColor(context,
                      dark: MyntColors.listItemBgDark,
                      light: MyntColors.listItemBg),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('NSE',
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.medium)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          meta.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => Text(s.name,
                style: MyntWebTextStyles.body(context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary))),
          ),
          const SizedBox(height: 6),
          ohlcv.when(
            loading: () => Text('Loading price…',
                style: MyntWebTextStyles.caption(context)),
            error: (e, _) => Text(e.toString(),
                style: MyntWebTextStyles.caption(context,
                    color: MyntColors.error)),
            data: (resp) {
              if (resp.bars.isEmpty) {
                return Text('No price data',
                    style: MyntWebTextStyles.caption(context));
              }
              final last = resp.bars.last;
              final prev = resp.bars.length > 1
                  ? resp.bars[resp.bars.length - 2]
                  : last;
              final lastClose = last.close ?? 0;
              final prevClose = prev.close ?? lastClose;
              final change = lastClose - prevClose;
              final pct = prevClose == 0 ? 0.0 : change / prevClose;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    last.close == null
                        ? kEmDash
                        : lastClose.toStringAsFixed(2),
                    style: MyntWebTextStyles.head(context,
                        fontWeight: MyntFonts.semiBold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${formatSignedNumber(change)}  (${formatPercent(pct, signed: true)})',
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium,
                        color: signedColor(context, change)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'As of ${formatDate(last.date)}',
                    style: MyntWebTextStyles.caption(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

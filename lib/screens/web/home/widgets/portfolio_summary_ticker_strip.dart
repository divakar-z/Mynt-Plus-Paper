import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../../provider/fund_provider.dart';
import '../../../../provider/mf_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../utils/custom_navigator.dart';
import '../../../../utils/rupee_convert_format.dart';
import '../../customizable_split_home_screen.dart' show tickerVisibilityNotifier;

/// Portfolio Summary Ticker Strip — the fixed summary shown in the top strip
/// of the split-home shell.
///
/// Displays: Equity P&L, MF Returns, Position P&L, Available Margin
/// (Total P&L is kept commented below, ready to switch on.)
///
/// This replaces what the Portfolio section used to show on the Dashboard
/// (`_buildDashboardCardsSection` in `dashboard_screen_web.dart`, kept
/// commented there), so it loads its own MF / fund data rather than assuming
/// the Dashboard was opened first.
///
/// The original auto-scrolling position ticker — `PortfolioTickerStrip` in
/// `customizable_split_home_screen.dart` — is untouched and still compiles;
/// swap the widget back in at the three call sites there to return to it.
class PortfolioSummaryTickerStrip extends ConsumerStatefulWidget {
  const PortfolioSummaryTickerStrip({super.key});

  @override
  ConsumerState<PortfolioSummaryTickerStrip> createState() =>
      _PortfolioSummaryTickerStripState();
}

class _PortfolioSummaryTickerStripState
    extends ConsumerState<PortfolioSummaryTickerStrip> {
  // This strip does not auto-scroll: it shows a fixed set of portfolio summary
  // items. The controller only serves the manual-scroll fallback on very
  // narrow layouts where the items cannot fit.
  late ScrollController _scrollController;

  /// Socket ticks mutate the holding/position models in place without the
  /// portfolio provider notifying, so the strip has to look for changes
  /// itself. It polls instead of watching `websocketProvider`: that notifies
  /// every 300ms whether or not these figures moved, and the strip — unlike
  /// the Dashboard section it replaced — is mounted for the whole session.
  Timer? _valueRefreshTimer;
  String _lastValueSignature = '';
  static const Duration _valueRefreshInterval = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // The strip is always on screen, so it can't rely on the Dashboard having
    // been opened for its MF / fund numbers. Fetch only what is still missing,
    // and skip a fetch already in flight from another screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mfData = ref.read(mfProvider);
      if (mfData.mfDematHolding == null && !mfData.dematHoldLoad) {
        mfData.fetchmfdematholding();
      }
      final fund = ref.read(fundProvider);
      if (fund.fundDetailModel == null) {
        fund.fetchFunds(context);
      }
    });
    _valueRefreshTimer =
        Timer.periodic(_valueRefreshInterval, (_) => _refreshIfValuesChanged());
  }

  @override
  void dispose() {
    _valueRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// The figures as displayed, so a tick that leaves every one of them
  /// unchanged at 2dp costs nothing.
  String _valueSignature() {
    final portfolio = ref.read(portfolioProvider);
    final fundDetail = ref.read(fundProvider).fundDetailModel;
    return [
      portfolio.totPnL,
      _equityPnl(portfolio).toStringAsFixed(2),
      _mutualFundPnl(ref.read(mfProvider)).toStringAsFixed(2),
      fundDetail?.avlMrg ?? fundDetail?.totCredit ?? '0',
    ].join('|');
  }

  void _refreshIfValuesChanged() {
    if (!mounted) return;
    final signature = _valueSignature();
    if (signature == _lastValueSignature) return;
    setState(() => _lastValueSignature = signature);
  }

  @override
  Widget build(BuildContext context) {
    // Use ValueListenableBuilder for reactive ticker visibility
    return ValueListenableBuilder<bool>(
      valueListenable: tickerVisibilityNotifier,
      builder: (context, isVisible, child) {
        if (!isVisible) {
          return const SizedBox.shrink();
        }
        return _buildTickerContent(context);
      },
    );
  }

  Widget _buildTickerContent(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final portfolio = ref.watch(portfolioProvider);
    final privacy = ref.watch(privacyProvider);
    final fund = ref.watch(fundProvider);
    final mfData = ref.watch(mfProvider);
    // Live prices move holdings/positions P&L, but socket ticks don't notify
    // these providers — _valueRefreshTimer picks those up.
    final isDarkMode = theme.isDarkMode;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: const Color.fromARGB(0, 26, 26, 46),
          light: const Color(0xFFFAFAFA),
        ),
        border: isDarkMode
            ? Border(
                bottom: BorderSide(
                  color: shadcn.Theme.of(context).colorScheme.border,
                  width: 1,
                ),
              )
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed summary items: Total P&L, Equity P&L, MF Returns,
          // Position P&L, Available Margin
          final tickerItems = _buildPortfolioSummaryTickerItems(
            portfolio: portfolio,
            fund: fund,
            mfData: mfData,
            isDarkMode: isDarkMode,
            isPrivate: privacy.isPrivate,
          );

          // Centered when the items fit, manually scrollable when they don't:
          // the min-width constraint lets the row grow past the strip instead
          // of overflowing on narrow panels.
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16),
                  ...tickerItems,
                  const SizedBox(width: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Holdings (equity) P&L, summed the same way the Portfolio cards did:
  /// `profitNloss` already carries the realized component, so fall back to
  /// `rpnl` only before the first socket tick has written it.
  double _equityPnl(PortfolioProvider portfolio) {
    double total = 0.0;
    for (final holding in portfolio.holdingsModel ?? []) {
      if (holding.exchTsym == null || holding.exchTsym!.isEmpty) continue;
      final pnlStr = holding.exchTsym![0].profitNloss;
      total += pnlStr != null
          ? (double.tryParse(pnlStr) ?? 0.0)
          : (double.tryParse(holding.rpnl ?? '0') ?? 0.0);
    }
    return total;
  }

  /// Mutual fund P&L from the demat holdings endpoint, preferring the API
  /// summary and falling back to the rows when the summary block is absent.
  double _mutualFundPnl(MFProvider mfData) {
    final summary = mfData.mfDematHolding?.summary;
    if (summary != null) {
      return double.tryParse(summary.absReturnValue ?? '0') ?? 0.0;
    }
    double invested = 0.0;
    double current = 0.0;
    for (final h in mfData.mfDematHolding?.data ?? []) {
      invested += double.tryParse(h.investedValue ?? '0') ?? 0.0;
      current += double.tryParse(h.currentValue ?? '0') ?? 0.0;
    }
    return current - invested;
  }

  /// Build the fixed portfolio summary items shown in the ticker.
  List<Widget> _buildPortfolioSummaryTickerItems({
    required PortfolioProvider portfolio,
    required FundProvider fund,
    required MFProvider mfData,
    required bool isDarkMode,
    required bool isPrivate,
  }) {
    final positionPnl = double.tryParse(portfolio.totPnL) ?? 0.0;
    final equityPnl = _equityPnl(portfolio);
    final mfPnl = _mutualFundPnl(mfData);
    final fundDetail = fund.fundDetailModel;
    final availableMargin =
        double.tryParse(fundDetail?.avlMrg ?? fundDetail?.totCredit ?? '0') ??
            0.0;

    final items = <Map<String, dynamic>>[
      // {
      //   'label': 'Total P&L',
      //   'value': equityPnl + mfPnl + positionPnl,
      //   'route': Routes.positionscreen,
      // },
      {
        'label': 'Equity P&L',
        'value': equityPnl,
        'route': Routes.holdingscreen,
      },
      {
        'label': 'MF Returns',
        'value': mfPnl,
        // Holdings page, Mutual Fund tab. Index 3, not 2: the old MF tab (2)
        // is retired and renders nothing — 3 is the demat-backed tab, and the
        // one this figure is computed from.
        'route': Routes.holdingscreen,
        'arguments': 3,
      },
      {
        'label': 'Position P&L',
        'value': positionPnl,
        'route': Routes.positionscreen,
      },
      {
        'label': 'Available Margin',
        'value': availableMargin,
        'route': Routes.fundscreen,
        // A balance, not a P&L — it must not read as a gain in profit-green.
        'neutral': true,
      },
    ];

    final List<Widget> widgets = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final route = item['route'] as String;
      final arguments = item['arguments'];
      widgets.add(
        _SummaryTickerItem(
          label: item['label'] as String,
          value: item['value'] as double,
          isDarkMode: isDarkMode,
          showAsAmount: true,
          isNeutral: item['neutral'] == true,
          isMasked: isPrivate,
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(route, arguments: arguments);
            }
          },
        ),
      );
      if (i < items.length - 1) {
        widgets.add(_tickerDivider(isDarkMode));
      }
    }
    return widgets;
  }

  Widget _tickerDivider(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: 1,
      height: 16,
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1),
    );
  }
}

/// One "label + amount" cell of the summary strip, with hover highlight and an
/// optional tap target. A private copy of the ticker item used by the original
/// `PortfolioTickerStrip`, so this widget stays self-contained and that file is
/// left untouched.
class _SummaryTickerItem extends StatefulWidget {
  final String label;
  final double value;
  final bool isDarkMode;
  final bool showAsAmount;
  // A balance rather than a P&L (e.g. Available Margin): shown in the plain
  // text colour, never profit-green or loss-red.
  final bool isNeutral;
  // Privacy Mode: hides the amount (and its sign/colour) behind a mask.
  final bool isMasked;
  final VoidCallback? onTap;

  const _SummaryTickerItem({
    required this.label,
    required this.value,
    required this.isDarkMode,
    this.showAsAmount = false,
    this.isNeutral = false,
    this.isMasked = false,
    this.onTap,
  });

  @override
  State<_SummaryTickerItem> createState() => _SummaryTickerItemState();
}

class _SummaryTickerItemState extends State<_SummaryTickerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPositive = widget.value >= 0;
    final displayValue = widget.showAsAmount
        ? "₹${_formatAmount(widget.value.abs())}"
        : widget.value.toStringAsFixed(2);

    Color valueColor;
    if (widget.isMasked || widget.isNeutral || widget.value == 0) {
      valueColor = widget.isDarkMode
          ? MyntColors.textPrimaryDark
          : MyntColors.textPrimary;
    } else {
      valueColor = isPositive
          ? (widget.isDarkMode ? MyntColors.profitDark : MyntColors.profit)
          : (widget.isDarkMode ? MyntColors.lossDark : MyntColors.loss);
    }

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isHovered && widget.onTap != null
                ? (widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: MyntWebTextStyles.para(
                  context,
                  fontWeight: MyntFonts.medium,
                  color: widget.isDarkMode
                      ? MyntColors.textPrimaryDark
                      : MyntColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isMasked
                    ? (widget.showAsAmount ? "₹$kPrivacyMask" : kPrivacyMask)
                    : (widget.showAsAmount
                        ? (isPositive ? displayValue : "-$displayValue")
                        : displayValue),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.semiBold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount.toIndianFormat();
  }
}

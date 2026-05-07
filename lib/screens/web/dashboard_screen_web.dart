import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../res/res.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/mynt_loader.dart';
import '../../../sharedWidget/feature_card_widget.dart';
import '../../../provider/index_list_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../provider/stocks_provider.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/fund_provider.dart';
import '../../../provider/mf_provider.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/explore_model/stocks_model/toplist_stocks.dart';
import 'dart:async';
import 'market_watch/index/index_bottom_sheet_web.dart';
import 'trade_action_screen_web.dart';
import '../../../routes/route_names.dart';
import '../../../utils/custom_navigator.dart';
import '../../../utils/rupee_convert_format.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../locator/locator.dart';
import '../../../locator/preference.dart';

class DashboardScreenWeb extends ConsumerStatefulWidget {
  const DashboardScreenWeb({super.key});

  @override
  ConsumerState<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends ConsumerState<DashboardScreenWeb> {
  final ScrollController _indexScrollController = ScrollController();
  final ScrollController _toolsScrollController = ScrollController();
  final ScrollController _tradeActionScrollController = ScrollController();
  // WebSocket subscription for live position updates
  StreamSubscription? _positionSocketSubscription;
  // WebSocket subscription for live holdings updates
  StreamSubscription? _holdingsSocketSubscription;
  // Flag to prevent accessing ref after disposal (race condition with stream callbacks)
  bool _isDisposed = false;
  // Throttle holdings updates
  DateTime _lastHoldingsUpdate = DateTime.now();
  static const Duration _holdingsUpdateInterval = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // Note: Data fetching is handled by _handleDashboardTap() in customizable_split_home_screen.dart
    // This prevents duplicate API calls when dashboard button is clicked
    // WebSocket bodyscription is handled by WebbodyscriptionManager
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final indexProvider = ref.read(indexListProvider);

      // Get top indices for dashboard (8 specific indices) if not already fetched
      // This ensures tokens are available for WebbodyscriptionManager
      // Only fetch if not already available to avoid duplicate calls
      if (indexProvider.topIndicesForDashboard == null) {
        await indexProvider.getTopIndicesForDashboard(context);
        if (!mounted) return;
      }

      // Fetch MF holdings for the dashboard portfolio tab using the same API as holdings tab
      // This avoids race condition with the old fetchMFHoldings API which can cause double data
      await ref.read(mfProvider).fetchmfholdingnew();
      if (!mounted) return;

      // Trade action data is fetched by _handleDashboardTap() before this screen is shown
      // No need to fetch here to avoid duplicate TopList API calls

      // Set up WebSocket subscription for live position updates
      _setupPositionSocketSubscription();
      // Set up WebSocket subscription for live holdings updates
      _setupHoldingsSocketSubscription();

      // Calculate holdings totals on initial load to ensure correct values
      final portfolio = ref.read(portfolioProvider);
      if (portfolio.holdingsModel != null && portfolio.holdingsModel!.isNotEmpty) {
        portfolio.pnlHoldCal();
      }
    });
  }

  void _setupPositionSocketSubscription() {
    if (!mounted) return;
    final websocket = ref.read(websocketProvider);
    // Store provider reference at setup time - the provider itself doesn't get
    // disposed when widget disposes, only the widget's ref access becomes invalid
    final portfolio = ref.read(portfolioProvider);

    _positionSocketSubscription =
        websocket.socketDataStream.listen((socketDatas) {
      // Check if widget is disposed before processing
      if (_isDisposed) return;

      // Get positions fresh from stored provider reference (not from ref)
      final positions = portfolio.postionBookModel ?? [];

      if (positions.isEmpty) return;

      bool needsUpdate = false;

      for (var position in positions) {
        if (socketDatas.containsKey(position.token)) {
          final socketData = socketDatas[position.token];

          // Update LTP if valid (strict guard rejects null/zero defaults)
          final lp = socketData['lp']?.toString();
          if (lp != null && lp != "null" && lp != "" &&
              lp != "0" && lp != "0.0" && lp != "0.00" &&
              lp != position.lp) {
            position.lp = lp;
            needsUpdate = true;
          }
        }
      }

      // Recalculate totals when price data changes
      if (needsUpdate) {
        portfolio.positionCal(portfolio.isDay);
      }
    });
  }

  void _setupHoldingsSocketSubscription() {
    if (!mounted) return;
    final websocket = ref.read(websocketProvider);
    final portfolio = ref.read(portfolioProvider);

    _holdingsSocketSubscription = websocket.socketDataStream.listen((socketDatas) {
      if (_isDisposed || !mounted) return;

      final holdings = portfolio.holdingsModel ?? [];
      if (holdings.isEmpty || socketDatas.isEmpty) return;

      // Throttle updates to avoid excessive rebuilds
      final now = DateTime.now();
      if (now.difference(_lastHoldingsUpdate) < _holdingsUpdateInterval) return;

      bool needsUpdate = false;

      // Check if any holdings tokens have updates
      for (var holding in holdings) {
        if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
          final token = holding.exchTsym![0].token;
          if (token != null && socketDatas.containsKey(token)) {
            needsUpdate = true;
            break;
          }
        }
      }

      // Call pnlHoldCal() which calculates all totals and calls notifyListeners()
      if (needsUpdate) {
        _lastHoldingsUpdate = now;
        portfolio.pnlHoldCal();
      }
    });
  }

  @override
  void dispose() {
    // Set disposed flag FIRST to prevent stream callbacks from accessing ref
    _isDisposed = true;
    // Cancel WebSocket subscriptions
    _positionSocketSubscription?.cancel();
    _holdingsSocketSubscription?.cancel();

    // Note: WebbodyscriptionManager handles unbodyscription automatically
    // when screen is replaced or removed via updateActiveScreen()
    // No need to unbodyscribe here to avoid double calls

    _indexScrollController.dispose();
    _toolsScrollController.dispose();
    _tradeActionScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indexProvider = ref.watch(indexListProvider);

    return Scaffold(
      backgroundColor: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopIndicesSection(context, indexProvider),
              const SizedBox(height: 32),
              // Dashboard cards section (Holdings, Position, Orders, Margins)
              _buildDashboardCardsSection(context),
              const SizedBox(height: 32),
              // Tools section (Scalper, Strategy Builder, OptionZ)
              _buildToolsSection(context),
              const SizedBox(height: 32),
              // Today's trade action section
              // _buildFeatureCardsSection(context),
              // const SizedBox(height: 32),
              _buildTodaysTradeActionSection(context),
              // Feature Cards Section - NEW UI TEST
              // const SizedBox(height: 32),
              // Portfolio Analysis section
              // _buildPortfolioAnalysisSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCardsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Quick Access',
          style: MyntWebTextStyles.title(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: FontWeight.bold,
          ).copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Access key features and insights at a glance',
          style: MyntWebTextStyles.para(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Feature Cards - 2 per row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FeatureCard(
                badgeNumber: '01',
                iconData:  shadcn.LucideIcons.chartBar,
                title: 'OptionZ',
                description: 'Access advanced options trading platform with real-time data and powerful analytics tools.',
                badgeColor: const Color(0xFF6366F1), // Indigo - vibrant purple
                iconColor: const Color(0xFF6366F1),
                onTap: () async {
                  // Open OptionZ in new tab
                  final funds = ref.read(fundProvider);
                  await funds.fetchHstoken(context);
                  await funds.openOptionZInNewTab();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FeatureCard(
                badgeNumber: '02',
                iconData: shadcn.LucideIcons.draftingCompass,
                title: 'Strategy Builder',
                description: 'Create and backtest your trading strategies with our powerful strategy building tools.',
                badgeColor: const Color(0xFF06B6D4), // Cyan - bright teal
                iconColor: const Color(0xFF06B6D4),
                onTap: () {
                  // Open Strategy Builder in right panel using WebNavigationHelper
                  WebNavigationHelper.navigateTo('strategyBuilder');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FeatureCard(
                badgeNumber: '03',
                iconData: shadcn.LucideIcons.shoppingBag,
                title: 'Scalper',
                description: 'Quick in & out trading with real-time market data and lightning-fast order execution.',
                badgeColor: const Color(0xFFEC4899),
                iconColor: const Color(0xFFEC4899),
                onTap: () {},
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FeatureCard(
                badgeNumber: '04',
                iconData: shadcn.BootstrapIcons.wechat,
                title: 'Refer & Earn',
                description: 'Invite your friends and earn rewards. Share the benefits of smart trading together.',
                badgeColor: const Color(0xFFF59E0B), // Amber - warm and inviting
                iconColor: const Color(0xFFF59E0B),
                onTap: () async {
                  // Open Refer & Earn in external browser (same as profile dropdown)
                  final Preferences pref = locator<Preferences>();
                  final url = 'https://profile.zebuetrade.com/refer?uid=${pref.clientId}&token=${pref.token}';
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardCardsSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildPortfolioCard(context, constraints.maxWidth);
      },
    );
  }

  Widget _buildPortfolioCard(BuildContext context, double width) {
    return Consumer(
      builder: (context, ref, _) {
        final portfolio = ref.watch(portfolioProvider);
        final orders = ref.watch(orderProvider);
        final fund = ref.watch(fundProvider);
        final mfData = ref.watch(mfProvider);
        // Watch websocket for price updates
        ref.watch(websocketProvider);

        return Container(
          width: width,
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPortfolioHeader(context),
              const SizedBox(height: 14),
              _buildPortfolioContent(context, portfolio, orders, fund, mfData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortfolioHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Portfolio',
              style: MyntWebTextStyles.head(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPortfolioContent(
    BuildContext context,
    PortfolioProvider portfolio,
    OrderProvider orders,
    FundProvider fund,
    MFProvider mfData,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const cardSpacing = 16.0;
        const minCardWidth = 240.0;
        const totalCards = 4;
        const totalSpacing = cardSpacing * (totalCards - 1);
        const totalMinWidth = (minCardWidth * totalCards) + totalSpacing;

        // Threshold for 2x2 grid layout (2 cards per row)
        const gridThreshold = (minCardWidth * 2) + cardSpacing;

        // Build card widgets
        Widget equityCard = _buildPortfolioSection(
          context,
          'Equity',
          _getEquityMetrics(context, portfolio),
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(Routes.holdingscreen);
            }
          },
            trailing: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
               onTap: () {
              if (WebNavigationHelper.isAvailable) {
                WebNavigationHelper.navigateTo(Routes.portfolioDashboard);
              }
            },
              child: Text(
                'Insights',
                style: MyntWebTextStyles.symbol(
                  context,
                  fontWeight: MyntFonts.bold,
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary),
                ),
              ),
            ),
          ),
        );

        Widget mutualFundCard = _buildPortfolioSection(
          context,
          'Mutual Fund',
          _getMutualFundMetrics(context, mfData),
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(Routes.mfmainscreen);
            }
          },
        );

        Widget positionCard = _buildPortfolioSection(
          context,
          'Position',
          _getPositionMetrics(context, portfolio),
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(Routes.positionscreen);
            }
          },
        );

        Widget fundsCard = _buildPortfolioSection(
          context,
          'Funds',
          _getFundsMetrics(context, fund),
          onTap: () {
            if (WebNavigationHelper.isAvailable) {
              WebNavigationHelper.navigateTo(Routes.fundscreen);
            }
          },
          trailing: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (WebNavigationHelper.isAvailable) {
                  WebNavigationHelper.navigateTo(Routes.fundscreen,
                      arguments: 'addMoney');
                }
              },
              child: Text(
                'Add Money',
                style: MyntWebTextStyles.symbol(
                  context,
                  fontWeight: MyntFonts.bold,
                  color: resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary),
                ),
              ),
            ),
          ),
        );

        if (availableWidth >= totalMinWidth) {
          // All 4 cards fit in a single row
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: equityCard),
                const SizedBox(width: cardSpacing),
                Expanded(child: mutualFundCard),
                const SizedBox(width: cardSpacing),
                Expanded(child: positionCard),
                const SizedBox(width: cardSpacing),
                Expanded(child: fundsCard),
              ],
            ),
          );
        } else if (availableWidth >= gridThreshold) {
          // 2x2 grid layout
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: equityCard),
                    const SizedBox(width: cardSpacing),
                    Expanded(child: mutualFundCard),
                  ],
                ),
              ),
              const SizedBox(height: cardSpacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: positionCard),
                    const SizedBox(width: cardSpacing),
                    Expanded(child: fundsCard),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Single column layout for very small screens
          return Column(
            children: [
              equityCard,
              const SizedBox(height: cardSpacing),
              mutualFundCard,
              const SizedBox(height: cardSpacing),
              positionCard,
              const SizedBox(height: cardSpacing),
              fundsCard,
            ],
          );
        }
      },
    );
  }

  Widget _buildPortfolioSection(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> metrics, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _buildMetricsGrid(context, title, metrics,
        trailing: trailing, onTap: onTap);
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> metrics, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    // We want a 2x2 grid layout inside a single border with the title at the top
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode(context) ? MyntColors.dashboardCarColor : shadcn.Theme.of(context).colorScheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: MyntWebTextStyles.symbol(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
              ),
              // Divider(
              //   height: 1,
              //   color: shadcn.Theme.of(context).colorScheme.border.withOpacity(0.5),
              // ),
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 16, top: 6),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(child: _buildMetricItem(context, metrics, 0)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricItem(context, metrics, 1)),
                      ],
                    ),
                    if (metrics.length > 2) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: shadcn.Theme.of(context)
                            .colorScheme
                            .border
                            .withOpacity(0.6),
                      ),
                      const SizedBox(height: 10),
                      // Row 2
                      Row(
                        children: [
                          Expanded(
                              child: _buildMetricItem(context, metrics, 2)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildMetricItem(context, metrics, 3)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    List<Map<String, dynamic>> metrics,
    int index,
  ) {
    if (index >= metrics.length) {
      return const SizedBox.shrink();
    }

    final metric = metrics[index];
    final String valueStr = metric['value'] as String;
    final bool isPnl = metric['isPnl'] ?? false;
    // Efficient color determination: check first char for negative, regex for zero
    final bool isNegative = valueStr.startsWith('-');
    final bool isZero = !valueStr.contains(RegExp(r'[1-9]'));
    final Color valueColor = (isPnl && !isZero)
        ? (isNegative
            ? resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss)
            : resolveThemeColor(context,
                dark: MyntColors.profitDark, light: MyntColors.profit))
        : resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final bool isLeftAligned = index % 2 == 0;
    final alignment =
        isLeftAligned ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final wrapAlignment =
        isLeftAligned ? WrapAlignment.start : WrapAlignment.end;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          metric['label'],
          style: MyntWebTextStyles.exch(
            context,
            fontWeight: FontWeight.w500,
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isLeftAligned ? TextAlign.left : TextAlign.right,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          alignment: wrapAlignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              metric['value'],
              style: MyntWebTextStyles.price(
                context,
                color: valueColor,
              ),
            ),
            if (metric['subValue'] != null)
              Text(
                metric['subValue'],
                style: MyntWebTextStyles.priceChange(
                  context,
                  color: valueColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getEquityMetrics(
      BuildContext context, PortfolioProvider portfolio) {
    final holdings = portfolio.holdingsModel ?? [];
    double totalPnlHolding = 0.0;
    double oneDayChng = 0.0;
    double invest = 0.0;
    double totalCurrentVal = 0.0;

    for (var holding in holdings) {
      if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
        final exchTsym = holding.exchTsym![0];
        final pnl = double.tryParse(exchTsym.profitNloss ?? '0') ?? 0.0;
        final rpnl = double.tryParse(holding.rpnl ?? '0') ?? 0.0;
        final oneDayChgVal = double.tryParse(exchTsym.oneDayChg ?? '0') ?? 0.0;
        final investedVal = double.tryParse(holding.invested ?? '0') ?? 0.0;
        final currentVal = double.tryParse(holding.currentValue ?? '0') ?? 0.0;

        totalPnlHolding += pnl + rpnl;
        oneDayChng += oneDayChgVal;
        invest += investedVal;
        totalCurrentVal += currentVal;
      }
    }

    final oneDayChngPer =
        totalCurrentVal > 0 ? (oneDayChng / totalCurrentVal) * 100 : 0.0;
    final totPnlPercHolding =
        invest > 0 ? (totalPnlHolding / invest) * 100 : 0.0;

    return [
      {'label': 'Invested', 'value': invest.toIndianRupee()},
      {'label': 'Current', 'value': totalCurrentVal.toIndianRupee()},
      {
        'label': 'Total P&L',
        'value': totalPnlHolding.toIndianRupee(),
        'subValue': '(${totPnlPercHolding.toStringAsFixed(2)}%)',
        'isPnl': true
      },
      {
        'label': 'Today P&L',
        'value': oneDayChng.toIndianRupee(),
        'subValue': '(${oneDayChngPer.toStringAsFixed(2)}%)',
        'isPnl': true
      },
    ];
  }

  List<Map<String, dynamic>> _getMutualFundMetrics(
      BuildContext context, MFProvider mfData) {
    // Use the same data source as holdings tab (mfholdingnew.summary)
    // This ensures consistency and avoids race condition with the old API
    final summary = mfData.mfholdingnew?.summary;
    final invest = double.tryParse(summary?.invested ?? '0') ?? 0.0;
    final current = double.tryParse(summary?.currentValue ?? '0') ?? 0.0;
    final totalPnL = double.tryParse(summary?.absReturnValue ?? '0') ?? 0.0;
    final totalPnLPer = double.tryParse(summary?.absReturnPercent ?? '0') ?? 0.0;

    return [
      {'label': 'Invested', 'value': invest.toIndianRupee()},
      {'label': 'Current', 'value': current.toIndianRupee()},
      {
        'label': 'Total P&L',
        'value': totalPnL.toIndianRupee(),
        'subValue': '(${totalPnLPer.toStringAsFixed(2)}%)',
        'isPnl': true
      },
    ];
  }

  List<Map<String, dynamic>> _getPositionMetrics(
      BuildContext context, PortfolioProvider portfolio) {
    final positions = portfolio.postionBookModel ?? [];
    final totalPnL = portfolio.totPnL;
    final mtm = portfolio.totMtM;
    final openPnL = portfolio.totUnRealMtm;

    double totBuyAmts = 0.0;
    for (var position in positions) {
      totBuyAmts += double.tryParse(position.totbuyamt ?? '0') ?? 0;
    }

    return [
      {'label': 'Trade value', 'value': totBuyAmts.toIndianRupee()},
      {'label': 'MTM', 'value': mtm.toIndianRupee(), 'isPnl': true},
      {'label': 'Total P&L', 'value': totalPnL.toIndianRupee(), 'isPnl': true},
      {'label': 'Open P&L', 'value': openPnL.toIndianRupee(), 'isPnl': true},
    ];
  }

  List<Map<String, dynamic>> _getFundsMetrics(
      BuildContext context, FundProvider fund) {
    final fundDetail = fund.fundDetailModel;
    final availableBalance =
        fundDetail?.avlMrg ?? fundDetail?.totCredit ?? '0.00';
    final totalCredits = fundDetail?.totCredit ?? '0.00';
    final marginUsed = fundDetail?.marginused ?? '0.00';

    return [
      {'label': 'Available Margin', 'value': availableBalance.toIndianRupee()},
      {'label': 'Capital', 'value': totalCredits.toIndianRupee()},
      {'label': 'Used', 'value': marginUsed.toIndianRupee()},
    ];
  }

  Widget _buildPortfolioFooter(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildTopIndicesSection(
      BuildContext context, IndexListProvider indexProvider) {
    // Use topIndicesForDashboard (8 specific indices for dashboard)
    final allIndexValues =
        indexProvider.topIndicesForDashboard?.indValues ?? [];
    final indexValues = allIndexValues.take(5).toList();
    final hasIndices = indexValues.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and navigation arrows
        Row(
          children: [
            Text(
              'Indices',
              style: MyntWebTextStyles.head(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.bold,
              ),
            ),
            const SizedBox(width: 12),
            // "See all indices" link moved near the title
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  await _showAllIndicesBottomSheet(context, indexProvider);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: shadcn.Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.0),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Index cards + Algo Trading card in a row
        SizedBox(
          height: 130,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              const algoCardWidth = 280.0;
              const cardSpacing = 12.0;
              // Reserve space for the algo card on the right
              final indicesAvailableWidth =
                  availableWidth - algoCardWidth - cardSpacing;

              const minCardWidth = 140.0;
              final totalCards = indexValues.length;
              final totalSpacing = cardSpacing * (totalCards - 1);
              final totalMinWidth =
                  (minCardWidth * totalCards) + totalSpacing;

              double cardWidth;
              bool needsScrolling = false;

              if (indicesAvailableWidth >= totalMinWidth) {
                cardWidth =
                    (indicesAvailableWidth - totalSpacing) / totalCards;
              } else {
                cardWidth = minCardWidth;
                needsScrolling = true;
              }

              return Row(
                children: [
                  // Left scroll button (outside scroll area)
                  if (needsScrolling)
                    _buildIndexScrollButton(
                      context,
                      icon: Icons.arrow_back_ios,
                      onTap: () {
                        if (_indexScrollController.hasClients) {
                          final scrollAmount = cardWidth + cardSpacing;
                          final newOffset =
                              (_indexScrollController.offset - scrollAmount)
                                  .clamp(
                            0.0,
                            _indexScrollController.position.maxScrollExtent,
                          );
                          _indexScrollController.animateTo(
                            newOffset,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  if (needsScrolling) const SizedBox(width: 8),
                  // Scrollable indices section
                  Expanded(
                    child: hasIndices
                        ? SingleChildScrollView(
                            controller: _indexScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: needsScrolling
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: Row(
                              children: indexValues
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return Container(
                                  width: cardWidth,
                                  margin: EdgeInsets.only(
                                    right: index < indexValues.length - 1
                                        ? cardSpacing
                                        : 0,
                                  ),
                                  child: _DashboardIndexCard(
                                    indexItem: item,
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : Center(
                            child:
                                MyntLoader.simple(size: MyntLoaderSize.small),
                          ),
                  ),
                  // Right scroll button (outside scroll area)
                  if (needsScrolling) const SizedBox(width: 8),
                  if (needsScrolling)
                    _buildIndexScrollButton(
                      context,
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (_indexScrollController.hasClients) {
                          final scrollAmount = cardWidth + cardSpacing;
                          final newOffset =
                              (_indexScrollController.offset + scrollAmount)
                                  .clamp(
                            0.0,
                            _indexScrollController.position.maxScrollExtent,
                          );
                          _indexScrollController.animateTo(
                            newOffset,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  const SizedBox(width: cardSpacing),
                  // Algo Trading card next to indices
                  _buildAlgoTradingBannerCard(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlgoTradingBannerCard() {
    const Color accent = Color(0xFF4A1F8E);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final Uri algoUri = Uri.parse('https://algo.zebuetrade.com/');
          if (await canLaunchUrl(algoUri)) {
            await launchUrl(
              algoUri,
              mode: LaunchMode.externalApplication,
            );
          }
        },
        child: Container(
          width: 280,
          height: 130,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
              colors: [
                Color(0xFF170B26),
                Color(0xFF4A1F8E),
                Color(0xFF7B3FB5),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Bottom-right glow (same as Tools card)
              Positioned(
                right: -70,
                bottom: -70,
                child: IgnorePointer(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFB685FF).withValues(alpha: 0.65),
                          const Color(0xFFB685FF).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Top-left glow (same as Tools card)
              Positioned(
                left: -50,
                top: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Stacked rotated icon (same as Tools card)
                        SizedBox(
                          width: 48,
                          height: 42,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 8,
                                child: Transform.rotate(
                                  angle: -0.18,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.22),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 4,
                                child: Transform.rotate(
                                  angle: -0.09,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.45),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                top: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(
                                            alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      assets.boltIcon,
                                      width: 18,
                                      height: 18,
                                      colorFilter: const ColorFilter.mode(
                                        accent,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Algo Trading',
                                      style: MyntWebTextStyles.body(
                                        context,
                                        color: Colors.white,
                                        fontWeight: MyntFonts.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: MyntWebTextStyles.caption(
                                        context,
                                        color: const Color(0xFF170B26),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Automated • Rule-based',
                                style: MyntWebTextStyles.para(
                                  context,
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        'Create & deploy automated trading strategies with Zebu Algo.',
                        style: MyntWebTextStyles.para(
                          context,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndexScrollButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shadcn.Theme.of(context).colorScheme.card,
                border: Border.all(
                  color: shadcn.Theme.of(context).colorScheme.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 12,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollIndices(double offset) {
    if (_indexScrollController.hasClients) {
      final currentOffset = _indexScrollController.offset;
      final maxScrollExtent = _indexScrollController.position.maxScrollExtent;
      final newOffset = currentOffset + offset;

      // Clamp the offset to prevent scrolling beyond boundaries
      final clampedOffset = newOffset.clamp(0.0, maxScrollExtent);

      // Only animate if we're not at the boundary
      if (clampedOffset != currentOffset) {
        _indexScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildToolsSection(BuildContext context) {
    final bool darkMode = isDarkMode(context);

    final List<Map<String, dynamic>> tools = [
      // Algo Trading card is now shown next to Indices section
      // {
      //   'title': 'Algo Trading',
      //   'subtitle': 'Automated • Rule-based',
      //   'description':
      //       'Create, backtest & deploy automated trading strategies with Zebu Algo.',
      //   'accentColor': const Color(0xFF4A1F8E),
      //   'badge': 'NEW',
      //   'filled': true,
      //   'isIcon': true,
      //   'icon': Icons.bolt_rounded,
      //   'onTap': () async {
      //     final Uri algoUri = Uri.parse('https://algo.zebuetrade.com/');
      //     if (await canLaunchUrl(algoUri)) {
      //       await launchUrl(
      //         algoUri,
      //         mode: LaunchMode.externalApplication,
      //       );
      //     }
      //   },
      // },
      {
        'title': 'MF Stratergy',
      'subtitle': 'Mutual Funds • Smart Investing',
    'description': 'Create and invest in curated mutual fund baskets with a single tap. Diversify your portfolio and manage multiple funds effortlessly.',
        'badge': null,
        'isIcon' :false,
        'accentColor': const Color(0xFF16C4C5),
        'svgAsset': assets.mfIcon,
        'onTap': () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('basketDashboard');
          }
        },
      },
      {
        'title': 'WebHook Trading',
        'subtitle': 'TradingView • Auto Alert',
        'description':
            'Automate trades via TradingView webhook alerts with real-time order execution.',
        'accentColor': const Color(0xFFEC4899),
        'badge': null,
        'icon': Icons.webhook,
        'isIcon' :true,
        'onTap': () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('tradingViewWebHook');
          }
        },
      },
      {
        'title': 'Equity SIP',
        'subtitle': 'Systematic Investment Plan',
        'description':
            'Create and manage SIP baskets to automate your equity investments with ease.',
        'accentColor': const Color(0xFF0EA5E9),
        'badge': null,
        'icon': Icons.auto_graph_rounded,
        'isIcon' :true,
        'onTap': () {
          // Navigate to orders screen and switch to SIP tab (index 5)
          ref.read(orderProvider).changeTabIndex(5, context);
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('orderBook');
          }
        },
      },
      {
        'title': 'Scalper',
        'subtitle': 'F&O • Index Trading',
        'description':
            'Ultra-fast one-tap order execution built for high-speed intraday & index traders.',
        'accentColor': const Color(0xFF3B82F6),
        'badge': null,
        'icon': Icons.rocket_launch_rounded,
        'isIcon' :true,
        'onTap': () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('scalper');
          }
        },
      },
      {
        'title': 'Strategy Builder',
        'subtitle': 'Multi-leg • Payoff Analytics',
        'description':
            'Design, analyze & visualize complex option strategies with real-time payoff charts.',
        'accentColor': const Color(0xFF8B5CF6),
        'badge': null,
        'icon': Icons.show_chart,
        'isIcon' :true,
        'onTap': () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('strategyBuilder');
          }
        },
      },
      {
        'title': 'OptionZ',
        'subtitle': 'IV • OI • Greeks • Option Chain',
        'description':
            'Institution-grade options dashboard with deep analytics & live market insights.',
        'accentColor': const Color(0xFF10B981),
        'badge': null,
        'icon': Icons.bar_chart_rounded,
        'isIcon' :true,
        'onTap': () async {
          final funds = ref.read(fundProvider);
          await funds.fetchHstoken(context);
          await funds.openOptionZInNewTab();
        },
      },
      {
        'title': 'Refer & Earn',
        'subtitle': 'Instant Rewards • Unlimited Referrals',
        'description':
            'Invite friends to Mynt and earn rewards for every successful referral.',
        'accentColor': const Color(0xFFF59E0B),
        'badge': null,
        'icon': Icons.card_giftcard_rounded,
        'isIcon' :true,
        // 'onTap': () {
        //   final Preferences pref = locator<Preferences>();
          // final url =
          //     'https://profile.zebuetrade.com/refer?uid=${pref.clientId}&token=${pref.token}';
          // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          'onTap': () {
          if (WebNavigationHelper.isAvailable) {
            WebNavigationHelper.navigateTo('refer');
          }
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'Tools',
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Tools cards
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const cardSpacing = 12.0;
            const minCardWidth = 280.0;
            final totalCards = tools.length;
            final totalSpacing = cardSpacing * (totalCards - 1);
            final totalMinWidth = (minCardWidth * totalCards) + totalSpacing;

            double cardWidth;
            bool needsScrolling = false;

            if (availableWidth >= totalMinWidth) {
              cardWidth = (availableWidth - totalSpacing) / totalCards;
            } else {
              cardWidth = minCardWidth;
              needsScrolling = true;
            }

            return Stack(
              children: [
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    controller: _toolsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: tools.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tool = entry.value;
                        final Color accent = tool['accentColor'] as Color;
                        final String? badge = tool['badge'] as String?;
                        final bool filled = tool['filled'] == true;

                        if (filled) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                (tool['onTap'] as Function).call();
                              },
                              child: Container(
                                width: cardWidth,
                                margin: EdgeInsets.only(
                                    right: index < tools.length - 1
                                        ? cardSpacing
                                        : 0),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: [0.0, 0.55, 1.0],
                                    colors: [
                                      Color(0xFF170B26),
                                      Color(0xFF4A1F8E),
                                      Color(0xFF7B3FB5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A1F8E)
                                          .withValues(alpha: 0.28),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -70,
                                      bottom: -70,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 240,
                                          height: 240,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                const Color(0xFFB685FF)
                                                    .withValues(alpha: 0.65),
                                                const Color(0xFFB685FF)
                                                    .withValues(alpha: 0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: -50,
                                      top: -50,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 160,
                                          height: 160,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                Colors.white
                                                    .withValues(alpha: 0.06),
                                                Colors.white
                                                    .withValues(alpha: 0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 64,
                                                height: 56,
                                                child: Stack(
                                                  children: [
                                                    Positioned(
                                                      left: 0,
                                                      top: 10,
                                                      child: Transform.rotate(
                                                        angle: -0.18,
                                                        child: Container(
                                                          width: 44,
                                                          height: 44,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.22),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        11),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 8,
                                                      top: 5,
                                                      child: Transform.rotate(
                                                        angle: -0.09,
                                                        child: Container(
                                                          width: 44,
                                                          height: 44,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.45),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        11),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 16,
                                                      top: 0,
                                                      child: Container(
                                                        width: 44,
                                                        height: 44,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(11),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: accent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                      0, 3),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Center(
                                                          child: tool['isIcon'] ==
                                                                  true
                                                              ? Icon(
                                                                  tool['icon']
                                                                      as IconData,
                                                                  size: 24,
                                                                  color: const Color(
                                                                      0xFF4A1F8E),
                                                                )
                                                              : SvgPicture.asset(
                                                                  tool['svgAsset']
                                                                      as String,
                                                                  width: 24,
                                                                  height: 24,
                                                                  colorFilter:
                                                                      const ColorFilter
                                                                          .mode(
                                                                    Color(
                                                                        0xFF4A1F8E),
                                                                    BlendMode
                                                                        .srcIn,
                                                                  ),
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            tool['title']
                                                                as String,
                                                            style: MyntWebTextStyles
                                                                .body(
                                                              context,
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  MyntFonts
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        if (badge != null) ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          5),
                                                            ),
                                                            child: Text(
                                                              'NEW',
                                                              style: MyntWebTextStyles
                                                                  .caption(
                                                                context,
                                                                color: const Color(
                                                                    0xFF170B26),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      tool['subtitle']
                                                          as String,
                                                      style: MyntWebTextStyles
                                                          .para(
                                                        context,
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.85),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Divider(
                                            height: 1,
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(
                                            child: Text(
                                              tool['description'] as String,
                                              style: MyntWebTextStyles.para(
                                                context,
                                                color: Colors.white
                                                    .withValues(alpha: 0.85),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              (tool['onTap'] as Function).call();
                            },
                            child: Container(
                              width: cardWidth,
                              margin: EdgeInsets.only(
                                  right: index < tools.length - 1
                                      ? cardSpacing
                                      : 0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: darkMode
                                    ? accent.withValues(alpha: 0.06)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: darkMode
                                      ? accent.withValues(alpha: 0.20)
                                      : accent.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: stacked card icon + title + badge
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                // Stacked card icon effect
                                SizedBox(
                                  width: 64,
                                  height: 56,
                                  child: Stack(
                                    children: [
                                      // Back card
                                      Positioned(
                                        left: 0,
                                        top: 10,
                                        child: Transform.rotate(
                                          angle: -0.18,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                                    color: accent
                                                        .withValues(alpha: 0.18),
                                                    borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Mid card
                                      Positioned(
                                        left: 8,
                                        top: 5,
                                        child: Transform.rotate(
                                          angle: -0.09,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                                    color: accent
                                                        .withValues(alpha: 0.35),
                                                     borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Front card with icon
                                      Positioned(
                                        left: 16,
                                        top: 0,
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            boxShadow: [
                                              BoxShadow(
                                                color: accent
                                                          .withValues(alpha: 0.4),
                                                      blurRadius: 8,
                                                offset:
                                                    const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child:  tool['isIcon'] == true
                                  ?  Icon(tool['icon'] as IconData, size: 24, color: Colors.white)
                                  : SvgPicture.asset(
                                      tool['svgAsset'] as String,
                                      width: 24,
                                      height: 24,
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              tool['title'] as String,
                                              style:
                                                  MyntWebTextStyles.body(
                                                context,
                                                darkColor: MyntColors
                                                    .textPrimaryDark,
                                                lightColor:
                                                    MyntColors.textPrimary,
                                                fontWeight:
                                                    MyntFonts.bold,
                                              ),
                                            ),
                                          ),
                                          if (badge != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: accent,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        5),
                                              ),
                                              child: Text(
                                                'NEW',
                                                style: MyntWebTextStyles
                                                    .caption(
                                                  context,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        tool['subtitle'] as String,
                                        style: MyntWebTextStyles.para(
                                          context,
                                          darkColor: MyntColors
                                              .textSecondaryDark,
                                          lightColor:
                                              MyntColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Divider
                            Divider(
                              height: 1,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.dividerDark,
                                  light: MyntColors.divider),
                            ),
                            const SizedBox(height: 10),
                            // Description
                            Expanded(
                              child: Text(
                                tool['description'] as String,
                                style: MyntWebTextStyles.para(
                                  context,
                                  darkColor:
                                      MyntColors.textSecondaryDark,
                                  lightColor:
                                      MyntColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                      }).toList(),
                    ),
                  ),
                ),
                // Left arrow
                if (needsScrolling)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_toolsScrollController.hasClients) {
                                final scrollAmount = cardWidth + cardSpacing;
                                final newOffset =
                                    (_toolsScrollController.offset -
                                            scrollAmount)
                                        .clamp(
                                  0.0,
                                  _toolsScrollController
                                      .position.maxScrollExtent,
                                );
                                _toolsScrollController.animateTo(
                                  newOffset,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: shadcn.Theme.of(context)
                                    .colorScheme
                                    .card,
                                border: Border.all(
                                  color: shadcn.Theme.of(context)
                                      .colorScheme
                                      .border,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Right arrow
                if (needsScrolling)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_toolsScrollController.hasClients) {
                                final scrollAmount = cardWidth + cardSpacing;
                                final newOffset =
                                    (_toolsScrollController.offset +
                                            scrollAmount)
                                        .clamp(
                                  0.0,
                                  _toolsScrollController
                                      .position.maxScrollExtent,
                                );
                                _toolsScrollController.animateTo(
                                  newOffset,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: shadcn.Theme.of(context)
                                    .colorScheme
                                    .card,
                                border: Border.all(
                                  color: shadcn.Theme.of(context)
                                      .colorScheme
                                      .border,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodaysTradeActionSection(BuildContext context) {
    final stocksProvider = ref.watch(stocksProvide);
    final topGainers = stocksProvider.topGainers;
    final topLosers = stocksProvider.topLosers;
    final byVolume = stocksProvider.byVolume;
    final byValue = stocksProvider.byValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          "Today's trade action",
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Four cards with responsive width
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const cardSpacing = 16.0;
            const minCardWidth = 300.0;
            const totalCards = 4;
            const totalSpacing = cardSpacing * (totalCards - 1);
            const totalMinWidth = (minCardWidth * totalCards) + totalSpacing;

            // Calculate card width
            double cardWidth;
            bool needsScrolling = false;

            if (availableWidth >= totalMinWidth) {
              // All cards fit, distribute evenly
              cardWidth = (availableWidth - totalSpacing) / totalCards;
            } else {
              // Need scrolling, use min width
              cardWidth = minCardWidth;
              needsScrolling = true;
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _tradeActionScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Gainers Card
                      _buildTradeActionCard(
                        tabIndex: 0, // Top gainer tab
                        context: context,
                        title: 'Top gainer',
                        stocks: topGainers,
                        icon: Icons.trending_up,
                        iconColor: resolveThemeColor(context,
                            dark: MyntColors.profitDark,
                            light: MyntColors.profit),
                        width: cardWidth,
                      ),
                      const SizedBox(width: cardSpacing),
                      // Top Losers Card
                      _buildTradeActionCard(
                        tabIndex: 1, // Top losers tab
                        context: context,
                        title: 'Top losers',
                        stocks: topLosers,
                        icon: Icons.trending_down,
                        iconColor: resolveThemeColor(context,
                            dark: MyntColors.lossDark, light: MyntColors.loss),
                        width: cardWidth,
                      ),
                      const SizedBox(width: cardSpacing),
                      // Volume Breakout Card
                      _buildTradeActionCard(
                        tabIndex: 2, // Volume breakout tab
                        context: context,
                        title: 'Volume breakout',
                        stocks: byVolume,
                        icon: Icons.bar_chart,
                        iconColor: resolveThemeColor(context,
                            dark: MyntColors.secondary,
                            light: MyntColors.secondary),
                        width: cardWidth,
                      ),
                      const SizedBox(width: cardSpacing),
                      // Most Active Card
                      _buildTradeActionCard(
                        tabIndex: 3, // Most active tab
                        context: context,
                        title: 'Most active',
                        stocks: byValue,
                        icon: Icons.star,
                        iconColor: resolveThemeColor(context,
                            dark: MyntColors.pending,
                            light: MyntColors.pending),
                        showPrice: true,
                        width: cardWidth,
                      ),
                    ],
                  ),
                ),
                // Left arrow (only show if scrolling is needed)
                if (needsScrolling)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_tradeActionScrollController.hasClients) {
                                final scrollAmount = cardWidth + cardSpacing;
                                final newOffset =
                                    (_tradeActionScrollController.offset -
                                            scrollAmount)
                                        .clamp(
                                  0.0,
                                  _tradeActionScrollController
                                      .position.maxScrollExtent,
                                );
                                _tradeActionScrollController.animateTo(
                                  newOffset,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    shadcn.Theme.of(context).colorScheme.card,
                                border: Border.all(
                                  color: shadcn.Theme.of(context)
                                      .colorScheme
                                      .border,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Right arrow (only show if scrolling is needed)
                if (needsScrolling)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_tradeActionScrollController.hasClients) {
                                final scrollAmount = cardWidth + cardSpacing;
                                final newOffset =
                                    (_tradeActionScrollController.offset +
                                            scrollAmount)
                                        .clamp(
                                  0.0,
                                  _tradeActionScrollController
                                      .position.maxScrollExtent,
                                );
                                _tradeActionScrollController.animateTo(
                                  newOffset,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    shadcn.Theme.of(context).colorScheme.card,
                                border: Border.all(
                                  color: shadcn.Theme.of(context)
                                      .colorScheme
                                      .border,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: resolveThemeColor(context,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTradeActionCard({
    required int tabIndex, // Add tab index parameter
    required BuildContext context,
    required String title,
    required List<TopGainers> stocks,
    required IconData icon,
    required Color iconColor,
    bool showPrice = true,
    required double width,
  }) {
    final stocksProvider = ref.watch(stocksProvide);
    final isLoaded = stocksProvider.isTradeActionLoaded;
    final hasStocks = stocks.isNotEmpty;
    final displayStocks = stocks.take(5).toList();
    final isVolumeBreakout = title == 'Volume breakout';

    return Container(
      width: width,
      height: 400,
      decoration: BoxDecoration(
        color: isDarkMode(context) ? MyntColors.dashboardCarColor : shadcn.Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.bold,
                      ),
                    ),
                  ],
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {

                      if (WebNavigationHelper.isAvailable) {
                        try {
                          WebNavigationHelper.navigateTo(
                              Routes.tradeActionScreen,
                              arguments: tabIndex);
                        } catch (e) {
                          // Fallback to direct navigation
                          _navigateToTradeAction(context, tabIndex);
                        }
                      } else {
                        _navigateToTradeAction(context, tabIndex);
                      }
                    },
                    child: Text(
                      'See all',
                      // '',
                      style: MyntWebTextStyles.para(
                        context,
                        darkColor: MyntColors.primaryDark,
                        lightColor: MyntColors.primary,
                        fontWeight: MyntFonts.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stock list
          if (hasStocks)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayStocks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: shadcn.Theme.of(context).colorScheme.border,
                ),
                itemBuilder: (context, index) {
                  final stock = displayStocks[index];
                  return _TradeActionStockItem(
                    stock: stock,
                    showVolume: isVolumeBreakout,
                    showPrice: showPrice,
                  );
                },
              ),
            )
          else if (isLoaded)
            // Show "No data" with bull image when data has been loaded but is empty
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // SvgPicture.asset(
                    //   assets.documentIcon,
                    //   width: 48,
                    //   height: 48,
                    //   colorFilter: ColorFilter.mode(
                    //     resolveThemeColor(
                    //       context,
                    //       dark: MyntColors.textSecondaryDark,
                    //       light: MyntColors.textSecondary,
                    //     ),
                    //     BlendMode.srcIn,
                    //   ),
                    // ),
                    const SizedBox(height: 8),
                    Text(
                      'No data available',
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Show loader while data is being fetched
            Expanded(
              child: Center(
                child: MyntLoader.simple(),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToTradeAction(BuildContext context, int tabIndex) {
    try {
      Navigator.of(context).pushNamed(
        Routes.tradeActionScreen,
        arguments: tabIndex,
      );
    } catch (e) {
      // Last resort: try MaterialPageRoute
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TradeActionScreenWeb(initialTabIndex: tabIndex),
        ),
      );
    }
  }

  void _scrollTradeAction(double offset) {
    if (_tradeActionScrollController.hasClients) {
      final currentOffset = _tradeActionScrollController.offset;
      final maxScrollExtent =
          _tradeActionScrollController.position.maxScrollExtent;
      final newOffset = currentOffset + offset;

      final clampedOffset = newOffset.clamp(0.0, maxScrollExtent);

      if (clampedOffset != currentOffset) {
        _tradeActionScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildPortfolioAnalysisSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          "Portfolio Analysis",
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Portfolio Analysis Card
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (WebNavigationHelper.isAvailable) {
                WebNavigationHelper.navigateTo(Routes.portfolioDashboard);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: shadcn.Theme.of(context).colorScheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark, light: MyntColors.divider),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context,
                              dark: MyntColors.primaryDark,
                              light: MyntColors.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pie_chart,
                      color: resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Portfolio Analysis',
                          style: MyntWebTextStyles.body(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analyze your portfolio performance, allocation, and returns',
                          style: MyntWebTextStyles.para(
                            context,
                            darkColor: MyntColors.textSecondaryDark,
                            lightColor: MyntColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAllIndicesBottomSheet(
    BuildContext context,
    IndexListProvider indexProvider,
  ) async {
    try {
      // Get first index from top indices or default index list as reference
      final topIndices = indexProvider.topIndicesForDashboard?.indValues;
      final defaultIndices = indexProvider.defaultIndexList?.indValues;

      // Use first index from top indices, or fallback to first default index
      final defaultIndex = (topIndices != null && topIndices.isNotEmpty)
          ? topIndices[0]
          : (defaultIndices != null && defaultIndices.isNotEmpty)
              ? defaultIndices[0]
              : null;

      if (defaultIndex == null) {
        return;
      }

      // Fetch index list for the bottom sheet
      await indexProvider.fetchIndexList("NSE", context);

      // Show the bottom sheet
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: IndexBottomSheetWeb(
              defaultIndex: defaultIndex,
              indexPosition: 0, // Use position 0 for "See all indices"
            ),
          );
        },
      );

      // Clean up after dialog closes
      await indexProvider.fetchIndexList("exit", context);
      final marketWatch = ref.read(marketWatchProvider);
      await marketWatch.requestMWScrip(context: context, isSubscribe: true);
    } catch (e) {
    }
  }
}

// Custom index card widget for dashboard
class _DashboardIndexCard extends ConsumerStatefulWidget {
  final dynamic indexItem;

  const _DashboardIndexCard({
    required this.indexItem,
  });

  @override
  ConsumerState<_DashboardIndexCard> createState() =>
      _DashboardIndexCardState();
}

class _DashboardIndexCardState extends ConsumerState<_DashboardIndexCard> {
  StreamSubscription? _subscription;
  String _ltp = "0.00";
  String _change = "0.00";
  String _perChange = "0.00";
  bool _isInitialized = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    final item = widget.indexItem;
    _ltp = (item.ltp == null || item.ltp == "null")
        ? "0.00"
        : item.ltp?.toString() ?? "0.00";
    _change = (item.change == null || item.change == "null")
        ? "0.00"
        : item.change?.toString() ?? "0.00";
    _perChange = (item.perChange == null || item.perChange == "null")
        ? "0.00"
        : item.perChange?.toString() ?? "0.00";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _setupSocketListener();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    final token = widget.indexItem.token?.toString() ?? "";
    if (token.isEmpty) return;

    final websocket = ref.read(websocketProvider);

    // Check existing data
    final existingData = websocket.socketDatas[token];
    if (existingData != null) {
      final hasChanged = _updateFromSocketData(existingData);
      if (hasChanged && mounted) {
        setState(() {});
      }
    }

    // Listen for updates - only rebuild if data actually changed
    _subscription = websocket.socketDataStream.listen((data) {
      if (data.containsKey(token) && mounted) {
        final socketData = data[token];
        if (socketData != null) {
          final hasChanged = _updateFromSocketData(socketData);
          if (hasChanged) {
            setState(() {});
          }
        }
      }
    });
  }

  bool _updateFromSocketData(dynamic data) {
    bool hasChanged = false;

    final newLtp = data['lp']?.toString() ?? "0.00";
    if (newLtp != "null" && newLtp != _ltp) {
      _ltp = newLtp;
      hasChanged = true;
    }

    final newChange = data['chng']?.toString() ?? "0.00";
    if (newChange != "null" && newChange != _change) {
      _change = newChange;
      hasChanged = true;
    }

    final newPerChange = data['pc']?.toString() ?? "0.00";
    if (newPerChange != "null" && newPerChange != _perChange) {
      _perChange = newPerChange;
      hasChanged = true;
    }

    return hasChanged;
  }

  Color _getChangeColor(BuildContext context) {
    if (_change.startsWith("-") || _perChange.startsWith('-')) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (_change == "0.00" || _perChange == "0.00") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor(context);
    final marketWatch = ref.read(marketWatchProvider);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try {
            // First, safely fetch the quote data
            await marketWatch.fetchScripQuoteIndex(
              widget.indexItem.token?.toString() ?? "",
              widget.indexItem.exch?.toString() ?? "",
              context,
            );

            final quots = marketWatch.getQuotes;

            // Make sure we have valid quote data before proceeding
            if (quots == null) {
              return;
            }

            // Create DepthInputArgs with null safety
            DepthInputArgs depthArgs = DepthInputArgs(
                exch: quots.exch?.toString() ?? "",
                token: quots.token?.toString() ?? "",
                tsym: quots.tsym?.toString() ?? "",
                instname: quots.instname?.toString() ?? "",
                symbol: quots.symbol?.toString() ?? "",
                expDate: quots.expDate?.toString() ?? "",
                option: quots.option?.toString() ?? "");

            // Call depth APIs with the safely constructed arguments
            if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
              await marketWatch.calldepthApis(context, depthArgs, "");
            }
          } catch (e) {
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use responsive width - minimum 140, expand to fit available space
            final cardWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 180.0;
            final isCompact = cardWidth < 160;

            return Container(
              constraints: const BoxConstraints(minWidth: 140),
              padding: EdgeInsets.all(isCompact ? 12 : 15),
              decoration: BoxDecoration(
                color: _isHovered
                    ? shadcn.Theme.of(context).colorScheme.muted
                    : resolveThemeColor(context,
                        dark: MyntColors.dashboardCarColor,
                        light: shadcn.Theme.of(context).colorScheme.card),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.indexItem.idxname?.toUpperCase() ?? "",
                    style: MyntWebTextStyles.symbol(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Price and change section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LTP without ₹ symbol, with profit/loss color
                      Text(
                        _ltp,
                        style: MyntWebTextStyles.price(
                          context,
                          color: changeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Change and percentage - wrap to next line if needed
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Text(
                            _change.startsWith("-") ? _change : "+$_change",
                            style: MyntWebTextStyles.priceChange(
                              context,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                          Text(
                            "($_perChange%)",
                            style: MyntWebTextStyles.priceChange(
                              context,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Custom stock card widget for gainers/losers
class _DashboardStockCard extends ConsumerStatefulWidget {
  final TopGainers stock;
  final bool isGainer;

  const _DashboardStockCard({
    required this.stock,
    required this.isGainer,
  });

  @override
  ConsumerState<_DashboardStockCard> createState() =>
      _DashboardStockCardState();
}

class _DashboardStockCardState extends ConsumerState<_DashboardStockCard> {
  StreamSubscription? _subscription;
  String _ltp = "0.00";
  String _change = "0.00";
  String _perChange = "0.00";
  bool _isInitialized = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ltp = widget.stock.lp ?? "0.00";
    _change = widget.stock.c ?? "0.00";
    _perChange = widget.stock.pc ?? "0.00";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _setupSocketListener();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    final token = widget.stock.token?.toString() ?? "";
    if (token.isEmpty) return;

    final websocket = ref.read(websocketProvider);

    final existingData = websocket.socketDatas[token];
    if (existingData != null) {
      final hasChanged = _updateFromSocketData(existingData);
      if (hasChanged && mounted) {
        setState(() {});
      }
    }

    // Listen for updates - only rebuild if data actually changed
    _subscription = websocket.socketDataStream.listen((data) {
      if (data.containsKey(token) && mounted) {
        final socketData = data[token];
        if (socketData != null) {
          final hasChanged = _updateFromSocketData(socketData);
          if (hasChanged) {
            setState(() {});
          }
        }
      }
    });
  }

  bool _updateFromSocketData(dynamic data) {
    bool hasChanged = false;

    final newLtp = data['lp']?.toString() ?? "0.00";
    if (newLtp != "null" && newLtp != _ltp) {
      _ltp = newLtp;
      hasChanged = true;
    }

    final newChange = data['c']?.toString() ?? "0.00";
    if (newChange != "null" && newChange != _change) {
      _change = newChange;
      hasChanged = true;
    }

    final newPerChange = data['pc']?.toString() ?? "0.00";
    if (newPerChange != "null" && newPerChange != _perChange) {
      _perChange = newPerChange;
      hasChanged = true;
    }

    return hasChanged;
  }

  Color _getChangeColor(BuildContext context) {
    if (_change.startsWith("-") || _perChange.startsWith('-')) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (_change == "0.00" || _perChange == "0.00") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor(context);
    final marketWatch = ref.read(marketWatchProvider);
    final symbolName = widget.stock.tsym?.split("-").isNotEmpty == true
        ? widget.stock.tsym!.split("-").first.toUpperCase()
        : widget.stock.tsym?.toUpperCase() ?? "";

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try {
            await marketWatch.fetchScripQuoteIndex(
              widget.stock.token?.toString() ?? "",
              widget.stock.exch?.toString() ?? "",
              context,
            );

            final quots = marketWatch.getQuotes;
            if (quots == null) {
              return;
            }

            DepthInputArgs depthArgs = DepthInputArgs(
                exch: quots.exch?.toString() ?? "",
                token: quots.token?.toString() ?? "",
                tsym: quots.tsym?.toString() ?? "",
                instname: quots.instname?.toString() ?? "",
                symbol: quots.symbol?.toString() ?? "",
                expDate: quots.expDate?.toString() ?? "",
                option: quots.option?.toString() ?? "");

            if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
              await marketWatch.calldepthApis(context, depthArgs, "");
            }
          } catch (e) {
          }
        },
        child: Container(
          width: 180,
          height: 125,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? shadcn.Theme.of(context).colorScheme.muted
                : shadcn.Theme.of(context).colorScheme.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: resolveThemeColor(context,
                  dark: MyntColors.dividerDark, light: MyntColors.divider),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stock name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbolName,
                    style: MyntWebTextStyles.body(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.stock.exch ?? "",
                    style: MyntWebTextStyles.caption(
                      context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Price and change section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LTP with profit/loss color
                  Text(
                    _ltp,
                    style: MyntWebTextStyles.body(
                      context,
                      color: changeColor,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Change and percentage - textPrimary color
                  Row(
                    children: [
                      Text(
                        _change.startsWith("-") ? _change : "+$_change ",
                        style: MyntWebTextStyles.para(
                          context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.semiBold,
                        ),
                      ),
                      Text(
                        "($_perChange%)",
                        style: MyntWebTextStyles.para(
                          context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.semiBold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Trade action stock item widget
class _TradeActionStockItem extends ConsumerStatefulWidget {
  final TopGainers stock;
  final bool showVolume;
  final bool showPrice;

  const _TradeActionStockItem({
    required this.stock,
    this.showVolume = false,
    this.showPrice = true,
  });

  @override
  ConsumerState<_TradeActionStockItem> createState() =>
      _TradeActionStockItemState();
}

class _TradeActionStockItemState extends ConsumerState<_TradeActionStockItem> {
  StreamSubscription? _subscription;
  String _ltp = "0.00";
  String _change = "0.00";
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _ltp = widget.stock.lp ?? "0.00";
    _change = widget.stock.c ?? "0.00";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _setupSocketListener();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setupSocketListener() {
    final token = widget.stock.token?.toString() ?? "";
    if (token.isEmpty) return;

    final websocket = ref.read(websocketProvider);

    final existingData = websocket.socketDatas[token];
    if (existingData != null) {
      final hasChanged = _updateFromSocketData(existingData);
      if (hasChanged && mounted) {
        setState(() {});
      }
    }

    // Listen for updates - only rebuild if data actually changed
    _subscription = websocket.socketDataStream.listen((data) {
      if (data.containsKey(token) && mounted) {
        final socketData = data[token];
        if (socketData != null) {
          final hasChanged = _updateFromSocketData(socketData);
          if (hasChanged) {
            setState(() {});
          }
        }
      }
    });
  }

  bool _updateFromSocketData(dynamic data) {
    bool hasChanged = false;

    final newLtp = data['lp']?.toString() ?? "0.00";
    if (newLtp != "null" && newLtp != _ltp) {
      _ltp = newLtp;
      hasChanged = true;
    }

    final newChange = data['c']?.toString() ?? "0.00";
    if (newChange != "null" && newChange != _change) {
      _change = newChange;
      hasChanged = true;
    }

    return hasChanged;
  }

  double get _computedChange {
    final lp = double.tryParse(_ltp);
    final close = double.tryParse(_change);
    if (lp != null && close != null) {
      return lp - close;
    }
    return 0.0;
  }

  double get _computedPerChange {
    final lp = double.tryParse(_ltp);
    final close = double.tryParse(_change);
    if (lp != null && close != null && close != 0) {
      return ((lp - close) / close) * 100;
    }
    return 0.0;
  }

  Color _getChangeColor(BuildContext context) {
    final change = _computedChange;
    if (change < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (change == 0) {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor(context);
    final marketWatch = ref.read(marketWatchProvider);
    final symbolName = widget.stock.tsym?.split("-").isNotEmpty == true
        ? widget.stock.tsym!.split("-").first.toUpperCase()
        : widget.stock.tsym?.toUpperCase() ?? "";
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: () async {
              try {
                await marketWatch.fetchScripQuoteIndex(
                  widget.stock.token?.toString() ?? "",
                  widget.stock.exch?.toString() ?? "",
                  context,
                );

                final quots = marketWatch.getQuotes;
                if (quots == null) {
                  return;
                }

                DepthInputArgs depthArgs = DepthInputArgs(
                    exch: quots.exch?.toString() ?? "",
                    token: quots.token?.toString() ?? "",
                    tsym: quots.tsym?.toString() ?? "",
                    instname: quots.instname?.toString() ?? "",
                    symbol: quots.symbol?.toString() ?? "",
                    expDate: quots.expDate?.toString() ?? "",
                    option: quots.option?.toString() ?? "");

                if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
                  await marketWatch.calldepthApis(context, depthArgs, "");
                }
              } catch (e) {
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              decoration: BoxDecoration(
                color: isHovered
                    // ? shadcn.Theme.of(context).colorScheme.muted
                  ? resolveThemeColor(context,
                      dark: MyntColors.primaryDark,
                      light: shadcn.Theme.of(context).colorScheme.muted,
                    ).withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // First row: Symbol | LTP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Symbol
                      Expanded(
                        child: Text(
                          symbolName,
                          style: MyntWebTextStyles.symbol(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      // LTP
                      if (widget.showPrice) ...[
                        Text(
                          "₹${(double.tryParse(_ltp) ?? 0.0).toStringAsFixed(2)}",
                          style: MyntWebTextStyles.price(
                            context,
                            color: changeColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Second row: Exchange | Change & Change %
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exchange
                      Expanded(
                        child: Text(
                          widget.stock.exch ?? "",
                          style: MyntWebTextStyles.exch(
                            context,
                            fontWeight: FontWeight.w500,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      // Change and percentage
                      if (widget.showPrice)
                        Text(
                          "${_computedChange < 0 ? _computedChange.toStringAsFixed(2) : _computedChange.toStringAsFixed(2)} (${_computedPerChange.toStringAsFixed(2)}%)",
                          style: MyntWebTextStyles.priceChange(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

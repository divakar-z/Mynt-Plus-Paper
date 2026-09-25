import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import '../../web/mutual_fund/mf_hold_new_screen_web.dart';
import '../../../provider/ledger_provider.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_state_text.dart';
import '../../../res/res.dart';
import '../profile_screen/fund_screen/secure_fund.dart';
import 'holdings/holding_screen.dart';
import 'positions/position_screen.dart';
import '../order_book/order_book_screen.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with TickerProviderStateMixin {
  late TabController _holdingsTabController;

  @override
  void initState() {
    //  await
    ref.read(portfolioProvider).fetchBrokerDetails(context, false, false);

    ref.read(portfolioProvider).portTab = TabController(
        length: ref.read(portfolioProvider).portTabName.length,
        vsync: this,
        initialIndex: ref.read(portfolioProvider).selectedTab);

    // Initialize holdingsTabController to prevent LateInitializationError
    _holdingsTabController = TabController(length: 2, vsync: this, initialIndex: ref.read(portfolioProvider).selectedHoldingsTab);
    ref.read(portfolioProvider).holdingsTabController = _holdingsTabController;
    
    // Add listener to sync tab controller changes with provider state
    _holdingsTabController.addListener(() {
      if (!mounted) return;
      ref.read(portfolioProvider).changeHoldingsTabIndex(_holdingsTabController.index);
    });

    ref.read(portfolioProvider).portTab?.addListener(() {
      if (!mounted) return;
      ref
          .read(portfolioProvider)
          .changeTabIndex(ref.read(portfolioProvider).portTab?.index ?? 0);

      // ref.read(portfolioProvider).tabSize(ref.read(themeProvider));
      if (ref.read(portfolioProvider).selectedTab == 0) {
        ref
            .read(portfolioProvider)
            .requestWSPosition(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: true);
        ref
            .read(portfolioProvider)
            .requestallHoldings(context: context, isSubscribe: false);
      } else if (ref.read(portfolioProvider).selectedTab == 1) {
        ref.read(portfolioProvider).cancelTimer();
        ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestWSPosition(context: context, isSubscribe: true);
        ref
            .read(portfolioProvider)
            .requestallHoldings(context: context, isSubscribe: false);

        if (ref.read(ledgerProvider).pledgeandunpledge == null) {
          ref.read(ledgerProvider).getCurrentDate("pandu");
          ref.read(ledgerProvider).fetchpledgeandunpledge(context);
        }

        ref.read(portfolioProvider).timerfunc();
      } else if (ref.read(portfolioProvider).selectedTab == 2) {
        // Orders tab - handle order-related logic
        ref.read(portfolioProvider).cancelTimer();
        ref
            .read(portfolioProvider)
            .requestWSPosition(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestallHoldings(context: context, isSubscribe: false);

        // Load order-related data
        ref.read(orderProvider).fetchOrderBook(context, false);
        ref.read(orderProvider).fetchTradeBook(context);
        ref.read(orderProvider).fetchGTTOrderBook(context, "");
        ref.read(orderProvider).fetchTriggeredGTTOrders(context);
        ref.read(orderProvider).fetchSipOrderHistory(context);
        ref.read(marketWatchProvider).fetchPendingAlert(context);
        ref
            .read(orderProvider)
            .requestWSOrderBook(context: context, isSubscribe: true);
      } else if (ref.read(portfolioProvider).selectedTab == 3) {
        ref.read(portfolioProvider).cancelTimer();

        ref
            .read(portfolioProvider)
            .requestWSPosition(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: false);
        ref.read(fundProvider).fetchFunds(context);
        // context
        //     .read(portfolioProvider)
        //     .requestallHoldings(context: context, isSubscribe: true);
      } else {
        ref.read(portfolioProvider).cancelTimer();
        ref
            .read(portfolioProvider)
            .requestWSPosition(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: false);
        ref
            .read(portfolioProvider)
            .requestallHoldings(context: context, isSubscribe: false);
      }
    });

    FirebaseAnalytics.instance.logScreenView(
      screenName: 'Portfolio Screen',
      screenClass: 'Portfolio_screen',
    );
    super.initState();
  }

  
  @override
  void dispose() {
    _holdingsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final portfolio = ref.watch(portfolioProvider);
      final theme = ref.read(themeProvider);
      String countText;
      if (portfolio.portTab?.index == 0) {
        countText = portfolio.allPostionList.isNotEmpty
            ? "${portfolio.allPostionList.length}"
            : "";
      } else if (portfolio.portTab?.index == 1) {
        final holdings = portfolio.holdingsModel;
        countText = (holdings != null && holdings.isNotEmpty)
            ? "${holdings.length}"
            : "";
      } else {
        countText = "";
      }

      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: MediaQuery.of(context).padding.bottom),
        child: Column(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const SizedBox(height: 100),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 40,
                child: TabBar(
                  onTap: (index) {
                    setState(() {});
                    FocusScope.of(context).unfocus();
                  },
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
                  isScrollable: true,
                  labelPadding: const EdgeInsets.only( left: 16, right: 12),
                  indicatorColor: theme.isDarkMode
                      ? colors.secondaryDark
                      : colors.secondaryLight,
                  unselectedLabelColor: theme.isDarkMode
                      ? colors.textSecondaryDark
                      : colors.textSecondaryLight,
                  unselectedLabelStyle: TextWidget.textStyle(
                    fontSize: 14,
                    theme: false,
                    fw: 3,
                  ),
                  labelColor: theme.isDarkMode
                      ? colors.secondaryDark
                      : colors.secondaryLight,
                  labelStyle:
                      TextWidget.textStyle(fontSize: 14, theme: false, fw: 3),
                  controller: portfolio.portTab,
                  tabs: List.generate(portfolio.portTabName.length, (index) {
                    final tabController = portfolio.portTab;
                    if (tabController == null) {
                      return Tab(
                        child: TextWidget.subText(
                          text: index == 0 ? "Holdings" : index == 1 ? "Positions" : index == 2 ? "Orders" : "Funds",
                          theme: false,
                          fw: 2,
                        ),
                      );
                    }
                    return AnimatedBuilder(
                      animation: tabController.animation!,
                      builder: (context, child) {
                        final isSelected = tabController.index == index;
                        final animationValue = tabController.animation!.value;
                        final isTransitioning =
                            (animationValue - index).abs() < 1;
        
                        final color = isTransitioning
                            ? Color.lerp(
                                theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                theme.isDarkMode
                                    ? colors.secondaryDark
                                    : colors.secondaryLight,
                                1 - (animationValue - index).abs())
                            : isSelected
                                ? theme.isDarkMode
                                    ? colors.secondaryDark
                                    : colors.secondaryLight
                                : theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight;
        
                        return Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              TextWidget.subText(
                                text: index == 0
                                    ? "Holding${portfolio.holdingsModel!.isNotEmpty ? "s" : ""}"
                                    : index == 1
                                        ? "Position${portfolio.allPostionList.isNotEmpty ? "s" : ""}"
                                        : index == 2
                                            ? "Orders"
                                            : "Funds",
                                theme: false,
                                color: color,
                                fw: isSelected ? 2 : 2,
                              ),
                              const SizedBox(width: 5),
                              if ((index == 0 &&
                                      (portfolio.holdingsModel?.isNotEmpty ??
                                          false)) ||
                                  (index == 1 &&
                                      portfolio.allPostionList.isNotEmpty))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: TextWidget.paraText(
                                    text: index == 0
                                        ? (portfolio.holdingsModel?.isNotEmpty ??
                                                false
                                            ? "${portfolio.holdingsModel!.length}"
                                            : "")
                                        : index == 1
                                            ? (portfolio.allPostionList.isNotEmpty
                                                ? "${portfolio.allPostionList.length}"
                                                : "")
                                            : "",
                                    theme: false,
                                    color: color,
                                    fw: isSelected ? 2 : 0,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color:
                    theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
              ),
            ],
          ),
          Expanded(
            // child: TransparentLoaderScreen(
            // isLoading: portfolio.loading,
            child: TabBarView(controller: portfolio.portTab, children: [
              portfolio.holdingsTabController.index == 0 ?
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabBar(context, ref),
                  const Expanded(child: HoldingScreen()),
                ],
              ) : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 _buildTabBar(context, ref),
                  const Expanded(child: MfHoldNewScreenWeb()),
                ],
              ),
              PositionScreen(listofPosition: portfolio.allPostionList),
              const OrdersTabView(),
              const SecureFund(),
              //   ]
              // ],
              // const Allholdings()
            ]),
            // )
          ),
        ]),
      );
    });
  }
}

Widget _buildTabBar(BuildContext context, WidgetRef ref) {
  final theme = ref.watch(themeProvider);
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    height: 40,
    decoration: BoxDecoration(
      color: theme.isDarkMode ? colors.searchBgDark : const Color(0xffF1F3F8),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(4),
    child: TabBar(
      controller: ref.read(portfolioProvider).holdingsTabController,
      tabAlignment: TabAlignment.fill,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      dividerColor: Colors.transparent,
      labelColor: theme.isDarkMode ? colors.textPrimaryDark : colors.textPrimaryLight,
      unselectedLabelColor: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
      labelStyle: TextWidget.textStyle(fontSize: 13, theme: false, fw: 2),
      unselectedLabelStyle: TextWidget.textStyle(fontSize: 13, theme: false, fw: 3),
      labelPadding: EdgeInsets.zero,
      tabs: const [
        Tab(text: "Equity"),
        Tab(text: "Mutual Fund"),
      ],
    ),
  );
}

// Orders tab view that embeds the OrderBook functionality
class OrdersTabView extends ConsumerWidget {
  const OrdersTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const OrderBookScreen();
  }
}

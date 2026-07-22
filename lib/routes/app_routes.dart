import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/profile_model/algo_strategy_model.dart';
import 'package:mynt_plus/screens/Mobile/algo/algo_create.dart';
import 'package:mynt_plus/screens/Mobile/bonds/bonds_common_search_screen.dart';
import 'package:mynt_plus/screens/Mobile/algo/algo_strategytlist.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart';
// import 'package:mynt_plus/screens/ipo/ipo_common_search_screen.dart';
import 'package:mynt_plus/screens/web/mutual_fund/cagr_calculator_screen_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_hold_singlepage_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_sip_details_screen_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/mf_sip_details_screen_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/order_single_page_web.dart';
import 'package:mynt_plus/screens/web/mutual_fund/redeem_new_bottomsheet_web.dart';
import 'package:mynt_plus/screens/Mobile/order_screen/order_confirmation_screen.dart';
import 'package:mynt_plus/screens/Mobile/profile_screen/app_webview/ipo_webview.dart';
import 'package:mynt_plus/screens/web/order/place_order_screen_web.dart';
import 'package:mynt_plus/screens/web/ordersbook/pending_alert_detail_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/notification_screens/notification_screen_web.dart';
import 'package:mynt_plus/screens/web/profile/pledge/pledge_approve_list_screen.dart';
import 'package:mynt_plus/screens/web/trade_action_screen_web.dart';
import 'package:mynt_plus/screens/web/window_based_home_screen.dart';
// import 'package:mynt_plus/screens/web/grid_dashboard_web.dart';
import '../main.dart'; // Import for FirebaseHelper
import '../screens/Mobile/algo/algo_strategy_show_list.dart';
import '../screens/Mobile/algo/create_algo_strategy_screen.dart';
import '../screens/Mobile/authentication/login/login_banner_screen.dart';
import '../screens/Mobile/authentication/login/login_screen.dart';
import '../screens/web/authentication/login/login_web.dart';
import '../screens/Mobile/authentication/password/change_pass.dart';
import '../screens/Mobile/authentication/password/forgot_pass_unblock_user.dart';
import '../screens/Mobile/bonds/bonds_main_screen.dart';
import '../screens/Mobile/bonds/bonds_order_screen/order_screen.dart';
import '../screens/Mobile/bonds/bonds_orderbook_screen/bonds_order_book_main_screen.dart';
import '../screens/Mobile/bonds/bonds_orderbook_screen/bonds_orderbook_details/close_order_details.dart';
import '../screens/Mobile/bonds/bonds_orderbook_screen/bonds_orderbook_details/open_order_details.dart';
import '../screens/Mobile/desk_reports/ca_action/ca_action_buyback.dart';
import '../screens/Mobile/desk_reports/ca_event_main_page.dart';
import '../screens/Mobile/desk_reports/calenderPnl_screen.dart';
import '../screens/Mobile/desk_reports/cdsl_pledge.dart';
import '../screens/Mobile/desk_reports/contract_calendar_screen.dart';
import '../screens/Mobile/desk_reports/cp_action_main_page.dart';
import '../screens/Mobile/desk_reports/equity_taxpnl_screen.dart';
import '../screens/Mobile/desk_reports/holding_screen.dart';
import '../screens/Mobile/desk_reports/ledger_screen.dart';
import '../screens/Mobile/desk_reports/pdf_downalod_screen.dart';
import '../screens/Mobile/desk_reports/pledge_history_main_screen.dart';
import '../screens/Mobile/desk_reports/pledge_unpledge_response_screen.dart';
import '../screens/Mobile/desk_reports/pledge_unpledge_screen.dart';
import '../screens/Mobile/desk_reports/position_screen.dart';
import '../screens/Mobile/desk_reports/profitnloss_screen.dart';
import '../screens/Mobile/desk_reports/tax_pnl_screen.dart';
import '../screens/Mobile/desk_reports/tradebook_screen.dart';
import '../screens/Mobile/market_watch/new_fundamental_screen.dart';
import '../screens/Mobile/market_watch/option_chain/collection_basket/basketlist_dashboard.dart';
import '../screens/Mobile/market_watch/option_chain/collection_basket/benchmark_backtest.dart';
import '../screens/Mobile/market_watch/option_chain/collection_basket/collection_basket_list.dart';
import '../screens/Mobile/market_watch/option_chain/collection_basket/create_baskerscreen.dart';
import '../screens/Mobile/market_watch/option_chain/collection_basket/save_strategy_screen.dart';
import '../screens/Mobile/stocks/explore/stocks/refer_earn.dart';
import '../screens/home_screen.dart';
import '../screens/Mobile/ipo/ipo_main_screen.dart';
import '../screens/Mobile/ipo/ipo_orderbook_screen/ipo_modify_order/modify_order_screen.dart';
import '../screens/Mobile/ipo/ipo_orderbook_screen/ipo_order_book_main_screen.dart';
import '../screens/Mobile/ipo/ipo_orderbook_screen/ipo_orderbook_details/close_order_details.dart';
import '../screens/Mobile/ipo/ipo_orderbook_screen/ipo_orderbook_details/open_order_details.dart';
import '../screens/Mobile/ipo/IPO_order_screen/ipo_order_screen.dart';
import '../screens/Mobile/market_watch/edit_scrip.dart';
import '../screens/Mobile/market_watch/fundamental_detail_screen.dart';
import '../screens/Mobile/market_watch/futures/future_screen.dart';
import '../screens/Mobile/market_watch/option_chain/option_chain_ss.dart';
import '../screens/Mobile/market_watch/search_screen.dart';
import '../screens/Mobile/market_watch/set_alert_screen_new.dart';
import '../screens/Mobile/market_watch/future_screen_new.dart';
import '../screens/web/mutual_fund/mf_nfo_screen_web.dart';
import '../screens/web/mutual_fund/mf_top_category_list_web.dart';
import '../screens/web/mutual_fund/mf_all_best_funds_web.dart';
import '../screens/web/mutual_fund/common_search_screen_web.dart';
import '../screens/web/mutual_fund/mf_order_book_screen_web.dart';
import '../screens/web/mutual_fund/mf_main_screen_web.dart';
import '../screens/web/mutual_fund/mf_order_screen_web.dart';
import '../screens/web/mutual_fund/mf_stock_detail_screen_web.dart';
import '../screens/Mobile/order_book/basket/basket_list.dart';
import '../screens/Mobile/order_book/exit_order_screen.dart';
import '../screens/Mobile/order_book/gtt_order_detail.dart';
import '../screens/Mobile/order_book/order_book_detail.dart';
import '../screens/Mobile/order_book/order_book_screen.dart';
import '../screens/Mobile/order_book/pending_alert_detail_screen.dart';
import '../screens/Mobile/order_book/sip_order_details.dart';
import '../screens/Mobile/order_book/trade_book_detail.dart';
import '../screens/Mobile/order_screen/Rework/modify_gtt.dart';
import '../screens/Mobile/order_screen/modify_place_order_screen.dart';
import '../screens/Mobile/order_screen/place_order_screen.dart';
import '../screens/Mobile/portfolio_screens/holdings/edies_webview.dart';
import '../screens/Mobile/portfolio_screens/holdings/exit_holdings_screen.dart';
import '../screens/Mobile/portfolio_screens/holdings/holding_detail_screen.dart';
// import '../screens/portfolio_screens/positions/exit_position_screen.dart';
import '../screens/Mobile/portfolio_screens/positions/exit_position_screen.dart';
import '../screens/Mobile/portfolio_screens/positions/group/position_group_detail.dart';
import '../screens/Mobile/portfolio_screens/positions/position_detail_screen.dart';
import '../screens/Mobile/profile_screen/app_webview/cams_web_view.dart';
import '../screens/Mobile/profile_screen/app_webview/fund_transaction.dart';
import '../screens/Mobile/profile_screen/app_webview/option_z.dart';
import '../screens/Mobile/profile_screen/app_webview/profile_web_view.dart';
import '../screens/Mobile/profile_screen/app_webview/report_web_view.dart';
import '../screens/Mobile/profile_screen/fund_screen/fund_screen.dart';
import '../screens/Mobile/profile_screen/fund_screen/secure_fund.dart';
import '../screens/Mobile/profile_screen/log_message.dart';
import '../screens/Mobile/profile_screen/manage_fund/report_screen.dart';
import '../screens/Mobile/profile_screen/my_ac_screens/bank_detail.dart';
// import '../screens/profile_screen/my_ac_screens/my_acc.dart';
// import '../screens/profile_screen/my_ac_screens/profile_details.dart';
import '../screens/Mobile/profile_screen/my_ac_screens/set_auto_pay.dart';
import '../screens/Mobile/profile_screen/my_ac_screens/setautopayscreen.dart';
import '../screens/Mobile/profile_screen/my_account_screens/profile_all_details_main_screen.dart';
import '../screens/Mobile/profile_screen/my_account_screens/profile_details_bank_screen.dart';
import '../screens/Mobile/profile_screen/my_account_screens/profile_details_screen.dart';
import '../screens/Mobile/profile_screen/notification_screens/notification_screen.dart';
import '../screens/Mobile/profile_screen/order_prefere_screen.dart';
import '../screens/Mobile/profile_screen/profile_main_screen.dart' as account;
import '../screens/Mobile/profile_screen/qr_scan_widget.dart';
import '../screens/Mobile/profile_screen/setting_screen/notification_setting.dart';
import '../screens/Mobile/profile_screen/setting_screen/settingmaincscreen.dart';
import '../screens/Mobile/profile_screen/setting_screen/window_settings.dart';
import '../screens/Mobile/profile_screen/settingui.dart' as settingUI;
import '../screens/splash_screen.dart';
import '../screens/Mobile/stocks/explore/stocks/broker_calculator.dart';
import '../screens/Mobile/stocks/explore/stocks/indices/all_index_screen.dart';
import '../screens/Mobile/stocks/explore/stocks/margin_calculator.dart';
import '../screens/Mobile/stocks/explore/stocks/news/news_listdata.dart';
import '../screens/Mobile/stocks/explore/stocks/portfolio_analysis.dart';
import '../screens/Mobile/stocks/explore/stocks/stock_screens.dart';
import '../screens/Mobile/stocks/explore/stocks/trade_action/all_trade.dart';
import '../screens/Mobile/stocks/explore/stocks/trade_action/sector_themeatic_details.dart';
import '../screens/web/market_watch/options/option_chain_ss_web.dart';
import '../screens/web/market_watch/set_alert_web.dart';
import '../screens/web/strategy_builder/strategy_builder_screen.dart';
import '../sharedWidget/internet_widget.dart';
import 'route_names.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import '../screens/web/mutual_fund/sip_calculator_screen_web.dart';
import '../screens/Mobile/profile_screen/fund_screen/withdraw/withdraw_screen.dart';
import '../provider/transcation_provider.dart';
import '../provider/thems.dart';

String? currentRouteName;

class AppRoutes {
  // Define constants for transitions
  static const Duration _transitionDuration =
      Duration(milliseconds: 180); // Slightly faster
  static const Curve _standardCurve =
      Curves.easeOutQuart; // Smooth acceleration-deceleration

// Helper method to create optimized transitions
  static PageRouteBuilder _createRoute({
    required Widget Function(BuildContext, Animation<double>, Animation<double>)
        pageBuilder,
    Offset beginOffset = const Offset(0.0, 0.0),
  }) {
    return PageRouteBuilder(
      pageBuilder: pageBuilder,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide transition
        final slideTween = Tween(
          begin: beginOffset,
          end: Offset.zero,
        ).chain(CurveTween(curve: _standardCurve));

        // Add subtle fade for enhanced experience
        final fadeTween = Tween(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: _standardCurve));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
      transitionDuration: _transitionDuration,
    );
  }

  // Safe method to log screen views to Firebase Analytics
  static void _logScreenView(String? screenName) {
    try {
      // Only log if Firebase is initialized and screenName is valid
      if (FirebaseHelper.isInitialized() && screenName != null) {
        FirebaseAnalytics.instance.logScreenView(
          screenName: screenName,
          screenClass: screenName,
        );
      }
    } catch (e) {
      // Silently handle analytics errors to prevent app navigation issues
    }
  }

  static Route router(RouteSettings settings) {
    currentRouteName = settings.name;

    // Log screen view using the safe method
    _logScreenView(currentRouteName);

    final dynamic args = settings.arguments;
    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case Routes.homeScreen:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      // case Routes.homeScreen:
      //   return MaterialPageRoute(builder: (_) => const HomeScreenDashBoard());
      case Routes.mainControlerScreenForWeb:
        return MaterialPageRoute(builder: (_) => const CustomizableSplitHomeScreen());
      case Routes.loginScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) =>
              kIsWeb ? const LoginScreenWeb() : const LoginScreen(),
          beginOffset: const Offset(1.0, 0.0),
        );

      case Routes.loginScreenBanner:
        return _createRoute(
          pageBuilder: (_, __, ___) => const LoginBannerScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.forgotPass:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ForgotPassUnblockUser(),
          beginOffset: const Offset(1.0, 0.0),
        );

      case Routes.changePass:
        return MaterialPageRoute(
            builder: (_) => ChangePass(isChangePass: args));
      case Routes.nointernet:
        return MaterialPageRoute(builder: (_) => const NoInternetScreen());
      case Routes.logError:
        return MaterialPageRoute(builder: (_) => const LogMessage());
      case Routes.orderPrefer:
        return MaterialPageRoute(
            builder: (_) => OrderPreference(
                  orderArg: args?['orderArg'],
                  scripInfo: args?['scripInfo'],
                  isRollback: args?['isRollback'],
                ));
      case Routes.stock:
        return MaterialPageRoute(builder: (_) => const StockScreen());
      case Routes.searchScrip:
        return _createRoute(
          pageBuilder: (_, __, ___) => SearchScreen(
            wlName: args,
            isBasket: args,
          ),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.editScrip:
        return _createRoute(
          pageBuilder: (_, __, ___) => EditScrip(wlName: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.algoCreate:
        return _createRoute(
          pageBuilder: (_, __, ___) => const AlgoCreate(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.algoList:
        return _createRoute(
          pageBuilder: (_, __, ___) => const AlgoStrategyList(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.algoStrategyShowList:
        return _createRoute(
          pageBuilder: (_, __, ___) => const AlgoStrategyShowList(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.createAlgoStrategy:
        return _createRoute(
          pageBuilder: (_, __, ___) {
            // Get arguments from the route context
            AlgoStrategyModel? strategyToEdit;
            if (args is AlgoStrategyModel) {
              strategyToEdit = args;
            } else if (args != null) {
              // If args is not null but not AlgoStrategyModel, try to extract it
            }
            return CreateAlgoStrategyScreen(strategyToEdit: strategyToEdit);
          },
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.fundamentalDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => FundamentalDetailScreen(
            wlValue: args['wlValue'],
            depthData: args['depthData'],
          ),
          beginOffset: const Offset(1.0, 0.0),
        );

     case Routes.pledgeapprovelistscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => PledgeApproveListScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.newFundamental:
        return _createRoute(
          pageBuilder: (_, __, ___) => NewFundamentalScreen(
            wlValue: args['wlValue'],
            depthData: args['depthData'],
          ),
          beginOffset: const Offset(1.0, 0.0),
        );

      case Routes.setAlertScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => SetAlertScreen(
            wlvalue: args['wlvalue'],
            depthdata: args['depthdata'],
          ),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.setAlertWeb:
        return _createRoute(
          pageBuilder: (_, __, ___) => SetAlertWeb(
            wlvalue: args['wlvalue'],
            depthdata: args['depthdata'],
          ),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.futureScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => FutureScreenNew(
            wlvalue: args['wlvalue'],
            depthdata: args['depthdata'],
          ),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.upiautopay:
        return _createRoute(
          pageBuilder: (_, __, ___) => const UpiPayement(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.notificationscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const NotificationScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.notificationscreenweb:
        return _createRoute(
          pageBuilder: (_, __, ___) => const NotificationScreenWeb(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.windowsetting:
        return _createRoute(
          pageBuilder: (_, __, ___) => const WindowSettings(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.placeOrderScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => PlaceOrderScreen(
            orderArg: args['orderArg'],
            scripInfo: args['scripInfo'],
            isBasket: args["isBskt"],
            fromChart: args["fromChart"] ?? false,
          ),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.placeOrderScreenWeb:
        return _createRoute(
          pageBuilder: (_, __, ___) => PlaceOrderScreenWeb(
            orderArg: args['orderArg'],
            scripInfo: args['scripInfo'],
            isBasket: args["isBskt"],
            fromChart: args["fromChart"] ?? false,
          ),
          beginOffset: const Offset(0.0, 1.0),
        );
      // case Routes.placeOrderScreenWeb:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => PlaceOrderScreenWeb(
      //       orderArg: args['orderArg'],
      //       scripInfo: args['scripInfo'],
      //       isBasket: args["isBskt"],
      //     ),
      //     beginOffset: const Offset(0.0, 1.0),
      //   );

      case Routes.orderConfirmation:
        return _createRoute(
          pageBuilder: (_, __, ___) => OrderConfirmationScreen(
            orderData: args['orderData'],
          ),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.optionChain:
        return _createRoute(
          pageBuilder: (_, __, ___) => OptionChainSS(wlValue: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.optionChainWeb:
        return _createRoute(
          pageBuilder: (_, __, ___) => OptionChainSSWeb(wlValue: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      // case Routes.gttOrderScreen:
      //   return PageRouteBuilder(
      //     pageBuilder: (context, animation, secondaryAnimation) =>
      //         GTTOrderScreen(
      //             orderArg: args['orderArg'], scripInfo: args['scripInfo']),
      //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
      //       const begin = Offset(0.0, 1.0);
      //       const end = Offset.zero;
      //       const curve = Curves.ease;

      //       final tween =
      //           Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      //       return SlideTransition(
      //         position: animation.drive(tween),
      //         child: child,
      //       );
      //     },
      //   );

      case Routes.modifyGtt:
        return _createRoute(
          pageBuilder: (_, __, ___) => ModifyGTT(
              gttOrderBook: args['gttOrderBook'], scripInfo: args['scripInfo']),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.modifyOrder:
        return _createRoute(
          pageBuilder: (_, __, ___) => ModifyPlaceOrderScreen(
              orderArg: args['orderArg'],
              modifyOrderArgs: args['modifyOrderArgs'],
              scripInfo: args['scripInfo']),
          beginOffset: const Offset(0.0, 1.0),
        );
      // case Routes.chartWebView:
      //   return PageRouteBuilder(
      //     pageBuilder: (context, animation, secondaryAnimation) =>
      //         ChartScreenWebView(chartArgs: args),
      //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
      //       const begin = Offset(-1.0, 0.0);
      //       const end = Offset.zero;
      //       const curve = Curves.ease;

      //       final tween =
      //           Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      //       return SlideTransition(
      //         position: animation.drive(tween),
      //         child: child,
      //       );
      //     },
      //   );

      case Routes.futures:
        return _createRoute(
          pageBuilder: (_, __, ___) => const FutureScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.holdingDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => HoldingDetailScreen(
              exchTsym: args['exchTsym'], holdingData: args['holdingData']),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.holdingExit:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ExitHoldingsScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.edis:
        return _createRoute(
          pageBuilder: (_, __, ___) => EdisWebview(params: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.optionZWebView:
        return _createRoute(
          pageBuilder: (_, __, ___) => OptionZWebView(argument: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.camsWebView:
        return _createRoute(
          pageBuilder: (_, __, ___) => CamsWebView(argument: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.orderDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => OrderBookDetail(orderBookData: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.bsktScripList:
        return _createRoute(
          pageBuilder: (_, __, ___) => BasketScripList(bsktName: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.tradeDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => TradeBookDetail(tradeData: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.gttOrderDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => GttOrderDetail(gttOrderBook: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.positionDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => PositionDetailScreen(positionList: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.positionGroupDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => PositionGroupDetail(positionData: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.positionExit:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ExitPositionScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.orderExit:
        return _createRoute(
          pageBuilder: (_, __, ___) => ExitOrderScreen(exitOrdersList: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.reports:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ReportsScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.myaccountScreen:
        // Extract arguments to pass to the screen
        final args = settings.arguments as Map<String, dynamic>?;
        final expandSection = args?['expandSection'] as String?;

        return _createRoute(
          pageBuilder: (_, __, ___) => account.MyAccountScreen(
            expandSection: expandSection,
          ),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.basketScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const StrategyDashboardScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.createBasketStrategy:
        return _createRoute(
          pageBuilder: (_, __, ___) => const StrategyBuilderScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.basketSelectionScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const FundSelectionScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.saveStrategyScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) {
            final routeArgs = args as Map<String, dynamic>?;
            return SaveStrategyScreen(
              isEditMode: routeArgs?['isEditMode'] ?? false,
              editStrategyName: routeArgs?['strategyName'],
              editStrategyUuid: routeArgs?['strategyUuid'],
            );
          },
          beginOffset: const Offset(-1.0, 0.0),
        );
      // case Routes.basketBacktestAnalysis:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => const BasketBacktestAnalysisScreen(),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );
      case Routes.benchmarkBacktestAnalysis:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BenchMarkBacktestScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // reports_dm
      case Routes.ledgerscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => LedgerScreen(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.positionscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => PositionScreen(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.pnlscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => PnlScreen(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.calenderpnlScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const CalenderpnlScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // rough

      // case Routes.heatmapcalendarscreen:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => HeatmapCalendarScreen(),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );

      case Routes.holdingscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => HoldingScreen(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.tradebook:
        return _createRoute(
          pageBuilder: (_, __, ___) => Tradebook(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.taxpnlscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const TaxPnlScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.caeventmainpage:
        return _createRoute(
          pageBuilder: (_, __, ___) => const CAEventMainPage(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.cpactionmainpage:
        return _createRoute(
          pageBuilder: (_, __, ___) => const CPActionMainpage(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.cabuyback:
        return _createRoute(
          pageBuilder: (_, __, ___) => const CABuyback(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.eqtaxpnleq:
        return _createRoute(
          pageBuilder: (_, __, ___) => const EqTaxpnlEq(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.pledgehistorymainscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const PledgeHistoryMainScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.pledgeunpledgeresponse:
        return _createRoute(
          pageBuilder: (_, __, ___) => PledgenUnpledgeResponse(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.pdfdownload:
        return _createRoute(
          pageBuilder: (_, __, ___) => PdfDownload(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.contractCalendar:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ContractCalendarScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.cdslWebView:
        return _createRoute(
          pageBuilder: (_, __, ___) => CDSLWebView(argument: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.pledgeandun:
        return _createRoute(
          pageBuilder: (_, __, ___) => PledgenUnpledge(ddd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

///////////////////////////////
      case Routes.settingscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const SettingMainScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.myAcc:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ProfileDetailsMainScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // case Routes.profileDetail:
      //   return PageRouteBuilder(
      //     pageBuilder: (context, animation, secondaryAnimation) =>
      //         const ProfileDetails(),
      //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
      //       const begin = Offset(0.0, 1.0);
      //       const end = Offset.zero;
      //       const curve = Curves.ease;

      //       final tween =
      //           Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      //       return SlideTransition(
      //         position: animation.drive(tween),
      //         child: child,
      //       );
      //     },
      //   );

      case Routes.bankDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BankDetail(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.setautopay:
        return _createRoute(
          pageBuilder: (_, __, ___) => const SetAutoPay(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.allIndex:
        return _createRoute(
          pageBuilder: (_, __, ___) => const AllIndicesScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.allTrade:
        return _createRoute(
          pageBuilder: (_, __, ___) => const AllTrade(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.tradeActionScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const TradeActionScreenWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.reportWebViewApp:
        return _createRoute(
          pageBuilder: (_, __, ___) => ReportWebViewApp(argument: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.ipowebview:
        return _createRoute(
          pageBuilder: (_, __, ___) => IpoWebview(argument: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.fund:
        return _createRoute(
          pageBuilder: (_, __, ___) => const SecureFund(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.fundTransaction:
        return _createRoute(
          pageBuilder: (_, __, ___) => FundTransaction(argument: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.profileWebViewApp:
        return _createRoute(
          pageBuilder: (_, __, ___) => ProfileWebViewApp(argument: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.allnews:
        return _createRoute(
          pageBuilder: (_, __, ___) => const NewsListData(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.profilesettingscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const settingUI.SettingsScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // case Routes.repeatOrd:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => RepeatOrder(orderBookList: args),
      //     beginOffset: const Offset(0.0, 1.0),
      //   );

      case Routes.notificationpage:
        return _createRoute(
          pageBuilder: (_, __, ___) => const Notificationpage(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.ipo:
        return _createRoute(
          pageBuilder: (_, __, ___) =>
              IPOScreen(initialTabIndex: args as int?, isIpo: true),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.applyIPO:
        return _createRoute(
          pageBuilder: (_, __, ___) => UnifiedIpoOrderScreen(ipoData: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // case Routes.smeapplyIPO:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => SMEApplyIpoScreen(smeipo: args),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );

      case Routes.ipoorderbook:
        return _createRoute(
          pageBuilder: (_, __, ___) => const IpoOrderbookMainScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.modifyipoorder:
        return _createRoute(
          pageBuilder: (_, __, ___) =>
              ModifyIpoOrderScreen(modifyipoorder: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.ipoclosedetailsscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => IpoCloseOrderDetails(
            ipoclose: args,
          ),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.ipoopendetailsscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => IpoOpenOrderDetails(
            ipodetails: args,
          ),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.sectorThematicDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => SectorThematicDetail(data: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.pendingalertdetails:
        // Check if running on web or kIsWeb
        if (kIsWeb) {
          return _createRoute(
            pageBuilder: (_, __, ___) => PendingAlertDetailScreenWeb(alert: args),
            beginOffset: const Offset(0.0, 1.0),
          );
        } else {
          return _createRoute(
            pageBuilder: (_, __, ___) => PendingAlertDetails(alert: args),
            beginOffset: const Offset(0.0, 1.0),
          );
        }

      case Routes.qrscanner:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BarcodeScannerWithScanWindow(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.bonds:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BondsScreen(isBonds: true),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.mfmainscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MfmainScreenWeb(),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.mfCategoryList:
        return _createRoute(
          pageBuilder: (_, __, ___) => MFCategoryListScreenWeb(title: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.mfnfoscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MFNFOScreenWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.mfsipcalscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MFSIPSCREENWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.brokerCalculator:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BrokerageCalculatorScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.marginCalculator:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MarginCalculatorScreen(),
          beginOffset: const Offset(-1.0, 0.0),
        );
        case Routes.portfolioDashboard:
          return _createRoute(
            pageBuilder: (_, __, ___) => const PortfolioDashboardScreen(),
            beginOffset: const Offset(-1.0, 0.0),
          );
        case Routes.referAndEarn:
          return _createRoute(
            pageBuilder: (_, __, ___) =>  const ReferAndEarnScreen(),
            beginOffset: const Offset(-1.0, 0.0),
          );
      case Routes.mfcagrcalss:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MFCAGRCALWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.mfOrderbookscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MfOrderBookScreenWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.mfSipdetScren:
        return _createRoute(
          pageBuilder: (_, __, ___) => const mfSipdetScrenWeb(data: {}),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.orderBook:
        return _createRoute(
          pageBuilder: (_, __, ___) => const OrderBookScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.mfholdsinlepage:
        return _createRoute(
          pageBuilder: (_, __, ___) => const mfholdsinlepageWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.mforderdetscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const mforderdetscreenWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.redeemNewBottomSheet:
        return _createRoute(
          pageBuilder: (_, __, ___) => const RedemptionBottomScreenNewWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // case Routes.iposearchscreen:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => const IpoCommonSearch(),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );
      case Routes.bondssearchScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BondsCommonSearch(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.bondsclosedetailsscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) =>
              BondsCloseOrderDetails(bondsCloseDetails: args),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.bondsopendetailsscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) =>
              BondsOpenOrderDetails(bondsdetails: args),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.bondsorderbook:
        return _createRoute(
          pageBuilder: (_, __, ___) => const BondsOrderbookMainScreen(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.bondsPlaceOrder:
        return _createRoute(
          pageBuilder: (_, __, ___) => ApplyBondsScreen(
            bondInfo: args,
          ),
          beginOffset: const Offset(0.0, 1.0),
        );
      case Routes.mfsearchscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => const MfCommonSearchWeb(),
          beginOffset: const Offset(-1.0, 0.0),
        );
      // case Routes.mfWatchlist:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => const MFWatchlistScreen(),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );
      case Routes.mfStockDetail:
        return _createRoute(
          pageBuilder: (_, __, ___) => MFStockDetailScreenWeb(mfStockData: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.mforderScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => MFOrderScreenWeb(mfData: args),
          beginOffset: const Offset(-1.0, 0.0),
        );
      case Routes.sipDetails:
        return _createRoute(
          pageBuilder: (_, __, ___) => SipOrderDetails(sipdetails: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      /////
      case Routes.fundscreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => FundScreen(dd: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      // case Routes.optionStrategy:
      //   return _createRoute(
      //     pageBuilder: (_, __, ___) => const OptionStrategey(),
      //     beginOffset: const Offset(-1.0, 0.0),
      //   );

      case Routes.strategyBuilder:
        return _createRoute(
          pageBuilder: (_, __, ___) => const StrategyBuilderScreenWeb(),
          beginOffset: const Offset(1.0, 0.0),
        );

      case Routes.bestMfScreen:
        return _createRoute(
          pageBuilder: (_, __, ___) => SaveTaxesScreenWeb(title: args),
          beginOffset: const Offset(-1.0, 0.0),
        );

      case Routes.profile:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ProfileInfoDetails(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.bank:
        return _createRoute(
          pageBuilder: (_, __, ___) => const ProfileDetailsBank(),
          beginOffset: const Offset(0.0, 1.0),
        );

      case Routes.withdrawscreen:
        final trancation = args as TranctionProvider;
        return _createRoute(
          pageBuilder: (_, __, ___) => Consumer(
            builder: (context, ref, _) {
              final theme = ref.read(themeProvider);
              final fund = ref.watch(transcationProvider);
              return WithdrawScreen(
                withdarw: trancation,
                foucs: fund.focusNode,
                theme: theme,
                segment: fund.textValue,
              );
            },
          ),
          beginOffset: const Offset(-1.0, 0.0),
        );

      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
          body: Center(
              child: Text('404 Page Not Found',
                  style: dysInter(
                      textStyle: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)))));
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/marketwatch_model/market_watch_scrip_model.dart';
import 'package:mynt_plus/screens/web/order/place_order_screen_web.dart';
import 'package:mynt_plus/screens/web/chart/web_chart_manager.dart';

import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/thems.dart';

/// ChartScreenWebViews - Renders the shared TradingView iframe.
///
/// Symbol changes are handled by [setChartScript] in MarketWatchProvider
/// which calls [WebChartManager.changeSymbol] directly. This widget only
/// initializes the manager and renders the iframe.
class ChartScreenWebViews extends ConsumerStatefulWidget {
  final ChartArgs chartArgs;

  const ChartScreenWebViews({
    super.key,
    required this.chartArgs,
  });

  @override
  ConsumerState<ChartScreenWebViews> createState() => _ChartScreenWebViewsState();
}

class _ChartScreenWebViewsState extends ConsumerState<ChartScreenWebViews> {
  @override
  void initState() {
    super.initState();
    // Initialize the shared chart manager (registers iframe if not already)
    webChartManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // Note: Symbol changes are handled by setChartScript() in MarketWatchProvider
    // which calls webChartManager.changeSymbol() with the correct params.
    // This widget only renders the iframe - it does NOT manage symbol changes.

    return SafeArea(
      child: SizedBox(
        height: (MediaQuery.of(context).size.height - 205),
        child: HtmlElementView(
          key: const ValueKey(WebChartManager.viewType),
          viewType: WebChartManager.viewType,
        ),
      ),
    );
  }

  Future<void> placeOrderInput(MarketWatchProvider scripInfo, BuildContext ctx,
      GetQuotes depthData, bool transType) async {
    
    final raw = ref.read(marketWatchProvider).getQuotes;
    await ref.read(marketWatchProvider).fetchScripInfo(
        raw!.token.toString(), raw.exch.toString(), ctx, true);
    OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: raw.exch.toString(),
        tSym: raw.tsym.toString(),
        isExit: false,
        token: raw.token.toString(),
        transType: transType,
        lotSize: depthData.ls,
        ltp: "${depthData.lp ?? depthData.c ?? 0.00}",
        perChange: depthData.pc ?? "0.00",
        orderTpye: '',
        holdQty: '',
        isModify: false,
        raw: {});

    // Show place order screen as draggable dialog
    PlaceOrderScreenWeb.showDraggable(
      context: ctx,
      orderArg: orderArgs,
      scripInfo: ref.read(marketWatchProvider).scripInfoModel!,
      isBasket: "",
    );
  }
}

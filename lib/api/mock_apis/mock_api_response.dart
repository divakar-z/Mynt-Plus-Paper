 

 

import 'package:flutter/services.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/order_book_model/trade_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';

import '../../models/desk_reports_model/holdings_model.dart';
import '../../models/json_model/strategy_model.dart';
import '../core/api_core.dart';

mixin MockApiResponse on ApiCore {

// Get json datas from asstes

  Future<StrategyJosnModel> getStrategyJson() async {
    try {
      final resp = await rootBundle.loadString("assets/mock_json/strategy.json");

      final json = jsonDecode(resp);

      // log("Strategy model =>  $json");
      return StrategyJosnModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }


    Future<Map<String, dynamic>> mockOrderBookResponse() async {
    try {
      final resp = await rootBundle.loadString("assets/mock_json/mockOrderBook.json");

      final json = jsonDecode(resp);
      final List<OrderBookModel> data = [];
      // log("Strategy model =>  $json");
      for (final item in json) {
              data.add(OrderBookModel.fromJson(item as Map<String, dynamic>));
            }
      return ({'stat': 'success', 'data': data});
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> mockPositionBookResponse() async {
    try {
      final resp = await rootBundle.loadString("assets/mock_json/mockPositionBook.json");

      final json = jsonDecode(resp);
      final List<PositionBookModel> data = [];
      // log("Strategy model =>  $json");
      for (final item in json) {
              data.add(
                  PositionBookModel.fromJson(item as Map<String, dynamic>));
            }
      return ({'stat': 'success', 'data': data});
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> mockTradeBookResponse() async {
    try {
      final resp = await rootBundle.loadString("assets/mock_json/mockTradeBook.json");

      final json = jsonDecode(resp);
      final List<TradeBookModel> data = [];
      // log("Strategy model =>  $json");
      for (final item in json) {
              data.add(
                  TradeBookModel.fromJson(item as Map<String, dynamic>));
            }
      return ({'stat': 'success', 'data': data});
    } catch (e) {
      rethrow;
    }
  }

  /// Returns a mock holdings response that mirrors the Noren `/Holdings`
  /// shape (top-level array, each item with nested `exch_tsym` and the raw
  /// qty fields). Mirrors `_holdingsFromNoren` in `ledger_provider.dart`:
  ///   - APPROVED = computed saleableQty
  ///   - NPOADQTY = raw npoadqty (used by Gate 2 as the e-DIS gate)
  Future<HoldingModel> mockHoldingsResponse() async {
    try {
      final resp =
          await rootBundle.loadString("assets/mock_json/mockHoldings.json");
      final decoded = jsonDecode(resp);
      if (decoded is! List) {
        return HoldingModel.fromJson({});
      }
      int parseQty(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
      final List<Map<String, dynamic>> mapped = [];
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;
        final exchTsym = raw['exch_tsym'];
        String? isin;
        if (exchTsym is List && exchTsym.isNotEmpty) {
          final first = exchTsym.first;
          if (first is Map<String, dynamic>) {
            isin = first['isin']?.toString();
          }
        }
        if (isin == null || isin.isEmpty) continue;
        final saleable = (parseQty(raw['holdqty']) +
                parseQty(raw['dpqty']) +
                parseQty(raw['btstqty'])) -
            parseQty(raw['usedqty']);
        mapped.add({
          'ISIN': isin,
          'NET': raw['holdqty']?.toString() ?? '0',
          'APPROVED': saleable.toString(),
          'NPOADQTY': raw['npoadqty'],
        });
      }
      return HoldingModel.fromJson({'Holdings': mapped});
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> mockPlaceSliceOrderResponse() async {
    try {
      final resp = await rootBundle.loadString("assets/mock_json/mockPlaceSliceOrderResp.json");
      final json = jsonDecode(resp);
      final List<PlaceOrderModel> data = [];
      for (final item in json) {
        data.add(PlaceOrderModel.fromJson(item as Map<String, dynamic>));
      }
      return ({'stat': 'success', 'data': data});
    } catch (e) {
      rethrow;
    }
  }
}

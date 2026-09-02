import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../utils/url_utils.dart';
import '../models/order_book_model/cancel_order_model.dart';
import '../models/order_book_model/get_brokerage.dart';
import '../models/order_book_model/gtt_order_book.dart';
import '../models/order_book_model/modify_order_model.dart';
import '../models/order_book_model/modify_sip_model.dart';
import '../models/order_book_model/order_book_model.dart';
import '../models/order_book_model/order_history_model.dart';
import '../models/order_book_model/order_margin_model.dart';
import '../models/order_book_model/place_gtt_order.dart';
import '../models/order_book_model/place_order_model.dart';
import '../models/order_book_model/sip_order_book.dart';
import '../models/order_book_model/sip_order_cancel.dart';
import '../models/order_book_model/sip_place_order.dart';
import '../models/order_book_model/trade_book_model.dart';
import '../models/strategy_builder_model/select_symbols_model.dart';
import 'core/api_core.dart';

// Synchronous parsers for compute() on native platforms.
// On web, compute() runs on the main thread — use async chunked versions instead.
//
// API contract:
//   Success → JSON List of order objects
//   No data / error → JSON Map: {"stat": "Not_Ok", "emsg": "..."}
//   Session expired → JSON Map: {"stat": "Not_Ok", "emsg": "Session Expired : ..."}

Map<String, dynamic> _parseOrderBookResponse(String body) {
  final json = jsonDecode(body);

  if (json is Map<String, dynamic>) {
    if (json['emsg'] != null &&
        json['emsg'].toString().contains('Session Expired')) {
      return {"stat": "error", "data": [OrderBookModel.fromJson(json)]};
    }
    return {"stat": "no data", "data": <OrderBookModel>[]};
  }

  if (json is List && json.isNotEmpty) {
    final List<OrderBookModel> data = [];
    for (final item in json) {
      data.add(OrderBookModel.fromJson(item as Map<String, dynamic>));
    }
    return {"stat": "success", "data": data};
  }

  return {"stat": "no data", "data": <OrderBookModel>[]};
}

Map<String, dynamic> _parseTradeBookResponse(String body) {
  final json = jsonDecode(body);

  if (json is Map<String, dynamic>) {
    if (json['emsg'] != null &&
        json['emsg'].toString().contains('Session Expired')) {
      return {"stat": "error", "data": [TradeBookModel.fromJson(json)]};
    }
    return {"stat": "no data", "data": <TradeBookModel>[]};
  }

  if (json is List && json.isNotEmpty) {
    final List<TradeBookModel> data = [];
    for (final item in json) {
      data.add(TradeBookModel.fromJson(item as Map<String, dynamic>));
    }
    return {"stat": "success", "data": data};
  }

  return {"stat": "no data", "data": <TradeBookModel>[]};
}

/// Batch size for chunked parsing — process this many items, then yield to event loop
const int _parseBatchSize = 200;

/// Async chunked order book parser for web — O(n) single pass with yields
/// every [_parseBatchSize] items so other XHR callbacks can process.
Future<Map<String, dynamic>> _parseOrderBookAsync(String body) async {
  final json = jsonDecode(body);

  if (json is Map<String, dynamic>) {
    if (json['emsg'] != null &&
        json['emsg'].toString().contains('Session Expired')) {
      return {"stat": "error", "data": [OrderBookModel.fromJson(json)]};
    }
    return {"stat": "no data", "data": <OrderBookModel>[]};
  }

  if (json is List && json.isNotEmpty) {
    final List<OrderBookModel> data = [];
    for (var i = 0; i < json.length; i++) {
      data.add(OrderBookModel.fromJson(json[i] as Map<String, dynamic>));
      // Yield every batch so event loop can process other XHR callbacks
      if ((i + 1) % _parseBatchSize == 0) {
        await Future.delayed(Duration.zero);
      }
    }
    return {"stat": "success", "data": data};
  }

  return {"stat": "no data", "data": <OrderBookModel>[]};
}

/// Async chunked trade book parser for web — O(n) single pass with yields
Future<Map<String, dynamic>> _parseTradeBookAsync(String body) async {
  final json = jsonDecode(body);

  if (json is Map<String, dynamic>) {
    if (json['emsg'] != null &&
        json['emsg'].toString().contains('Session Expired')) {
      return {"stat": "error", "data": [TradeBookModel.fromJson(json)]};
    }
    return {"stat": "no data", "data": <TradeBookModel>[]};
  }

  if (json is List && json.isNotEmpty) {
    final List<TradeBookModel> data = [];
    for (var i = 0; i < json.length; i++) {
      data.add(TradeBookModel.fromJson(json[i] as Map<String, dynamic>));
      if ((i + 1) % _parseBatchSize == 0) {
        await Future.delayed(Duration.zero);
      }
    }
    return {"stat": "success", "data": data};
  }

  return {"stat": "no data", "data": <TradeBookModel>[]};
}

mixin OrderAPI on ApiCore {
  // Get Order placing response from kambala

  Future<PlaceOrderModel> getPlaceOrder(PlaceOrderInput placeOrderInput, String ip) async {
    try {

      final uri = Uri.parse(apiLinks.placeOrder);
      Map payload = {
        "uid": prefs.clientId,
        "actid": prefs.clientId,
        "exch": placeOrderInput.exch,
        "tsym": UrlUtils.encodeParameter(placeOrderInput.tsym),
        "qty": placeOrderInput.qty.replaceAll("-", ""),
        // Disclosed quantity. This key was missing entirely, so anything the
        // user typed on Place Order was silently dropped and the order book
        // came back with dscqty 0. The vendor always sends it - the real
        // value when set, "0" when not - so match that. Several call sites
        // pass an empty string, coerced here rather than at each one.
        "dscqty": placeOrderInput.dscqty.trim().isEmpty
            ? "0"
            : placeOrderInput.dscqty.trim(),
        "prc": (placeOrderInput.prctype == 'MKT' ||
                placeOrderInput.prctype == 'SL-MKT')
            ? '0'
            : placeOrderInput.prc,
        "prd": placeOrderInput.prd,
        "trantype": placeOrderInput.trantype,
        "prctyp": placeOrderInput.prctype,
        "ret": placeOrderInput.ret.toUpperCase(),
        "channel": placeOrderInput.channel,
        "usr_agent": "${prefs.deviceName!}   ${prefs.imei}",
        "app_inst_id": "${prefs.imei}",
        "ordersource": "WEB",
        "ipaddr": ip
      };
      if (placeOrderInput.amo == "Yes") {
        payload.addAll({"amo": "Yes"});
      }
      if (placeOrderInput.blprc.isNotEmpty) {
        payload.addAll({"blprc": placeOrderInput.blprc});
      }
      if (placeOrderInput.bpprc.isNotEmpty) {
        payload.addAll({"bpprc": placeOrderInput.bpprc});
      }
      if (placeOrderInput.trailprc.isNotEmpty) {
        payload.addAll({"trailprc": placeOrderInput.trailprc});
      }
      if (placeOrderInput.trgprc.isNotEmpty) {
        payload.addAll({"trgprc": placeOrderInput.trgprc});
      }
      if (placeOrderInput.mktProt.isNotEmpty) {
        payload.addAll({"mkt_protection": placeOrderInput.mktProt});
      }

      log("PlaceOrder Input => $payload");

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');
      log("PlaceOrder => ${res.body}");
      final json = jsonDecode(res.body);

      return PlaceOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Get order book data from kambala

  Future<Map<String, dynamic>> getOrderBook() async {
    try {
      final uri = Uri.parse(apiLinks.getOrder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}" }&jKey=${prefs.clientSession}''');

      if (res.statusCode == 200) {
        // On web, compute() runs synchronously and blocks the main thread.
        // Use async chunked parser to yield between batches so other
        // XHR callbacks (e.g. getLinkedScrips) can process their responses.
        if (kIsWeb) {
          return await _parseOrderBookAsync(res.body);
        }
        return await compute(_parseOrderBookResponse, res.body);
      } else {
        final json = jsonDecode(res.body);
        final List<OrderBookModel> data = [];
        if (json is Map<String, dynamic> &&
            json['emsg'] != null &&
            json['emsg'].toString().contains('Session Expired')) {
          data.add(OrderBookModel.fromJson(json));
        }
        return {"stat": "error", "data": data};
      }
    } catch (e) {
      rethrow;
    }
  }

// Get Trade book data from kambala

  Future<Map<String, dynamic>> getTradeBook() async {
    try {
      final uri = Uri.parse(apiLinks.tradeBook);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

      if (res.statusCode == 200) {
        if (kIsWeb) {
          return await _parseTradeBookAsync(res.body);
        }
        return await compute(_parseTradeBookResponse, res.body);
      } else {
        final json = jsonDecode(res.body);
        final List<TradeBookModel> data = [];
        if (json is Map<String, dynamic> &&
            json['emsg'] != null &&
            json['emsg'].toString().contains('Session Expired')) {
          data.add(TradeBookModel.fromJson(json));
        }
        return {"stat": "error", "data": data};
      }
    } catch (e) {
      rethrow;
    }
  }

// Get Single scrip order history from kambala

  Future<List<OrderHistoryModel>> getOrderHistory(String orderNum) async {
    try {
      final uri = Uri.parse(apiLinks.orderHistory);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","norenordno":"$orderNum"}&jKey=${prefs.clientSession}''');
      // log("ORDER History RESPONSE ::: ${res.body}");

      final List<OrderHistoryModel> data = [];

      final json = jsonDecode(res.body);
      try {
        if (json['stat'] == 'Not_Ok') {
          final OrderHistoryModel ord =
              OrderHistoryModel.fromJson(json as Map<String, dynamic>);
          return [ord];
        } else {
          for (final item in json) {
            data.add(OrderHistoryModel.fromJson(item as Map<String, dynamic>));
          }
        }
      } catch (e) {
        if (res.statusCode == 200) {
          for (final item in json) {
            data.add(OrderHistoryModel.fromJson(item as Map<String, dynamic>));
          }
        }
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

// get Cancel order response from kambala

  Future<CancelOrderModel> getCancelOrder(String orderNo) async {
    try {
      final uri = Uri.parse(apiLinks.cancelOrder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","norenordno":"$orderNo","ordersource":"WEB"}&jKey=${prefs.clientSession}''');

      log("Cancel Order => ${res.body}"'''jData={"uid":"${prefs.clientId}","norenordno":"$orderNo","ordersource":"WEB"}&jKey=${prefs.clientSession}''');
      final json = jsonDecode(res.body);

      return CancelOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get Exit SNOCancel order response from kambala

  Future<CancelOrderModel> getExitSNOOrder(String orderNo, String prd) async {
    try {
      final uri = Uri.parse(apiLinks.exitSNOOrder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","norenordno":"$orderNo","prd":"$prd"}&jKey=${prefs.clientSession}''');

      log("Exit SNO OrderModel => ${res.body} ${'''jData={"uid":"${prefs.clientId}","norenordno":"$orderNo","prd":"$prd"}&jKey=${prefs.clientSession}'''}");
      final json = jsonDecode(res.body);

      return CancelOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // get order margin response from kambala

  Future<OrderMarginModel> getOrderMargin(OrderMarginInput input) async {
    try {
      final uri = Uri.parse(apiLinks.orderMargin);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","exch":"${input.exch}","tsym":"${UrlUtils.encodeParameter(input.tsym)}","qty":"${input.qty}","prc":"${input.prc}","prd":"${input.prd}","trantype":"${input.trantype}","prctyp":"${input.prctyp}","rorgqty":"${input.rorgqty}","rorgprc":"${input.rorgprc}","blprc": "${input.blprc}","trgprc": "${input.trgprc}"}&jKey=${prefs.clientSession}''');

      log("Order Margin => ${res.body}  ${'''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","exch":"${input.exch}","tsym":"${UrlUtils.encodeParameter(input.tsym)}","qty":"${input.qty}","prc":"${input.prc}","prd":"${input.prd}","trantype":"${input.trantype}","prctyp":"${input.prctyp}","rorgqty":"${input.rorgqty}","rorgprc":"${input.rorgprc}","blprc": "${input.blprc}","trgprc": "${input.trgprc}"}&jKey=${prefs.clientSession}'''}");
      final json = jsonDecode(res.body);

      return OrderMarginModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // get  order brokerage response from kambala

  Future<GetBrokerageModel> getBrokerage(BrokerageInput input) async {
    try {
      final uri = Uri.parse(apiLinks.getBrokerage);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","exch":"${input.exch}","tsym":"${UrlUtils.encodeParameter(input.tsym)}","qty":"${input.qty}","prc":"${input.prc}","prd":"${input.prd}","trantype":"${input.trantype}" }&jKey=${prefs.clientSession}''');

      log("Order Brokerage => ${res.body} ${'''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","exch":"${input.exch}","tsym":"${UrlUtils.encodeParameter(input.tsym)}","qty":"${input.qty}","prc":"${input.prc}","prd":"${input.prd}","trantype":"${input.trantype}" }&jKey=${prefs.clientSession}'''}");
      final json = jsonDecode(res.body);

      return GetBrokerageModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get Cancel GTT order response from kambala

  Future<PlaceGttOrderModel> cancelGTTOrderAPI(String cancelId) async {
    try {
      final uri = Uri.parse(apiLinks.cancelGTTOrderURL);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","al_id":"$cancelId" }&jKey=${prefs.clientSession}''');

      // log("Cancel GTT => ${res.body} ");
      final json = jsonDecode(res.body);

      return PlaceGttOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get Modify order response from kambala

  Future<ModifyOrderModel> getModifyOrder(ModifyOrderInput input, String ip) async {
    try {

      final uri = Uri.parse(apiLinks.mdifyOrder);
      Map payload = {
        "uid": prefs.clientId,
        "actid": prefs.clientId,
        "exch": input.exch,
        "tsym":  UrlUtils.encodeParameter(input.tsym),
        "qty": input.qty.replaceAll("-", ""),
        "prc": (input.prctyp == 'MKT' || input.prctyp == 'SL-MKT')
            ? '0'
            : input.prc,
        "norenordno": input.orderNum,
        "prctyp": input.prctyp,
        "ret": input.ret.toUpperCase(),
        "dscqty": input.dscqty,
        "ordersource": "WEB",
        "prd": input.prd,
        "trantype": input.trantype,
        "usr_agent": "${prefs.deviceName!}   ${prefs.imei}",
        "app_inst_id": "${prefs.imei}",
        "ipaddr": ip
      };

      if ((input.prctyp == 'SL-MKT' || input.prctyp == 'SL-LMT') &&
          input.trgprc.isNotEmpty &&
          double.parse(input.trgprc) > 0) {
        payload.addAll({"trgprc": input.trgprc});
      }
      if (input.blprc.isNotEmpty && double.parse(input.blprc) > 0) {
        payload.addAll({"blprc": input.blprc});
      }
      if (input.bpprc.isNotEmpty && double.parse(input.blprc) > 0) {
        payload.addAll({"bpprc": input.bpprc});
      }
      // Market protection applies only to market-type orders (mirrors the
      // prc:'0' rule above and the place-order payload). Sent as a percentage.
      if ((input.prctyp == 'MKT' || input.prctyp == 'SL-MKT') &&
          input.mktProt.isNotEmpty) {
        payload.addAll({"mkt_protection": input.mktProt});
      }
      // if (input.trailprc.isNotEmpty) {
      //   payload.addAll({"trailprc": input.trailprc});
      // }

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');

      log("Modify order=> ${res.body}");
      final json = jsonDecode(res.body);

      return ModifyOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get SIP order place response from kambala

  Future<SipPlaceOrderModel> getPlaceSipOrder(
      SipInputField sipInputField) async {
    try {
      final uri = Uri.parse(apiLinks.placeSipOrder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","reg_date":"${sipInputField.regdate}","start_date":"${sipInputField.startdate}","actid":"${prefs.clientId}","frequency":"${sipInputField.frequency}","end_period":"${sipInputField.endperiod}","sip_name":"${sipInputField.sipname}","Scrips":[{"exch":"${sipInputField.exch}","tsym":"${sipInputField.tysm != null ? UrlUtils.encodeParameter(sipInputField.tysm!) : ''}","prd":"${sipInputField.prd}","token":"${sipInputField.token}","qty":"${sipInputField.qty}"}]}&jKey=${prefs.clientSession}''');

      // log("PlaceOrdersip => ${res.body}");
      final json = jsonDecode(res.body);

      return SipPlaceOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("PlaceOrdersip Error::$e");
      rethrow;
    }
  }

// Place SIP basket order with multiple scrips
  Future<SipPlaceOrderModel> getPlaceSipBasketOrder(
      SipBasketInput sipBasketInput) async {
    try {
      final uri = Uri.parse(apiLinks.placeSipOrder);

      // Build scrips array JSON - include qty for qty type, prc for amount type
      final scripsJson = sipBasketInput.scrips.map((scrip) {
        final valueField = scrip.sipType == 'qty'
            ? '"qty":"${scrip.qty}"'
            : '"prc":"${scrip.prc ?? ''}"';
        return '{"exch":"${scrip.exch}","tsym":"${UrlUtils.encodeParameter(scrip.tsym)}","prd":"${scrip.prd}","token":"${scrip.token}",$valueField,"sip_type":"${scrip.sipType}"}';
      }).join(',');

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","reg_date":"${sipBasketInput.regdate}","start_date":"${sipBasketInput.startdate}","actid":"${prefs.clientId}","frequency":"${sipBasketInput.frequency}","end_period":"${sipBasketInput.endperiod}","sip_name":"${sipBasketInput.sipname}","Scrips":[$scripsJson]}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);
      return SipPlaceOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("PlaceSipBasketOrder Error::$e");
      rethrow;
    }
  }

// // get Modify SIP order response from kambala

  Future<ModifySIPModel> getmodifysiporder(
      ModifySipInput modifysipinput) async {
    try {
      final uri = Uri.parse(apiLinks.modifySipOrder);

      // Build scrips array JSON - include qty for qty type, prc for amount type
      final scripsJson = modifysipinput.scrips.map((scrip) {
        final valueField = scrip.sipType == 'qty'
            ? '"qty":"${scrip.qty}"'
            : '"prc":"${scrip.prc ?? ''}"';
        return '{"exch":"${scrip.exch}","tsym":"${UrlUtils.encodeParameter(scrip.tsym)}","prd":"${scrip.prd}","token":"${scrip.token}",$valueField,"sip_type":"${scrip.sipType}"}';
      }).join(',');

      // Only include start_date if provided (not passed when SIP already started)
      final startDateField = modifysipinput.startdate != null && modifysipinput.startdate!.isNotEmpty
          ? ',"start_date":"${modifysipinput.startdate}"'
          : '';

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"reg_date":"${modifysipinput.regdate}"$startDateField,"frequency":"${modifysipinput.frequency}","end_period":"${modifysipinput.endperiod}","sip_name":"${modifysipinput.sipname}","internal":{"PrevExecDate":"${modifysipinput.prevExecutedate}","DueDate":"${modifysipinput.duedate}","ExecDate":"${modifysipinput.exedate}","period":"${modifysipinput.period}","active":"${modifysipinput.active}","SipId":"${modifysipinput.sipId}"},"Scrips":[$scripsJson]}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);

      return ModifySIPModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("ModifySipOrder Error::$e");
      rethrow;
    }
  }

// get SIP order book response from kambala

  Future<SipOrderBookModel> getSipOrderBook() async {
    try {
      final uri = Uri.parse(apiLinks.sipOrderBook);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"actid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');
      // log("SIP Order BOOK => ${jsonDecode(res.body)}");
      final json = jsonDecode(res.body);

      return SipOrderBookModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("RESPONCE SIP HISTORY $e");
      rethrow;
    }
  }

// get SIP Cancel order response from kambala

  Future<CancleSipOrder> getSipCancelOrder(String sipOrderno) async {
    try {
      final uri = Uri.parse(apiLinks.cancleSiporder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"SipId":"$sipOrderno"}&jKey=${prefs.clientSession}''');

      // log("Cancel SIP Order => ${res.body}");
      final json = jsonDecode(res.body);

      return CancleSipOrder.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("SIP CANCEL ERRROR LOG :: $e");
      rethrow;
    }
  }

// Place GTT order to kambala
  Future<PlaceGttOrderModel> placeGTTOrderAPI(PlaceGTTOrderInput input) async {
    try {
      final uri = Uri.parse(apiLinks.placeGTTOrderURL);
      Map payload = {
        "uid": prefs.clientId,
        "tsym": UrlUtils.encodeParameter(input.tsym),
        "exch": input.exch,
        "ai_t": input.ait,
        "validity": input.validity,
        "d": input.d,
        "trantype": input.trantype,
        "prctyp": input.prctyp,
        "prd": input.prd,
        "ret": input.ret.toUpperCase(),
        "actid": prefs.clientId,
        "qty": input.qty,
        "prc": input.prc
      };

      if (input.trgprc.isNotEmpty) {
        payload.addAll({"trgprc": input.trgprc});
      }
      if (input.remarks.isNotEmpty) {
        payload.addAll({"remarks": input.remarks});
      }
      log("Place GTT Order payload => ${inspect(payload)}");

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');
      log("Place GTT Order response => ${res.body}");
      final json = jsonDecode(res.body);

      return PlaceGttOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Modify GTT order to kambala
  Future<PlaceGttOrderModel> modifyGTTOrderAPI(PlaceGTTOrderInput input) async {
    try {
      final uri = Uri.parse(apiLinks.modifyGTTOrderURL);
      Map payload = {
        "uid": prefs.clientId,
        "tsym": UrlUtils.encodeParameter(input.tsym),
        "exch": input.exch,
        "ai_t": input.ait,
        "validity": input.validity,
        "d": input.d,
        "trantype": input.trantype,
        "prctyp": input.prctyp,
        "prd": input.prd,
        "ret": input.ret.toUpperCase(),
        "actid": prefs.clientId,
        "qty": input.qty,
        "prc": input.prc,
        "al_id": input.alid
      };

      if (input.trgprc.isNotEmpty) {
        payload.addAll({"trgprc": input.trgprc});
      }
      if (input.remarks.isNotEmpty) {
        payload.addAll({"remarks": input.remarks});
      }
      // log("Modify GTT Order => $payload");
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');
      // log("Modify GTT Order => ${res.body}");
      final json = jsonDecode(res.body);

      return PlaceGttOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("Place GTT Order Error => $e");
      rethrow;
    }
  }

  //  Place OCO order to kambala
  Future<PlaceGttOrderModel> placeOCOOrderAPI(PlaceOcoOrderInput input) async {
    try {
      final uri = Uri.parse(apiLinks.placeOCOOrderURL);
      // ai_t is LMT_BOS_O for both buy and sell OCO — confirmed against a
      // working sell-side OCO request (the doc's "LMT_SOB_O for sell" is
      // not what the broker actually accepts).
      Map payload = {
        "uid": prefs.clientId,
        "ai_t": "LMT_BOS_O",
        "validity": "GTT",
        "tsym": UrlUtils.encodeParameter(input.tsym),
        "exch": input.exch,
        "oivariable": [
          {"d": input.d1, "var_name": "x"},
          {"d": input.d2, "var_name": "y"}
        ],
        "place_order_params": {
          "tsym": UrlUtils.encodeParameter(input.tsym),
          "exch": input.exch,
          "trantype": input.trantype,
          "prctyp": input.prctyp1,
          "prd": input.prd1,
          "ret": "DAY",
          "actid": prefs.clientId,
          "uid": prefs.clientId,
          "ordersource": "WEB",
          "qty": input.qty1,
          "prc": input.prc1,
          "trgprc": input.trgprc1
        },
        "place_order_params_leg2": {
          "tsym": UrlUtils.encodeParameter(input.tsym),
          "exch": input.exch,
          "trantype": input.trantype,
          "prctyp": input.prctyp2,
          "prd": input.prd2,
          "ret": "DAY",
          "actid": prefs.clientId,
          "uid": prefs.clientId,
          "ordersource": "WEB",
          "qty": input.qty2,
          "prc": input.prc2,
          "trgprc": input.trgprc2,
        }
      };

      if (input.remarks.isNotEmpty) {
        payload.addAll({"remarks": input.remarks});
      }
      log("Place GTT OCO Order payload => ${inspect(payload)}");
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');
      log("Place GTT OCO Order Response => ${res.body}");
      final json = jsonDecode(res.body);

      return PlaceGttOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      log("Place GTT OCO Order Error => $e");
      rethrow;
    }
  }

  // modify OCO order to kambala
  Future<PlaceGttOrderModel> modifyOCOOrderAPI(PlaceOcoOrderInput input) async {
    try {
      final uri = Uri.parse(apiLinks.modifyOCOOrderURL);
      Map payload = {
        "uid": prefs.clientId,
        "ai_t": "LMT_BOS_O",
        "validity": input.validity,
        "tsym": UrlUtils.encodeParameter(input.tsym),
        "exch": input.exch,
        "al_id": input.alid,
        "oivariable": [
          {"d": input.d1, "var_name": "x"},
          {"d": input.d2, "var_name": "y"}
        ],
        "place_order_params": {
          "tsym": UrlUtils.encodeParameter(input.tsym),
          "exch": input.exch,
          "trantype": input.trantype,
          "prctyp": input.prctyp1,
          "prd": input.prd1,
          "ret": "DAY",
          "actid": prefs.clientId,
          "uid": prefs.clientId,
          "ordersource": "WEB",
          "qty": input.qty1,
          "prc": input.prc1,
          "trgprc": input.trgprc1
        },
        "place_order_params_leg2": {
          "tsym": UrlUtils.encodeParameter(input.tsym),
          "exch": input.exch,
          "trantype": input.trantype,
          "prctyp": input.prctyp2,
          "prd": input.prd2,
          "ret": "DAY",
          "actid": prefs.clientId,
          "uid": prefs.clientId,
          "ordersource": "WEB",
          "qty": input.qty2,
          "prc": input.prc2,
          "trgprc": input.trgprc2,
        }
      };

      if (input.remarks.isNotEmpty) {
        payload.addAll({"remarks": input.remarks});
      }

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');
      // log("Place Modify OCO Order => ${res.body}");
      final json = jsonDecode(res.body);

      return PlaceGttOrderModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get GTT order book response from kambala

  Future<Map<String, dynamic>> getGTTOrderBook() async {
    try {
      final uri = Uri.parse(apiLinks.pendingGttorder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}" }&jKey=${prefs.clientSession}''');

      final List<GttOrderBookModel> data = [];

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        // Map response = error or "no data" from API
        if (json is Map<String, dynamic>) {
          if (json['emsg'] != null &&
              json['emsg'].toString().contains('Session Expired')) {
            data.add(GttOrderBookModel.fromJson(json));
            return {"stat": "error", "data": data};
          }
          return {"stat": "no data", "data": data};
        }

        // List response = success
        if (json is List && json.isNotEmpty) {
          for (final item in json) {
            data.add(
                GttOrderBookModel.fromJson(item as Map<String, dynamic>));
          }
          return {"stat": "success", "data": data};
        }

        // Empty list
        return {"stat": "no data", "data": data};
      } else {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> &&
            json['emsg'] != null &&
            json['emsg'].toString().contains('Session Expired')) {
          data.add(GttOrderBookModel.fromJson(json));
        }
        return {"stat": "error", "data": data};
      }
    } catch (e) {
      rethrow;
    }
  }

  // get Triggered GTT orders from kambala

  Future<Map<String, dynamic>> getTriggeredGTTOrders() async {
    try {
      final uri = Uri.parse(apiLinks.triggeredGttorder);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"actid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

      final List<GttOrderBookModel> data = [];

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        // Map response = error or "no data" from API
        if (json is Map<String, dynamic>) {
          if (json['emsg'] != null &&
              json['emsg'].toString().contains('Session Expired')) {
            data.add(GttOrderBookModel.fromJson(json));
            return {"stat": "error", "data": data};
          }
          return {"stat": "no data", "data": data};
        }

        // List response = success
        if (json is List && json.isNotEmpty) {
          for (final item in json) {
            data.add(
                GttOrderBookModel.fromJson(item as Map<String, dynamic>));
          }
          return {"stat": "success", "data": data};
        }

        return {"stat": "no data", "data": data};
      } else {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> &&
            json['emsg'] != null &&
            json['emsg'].toString().contains('Session Expired')) {
          data.add(GttOrderBookModel.fromJson(json));
        }
        return {"stat": "error", "data": data};
      }
    } catch (e) {
      rethrow;
    }
  }

  // get Basket order margin  from kambala

  Future<OrderMarginModel> getBasketMargin(
      OrderMarginInput input, List basket) async {
    try {
      final uri = Uri.parse(apiLinks.basketMargin);

      Map payload = {
        "uid": "${prefs.clientId}",
        "actid": "${prefs.clientId}",
        "exch": input.exch,
        "tsym": UrlUtils.encodeParameter(input.tsym),
        "qty": input.qty,
        "prc": input.prc,
        "prd": input.prd,
        "trantype": input.trantype,
        "prctyp": input.prctyp,
        "blprc": input.blprc,
        "trgprc": input.trgprc,
      };

      if (basket.isNotEmpty) {
        payload.addAll({"basketlists": basket});
      }
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: '''jData=${jsonEncode(payload)}&jKey=${prefs.clientSession}''');

      // log("Basket Order Margin => ${res.body}");
      final json = jsonDecode(res.body);

      return OrderMarginModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Get Payoff Calculation from be.mynt.in
  Future<Map<String, dynamic>> getPayoffCalculation({
    required String strategy,
    required bool isPosition,
    required String spotPrice,
    required int daysToExpiry,
    required List<Map<String, dynamic>> legs,
    double? targetSpotPrice,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.payoffCalculation);

      final payload = {
        "strategy": strategy,
        "ispotion": isPosition,
        "spotPrice": spotPrice,
        "daysToExpiry": daysToExpiry,
        "legs": legs,
        if (targetSpotPrice != null) "targetSpotPrice": targetSpotPrice,
      };

      log("[PayoffCalculation] Request: ${jsonEncode(payload)}");

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );

      log("[PayoffCalculation] Response: ${res.body}");
      final json = jsonDecode(res.body);
      return json as Map<String, dynamic>;
    } catch (e) {
      log("[PayoffCalculation] Error: $e");
      rethrow;
    }
  }

  /// Get Option Greeks from be.mynt.in
  Future<Map<String, dynamic>> getOptionGreeks({
    required String spotPrice,
    required int expiryDay,
    required List<Map<String, dynamic>> options,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.optionGreeks);

      final payload = {
        "spotPrice": spotPrice,
        "expiryDay": expiryDay,
        "OPTIONS": options,
      };

      log("[OptionGreeks] Request: ${jsonEncode(payload)}");

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );

      log("[OptionGreeks] Response: ${res.body}");
      final json = jsonDecode(res.body);
      return json as Map<String, dynamic>;
    } catch (e) {
      log("[OptionGreeks] Error: $e");
      rethrow;
    }
  }

  /// Call /select-symbols to resolve strategy legs to concrete option contracts
  Future<List<SelectSymbolsLegResponse>> selectSymbols(
    List<SelectSymbolsLegRequest> legs,
  ) async {
    try {
      final uri = Uri.parse(apiLinks.selectSymbols);

      final payload = legs.map((leg) => leg.toJson()).toList();

      log("[SelectSymbols] Request: ${jsonEncode(payload)}");

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );

      log("[SelectSymbols] Response: ${res.body}");

      final jsonList = jsonDecode(res.body) as List<dynamic>;
      return jsonList
          .map((item) =>
              SelectSymbolsLegResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log("[SelectSymbols] Error: $e");
      rethrow;
    }
  }

  /// Call /select-symbols with direct expiry and strike to resolve a single contract
  Future<SelectSymbolsLegResponse> selectSymbolsDirect(
    SelectSymbolsDirectRequest request,
  ) async {
    try {
      final uri = Uri.parse(apiLinks.selectSymbols);

      final payload = [request.toJson()];

      log("[SelectSymbolsDirect] Request: ${jsonEncode(payload)}");

      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );

      log("[SelectSymbolsDirect] Response: ${res.body}");

      final jsonList = jsonDecode(res.body) as List<dynamic>;
      if (jsonList.isEmpty) {
        throw Exception('Empty response from select-symbols');
      }
      return SelectSymbolsLegResponse.fromJson(
          jsonList.first as Map<String, dynamic>);
    } catch (e) {
      log("[SelectSymbolsDirect] Error: $e");
      rethrow;
    }
  }

  // / POST /strategies — Create a new custom option strategy
  Future<Map<String, dynamic>> createOptionStrategy({
    required String clientId,
    required String name,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> legs,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.strategies);
      final payload = {
        'client_id': clientId,
        'name': name,
        'description': description,
        'tags': tags,
        'legs': legs,
      };
      log("[CreateOptionStrategy] Request: ${jsonEncode(payload)}");
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );
      // log("[CreateOptionStrategy] Response: ${res.body}");
      if (res.statusCode == 201 || res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception('Create option strategy failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      log("[CreateOptionStrategy] Error: $e");
      rethrow;
    }
  }

  /// GET /strategies?client_id=X — List all strategies for client
  Future<Map<String, dynamic>> listStrategies({
      required String clientId,
      int page = 1,
      int pageSize = 100,
  }) async {
    try {
      final uri =
          Uri.parse(apiLinks.strategies).replace(queryParameters: {
        'client_id': clientId,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      });
      log("[ListStrategies] Request: $uri");
      final res = await apiClient.get(
        uri,
        headers:defaultHeaders,
      );
      log("[ListStrategies] Response: ${res.body}");
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception(
          'List strategies failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      log("[ListStrategies] Error: $e");
      rethrow;
    }
  }

  /// PUT /strategies/{id} — Update an existing strategy
  Future<Map<String, dynamic>> updateStrategy({
    required String strategyId,
    required String clientId,
    String? name,
    String? description,
    List<String>? tags,
    List<Map<String, dynamic>>? legs,
  }) async {
    try {
      final uri = Uri.parse('${apiLinks.strategies}/$strategyId');
      final payload = <String, dynamic>{'client_id': clientId};
      if (name != null) payload['name'] = name;
      if (description != null) payload['description'] = description;
      if (tags != null) payload['tags'] = tags;
      if (legs != null) payload['legs'] = legs;

      log("[UpdateStrategy] Request: ${jsonEncode(payload)}");
      final res = await apiClient.put(
        uri,
        headers: defaultHeaders,
        body: jsonEncode(payload),
      );
      log("[UpdateStrategy] Response: ${res.body}");
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Update strategy failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      log("[UpdateStrategy] Error: $e");
      rethrow;
    }
  }

  /// DELETE /strategies/{id}?client_id=X — Delete a strategy
  Future<void> deleteStrategy({
    required String strategyId,
    required String clientId,
  }) async {
    try {
      final uri = Uri.parse('${apiLinks.strategies}/$strategyId')
          .replace(queryParameters: {'client_id': clientId});
      log("[DeleteStrategy] Request: $uri");
      final res = await apiClient.delete(
        uri,
        headers: defaultHeaders,
      );
      // log("[DeleteStrategy] Response: ${res.body}");
      if (res.statusCode != 200) {
        throw Exception(
            'Delete strategy failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      log("[DeleteStrategy] Error: $e");
      rethrow;
    }
  }
}

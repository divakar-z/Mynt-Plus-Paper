
import 'package:flutter/material.dart';
import '../models/marketwatch_model/scrip_overview/eodchartdata_model.dart';
import '../utils/url_utils.dart';
import '../models/marketwatch_model/add_delete_scrip_model.dart';
import '../models/marketwatch_model/alert_model/alert_pending_model.dart';
import '../models/marketwatch_model/alert_model/cancel_alert_model.dart';
import '../models/marketwatch_model/alert_model/modify_alert_model.dart';
import '../models/marketwatch_model/alert_model/set_alert_model.dart';
import '../models/marketwatch_model/get_quotes.dart';
import '../models/marketwatch_model/linked_scrips.dart';
import '../models/marketwatch_model/market_watch_scrip_model.dart';
import '../models/marketwatch_model/market_watchlist_model.dart';
import '../models/marketwatch_model/opt_chain_model.dart';
import '../models/marketwatch_model/pre_define_wl_model.dart';
import '../models/marketwatch_model/scrip_info.dart';
import '../models/marketwatch_model/scrip_overview/stock_data.dart';
import '../models/marketwatch_model/scrip_overview/technical_data.dart';
import '../models/marketwatch_model/search_scrip_model.dart';
import '../models/marketwatch_model/search_scrip_new_model.dart';
import '../models/marketwatch_model/tpseries.dart';
import '../models/marketwatch_model/watchlist_rename_model.dart';
import 'core/api_core.dart';

mixin MarketWatchApi on ApiCore {
  // Get List of watchlist names form kambala

  Future<MarketWatchlist> getMWList() async {
    try {
      final uri = Uri.parse(apiLinks.watchList);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');
      final json = jsonDecode(res.body);

      return MarketWatchlist.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<TpSeries> getTPSeries({
  String? exchange,
  String? token,
  String? timeframe,
  String? fromDate,
  String? toDate,
}) async {
  try {
    // final fromTimestamp = fromDate != null
    //     ? (DateFormat('dd-MM-yyyy').parse(fromDate).millisecondsSinceEpoch ~/ 1000)
    //     : (DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch ~/ 1000);
    // final toTimestamp = toDate != null
    //     ? (DateFormat('dd-MM-yyyy').parse(toDate).millisecondsSinceEpoch ~/ 1000)
    //     : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final uri = Uri.parse(apiLinks.tpseries);
    final res = await apiClient.post(
      uri,
      headers: defaultHeaders,
      body:
          '''jData={"uid":"${prefs.clientId}","exch":"${exchange ?? 'NSE'}","token":"${token ?? 'Nifty%2050'}","st":"$fromDate / 1000","et":"$toDate","intrv":"${timeframe ?? '5'}"}&jKey=${prefs.clientSession}''',
    );
    final json = jsonDecode(res.body);
    if (json is List) {
      return TpSeries.fromJson({"data": json});
    } else if (json is Map) {
      return TpSeries.fromJson(json as Map<String, dynamic>);
    } else {
      throw Exception("Unexpected JSON type: ${json.runtimeType}");
    }
  } catch (e) {
    rethrow;
  }
}

  /// Fetch TPSeries candle data with clean timestamp handling.
  /// [startEpoch] and [endEpoch] are Unix epoch seconds.
  Future<TpSeries> getTPSeriesChart({
    required String exchange,
    required String token,
    required String interval,
    required int startEpoch,
    required int endEpoch,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.tpseries);
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body:
            '''jData={"uid":"${prefs.clientId}","exch":"$exchange","token":"$token","st":"$startEpoch","et":"$endEpoch","intrv":"$interval"}&jKey=${prefs.clientSession}''',
      );
      final json = jsonDecode(res.body);
      if (json is List) {
        return TpSeries.fromJson({"data": json});
      } else if (json is Map) {
        return TpSeries.fromJson(json as Map<String, dynamic>);
      } else {
        throw Exception("Unexpected JSON type: ${json.runtimeType}");
      }
    } catch (e) {
      rethrow;
    }
  }

// Edit watchlist name from kambala

  Future<WatchlistRenameModel> getWatchListRename(
      String oldName, String newName) async {
    try {
      final uri = Uri.parse(apiLinks.watchListrename);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","wlname":"$oldName","newwlname":"$newName"}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);

      return WatchlistRenameModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get List of Market scrips by watchlist names form kambala

  Future<MarketWatchScrip> getMWScrip(String wlname) async {
    try {
      final uri = Uri.parse(apiLinks.marketWatchScrip);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","wlname":"$wlname"}&jKey=${prefs.clientSession}''');
      // print("Market WatchScrip => ${res.body}");
      final json = jsonDecode(res.body);

      return MarketWatchScrip.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get Predefined MArket scrips (NIFTY,BANK NIFTY,SENSEX)
// New endpoint accepts one wlname per call, so fire 3 in parallel and stitch
// the results back into the existing PreDefinedMWlist shape.

  Future<List<WatchListValues>> _fetchPreDefMWByName(String wlname) async {
    final uri = Uri.parse(apiLinks.preDefdMWatchScrip);
    final res = await apiClient.post(uri,
        headers: defaultHeaders,
        body:
            '''jData={"uid":"${prefs.clientId}","wlname":"$wlname"}&jKey=${prefs.clientSession}''');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['stat'] != 'Ok') return [];
    final List<WatchListValues> values = [];
    if (json['values'] != null) {
      for (final v in (json['values'] as List)) {
        values.add(WatchListValues.fromJson(v as Map<String, dynamic>));
      }
    }
    return values;
  }

  Future<PreDefinedMWlist> getPreDefMWScrip() async {
    try {
      final results = await Future.wait([
        _fetchPreDefMWByName('NIFTY50:NSE'),
        _fetchPreDefMWByName('NIFTYBANK:NSE'),
        _fetchPreDefMWByName('SENSEX:BSE'),
      ]);
      return PreDefinedMWlist(
        nIFTY50NSE: results[0],
        nIFTYBANKNSE: results[1],
        sENSEXBSE: results[2],
        stat: 'Ok',
      );
    } catch (e) {
      rethrow;
    }
  }

// Get Single Market scrip info from kambala

  Future<ScripInfoModel> getScripInfo(String token, String exch) async {
    try {
      final uri = Uri.parse(apiLinks.securityInfo);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","token":"$token"}&jKey=${prefs.clientSession}''');

      // log("Scrip Info => ${res.body}");
      final json = jsonDecode(res.body);

      return ScripInfoModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get Single Market scrip Details from kambala

  Future<GetQuotes> getScripQuote(String token, String exch) async {
    try {
      final uri = Uri.parse(apiLinks.getQuotes);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","token":"$token"}&jKey=${prefs.clientSession}''');

      //  log("Scrip Get Info => ${res.body}");
      final json = jsonDecode(res.body);

      return GetQuotes.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // get Add / Delete Scrips to watchlist from kamabal

  Future<AddDeleteScripModel> getAddDeleteSciptoMW(
      {required String wlname,
      required String scripToken,
      required bool isAdd}) async {
    try {
      final uri =
          Uri.parse(isAdd ? apiLinks.addMWScrips : apiLinks.deleteMWScrips);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","wlname":"$wlname","scrips":"$scripToken"}&jKey=${prefs.clientSession}''');

      // log("Add Delete SciptoMW => ${res.body}");
      final json = jsonDecode(res.body);

      return AddDeleteScripModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Reorder scrips within a watchlist — vendor endpoint that takes the full
  // ordered list and atomically updates positions on the backend. Replaces
  // the older delete-all + add-all dance which always tripped the "at least
  // 1 stock must remain" rule on the delete step.
  Future<AddDeleteScripModel> getReorderMWScrips({
    required String wlname,
    required String scripToken,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.reorderMWScrips);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","wlname":"$wlname","scrips":"$scripToken"}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);
      return AddDeleteScripModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get Trade symbol wise search from kambala

  Future<SearchScripModel> getSearchScrip({required String searchText}) async {
    try {
      final uri = Uri.parse(apiLinks.searchScrip);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","stext":"${UrlUtils.encodeParameter(searchText)}"}&jKey=${prefs.clientSession}''');

      //  log("Search Scrip => ${res.body}");
      final json = jsonDecode(res.body);

      return SearchScripModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

    Future<SearchScripNewModel> getSearchScripNew({required String searchText, required String categ, required List exchs, required bool opt}) async {
    try {
      final uri = Uri.parse(apiLinks.searchScripNew);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","stext":"${UrlUtils.encodeParameter(searchText)}","cat":"$categ","fil":${exchs.toList()},"opt":"${opt.toString()}"}&jKey=${prefs.clientSession}''');

      //  print("Search Scrip => ${res.body}");
      final json = jsonDecode(res.body);
      //  print("Search Scrip => ${json['values'].length}");
      return SearchScripNewModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Derivative contract master (NFO/BFO/MCX/NCOM): a flat map of "EXCH:token" ->
  /// ready display name, fetched once on login and cached in DerivativeMaster so
  /// every screen can resolve a contract's name from one source. [exchanges] are
  /// the user's entitled derivative exchanges, sent as ?exch=NFO,BFO,MCX.
  Future<Map<String, String>> getDerivativeMaster(
      {required List<String> exchanges}) async {
    try {
      final uri = Uri.parse(
          '${apiLinks.derivativeMaster}?exch=${exchanges.join(',')}');
      final res = await apiClient.get(uri, headers: defaultHeaders);
      final json = jsonDecode(res.body);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return <String, String>{};
    } catch (e) {
      rethrow;
    }
  }

  /// Search scrip for Strategy Builder - properly encodes exchange filter array
  Future<SearchScripNewModel> searchScripForStrategyBuilder({
    required String searchText,
    required List<String> exchanges,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.searchScripNew);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","stext":"${UrlUtils.encodeParameter(searchText)}","cat":"","fil":${jsonEncode(exchanges)},"opt":"false"}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);
      return SearchScripNewModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Fetch all available option scripts (called once, cached in provider)
  Future<SearchScripModel> fetchAllOptScripts() async {
    try {
      final uri = Uri.parse(apiLinks.searchOptScript);
      final res = await apiClient.post(uri,
          headers: {'Content-Type': 'text/plain'},
          body:
              '''jData={"stext":""}&jKey=${prefs.clientSession}''');

      final json = jsonDecode(res.body);
      return SearchScripModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get Linked scrip details from kambala

  Future<LinkedScrips> getLinkedScrip(String token, String exch) async {
    try {
      final uri = Uri.parse(apiLinks.getLinkedScrip);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","token":"$token"}&jKey=${prefs.clientSession}''');

      //  log(" LinkedScrips Info => ${res.body}");
      final json = jsonDecode(res.body);

      return LinkedScrips.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Get Option chain datas from kambala

  Future<OptionChainModel?> getOptionChain(
      {required String strPrc,
      required String tradeSym,
      required String exchange,
      required BuildContext context,
      required String numofStrike}) async {
    try {
      final uri = Uri.parse(apiLinks.optionChain);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exchange" ,"tsym":"${UrlUtils.encodeParameter(tradeSym)}","cnt":"$numofStrike ","strprc":"$strPrc"}&jKey=${prefs.clientSession}''');

      //  log(" Option Chain   => ${res.body}");

      // print(" Option Chain Response => ${res.body}");

      final resp = OptionChainModel.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      return resp;
    } catch (e) {
      // log(e.toString());
      rethrow;
    }
  }

  // Future<MarketWatchlist> getPreDefMWList() async {
  //   try {
  //     final uri = Uri.parse(apiLinks.preDefinedMWList);
  //     final res = await apiClient.post(uri,
  //         headers: defaultHeaders,
  //         body:
  //             '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

  //     final json = jsonDecode(res.body);

  //     return MarketWatchlist.fromJson(json as Map<String, dynamic>);
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  // Get Scrip returns data from kambala

  Future<TechnicalData> getTechData(String exch, String tsym) async {
    try {
      final uri = Uri.parse(apiLinks.technicalData);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","tsym":"${UrlUtils.encodeParameter(tsym)}"}&jKey=${prefs.clientSession}''');
      final json = jsonDecode(res.body);

      // log(" Tech Data   => ${res.body}");

      return TechnicalData.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // Get Equity and BSE Stocks fundamental data

  Future<StockData> getFundamentalData(String tsym) async {
    try {
      final uri = Uri.parse(apiLinks.fundamentalDetail);
      final res = await apiClient.post(uri,
          headers: defaultHeaders, body: jsonEncode({"symbol": tsym}));

      final json = jsonDecode(res.body);

    //  log(" Fundamental Data   => ${res.body}");

      return StockData.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

/////////////////// SET ALERTS API////////////////
  Future<SetAlertModel> getSetAlert(String exch, String tysm, String value,
      String alertTypeVal, String remark) async {
    try {
      final uri = Uri.parse(apiLinks.setAlert);
      // Free-text remark: JSON-escape (quotes, backslashes) then URL-encode
      // (&, %, +) so characters like "!@#$%^&*()_+" don't break jData.
      final jsonRemark = jsonEncode(remark);
      final encodedRemark = UrlUtils.encodeParameter(
          jsonRemark.substring(1, jsonRemark.length - 1));
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","tsym":"${UrlUtils.encodeParameter(tysm)}","ai_t":"$alertTypeVal","validity":"GTT","d":"$value","remarks":"$encodedRemark"}&jKey=${prefs.clientSession}''');

      // log("SetAlert => ${res.body}");
      final json = jsonDecode(res.body);

      return SetAlertModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AlertPendingModel>> getPendingAlert() async {
    try {
      final uri = Uri.parse(apiLinks.pendingalert);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');
      // log("Pending Alert => ${res.body}");

      final List<AlertPendingModel> data = [];

      final json = jsonDecode(res.body);

      // Check if response is an error (Map with stat field) or success (List of items)
      if (json is Map && json['stat']?.toString() == 'Not_Ok') {
        final AlertPendingModel ord =
            AlertPendingModel.fromJson(json as Map<String, dynamic>);
        return [ord];
      } else if (json is List) {
        for (final item in json) {
          data.add(AlertPendingModel.fromJson(item as Map<String, dynamic>));
        }
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<CancelAlertModel> getCancelAlert(String alId) async {
    try {
      final uri = Uri.parse(apiLinks.cancelAlert);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","al_id":"$alId"}&jKey=${prefs.clientSession}''');

      // log("Cancel  => ${res.body}");
      final json = jsonDecode(res.body);

      return CancelAlertModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<ModifyAlertModel> getmodifyalert(String exch, String tysm,
      String value, String alertTypeVal, String alid) async {
    try {
      final uri = Uri.parse(apiLinks.modifyalert);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch","tsym":"${UrlUtils.encodeParameter(tysm)}","ai_t":"$alertTypeVal","validity":"GTT","al_id":"$alid","d":"$value"}&jKey=${prefs.clientSession}''');

      // log("Modify Alert => ${res.body}");
      final json = jsonDecode(res.body);

      return ModifyAlertModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }



  // Variant used by the chart engine. Takes explicit from/to unix-epoch
  // seconds (matches the EODChartData API contract directly) so callers
  // that already compute their own time range — like the chart engine's
  // infinite-scroll extend path — don't have to round-trip through a
  // timeframe-string enum.
  Future<List<EodChartData>> getEODChartDataRange({
    required String tsym,
    required String exch,
    required int fromEpoch,
    required int toEpoch,
  }) async {
    final uri = Uri.parse(apiLinks.eodchartdata);
    final formattedSymbol = "$exch:$tsym";
    final payload =
        'jData={"sym": "$formattedSymbol","from": "$fromEpoch","to": "$toEpoch"}'
        '&jKey=${prefs.clientSession}';
    final res = await apiClient.post(uri, headers: defaultHeaders, body: payload);
    final json = jsonDecode(res.body);
    if (json is Map &&
        json['stat'] == 'Not_Ok' &&
        json['emsg'] == 'Session Expired :  Invalid Session Key') {
      throw Exception('Session Expired :  Invalid Session Key');
    }
    if (json is List) {
      return json.map((item) {
        // Backend wraps each row as a JSON string inside the outer array.
        final itemData = jsonDecode(item as String);
        return EodChartData.fromJson(itemData as Map<String, dynamic>);
      }).toList();
    }
    if (json is Map) {
      return [EodChartData.fromJson(json as Map<String, dynamic>)];
    }
    throw Exception('Unexpected EOD response format');
  }

  Future<List<EodChartData>> getEODChartData(String tsym, String exch, {String timeframe = "1Y"}) async {
    try {
      final uri = Uri.parse(apiLinks.eodchartdata);
      final formattedSymbol = "$exch:$tsym";
      
      // Calculate timestamps based on timeframe
      final now = DateTime.now();
      DateTime fromDate;
      
      switch (timeframe) {
        case "5Y":
          fromDate = DateTime(now.year - 5, now.month, now.day);
          break;
        case "3Y":
          fromDate = DateTime(now.year - 3, now.month, now.day);
          break;
        case "1Y":
          fromDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case "3M":
          fromDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case "1M":
          fromDate = DateTime(now.year, now.month - 1, now.day);
          break;
        default:
          fromDate = DateTime(now.year - 1, now.month, now.day);
      }
      
      final fromTimestamp = fromDate.millisecondsSinceEpoch ~/ 1000;
      final toTimestamp = now.millisecondsSinceEpoch ~/ 1000;
      
      
      final payload = '''jData={"sym": "$formattedSymbol","from": "$fromTimestamp","to": "$toTimestamp"}&jKey=${prefs.clientSession}''';
      
      
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: payload);

      // print("EOD CHART DATA RESPONSE: ${res.body}");
      
      final json = jsonDecode(res.body);

      // print("API Response for $timeframe: ${json.runtimeType} with ${json is List ? json.length : 1} items");

    
      if (json is Map &&
          json['stat'] == 'Not_Ok' &&
          json['emsg'] == 'Session Expired :  Invalid Session Key') {
        throw Exception('Session Expired :  Invalid Session Key');
      }

      // Handle list response
      if (json is List) {
        final result = json.map((item) {
          final itemData = jsonDecode(item as String);
          return EodChartData.fromJson(itemData as Map<String, dynamic>);
        }).toList();
        return result;
      } else if (json is Map) {
        final result = [EodChartData.fromJson(json as Map<String, dynamic>)];
        return result;
      } else {
        throw Exception("Unexpected response format");
      }
    } catch (e) {
      rethrow;
    }
  }
}




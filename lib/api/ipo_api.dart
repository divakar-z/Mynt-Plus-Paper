import 'dart:developer';

import 'package:mynt_plus/models/ipo_model/ipo_pre_close_model.dart';
import 'package:mynt_plus/models/ipo_model/ipo_upcoming_model.dart';

import '../models/ipo_model/ipo_db_model.dart';
import '../models/ipo_model/ipo_mainstream_model.dart';
import '../models/ipo_model/ipo_order_book_model.dart';
import '../models/ipo_model/ipo_order_res_model.dart';
import '../models/ipo_model/ipo_performance_model.dart';
import '../models/ipo_model/ipo_place_order_model.dart';
import '../models/ipo_model/ipo_single_page_model.dart';
import '../models/ipo_model/ipo_sme_model.dart';
import 'core/api_core.dart';

mixin IPOApi on ApiCore {
  Future<List<IpoOrderBookModel>> fetchipoorderbook() async {
    try {
      final uri = Uri.parse(apiLinks.ipoorderbook);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: (jsonEncode({"client_id": "${prefs.clientId}"})));
      
      final dynamic responseBody = jsonDecode(res.body);
      
      if (responseBody is Map<String, dynamic> && responseBody.containsKey('msg')) {
        if (responseBody['msg'] == 'orders not found') {
          return [];
        }
        throw Exception(responseBody['msg']);
      }
      
      if (responseBody is List) {
        return responseBody.map((e) {
          return IpoOrderBookModel.fromJson(e);
        }).toList();
      }
      
      throw Exception('Unexpected response format: ${responseBody.runtimeType}');
      
    } catch (e) {
      //  log("SDSDSDSD $e");
      rethrow;
    }
  }

  Future<IpoOrderResponcesModel> fetchipoplaceorder(
      MenuData menudata, List<IposBid> iposbids, String iposupiid) async {
    List<Map<String, dynamic>> bids = [];
    if (menudata.flow != 'can') {
      for (int i = 0; i < iposbids.length; i++) {
        if (iposbids[i].bitis) {
          if (menudata.type == 'NSE') {
            bids.add({
              "activityType": menudata.flow == 'mod' ? 'modify' : 'new',
              "quantity": iposbids[i].qty,
              "atCutOff": iposbids[i].cutoff,
              "price": iposbids[i].price.toString(),
              "amount": iposbids[i].total.toString(),
              "bidReferenceNumber":
                  menudata.respBid.isNotEmpty && menudata.respBid.length > i
                      ? menudata.respBid[i].bidReferenceNumber
                      : '',
            });
          } else {
            bids.add({
              "actioncode": menudata.flow == 'mod' ? 'm' : 'n',
              "quantity": iposbids[i].qty.toString(),
              "cuttoffflag": iposbids[i].cutoff,
              "rate": iposbids[i].price.toString(),
              "bidid":
                  menudata.respBid.isNotEmpty && menudata.respBid.length > i
                      ? menudata.respBid[i].bidReferenceNumber
                      : '',
              "orderno": '1234${5 + i}',
            });
          }
        }
      }
    }

    Map<String, dynamic> data = {
      "symbol": menudata.symbol,
      "UPI": iposupiid,
      "type": menudata.type,
      "category": menudata.category,
      "company_name": menudata.name,
      "BID": bids,
    };

    if (menudata.flow == 'can' || menudata.flow == 'mod') {
      data['applicationNo'] = menudata.applicationNumber;
    }

    if (menudata.flow == 'can') {
      data['BID'] = [
        menudata.type == 'NSE'
            ? {"activityType": "cancel"}
            : {"actioncode": "d"}
      ];
      data.remove('UPI');
      data.remove('company_name');
    }
    log("IPO PLACEORDER $data");
    try {
      final uri = Uri.parse(apiLinks.placeipoorder);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders, body: (jsonEncode(data)));
      final json = jsonDecode(res.body);
      log("ORDER PLACE IPO=>${res.body} ");
      return IpoOrderResponcesModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<IpoPerformanceModel> fetchipoperfomance(int year) async {
    try {
      final uri = Uri.parse("https://v3.mynt.in/ipo/ipo_performer?year=$year");
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
      );
      final json = jsonDecode(res.body);
      //log("Ipo Perfomance res=>${res.body} ");
      return IpoPerformanceModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      // print("GETIPOPERFORMANCE $e");
      rethrow;
    }
  }

  Future<MainStreamIpoModel> fetchmainstreamoipo() async {
    try {
      final uri = Uri.parse(apiLinks.mainstreamipo);
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
      );
      final json = jsonDecode(res.body);
      log("mainstream ipo res=>${res.body} ");

      return MainStreamIpoModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<SmeIpoModel> fetchsmeipo() async {
    try {
      final uri = Uri.parse(apiLinks.smeipos);
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
      );
      final json = jsonDecode(res.body);
      //  log("sme ipo res=>${res.body} ");
      return SmeIpoModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<DashbordIposIPOS> fetchDashbordIposIPOS() async {
    try {
      final uri = Uri.parse(apiLinks.dashboardipos);
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
      );
      final json = jsonDecode(res.body);
      // print("dashbord ipo res=>${res.body} ");
      return DashbordIposIPOS.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<IpoSinglePage> fetchiposinglepage(String iponame) async {
    try {
      final uri = Uri.parse(apiLinks.iposinglepage);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: (jsonEncode({"company_name": iponame})));
      final json = jsonDecode(res.body);
      // log(res.body);
      if (json['data'] != "no data") {
        IpoSinglePage ipoModel = IpoSinglePage.fromJson(json);
        return ipoModel;
      } else {
        IpoSinglePage ipoModels = IpoSinglePage.fromJson(json);

        return ipoModels;
      }
    } catch (e) {
      // print("object $e");
      rethrow;
    }
  }

  Future<IpoPreCloseModel> fetchIpoPreCloseApi() async {
    try {
      final uri = Uri.parse(apiLinks.ipoprecloseurl);
      final res = await apiClient.post(uri, headers: defaultHeaders);
      final json = jsonDecode(res.body);
      // log("fetchipopreclose :: ${res.body}");
      IpoPreCloseModel ipoModel = IpoPreCloseModel.fromJson(json);
      return ipoModel;
    } catch (e) {
      // print("fetchipopreclose ::  $e");
      rethrow;
    }
  }

  Future<Upcoming_ipo> fetchIpoUpcomingApi() async {
    try {
      final uri = Uri.parse(apiLinks.ipoupcomingurl);
      final res = await apiClient.post(uri, headers: defaultHeaders);
      final json = jsonDecode(res.body);
      // log("fetchipopreclose :: ${res.body}");
      Upcoming_ipo ipoModel = Upcoming_ipo.fromJson(json);
      return ipoModel;
    } catch (e) {
      // print("fetchipopreclose ::  $e");
      rethrow;
    }
  }
}

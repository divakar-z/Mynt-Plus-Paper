import '../models/camsres_model.dart';
import '../utils/url_utils.dart';
import '../models/portfolio_model/allholdings_model.dart';
import '../models/portfolio_model/holdings_model.dart';
import '../models/portfolio_model/mf_holdings_model.dart';
import '../models/portfolio_model/mf_quotes.dart';
import '../models/portfolio_model/position_book_model.dart';
import '../models/portfolio_model/position_convertion_model.dart';
import '../models/portfolio_model/position_group_model.dart';
import 'core/api_core.dart';

mixin PortfolioAPI on ApiCore {
// get Holdings from kambala
  Future<List> getOptionlist() async {
    try {
      String u = "https://be.mynt.in/oplist";
      final uri = Uri.parse(u);
      final res = await apiClient.post(uri, headers: defaultHeaders, body: '');

      List data = [];
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json.isNotEmpty && json['Tokens'].isNotEmpty) {
          data = json['Tokens'];
        }
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHolding({String prd = "C"}) async {
    String stat = "";
    try {
      final uri = Uri.parse(apiLinks.getHoldings);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","prd":"$prd"}&jKey=${prefs.clientSession}''');
      //  log("Holdings res=>${res.body} ");
      final List<HoldingsModel> data = [];
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        try {
          // print(
              // 'qwqwqw hold start T ${json.runtimeType} E ${json.isNotEmpty} L ${json.length}');
          if (json.isNotEmpty && json.length > 0) {
              stat = 'success';
              for (final item in json) {
                data.add(HoldingsModel.fromJson(item as Map<String, dynamic>));
              }
          } else if (json.isEmpty && json.toString() == '[]') {
            stat = 'no data';
          } else if (json['stat'] == 'Not_Ok') {
            stat = 'Not_Ok';
            final HoldingsModel ord =
                HoldingsModel.fromJson(json as Map<String, dynamic>);
            return {"stat": stat, "data": ord};
          } else {
            stat = 'error';
            for (final item in json) {
              data.add(HoldingsModel.fromJson(item as Map<String, dynamic>));
            }
          }
        } catch (e) {
          // print('qwqwqw hold json catch$e');
          stat = 'error';
          if (res.statusCode == 200) {
            for (final item in json) {
              data.add(HoldingsModel.fromJson(item as Map<String, dynamic>));
            }
          }
        }
      } else {
          final json = jsonDecode(res.body);
        if (json['emsg'].contains('Session Expired')) {
          data.add(HoldingsModel.fromJson(json as Map<String, dynamic>));
          return json;
        }
      }
      return {"stat": stat, "data": data};
    } catch (e) {
      rethrow;
    }
  }

  // get Mutual fund holdings from kambala

  Future<List<MFHoldingsModel>> getMFHolding() async {
    try {
      final uri = Uri.parse(apiLinks.getMFHoldings);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}","prd":"C"}&jKey=${prefs.clientSession}''');
      // log("MF Holdings res=>${res.body} ");
      final List<MFHoldingsModel> data = [];
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        try {
          var raw = [
            {"stat": "no data"}
          ];
            // print("holdingres");

          // print(json);
          if (json.toString() == '[]') {
            data.add(MFHoldingsModel.fromJson(raw as Map<String, dynamic>));
          } else if (json['stat'] == 'Not_Ok') {
            final MFHoldingsModel ord =
                MFHoldingsModel.fromJson(json as Map<String, dynamic>);
            return [ord];
          } else {
            for (final item in json) {
              data.add(MFHoldingsModel.fromJson(item as Map<String, dynamic>));
            }
          }
        } catch (e) {
          if (res.statusCode == 200) {
            for (final item in json) {
              data.add(MFHoldingsModel.fromJson(item as Map<String, dynamic>));
            }
          }
        }
      } else {
        final json = jsonDecode(res.body);
        if (json['emsg'].contains('Session Expired')) {
          data.add(MFHoldingsModel.fromJson(json as Map<String, dynamic>));
          return data;
        }
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<AllholdModel> getallHolding() async {
    try {
      final uri = Uri.parse(apiLinks.getCames);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "mobileNo": prefs.clientMob,
            // "mobileNo": '9444856459',
            // "mobileNo": '9962573900',
            // "mobileNo": '7639366224',
          }));
      final json = jsonDecode(res.body);

      late AllholdModel allholds;
      if (json['msg'] is Map<String, dynamic> &&
          json['msg']['equities'] != null) {
        allholds = AllholdModel.fromJson(json['msg']);
      } else {
        allholds = AllholdModel(
          equities: {},
          mutualfunds: {},
          syncDatetime: '',
        );
      }
      return allholds;
    } catch (e) {
      rethrow;
    }
  }

  Future<Camsmodel> getcamsapi() async {
    try {
      final uri = Uri.parse(apiLinks.getCamesauth);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({"mobile": prefs.clientMob}));
      // body: jsonEncode({"mobile": '9444856459'}));
      final json = jsonDecode(res.body);

      return Camsmodel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // get Mutual fund  scrip info from kambala

  Future<MFQuotes> getMFQutoes(String exch, String token) async {
    try {
      final uri = Uri.parse(apiLinks.getQuotesMF);
      final res = await apiClient.post(uri,
          headers: defaultHeaders, body: '''jData={"uid":"${prefs.clientId}",
          "exch":"$exch","token":"$token"}&jKey=${prefs.clientSession}''');

      // log("MF Quotes => ${res.body}");
      final json = jsonDecode(res.body);

      return MFQuotes.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get Position book from kambala

  // Future<List<PositionBookModel>> getPostionJson() async {
  //   try {
  //     final resp = await rootBundle.loadString("assets/json/postion_Book.json");

  //     final json = jsonDecode(resp);
  //     final List<PositionBookModel> data = [];
  //     for (final item in json) {
  //       data.add(PositionBookModel.fromJson(item as Map<String, dynamic>));
  //     }

  //     // log("Strategy model =>  $json");
  //     return data;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }
  Future<Map<String, dynamic>> getPositionBook() async {
    String stat = "";
    try {
      final uri = Uri.parse(apiLinks.getPosition);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","actid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');
      //  log("PositionBook => ${res.body}");

      final List<PositionBookModel> data = [];

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        try {
          // print('qwqwqw pos start T ${json.runtimeType} E ${json.isNotEmpty} L ${json.length}');
          if (json is Map<String, dynamic>) {
            stat = 'no data';
          } else if (json.isNotEmpty && json.length > 0) {
            stat = 'success';
            for (final item in json) {
              data.add(
                  PositionBookModel.fromJson(item as Map<String, dynamic>));
            }
          } else if (json['stat'] == 'Not_Ok') {
            stat = 'Not_Ok';
            final PositionBookModel ord =
                PositionBookModel.fromJson(json as Map<String, dynamic>);
            return {"stat": stat, "data": ord};
          } else {
            stat = 'error';
            for (final item in json) {
              data.add(
                  PositionBookModel.fromJson(item as Map<String, dynamic>));
            }
          }
        } catch (e) {
          // print('qwqwqw pos json catch$e');
          stat = 'error';
          if (res.statusCode == 200) {
            for (final item in json) {
              data.add(
                  PositionBookModel.fromJson(item as Map<String, dynamic>));
            }
          }
        }
      } else {
        final json = jsonDecode(res.body);
        if (json['emsg'].contains('Session Expired')) {
          data.add(PositionBookModel.fromJson(json as Map<String, dynamic>));
          return json;
        }
      }
      return {"stat": stat, "data": data};
    } catch (e) {
      rethrow;
    }
  }

  // get Position convertion response from kambala

  Future<PositionConvertionModel> getPositionConvertion(
      PositionConvertionInput positionConvertionInput) async {
    try {
      final uri = Uri.parse(apiLinks.positionConvert);
      final res = await apiClient.post(uri,
          headers: defaultHeaders, body: '''jData={"uid":"${prefs.clientId}",
              "actid":"${prefs.clientId}",
              "exch":"${positionConvertionInput.exch}",
              "tsym":"${UrlUtils.encodeParameter(positionConvertionInput.tsym)}",
              "qty":"${positionConvertionInput.qty}",
              "prd":"${positionConvertionInput.prd}",
              "prevprd":"${positionConvertionInput.prevprd}",
              "trantype":"${positionConvertionInput.trantype}",
              "postype":"${positionConvertionInput.postype}",
              "ordersource":"WEB"}&jKey=${prefs.clientSession}''');
      // "ordersource":"MOB"}&jKey=${prefs.clientSession}''');

      // log("Position Convertion => ${res.body}");
      final json = jsonDecode(res.body);

      return PositionConvertionModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// get Grouped position datas

  Future<List<GetGroupSymbol>> getGroupPosition() async {
    try {
      final uri =
          Uri.parse("${apiLinks.positionGrp}?clientid=${prefs.clientId}");
      final res = await apiClient.get(uri, headers: defaultHeaders);

      // log("Position Group List => ${res.body}");
      final json = jsonDecode(res.body);
      final List<GetGroupSymbol> data = [];

      for (final item in json) {
        data.add(GetGroupSymbol.fromJson(item as Map<String, dynamic>));
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Create custom group Name for position

  Future<CreateGroupName> createGroupName(String name) async {
    try {
      final uri = Uri.parse(apiLinks.creatGrpName);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({"clientid": "${prefs.clientId}", "posname": name}));

      // log("Position Group Name => ${res.body}");
      final json = jsonDecode(res.body);

      return CreateGroupName.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Add position scrip to grouped named

  Future<CreateGroupName> addGroupNameSymbol(String name, Map data) async {
    try {
      final uri = Uri.parse(apiLinks.addSymbolGrp);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "clientid": "${prefs.clientId}",
            "posname": name,
            "symdata": data
          }));

      // log("Add symbol Group Name => ${res.body}");
      final json = jsonDecode(res.body);

      return CreateGroupName.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Delete position scrip to grouped named

  Future<CreateGroupName> deletePositionGrpName(String name) async {
    try {
      final uri = Uri.parse(
          "${apiLinks.delpositiongrpName}?clientid=${prefs.clientId}&posname=$name");
      final res = await apiClient.get(uri, headers: defaultHeaders);

      // log("Delete vPosition Group  Name => ${res.body}");
      final json = jsonDecode(res.body);

      return CreateGroupName.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

// Delete position group name

  Future<CreateGroupName> deletePositionGrpSym(
      String grpName, String tsym) async {
    try {
      final uri = Uri.parse(apiLinks.delpositiongrpSym);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "clientid": "${prefs.clientId}",
            "posname": grpName,
            "tsym": UrlUtils.encodeParameter(tsym)
          }));

      // log("Delete Position Group Symbol => ${res.body}");
      final json = jsonDecode(res.body);

      return CreateGroupName.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}
// "symbol removed"

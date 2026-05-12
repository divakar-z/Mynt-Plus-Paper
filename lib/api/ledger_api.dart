import 'dart:developer';
// import 'dart:io';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:mynt_plus/models/desk_reports_model/contract_note_model.dart';
import 'package:mynt_plus/models/desk_reports_model/pdf_download_model.dart';
import 'package:mynt_plus/models/desk_reports_model/pnl_seg_charges_model.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/core/api_core.dart';
import '../models/desk_reports_model/SharingResponseCalendar_model.dart';
import '../models/desk_reports_model/approved_pledge_list_model.dart';
import '../models/desk_reports_model/ca_events_model.dart';
import '../models/desk_reports_model/calender_pnl_model.dart';
import '../models/desk_reports_model/cdsl_response_model.dart';
import '../models/desk_reports_model/cmr_download_model.dart';
import '../models/desk_reports_model/cp_action_model.dart';
import '../models/desk_reports_model/dercomcur_taxpnl_model.dart';
import '../models/desk_reports_model/editreport_model.dart';
import '../models/desk_reports_model/holdings_model.dart';
import '../models/desk_reports_model/ledger_bill_model.dart';
import '../models/desk_reports_model/ledger_model.dart';
import '../models/desk_reports_model/order_response_cop.dart';
import '../models/desk_reports_model/placeorder_response_model.dart';
import '../models/desk_reports_model/pledge_history_model.dart';
import '../models/desk_reports_model/pledge_segment_check_model.dart';
import '../models/desk_reports_model/pledge_unpledge_model.dart';
import '../models/desk_reports_model/pnl_model.dart';
import '../models/desk_reports_model/pnl_summary_model.dart';
import '../models/desk_reports_model/position_model.dart';
import '../models/desk_reports_model/sharing_on_off_model.dart';
import '../models/desk_reports_model/tax_pnl_Eq_charge_model.dart';
import '../models/desk_reports_model/taxpnl_eq_model.dart';
import '../models/desk_reports_model/tradebook_model.dart';
import 'dart:convert';

import '../models/desk_reports_model/unpledge_history_model.dart';
import '../sharedWidget/fund_function.dart';
// import 'package:permission_handler/permission_handler.dart';

// import 'package:open_file/open_file.dart';
mixin LedgerApi on ApiCore {
  Future<CPActionModule> getcpactiondata() async {
    try {
      final uri =
          // Uri.parse('${apiLinks.reportsapiforcpaction}/getCorporateAction');
          Uri.parse('${apiLinks.reportsapiforcpaction}/getCorporateAction');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({}));

      final json = jsonDecode((res.body));
      // print("${json['stat']}");
      if (json['stat'] != 'Not Ok') {
        return CPActionModule.fromJson(json as Map<String, dynamic>);
      } else {
        return CPActionModule.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<GetOrderlistCopModel> getorderdetails() async {
    try {
      final uri =
          // Uri.parse('${apiLinks.reportsapiforcpaction}/getCorporateAction');
          Uri.parse('${apiLinks.reportsapiforcpaction}/fetchorderdetailcorp');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({}));

      final json = jsonDecode((res.body));
      // print("${json['stat']}");
      if (json['msg'] != 'No data') {
        return GetOrderlistCopModel.fromJson(json as Map<String, dynamic>);
      } else {
        return GetOrderlistCopModel.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<EdisReportModel> geteditsdata(List<dynamic> isinlist) async {
    try {
      final uri =
          // Uri.parse('${apiLinks.reportsapiforcpaction}/getCorporateAction');
          Uri.parse('${apiLinks.reportsapiforcpaction}/EdisReport');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              jsonEncode({"clientid": "${prefs.clientId}", "isin": isinlist}));

      final json = jsonDecode((res.body));
      // print("${json['stat']}");
      if (json['msg'] != 'edis report error') {
        return EdisReportModel.fromJson(json as Map<String, dynamic>);
      } else {
        return EdisReportModel.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LedgerModelData> getLedgerdata(String from, String to, bool includeBillMargin) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/${includeBillMargin ? 'getLedger' : 'getLedgerNoMargin'}');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "TN1V2",

            "from": from, "to": to
          }));

      final json = jsonDecode((res.body));
      // print("${json['stat']}");
      if (json['stat'] != 'Not Ok') {
        return LedgerModelData.fromJson(json as Map<String, dynamic>);
      } else {
        return LedgerModelData.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UnpledgeHistoryModel> getunpledgehistory() async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/unpledge_history');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "clientid": "${prefs.clientId}",
            "date": "",
          }));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not Ok') {
      return UnpledgeHistoryModel.fromJson(json as Map<String, dynamic>);
      // } else {
      // return UnpledgeHistoryModel.fromJson({});
      // }
    } catch (e) {
      rethrow;
    }
  }

  Future<PledgeHistoryModel> getpledgehistory() async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/PledgeHistory');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({"clientid": "${prefs.clientId}"}));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not Ok') {
      return PledgeHistoryModel.fromJson(json as Map<String, dynamic>);
      // } else {
      // return UnpledgeHistoryModel.fromJson({});
      // }
    } catch (e) {
      rethrow;
    }
  }

  Future<HoldingModel> getHoldingsdata(String from) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getHoldings');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "TN1V2",

            // "from": from,
            "to": from,
            // "withopen": "Y"
          }));
      if (res.body != 'no data found') {
        final json = jsonDecode((res.body));
        return HoldingModel.fromJson(json as Map<String, dynamic>);
      } else {
        return HoldingModel.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<SharingResponse> getsharingdata(
      String from, String to, String seg) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getclientsharelist');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            "from": from,
            "to": to,
            "segment": seg
          }));
      final json = jsonDecode((res.body));
      if (json['msg'] != 'No Data Available') {
        return SharingResponse.fromJson(json as Map<String, dynamic>);
      } else {
        return SharingResponse.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<placeOrderResponseCopModel> putorderapicopaction(
      String tabval,
      String sym,
      String exchange,
      String issueType,
      String qty,
      String price,
      String ordertype,
      String appno) async {
    try {
      final uri =
          Uri.parse('${apiLinks.reportsapiforcpaction}/addCorporateAction');
      dynamic data;
      if (issueType == 'RS' || issueType == 'IS') {
        data = {
          "exchange": exchange,
          "symbol": sym,
          "series": issueType,
          "activityType": ordertype,
          "quantity": int.parse(qty),
          "price": int.parse(double.parse(price).toStringAsFixed(0)),
          "cutOffPrice": false,
          ordertype == 'CR' ? "applicationNo" : "appno": appno
        };
      } else {
        data = {
          "exchange": exchange,
          "symbol": sym,
          "series": issueType,
          "activityType": ordertype,
          "bidQuantity": int.parse(qty),
          "price": int.parse(double.parse(price).toStringAsFixed(0)),
          ordertype == 'CR' ? "applicationNo" : "appno": appno
        };
      }
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode(data));
      final json = jsonDecode((res.body));
      // Always parse the response so callers can surface unexpected backend
      // errors (e.g. `{"emsg": "clientid not exist"}`) instead of getting an
      // empty model with no clue what went wrong.
      if (json is Map<String, dynamic>) {
        return placeOrderResponseCopModel.fromJson(json);
      }
      return placeOrderResponseCopModel.fromJson({});
    } catch (e) {
      rethrow;
    }
  }

  Future<OnorOffSharingModel> senddharingdataapi(
      ucode, String from, String to, response, status, String seg) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/sharenew');

      // Convert numeric strings to numbers in the request payload
      var clientId = int.tryParse(prefs.clientId ?? "") ?? prefs.clientId;
      var responseData = response;

      // If response is a string that contains JSON, parse and convert numeric values
      if (response is String && response.isNotEmpty) {
        try {
          // Try to parse as JSON if it's a JSON string
          var parsedResponse = jsonDecode(response);
          responseData = _convertStringsToNumbers(parsedResponse);
        } catch (e) {
          // If not JSON, try to convert to number if possible
          var numValue = num.tryParse(response);
          if (numValue != null) {
            responseData = numValue;
          }
        }
      } else if (response is Map || response is List) {
        // If already a Map or List, convert numeric strings inside it
        responseData = _convertStringsToNumbers(response);
      }

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": clientId,
            "from": from,
            "to": to,
            "sharing": !status, // Using status directly as per corrected logic
            "response": responseData,
            "Unique_Code": ucode,
            "uname": "${prefs.clientName}",
            "segment": seg
          }));

      final json = jsonDecode((res.body));
      if (json['stat'] == 'Ok') {
        return OnorOffSharingModel.fromJson(json as Map<String, dynamic>);
      } else {
        return OnorOffSharingModel.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  // Helper function to recursively convert string numbers to actual numbers
  dynamic _convertStringsToNumbers(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        if (value is String) {
          // Try to convert strings to numbers if possible
          final numValue = num.tryParse(value);
          result[key] = numValue ?? value;
        } else if (value is Map || value is List) {
          result[key] = _convertStringsToNumbers(value);
        } else {
          result[key] = value;
        }
      });
      return result;
    } else if (data is List) {
      return data.map((item) {
        if (item is String) {
          // Try to convert strings to numbers if possible
          final numValue = num.tryParse(item);
          return numValue ?? item;
        } else if (item is Map || item is List) {
          return _convertStringsToNumbers(item);
        }
        return item;
      }).toList();
    }
    return data;
  }

  Future<PositionModel> getposition() async {
    try {
      // const ip = '192.168.5.22'; // the real server IP
      // const hostHeader = 'be.zebull.in'; // whatever your fake hostname was
      // final uri = Uri(
      //   scheme: 'https',
      //   host: ip,
      //   path: '/_link/GetPosition',
      // );
      final uri = Uri.parse('${apiLinks.position}GetPosition');
      final res = await apiClient.post(uri,
          // headers: {
          //   'Content-Type': 'application/json',
          //   'Host': hostHeader,
          // },
          headers: funddefaultHeaders,
          body: jsonEncode({"client_id": "${prefs.clientId}"}));
      // body: jsonEncode({"client_id": "ZVK0106"}));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not Ok') {
      // return PositionModel.fromJson(json as Map<String, dynamic>);
      return PositionModel.fromJson({'data': json});
      // } else {
      // return PositionModel.fromJson({});
      // }
    } catch (e) {
      rethrow;
    }
  }

  Future<LedgerBillModel> getLedgerBilldata(
      String sett, String mrktyp, String comc, String tdate) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getbillsummary');

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "settlementno": sett,
            "markettype": mrktyp,
            "companycode": comc,
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",
            "tradedate": tdate
          }));

      final json = jsonDecode((res.body));

      // log("MF Master ==>$json");

      return LedgerBillModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<PnlModel> getpnldata(String from, String to, bool yrn) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getpnl');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZP00172",
            "from": from,
            "to": to,
            "withopen": yrn == true ? 'Y' : 'N'
          }));

      final json = jsonDecode((res.body));

      // log("MF Master ==>$json");
      if (json['stat'] != 'Not OK') {
        return PnlModel.fromJson(json as Map<String, dynamic>);
      } else {
        return PnlModel.fromJson({});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<CalenderpnlModel> getcalenderpnldata(
      String from, String to, String type) async {
    try {
      String endpoint = type == "Commodity" ? "getJournalDiary3" : "getJournalDiary";
      final uri = Uri.parse('${apiLinks.reportsapi}$endpoint');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",

            "from": from,
            "to": to,
            "segment": type == 'Equity'
                ? "NSE_CASH,BSE_CASH"
                : type == 'FNO'
                    ? "NSE_FNO,BSE_FNO"
                    : type == 'Commodity'
                        ? "MCX,NCDEX,NSE_COM,BSE_COM"
                        : "CD_NSE,CD_BSE,CD_MCX,CD_USE"
          }));

      // print(" ${res.body} reswwwww");
      if (res.body == 'No Data') {
        return CalenderpnlModel.fromJson({"data": res.body});
      } else {
        final json = jsonDecode((res.body));
        json['segment'] = type;
        return CalenderpnlModel.fromJson(json as Map<String, dynamic>);
      }
      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<TradeBookModel> gettradebookdata(String from, String to) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getTradeDetails');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZP00172",

            "from": from,
            "to": to
          }));

      // print(" ${res.body} reswwwww");
      final json = jsonDecode((res.body));

      // final resval = res.body;
      if (json['trades'] != null && (json['trades'] as List).isNotEmpty) {
        return TradeBookModel.fromJson(json as Map<String, dynamic>);
      } else {
        return TradeBookModel.fromJson({});
      }
      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  getpdffileapi(String recno, String filename) async {
    try {
      // final url = Uri.parse('${apiLinks.reportsapi}/getdocdownloadsmobile?cc=${prefs.clientId}&recno=${recno}');
      // final url = Uri.parse(
      //     '${apiLinks.reportsapi}/downloaddocmob?cc=ZE1A40&recno=${recno}');
      // final response = await apiClient.get(
      //   url,
      //   headers: testingrameshheader,
      //   // headers: funddefaultHeaders,
      // );
      //file download.

      // print("${response}");
      final Uri uri = Uri.parse(
          "${apiLinks.reportsapi}/downloaddocmob1?cc=${prefs.clientId}&recno=${recno}");
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch  ';
      }

      // Check Content-Type
      // String? contentType = response.headers['content-type'];
      // if (contentType != null && contentType.contains('application/json')) {
      //   print("Received JSON response, not a file.");
      //   return;
      // }

      // String baseName = filename.split(".")[0];

      // Directory? directory;
      // if (Platform.isAndroid) {
      //   directory = Directory("/storage/emulated/0/Download");
      // } else {
      //   directory = await getDownloadsDirectory();
      // }

      // if (directory == null) {
      //   print("Error: Unable to get storage directory.");
      //   return;
      // }

      // String filePath = "${directory.path}/$baseName.zip";

      // File file = File(filePath);
      // await file.writeAsBytes(response.bodyBytes);

      // return 'Success';
      return "File downloaded successfully";
    } catch (e) {
      rethrow;
    }
  }

  Future<String> downloadDocWeb(String recno, String filename) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}downloaddoc');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            "recno": recno,
          }));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          final json = jsonDecode(res.body);

          if (json['stat'] == 'Not Ok') {
            return json['msg'] ?? 'No data available';
          }

          final filepath = json['filepath']?.toString() ??
              json['path']?.toString() ??
              '';
          if (filepath.isEmpty) {
            return 'No data available';
          }

          final staticPath =
              filepath.split('static').last.replaceAll(r'\', '/');
          final finalUrl = '${apiLinks.reportsapi}static$staticPath';
          html.window.open(finalUrl, '_blank');
        } else {
          if (res.bodyBytes.isEmpty) {
            return 'No data available';
          }
          final blob = html.Blob(
              [Uint8List.fromList(res.bodyBytes)], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download',
                filename.isNotEmpty ? filename : 'document.pdf')
            ..click();
          html.Url.revokeObjectUrl(url);
        }
        return "File downloaded successfully";
      } else {
        return "Error: Server returned ${res.statusCode}";
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> downloadTaxPnlWeb(int year, String format) async {
    try {
      final isPdf = format == 'PDF';
      final uri = Uri.parse(
          '${apiLinks.reportsapi}${isPdf ? 'taxpnl_pdf' : 'tax_p_l_excel'}');
      final fromapi = '01/04/$year';
      final toapi = '31/03/${year + 1}';

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_code": "${prefs.clientId}",
            "from_date": fromapi,
            "to_date": toapi,
          }));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        if (json['stat'] == 'Not Ok') {
          return json['msg'] ?? 'Error generating file';
        }

        final filepath = json['filepath']?.toString() ?? '';
        if (filepath.isEmpty) {
          return 'Error: No file path in response';
        }

        // Build URL: split on "static" and append to base
        final staticPath = filepath.split('static').last.replaceAll(r'\', '/');
        final finalUrl = '${apiLinks.reportsapi}static$staticPath';

        if (isPdf) {
          html.window.open(finalUrl, '_blank');
        } else {
          html.window.location.href = finalUrl;
        }

        return "File downloaded successfully";
      } else {
        return "Error: Server returned ${res.statusCode}";
      }
    } catch (e) {
      rethrow;
    }
  }

  Future getpdffileapitaxpnl(eq, der, eqcharge, year, format) async {
    try {
      // final url = Uri.parse('${apiLinks.reportsapi}/getdocdownloadsmobile?cc=${prefs.clientId}&recno=${recno}');
      // final url = Uri.parse(
      //     '${apiLinks.reportsapi}/downloaddocmob?cc=ZE1A40&recno=${recno}');
      // final response = await apiClient.get(
      //   url,
      //   headers: testingrameshheader,
      //   // headers: funddefaultHeaders,
      // );
      //file download.
      // print("${response}");
      final pdfuri = Uri.parse('${apiLinks.reportsapi}/taxpnl_pdf');
      final exceluri = Uri.parse('${apiLinks.reportsapi}/tax_p_l_excel');
      // final uri = Uri.parse('${apiLinks.reportsapi}/getdocdownloads');
      final fromapi = '01/04/$year';
      final toapi = '31/03/${(year) + 1}';
      final res = await apiClient.post(format == "PDF" ? pdfuri : exceluri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "client_code": "${prefs.clientId}",
            "dercomcur": der,
            "equity": eq,
            "equity_taxes": eqcharge,
            "from_date": fromapi,
            "to_date": toapi
          }));

      final json = jsonDecode((res.body));
      
    // final filepath = json['filepath'].split('static').last.replaceAll(r'\', '/');
      if (json['stat'] != 'Not Ok') {
        // final urival = Uri.parse('${apiLinks.reportsapi}${json['path']}');
        // final urival = Uri.parse('http://192.168.5.207:5100/static${filepath}');

        // if (!await launchUrl(urival, mode: LaunchMode.externalApplication)) {
        //   throw 'Could not launch';
        // }
        return "File Sent to mail successfully";
      } else {
        return json['msg'];
      }

      // Check Content-Type
      // String? contentType = response.headers['content-type'];
      // if (contentType != null && contentType.contains('application/json')) {
      //   print("Received JSON response, not a file.");
      //   return;
      // }

      // String baseName = filename.split(".")[0];

      // Directory? directory;
      // if (Platform.isAndroid) {
      //   directory = Directory("/storage/emulated/0/Download");
      // } else {
      //   directory = await getDownloadsDirectory();
      // }

      // if (directory == null) {
      //   print("Error: Unable to get storage directory.");
      //   return;
      // }

      // String filePath = "${directory.path}/$baseName.zip";

      // File file = File(filePath);
      // await file.writeAsBytes(response.bodyBytes);

      // return 'Success';
    } catch (e) {
      rethrow;
    }
  }

  Future getpdffileapiledger(resp, dr, cr, op, clb, sdate, edate) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/ledger_pdf');
      // final uri = Uri.parse('http://192.168.5.175:5004/ledger_pdf');

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "client_code": "${prefs.clientId}",
            "resp": resp,
            "debit": dr,
            "credit": cr,
            "opening_balance": op,
            "closing_balance": clb,
            "from_date": sdate,
            "to_date": edate
          }));

      final json = jsonDecode((res.body));
      if (json['stat'] != 'Not Ok') {
        final urival = Uri.parse('${apiLinks.reportsapi}${json['path']}');
        // final urival = Uri.parse('http://192.168.5.175:5004/${json['path']}');

        if (!await launchUrl(urival, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch';
        }
        return "File downloaded successfully";
      } else {
        return json['msg'];
      }
    } catch (e) {
      rethrow;
    }
  }

  Future getpdffileapipnl(resp, sdate, edate, string, notional, value) async {
    try {
      // final uri = Uri.parse('${apiLinks.reportsapi}/taxpnl_pdf');
      final uri = Uri.parse('${apiLinks.reportsapi}/notional_p_and_l');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "client_code": "${prefs.clientId}",
            "resp": resp,
            "heading_value": notional,
            "heading": string,
            "all_charges": value,
            "from_date": sdate,
            "to_date": edate
          }));
      final json = jsonDecode((res.body));
      if (json['stat'] != 'Not Ok') {
        // final urival = Uri.parse('${apiLinks.reportsapi}${json['path']}');
        final urival = Uri.parse('${apiLinks.reportsapi}/${json['path']}');
        if (!await launchUrl(urival, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch';
        }
        return "File downloaded successfully";
      } else {
        return json['msg'];
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<PdfDownloadModel> getpdfdownload(String from, String to) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getdocdownloads');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",
            "from": from,
            "to": to
          }));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not OK') {
      return PdfDownloadModel.fromJson({'data': json});
      // } else {
      // return PdfDownloadModel.fromJson({});
      // }

      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<PledgeAndUnpledgeModel> getpledgeandunpledge() async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}PledgeHoldings');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "clientid": "${prefs.clientId}",
          }));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not OK') {
      return PledgeAndUnpledgeModel.fromJson(json as Map<String, dynamic>);
      // } else {
      // return PdfDownloadModel.fromJson({});
      // }

      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<ApprovedPledgeListModel> getapprovepledge() async {
    try {
      // final uri = Uri.parse('${apiLinks.reportspledge}ApprovePledge');
      final uri = Uri.parse('${apiLinks.reportspledge}ApprovedScripts');
      final res = await apiClient.get(uri,
          headers: defaultHeaders,
          );
      final json = jsonDecode((res.body));
      return ApprovedPledgeListModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<CAEventsModel> getcaevents(start, end) async {
    try {
      final uri = Uri.parse('${apiLinks.caevents}getEquityCorporateActions');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "fromDate": start.split("/")[2] +
                "-" +
                start.split("/")[1] +
                "-" +
                start.split("/")[0],
            "toDate": end.split("/")[2] +
                "-" +
                end.split("/")[1] +
                "-" +
                end.split("/")[0]
          }));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not OK') {
      return CAEventsModel.fromJson(json as Map<String, dynamic>);
      // } else {
      // return PdfDownloadModel.fromJson({});
      // }

      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<PledgeSegmentCheckModel> getsegforpledge() async {
    try {
      final uri = Uri.parse('${apiLinks.fundforprofile}client_check');
      String payload = jsonEncode({
        "client_code": "${prefs.clientId}",
      });
      String encryptedPayload = encryptionFunction(payload);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({"code": encryptedPayload}));

      final json = jsonDecode((res.body));
      // if (json['stat'] != 'Not OK') {
      return PledgeSegmentCheckModel.fromJson(json as Map<String, dynamic>);
      // } else {
      // return PdfDownloadModel.fromJson({});
      // }

      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<TaxPnlEqModel> gettaxpnleq(int from) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getequitypnl');
      final fromapi = '01/04/$from';
      final toapi = '31/03/${(from) + 1}';

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
//
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));

              jsonEncode({
            // "cc": "ZP00172",

            "cc": "${prefs.clientId}",
            "from": fromapi,
            "to": toapi,
          }));

      final json = {"data": jsonDecode((res.body))};

      if (json['data']['stat'] != 'Not Ok') {
        return TaxPnlEqModel.fromJson({'data': json});
      } else {
        return TaxPnlEqModel.fromJson({});
      }

      // return TaxPnlEqModel.fromJson(json as Map<String, dynamic>);

      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<PnlSegCharge> getpnlsegcharge(
      String seg, String start, String today, bool yrn) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getpnlexpenses');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",
            "from": start,
            "to": today,
            'seg': seg,
            'withopen': yrn
          }));
      final json = jsonDecode((res.body));
      // log("MF Master ==>$json");
      return PnlSegCharge.fromJson(json as Map<String, dynamic>);

      // return PnlSegCharge.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future<TaxPnlEqCharges> GettaxpnleqCharge(String seg, int from) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getexpenseseperate');
      final fromapi = '01/04/$from';
      final toapi = '31/03/${(from) + 1}';
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZP00172",

            "from": fromapi,
            "to": toapi,
            'seg': seg
          }));
      final json = jsonDecode((res.body));
      // log("MF Master ==>$json");
      return TaxPnlEqCharges.fromJson(json as Map<String, dynamic>);

      // return PnlSegCharge.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future geturlforcdsl(
      String ccode, String boid, String cname, List list) async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/response');

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "uccid": ccode,
            "client_bo_id": boid,
            "CLIENT_NAME": cname,
            "pledgeReq": list
          }));
      final json = jsonDecode((res.body));

      // log("MF Master ==>$json");
      return json;

      // return PnlSegCharge.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future<CdslReponseModel> getresponsefromcdsl(String response) async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/reqid_details');

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "reqid": response,
          }));
      final json = jsonDecode((res.body));

      // log("MF Master ==>$json");
      return CdslReponseModel.fromJson(json as Map<String, dynamic>);

      // return PnlSegCharge.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future<PnlSegCharge> GettaxeqpnlTacCharges(
      String seg, String start, String today, bool yrn) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getpnlexpenses');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",
            "from": start,
            "to": today,
            'seg': seg,
            'withopen': yrn
          }));
      final json = jsonDecode((res.body));
      // log("MF Master ==>$json");
      return PnlSegCharge.fromJson(json as Map<String, dynamic>);

      // return PnlSegCharge.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future<PnlSummaryModel> getPnlSummary(
      String script, String comcode, String from, String to) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}/getpnlscriptdetail');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            // "cc": "ZE1A40",

            "from": from,
            "to": to,
            "script": script,
            "cocd": comcode
          }));
      final json = jsonDecode((res.body));
      // log("MF Master ==>$json");

      return PnlSummaryModel.fromJson({'data': json});
    } catch (e) {
      rethrow;
    }
  }

  Future sendunpledgeapi(
      String uccid, String boid, String cname, List list) async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/unpledge_requested');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({
            "boid": boid,
            "clientid": uccid,
            "clientname": cname,
            "unpledge_req_data": list,
          }));
      if (res.statusCode == 200) {
        final json = jsonDecode((res.body));
        // log("MF Master ==>$json");
        return json;
      } else {
        return {"msg": 'error occurre'};
      }
    } catch (e) {
      return {"msg": 'error occurre'};
    }
  }

  Future sendunpledgedeleteapi(String uccid, List list) async {
    try {
      final uri = Uri.parse('${apiLinks.reportspledge}/del_unpledge');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body: jsonEncode({"clientid": uccid, "ISIN": list}));
      if (res.statusCode == 200) {
        final json = jsonDecode((res.body));
        // log("MF Master ==>$json");
        return json;
      } else {
        return {"msg": 'error occurre'};
      }
    } catch (e) {
      return {"msg": 'error occurre'};
    }
  }

  Future<DercomcurModel> gettaxpnldercomcur(int from) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}getderpnl');
      final fromapi = '01/04/$from';
      final toapi = '31/03/${(from) + 1}';
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          // headers: testingrameshheader,
          body:
              // jsonEncode({"cc": "${prefs.clientId}", "from": from, "to": to}));
              jsonEncode({
            "cc": "${prefs.clientId}",

            // "cc": "ZP00172",

            "from": fromapi,
            "to": toapi,
          }));
      final json = {"data": jsonDecode((res.body))};
      log("${res.body} datdatdatdadta");

      if (json['data']['stat'] != 'Not Ok') {
        return DercomcurModel.fromJson({'data': json});
      } else {
        return DercomcurModel.fromJson({});
      }

      // return TaxPnlEqModel.fromJson(json as Map<String, dynamic>);
      // log("MF Master ==>$json");
    } catch (e) {
      rethrow;
    }
  }

  Future<CmrDownloadModel> cmrdownload() async {
    try {
      final uri = Uri.parse(apiLinks.cmrdownload);
      final res = await apiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "client_id": "${prefs.clientId}",
        }),
      );

      final json = jsonDecode((res.body));
      return CmrDownloadModel.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  Future<ContractNoteModel> getContractNote(String from, String to) async {
    try {
      final uri = Uri.parse('${apiLinks.reportsapi}getContractNote');
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "cc": "${prefs.clientId}",
            "from": from,
            "to": to,
          }));

      final json = jsonDecode(res.body);
      return ContractNoteModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}

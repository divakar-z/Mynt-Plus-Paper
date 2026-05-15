import 'dart:typed_data';
import 'package:mynt_plus/models/client_profile_all_details/details_change_current_status_model.dart';
import 'package:mynt_plus/models/client_profile_all_details/profile_all_details_model.dart';
import 'package:mynt_plus/sharedWidget/fund_function.dart';
import '../api/core/api_core.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../screens/Mobile/profile_screen/profile_main_screen.dart';

String globalcurrmail = '';
String globalNewEmail = '';
String globaldpcode = '';
var globalfulldata;
String globalnewmob = '';

String globalIfscResponse = '';

final profileres = ProviderContainer().read(transcationProvider);
var profileres2 = profileres;

mixin ProfileAllDetailsApi on ApiCore {
  Future<DetailsChangeCurrentStatus> getDetailsChangeCurrentStatusApi() async {
    try {
      final uri = Uri.parse(apiLinks.detailschangecurrentstatusURL);
      final res = await apiClient.post(
        uri,
        headers: funddefaultHeaders,
        body: jsonEncode(
          {"client_id": "${prefs.clientId}"},
        ),
      );
      final json = jsonDecode(res.body);
      return DetailsChangeCurrentStatus.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  sendOTPtoChangeEmailApi(String newEmail, String oldEmail, String clientName,
      String dpcode) async {
    globalcurrmail = oldEmail;
    globalNewEmail = newEmail;
    globaldpcode = dpcode;
    try {
      final uri = Uri.parse(apiLinks.sendOTPEmailURL);

      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "previous_email": oldEmail,
            "present_email": newEmail,
            "client_name": clientName
          }));

      final json = jsonDecode((res.body));

      // // print("MF Master ==>${json['msg']}");

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  verifyOTPtoChangeEmailApi(String otpres, newEmail) async {
    try {
      final uri = Uri.parse(apiLinks.verifyOTPEmailURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "present_email": newEmail,
            "emailotp": otpres
          }));

      final json = jsonDecode((res.body));
      // // print("otpres $otpres");
      // // print("newemail $newEmail");

      // // print("otp email resp ==>${json['msg']}");

      if (json['msg'] == "otp valid") {
        // // print("function call");
        // // print("globalcurrmail , ${globalcurrmail}");
        // // print("client_id, ${prefs.clientId}");
        // // print("client_email: ${globalcurrmail}");
        // // print("dp_code: ${globaldpcode}");
        // // print("present_email: ${globalNewEmail}");
        // // print("previous_email: ${globalcurrmail}");

        // // print("client_name: ${prefs.clientName}");

        // // String old_email  = old;
        // // String newemail = json['new_email'];
        // // print("------------------------------------------------------");
        emailfilewrittenapi();
      }

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  emailfilewrittenapi() async {
    try {
      DateTime nowUtc = DateTime.now().toUtc();

      // Manually format the date
      String formattedDateUtc = "${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}.${nowUtc.millisecond.toString().padLeft(3, '0')}Z"; // You can use milliseconds instead of microseconds for simplicity.

      // // print("Formatted UTC date: $formattedDateUtc");
      // // print("Current date and time: $now");
      final uri = Uri.parse(apiLinks.filewriteemailURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "client_email": globalcurrmail,
            "dp_code": globaldpcode,
            "date_time": formattedDateUtc,
            "present_email": globalNewEmail,
            "previous_email": globalcurrmail,
            "client_name": "${prefs.clientName}",
          }));

      // // print(jsonEncode({
      //   "client_id": "${prefs.clientId}",
      //   "client_email": "${globalcurrmail}",
      //   "dp_code": globaldpcode,
      //   "date_time": "${formattedDateUtc}",
      //   "present_email": "${globalNewEmail}",
      //   "previous_email": "${globalcurrmail}",
      //   "client_name": "${prefs.clientName}",
      // }));

      final json = jsonDecode((res.body));

      // // print("filewriteep ==>${json}");

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

// startDigioEsign() async {
//   try {

//     final result = await platform.invokeMethod('startDigioEsign', {
//       'fileId': "DID250211194303853KXRAIB6KN72FOV",
//       'email': "sabarimechc12@gmail.com",
//       'session': "GWT250212102955344POFS5I2GD7C2DS",
//     });

//     if (result == 'Signed Successfully') {
//       // print("Document signed successfully!");

//     } else if (result == 'Signing cancelled') {
//       // print("Signing process was cancelled.");

//     } else {
//       // print("Unexpected result: $result");

//     }
//   } catch (e) {
//     // print('Error during Digio eSign: $e');

//   }
// }

  Future<void> esignfunstart() async {
    // // print("Starting Digio eSign workflow...");
    // var workflowResult;

    // try {
    //   var digioConfig = DigioConfig();
    //   digioConfig.theme.primaryColor = "#32a83a";
    //   digioConfig.environment = Environment.PRODUCTION;

    //   final _kycWorkflowPlugin = KycWorkflow(digioConfig);

    //   // Set the listener for gateway events
    //   _kycWorkflowPlugin.setGatewayEventListener((GatewayEvent? gatewayEvent) {
    //     // print("Gateway funnel event: " + gatewayEvent.toString());
    //   });

    //   // Start the eSign workflow
    //   workflowResult = await _kycWorkflowPlugin.start(
    //     "DID250211194303853KXRAIB6KN72FOV", // Sample Client ID
    //     "sabarimechc12@gmail.com", // Sample email
    //     "GWT250212102955344POFS5I2GD7C2DS", // Sample Reference ID
    //     null,
    //   );

    //   // print('workflowResult : ' + workflowResult.toString());
    // } catch (e) {
    //   // print('Error during Digio eSign: $e');
    // }
    // // print("eSign workflow finished.");
  }

  Future<ProfileAllDetails> getClientProfileAllDetailsApi() async {
    String payload = jsonEncode({"client_id": prefs.clientId});
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.profileAllDetailsURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      Map<String, dynamic> json = jsonDecode(res.body);
      if (json.containsKey('emsg')) {
        return ProfileAllDetails.fromJson(json);
      } else {
        final decryptedData = decryptionFunction(json["str"]);
        //  log("client Data------------ ${jsonDecode(jsonEncode(decryptedData))}}");
        // print("decryptedData------------ ${jsonDecode(decryptedData)}");
        return ProfileAllDetails.fromJson(jsonDecode(decryptedData));
      }
    } catch (e) {
      // // print("object :: $e");
      rethrow;
    }
  }

  Future<PendingStatus> fetchPendingstatusApi() async {
  try {
    final uri = Uri.parse(apiLinks.rekycpendingstatusURL);

    final res = await apiClient.post(
      uri,
      headers: defaultHeaders,
      body: jsonEncode({"clientId": prefs.clientId}),
    );
    return PendingStatus.fromJson(jsonDecode(res.body));
  } catch (e) {
    rethrow;
  }
}

 Future<String?> fetctfileidapi(String type) async {
  try {
    final uri = Uri.parse(
      type != "nominee"
          ? apiLinks.fetctfileidURL
          : apiLinks.fetctfileidURLnominee,
    );

    final res = await apiClient.post(
      uri,
      headers: defaultHeaders,
      body: jsonEncode({"client_id": prefs.clientId}),
    );

      final json = jsonDecode(res.body);
      switch (type) {
      case "email_change":
        return json["email_file_id"];
      case "mobile_change":
        return json["mobile_file_id"];
      case "address_change":
        return json["address_file_id"];
      case "bank_change":
        return json["bank_file_id"];
      case "mtf":
        return json["mtf_fileid"];
      case "nominee":
      final nomStat = json["nom_stat"];
  if (nomStat != null && nomStat is List && nomStat.isNotEmpty) {
    final fileId = nomStat[0]["file_id"];
    return fileId;
  }
      case "DDPI":
        return json["DDPI_fileid"];
      case "closure":
        return json["closure_fileid"];
      case "segment_change":
        return json["segment_file_id"];
      default:
        return null;
    }
  } catch (e) {
    return null;
  }
  return null;
}


  cancelPendingStatusApi(String type, String fileid) async {
  try {
    final String response;
    final uri = Uri.parse(apiLinks.cancelPendingesignURL);
    final res = await apiClient.post(uri, headers: defaultHeaders, body: jsonEncode({"client_id": prefs.clientId, "file_id": fileid, "type": type}));
    if(res.statusCode == 200){
     return response = "Cancel Success";
    }else{
      return response = "Cancel Failed";
    }
  } catch (e) {
    rethrow;
  }
}


  /// Calls /checkrekyc to determine whether a Re-KYC is currently in progress
  /// for the logged-in client. Returns the raw rekyc_status string ("Yes" / "No") or null on error.
  Future<String?> checkRekycStatusApi() async {
    try {
      final uri = Uri.parse(apiLinks.checkRekycURL);
      final res = await apiClient.post(
        uri,
        headers: funddefaultHeaders,
        body: jsonEncode({"client_code": prefs.clientId}),
      );
      final json = jsonDecode(res.body);
      return json['rekyc_status']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<DetailsChangeCurrentStatus> fetchMobEmailStatusApi() async {
    try {
      final uri = Uri.parse(apiLinks.detailschangecurrentstatusURL);
      final res = await apiClient.post(
        uri,
        headers: funddefaultHeaders,
        body: jsonEncode({"client_id": prefs.clientId}),
      );
      return DetailsChangeCurrentStatus.fromJson(jsonDecode(res.body));
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addSegmentApi({
    required List<String> newSegments,
    required List<String> existingSegments,
    required String dpCode,
    required String addingSegments,
    required String reActiveSegments,
    required String clientId,
    required bool equitySelected,
    required bool fnoSelected,
    required bool currencySelected,
    required bool commoditySelected,
    required String clientEmail,
    required String clientName,
    required String address,
    Uint8List? proofBytes,
    String? proofFileName,
    required String passwordRequired,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.addSegmentURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);

      request.fields['new_segments'] = jsonEncode(newSegments);
      request.fields['ext_segments'] = jsonEncode(existingSegments);
      request.fields['dp_code'] = dpCode;
      request.fields['adding_segments'] = addingSegments;
      request.fields['re_active_segments'] = reActiveSegments;
      request.fields['client_id'] = clientId;
      request.fields['nse_equity'] = equitySelected ? 'YES' : 'NO';
      request.fields['bse_equity'] = equitySelected ? 'YES' : 'NO';
      request.fields['nse_equity_der'] = fnoSelected ? 'YES' : 'NO';
      request.fields['bse_equity_der'] = fnoSelected ? 'YES' : 'NO';
      request.fields['nse_currency_der'] = currencySelected ? 'YES' : 'NO';
      request.fields['bse_currency_der'] = currencySelected ? 'YES' : 'NO';
      request.fields['nse_commodity_der'] = commoditySelected ? 'YES' : 'NO';
      request.fields['bse_commodity_der'] = commoditySelected ? 'YES' : 'NO';
      request.fields['mcx_commodity_der'] = commoditySelected ? 'YES' : 'NO';
      request.fields['icex_commodity_der'] = commoditySelected ? 'YES' : 'NO';
      request.fields['nse_mfss'] = 'NO';
      request.fields['bse_mfss'] = 'NO';
      request.fields['nse_slbm'] = 'NO';
      request.fields['client_email'] = clientEmail;
      request.fields['client_name'] = clientName;
      request.fields['address'] = address;
      request.fields['password_required'] = passwordRequired;
      request.fields['password'] = password;

      if (proofBytes != null && proofFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'proff',
          proofBytes,
          filename: proofFileName,
        ));
      } else {
        request.fields['proff'] = '';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> filedownloadApi({
    required String clientId,
    required String fileId,
    required String response,
    required String type,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.filedownloadURL);
      await apiClient.post(
        uri,
        headers: funddefaultHeaders,
        body: jsonEncode({
          'client_id': clientId,
          'file_id': fileId,
          'response': response,
          'type': type,
        }),
      );
    } catch (e) {
    }
  }

  mobileotpapifun(String newmo, clemail, oldmobilmo, fulldataprf) async {
//  String formattedData = jsonEncode(fulldataprf.toJson()); // Convert object to JSON
    // // print("Formatted Profile Data: $formattedData");

    // Now you can use []
    // // print("CLIENT_ID: ${fulldataprf.toJson()['CLIENT_ID']}");

    try {
      final uri = Uri.parse(apiLinks.mobotpreq);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "prev_mobile_no": oldmobilmo,
            "pres_mobile_no": newmo,
            "client_id": "${prefs.clientId}",
            "client_name": "${prefs.clientName}",
            "client_email": oldmobilmo
          }));

      final json = jsonDecode((res.body));
// startDigioEsign();
      // // print("otp email resp ==>${json['msg']}");
      // // print("------------------------------------------------------");
      // // print("testttt${fulldataprf}");

      esignfunstart();

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  mobileotpverify(String newmo, mbotp, fulldataprf) async {
    try {
      globalfulldata = fulldataprf;
      globalnewmob = newmo;
      final uri = Uri.parse(apiLinks.mobotpver);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "pres_mobile_no": newmo,
            "client_id": "${prefs.clientId}",
            "mobile_otp": mbotp,
            "prev_mobile_no": "${fulldataprf.toJson()['MOBILE_NO']}",
            "client_name": "${prefs.clientName}",
            "client_email": "${fulldataprf.toJson()['CLIENT_ID_MAIL']}",
            "dp_code": "${fulldataprf.toJson()['CLIENT_DP_CODE']}"
          }));

      final json = jsonDecode((res.body));

      // // print("otp email resp ==>${json['msg']}");
      // // print("${globalfulldata.toJson()['CLIENT_DP_CODE']}");

      if (json['msg'] == "otp valid") {
        mobilefilewrite();
      }

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  mobilefilewrite() async {
    try {
      DateTime nowUtc = DateTime.now().toUtc();

      // Manually format the date
      String formattedDateUtc = "${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}.${nowUtc.millisecond.toString().padLeft(3, '0')}Z"; // You can use milliseconds instead of microseconds for simplicity.

      // // print("Formatted UTC date: $formattedDateUtc");
      final uri = Uri.parse(apiLinks.filewritemob);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "pres_mobile_no": globalnewmob,
            "client_id": "${prefs.clientId}",
            "prev_mobile_no": "${globalfulldata.toJson()['MOBILE_NO']}",
            "client_name": "${prefs.clientName}",
            "client_email": "${globalfulldata.toJson()['CLIENT_ID_MAIL']}",
            "dp_code": "${globalfulldata.toJson()['CLIENT_DP_CODE']}",
            "date_time": formattedDateUtc
          }));
      final json = jsonDecode((res.body));

      // // print("filewriteep ==>${json}");

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  manaddbankapi(String newadd, String pincoderes, String dist, String state,
      String county, String profty, fulldataprf, String filepath) async {
    try {
      // // print(
      //     "123456er${newadd}, ${pincoderes}, ${dist}, ${state}, ${county}, ${profty}, ${filepath}");
      globalfulldata = fulldataprf;
      final uri = Uri.parse(apiLinks.adrchnURL);

      var request = http.MultipartRequest('POST', uri);

      // Adding headers
      request.headers.addAll(funddefaultHeaders);
      // // print("${fulldataprf.toJson()}");
      // Adding form data
      request.fields['proff'] = profty;
      request.fields['cur_address'] =
          '{"address":"$newadd","pincode":"$pincoderes","state":"$state","dist":"$dist","country":"$county"}';
      request.fields['ext_address'] =
          ("${fulldataprf.toJson()['CL_RESI_ADD1']}, ${fulldataprf.toJson()['CL_RESI_ADD2']}, ${fulldataprf.toJson()['CL_RESI_ADD3']}");
      request.fields['dp_code'] = "${fulldataprf.toJson()['CLIENT_DP_CODE']}";
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['client_name'] = "${prefs.clientName}";
      request.fields['adr_manual'] = 'manual';
      request.fields['aadhar_address'] = '';
      request.fields['code'] = '';
      request.fields['state'] = '';
      request.fields['client_email'] =
          "${fulldataprf.toJson()['CLIENT_ID_MAIL']}";

      // // print("proff: ${request.fields['proff']}");
      // // print("cur_address: ${request.fields['cur_address']}");
      // // print("ext_address: ${request.fields['ext_address']}");
      // // print("dp_code: ${request.fields['dp_code']}");
      // // print("client_id: ${request.fields['client_id']}");
      // // print("client_name: ${request.fields['client_name']}");
      // // print("adr_manual: ${request.fields['adr_manual']}");
      // // print("aadhar_address: ${request.fields['aadhar_address']}");
      // // print("code: ${request.fields['code']}");
      // // print("state: ${request.fields['state']}");
      // // print("client_email: ${request.fields['client_email']}");

      // Attaching the file
      request.files.add(await http.MultipartFile.fromPath('file', filepath));

      // Sending the request
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        // print("Response: $responseBody");
        // return responseBody['msg'];
      } else {
        // // print("Error: ${response.reasonPhrase}");
      }
    } catch (e) {
      // // print("Exception: $e");
    }
  }

  ledgerbalanceapi() async {
    try {
      final uri = Uri.parse(apiLinks.allledgerbalanceURL);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "clientid": "${prefs.clientId}",
          }));

      final json = jsonDecode(res.body);
      // print("djsonjson ==> ${json}");
      // print("ddpi balance ==> ${json['total']}");
      return json['total'];
      // int totalBalance;
      // if (json['total'] is int) {
      //   totalBalance = json['total']; // Directly use the int value
      // } else if (json['total'] is double) {
      //   totalBalance = json['total'].toInt(); // Convert double to int
      // } else {
      //   // Handle unexpected types (e.g., string or null)
      //   totalBalance = int.tryParse(json['total']?.toString() ?? '') ?? 0;
      // }

      // return totalBalance;
    } catch (e) {
      rethrow;
    }
  }

  finalddpisubmitapi(fulldataprf) async {
    // print("testing");
    // print("1111111111111111${fulldataprf.toJson()}");

    try {
      final uri = Uri.parse(apiLinks.ddpiURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "CLIENT_ID": "${prefs.clientId}",
            "CLIENT_NAME": "${prefs.clientName}",
            "MOBILE_NO": "${fulldataprf.toJson()['MOBILE_NO']}",
            "CLIENT_ID_MAIL": "${fulldataprf.toJson()['CLIENT_ID_MAIL']}",
            "CL_RESI_ADD3": "${fulldataprf.toJson()['CL_RESI_ADD1']}",
            "CLIENT_DP_CODE": "${fulldataprf.toJson()['CLIENT_DP_CODE']}",
            "PAN_NO": "${fulldataprf.toJson()['PAN_NO']}"
          }));

      final json = jsonDecode((res.body));

      // print("otp email resp ==>${json}");

      return json;
    } catch (e) {
      rethrow;
    }
  }

  mtfenabapipage(fulldataprf) async {
    // print("mtfff");
    // print("1111111111111111${fulldataprf.toJson()}");

    try {
      final uri = Uri.parse(apiLinks.mtfURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "client_name": "${prefs.clientName}",
            "client_email": "${fulldataprf.toJson()['CLIENT_ID_MAIL']}",
            "client_address": "${fulldataprf.toJson()['CL_RESI_ADD1']}",
            "dp_code": "${fulldataprf.toJson()['CLIENT_DP_CODE']}",
          }));

      final json = jsonDecode((res.body));

      // print("otp email resp ==>${json}");

      return json;
    } catch (e) {
      rethrow;
    }
  }

  incomeotesendapi(mobileno) async {
    // // print("mtfff");
    // // print("1111111111111111${fulldataprf.toJson()}");

    try {
      final uri = Uri.parse(apiLinks.incomeotpreqURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "client_name": "${prefs.clientName}",
            "mobile_number": mobileno,
          }));

      final json = jsonDecode((res.body));

      // print("otp email respincomeee ==>${json}");
      // print("otp email in1234567 ==>${json['msg']}");

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  incomeotpverfapi(otpno, fulldataprf, chipval, file, proftye) async {
    // // print("mtfff");
    // // print("1111111111111111${fulldataprf.toJson()}");
    globalfulldata = fulldataprf;
    try {
      final uri = Uri.parse(apiLinks.incomeotpverURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "mobile_otp": otpno,
            "mobile_number": "${globalfulldata.toJson()['MOBILE_NO']}",
          }));

      final json = jsonDecode((res.body));

      // Income update is now handled by the provider after OTP verification

      return json['msg'];
    } catch (e) {
      rethrow;
    }
  }

  incomeupdateaapi(
      fulldataprf, String chipval, String proftye,
      {List<int>? fileBytes, String? fileName}) async {
    try {
      globalfulldata = fulldataprf;
      final uri = Uri.parse(apiLinks.incomeURL);

      var request = http.MultipartRequest('POST', uri);

      // Adding headers
      request.headers.addAll(funddefaultHeaders);

      // Adding form data
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['client_email'] =
          "${fulldataprf.toJson()['CLIENT_ID_MAIL']}";
      request.fields['client_name'] = "${prefs.clientName}";
      request.fields['ext_income_range'] =
          "${fulldataprf.toJson()['ANNUAL_INCOME']}";
      request.fields['cur_income_range'] = chipval;
      request.fields['proff'] = chipval == "Above 25L" ? "YES" : "NO";
      request.fields['dp_code'] = "${fulldataprf.toJson()['CLIENT_DP_CODE']}";
      request.fields['proff_type'] = chipval == "Above 25L" ? proftye : "";
      request.fields['password'] = "";
      request.fields['password_reqiured'] = "";

      // Add file if 'Above 25L' and file bytes provided (web compatible)
      if (chipval == "Above 25L" && fileBytes != null && fileBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'proff_file',
          fileBytes,
          filename: fileName ?? 'proof.pdf',
        ));
      }

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if uploaded PDF is password protected
  pdfLockCheckApi({required List<int> fileBytes, required String fileName}) async {
    try {
      final uri = Uri.parse(apiLinks.pdfLockURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['checktype'] = "income";
      request.files.add(http.MultipartFile.fromBytes(
        'proff_file',
        fileBytes,
        filename: fileName,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Verify PDF password
  pdfPasswordCheckApi({
    required List<int> fileBytes,
    required String fileName,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.pdfPasswordCheckURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['password'] = password;
      request.fields['checktype'] = "income";
      request.files.add(http.MultipartFile.fromBytes(
        'proff_file',
        fileBytes,
        filename: fileName,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  ifsccodecheckapi(String ifsccode) async {
    // // print("djsonjson ==> ${ifsccode}");

    try {
      if (ifsccode.length > 9) {
        // print("Valid IFSC Code: $ifsccode");

        final uri = Uri.parse("https://ifsc.razorpay.com/$ifsccode");
        final res = await http.get(uri);

        if (res.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(res.body);
          globalfulldata = json;
          // print("@@@@@@@@@@@@${globalfulldata}");
          // print("11111111111${globalfulldata['MICR']}");

          if (json.containsKey('BANK') && json.containsKey('BRANCH')) {
            return "${json['BANK']} - ${json['BRANCH']}";
          } else {
            // print("Error: Invalid API response format");
            return "Invalid response";
          }
        } else {
          // print("Error: Invalid IFSC Code or API issue");
          return "Invalid IFSC Code";
        }
      } else {
        // print("Error: IFSC Code is too short");
        return "Invalid IFSC Code";
      }
    } catch (e) {
      rethrow;
    }
  }

  // IFSC lookup returning full data map
  Future<Map<String, dynamic>?> ifscLookupApi(String ifscCode) async {
    try {
      if (ifscCode.length < 11) return null;
      final uri = Uri.parse("https://ifsc.razorpay.com/$ifscCode");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> pincodeLookupApi(String pincode) async {
    try {
      if (pincode.length < 6) return null;
      final uri = Uri.parse("https://api.postalpincode.in/pincode/$pincode");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List &&
            data.isNotEmpty &&
            data[0]['PostOffice'] != null &&
            (data[0]['PostOffice'] as List).isNotEmpty) {
          return data[0]['PostOffice'][0] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> addressChangeApiWeb({
    required String newAddress,
    required String pincode,
    required String district,
    required String state,
    required String country,
    required String proofType,
    required dynamic clientData,
    List<int>? proofBytes,
    String? proofFileName,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.adrchnURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);

      request.fields['proff'] = proofType;
      request.fields['cur_address'] =
          '{"address":"$newAddress","pincode":"$pincode","state":"$state","dist":"$district","country":"$country"}';
      request.fields['ext_address'] =
          "${clientData.toJson()['CL_RESI_ADD1']}, ${clientData.toJson()['CL_RESI_ADD2']}, ${clientData.toJson()['CL_RESI_ADD3']}";
      request.fields['dp_code'] =
          "${clientData.toJson()['CLIENT_DP_CODE']}";
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['client_name'] = "${prefs.clientName}";
      request.fields['adr_manual'] = 'manual';
      request.fields['aadhar_address'] = '';
      request.fields['code'] = '';
      request.fields['state'] = state;
      request.fields['client_email'] =
          "${clientData.toJson()['CLIENT_ID_MAIL']}";

      if (proofBytes != null && proofFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          proofBytes,
          filename: proofFileName,
        ));
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Aadhaar/Digilocker address change API (adr_manual='aadhar')
  Future<Map<String, dynamic>?> addressChangeDigilockerApiWeb({
    required String code,
    required String state,
    required dynamic clientData,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.adrchnURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);

      request.fields['file'] = '';
      request.fields['proff'] = '';
      request.fields['cur_address'] = '';
      request.fields['ext_address'] =
          "${clientData.toJson()['CL_RESI_ADD1']} ${clientData.toJson()['CL_RESI_ADD2']} ${clientData.toJson()['CL_RESI_ADD3']}";
      request.fields['dp_code'] =
          "${clientData.toJson()['CLIENT_DP_CODE']}";
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['client_name'] = "${prefs.clientName}";
      request.fields['client_email'] =
          "${clientData.toJson()['CLIENT_ID_MAIL']}";
      request.fields['aadhar_address'] = '';
      request.fields['adr_manual'] = 'aadhar';
      request.fields['code'] = code;
      request.fields['state'] = state;

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOMINEE API
  // ═══════════════════════════════════════════════════════════════

  /// Submit nominee form - POST /nominee (multipart/form-data)
  Future<Map<String, dynamic>?> nomineeSubmitApi({
    required Map<String, String> fields,
    Map<String, ({String filename, Uint8List bytes})>? files,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.nomineeSubmitURL);
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);
      request.fields.addAll(fields);
      if (files != null) {
        for (final entry in files.entries) {
          request.files.add(http.MultipartFile.fromBytes(
            entry.key,
            entry.value.bytes,
            filename: entry.value.filename,
          ));
        }
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch nominee status - POST /nom_stat
  /// Returns full response including nom_stat array with app_status, file_id, session etc.
  Future<Map<String, dynamic>?> nomineeStatusApi() async {
    try {
      final uri = Uri.parse(apiLinks.fetctfileidURLnominee);
      final res = await apiClient.post(
        uri,
        headers: defaultHeaders,
        body: jsonEncode({"client_id": prefs.clientId}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Web-compatible bank API (add/edit/delete/set-primary)
  Future<Map<String, dynamic>?> addBankApiWeb({
    required String option, // add, modify, delete
    required String accountNo,
    required String bankName,
    required String ifsc,
    required String branch,
    required String bankAccountType,
    required String setDefault,
    required String micr,
    required String dpCode,
    required String mobile,
    required String clientEmail,
    required List<Map<String, String>> existingBanks,
    String? proffType,
    List<int>? proofBytes,
    String? proofFileName,
    String? passwordRequired,
    String? password,
    int count = 3,
  }) async {
    try {
      final isAdd = option == 'add';
      var queryParams = 'mob=$mobile'
          '&bankName=${Uri.encodeComponent(bankName)}'
          '&ifsc=$ifsc'
          '&accountNo=$accountNo';

      if (isAdd) {
        queryParams += '&proff_type=${Uri.encodeComponent(proffType ?? "")}';
      }

      queryParams += '&branch=${Uri.encodeComponent(branch)}'
          '&bank_account_type=${Uri.encodeComponent(bankAccountType)}'
          '&client_name=${Uri.encodeComponent(prefs.clientName ?? "")}'
          '&option=$option'
          '&client_id=${prefs.clientId}'
          '&set_defalut=${setDefault.toLowerCase()}'
          '&dp_code=$dpCode'
          '&micr=$micr'
          '&client_email=${Uri.encodeComponent(clientEmail)}'
          '&password_required=${passwordRequired ?? "NO"}'
          '&password=${password ?? ""}';
      if (isAdd) {
        queryParams += '&count=$count';
      }

      final uri = Uri.parse("${apiLinks.bankURL}?$queryParams");
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);
      request.fields['bank_exists'] = jsonEncode(existingBanks);

      if (proofBytes != null && proofBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'proff',
          proofBytes,
          filename: proofFileName ?? 'proof.pdf',
        ));
      } else {
        request.fields['proff'] = '';
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  addbankapi(String banacc, String bankifc, String filepath, String profftype,
      String setpri, String accty, fulldataprf, bankdata) async {
//         final file = File(filepath);
// if (await file.exists()) {
    // print('File exists!${filepath}');
// } else {
//   // print('File does not exist at $filepath');
// }

    if (bankdata is String) {
      List<Map<String, dynamic>> decodedBankData =
          List<Map<String, dynamic>>.from(jsonDecode(bankdata));
      List<Map<String, String>> formattedBankData = decodedBankData.map((item) {
        return {
          "acc_no": item["Bank_AcNo"] as String,
          "ifsc_no": item["IFSC_Code"] as String,
        };
      }).toList();
      try {
        final uri = Uri.parse(
            "${apiLinks.bankURL}?mob=${fulldataprf.toJson()['MOBILE_NO']}&bankName=${globalfulldata['BANK']}&ifsc=${globalfulldata['IFSC']}&proff_type=$profftype&branch=${globalfulldata['BRANCH']}&bank_account_type=$accty&client_name=${prefs.clientName}&option=add&client_id=${prefs.clientId}&set_default=no&dp_code=${fulldataprf.toJson()['CLIENT_DP_CODE']}&micr=${globalfulldata['MICR']}&client_email=${fulldataprf.toJson()['CLIENT_ID_MAIL']}&password_required=NO&Password=&count=3");
        var request = http.MultipartRequest('POST', uri);
        request.headers.addAll(funddefaultHeaders);
        request.fields['bank_exists'] = jsonEncode(formattedBankData);
        request.files.add(await http.MultipartFile.fromPath('proff', filepath));
        // print("1111111111${filepath}");
        if (filepath.isNotEmpty) {
          request.files
              .add(await http.MultipartFile.fromPath('proff_file', filepath));
        }
        var response = await request.send();
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          // print("Response: $responseBody");
        } else {
          // print("Error: ${response.reasonPhrase}");
        }
      } catch (e) {
        // print("Exception1111111: $e");
      }
    }
  }

  addfamilaccapi(String menid, String relation, String menpan, String mobilno,
      fulldataprf) async {
    try {
      final uri = Uri.parse(apiLinks.sendlinkrequestURL);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "clientid": "${prefs.clientId}",
            "memberid": menid,
            "pan": menpan,
            "mobile_no": mobilno,
            "clientname": "${prefs.clientName}",
            "relationship": relation
          }));
      // print({
      //   "clientid": "${prefs.clientId}",
      //   "memberid": menid,
      //   "pan": menpan,
      //   "mobile_no": mobilno,
      //   "clientname": "${prefs.clientName}",
      //   "relationship": relation
      // });
      final json = jsonDecode(res.body);
      // print(json['emsg']);

      return json['emsg'];
    } catch (e) {
      rethrow;
    }
  }

  closeacbalapi(String resaqon, fulldataprf) async {
    try {
      final uri = Uri.parse(apiLinks.checkclosureURL);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
          }));

      final json = jsonDecode(res.body);

      double balance = (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : 0.0;
      String msg1 = json['msg1'] ?? '';
      String msg2 = json['msg2'] ?? '';
      String stat = json['stat'] ?? '';
      String stage = '';

      if (balance > 0 && msg2.isEmpty) {
        stage = "Stage 1: Positive Balance";
      } else if (balance < 0 && msg2.isEmpty) {
        stage = "Stage 2: Negative Balance";
      } else if (balance > 0 && msg2 == "some holdings") {
        stage = "Stage 3: Positive Balance & Some Holdings";
      } else if (balance < 0 && msg2 == "some holdings") {
        stage = "Stage 4: Negative Balance & Some Holdings";
      } else if (balance == 0 && msg2 == "some holdings") {
        stage = "Stage 5: Zero Balance & Some Holdings";
      } else if (msg2 == "some holdings") {
        stage = "Stage 6: Some Holdings (Balance Unspecified)";
      } else {
        stage = "Unknown Stage";
      }

      // print("Stage: $stage");
      // print("Balance: $balance");
      // print("Response JSON: $json");

      return {
        "stage": stage,
        "balance": balance,
        "msg1": msg1,
        "msg2": msg2,
        "stat": stat,
      };

      // if (json['msg1'] == 'zero ledger balance' &&
      //     json['msg2'] == 'zero holdings' &&
      //     json['stat'] == 'Ok') {
      //   // print("condition satsfy");
      // } else {
      //   // print("condition not satsfy");
      //   holdingsapiceckapi();
      // }
      // // print("djsonjson ==> ${json}");
      // // // print("ddpi balance ==> ${json['total']}");
      // return json['total'];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> holdingsapiceckapi() async {
    try {
      final uri = Uri.parse(apiLinks.getholdingscheckURL);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "client_code": "${prefs.clientId}",
          }));

      final json = jsonDecode(res.body);
      final String stat = (json['stat'] ?? '').toString();
      final String holdings = stat == 'Ok'
          ? (json['holdings']?.toString() ?? '')
          : '';
      return {
        "stat": stat,
        "holdings": holdings,
        "raw": json,
      };
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> acccloserapi(String dpid, String boid, String filepath,
      String reason, fulldataprf, bankdata,
      {bool hasHoldings = false,
      Uint8List? fileBytes,
      String? fileName}) async {
    List<Map<String, dynamic>> decodedBankData =
        List<Map<String, dynamic>>.from(jsonDecode(bankdata));

    // Convert decodedBankData to string format
    String bankDataString = jsonEncode(decodedBankData);
    globalfulldata = fulldataprf;

    // Print all data as string
    // Debugging: Print values before assigning them to request fields
    // print("client_id: ${prefs.clientId}");
    // print("client_name: ${prefs.clientName}");
    // print("client_email: ${fulldataprf.toJson()['CLIENT_ID_MAIL']}");
    // print("dp_code: ${fulldataprf.toJson()['CLIENT_DP_CODE']}");
    // print("segments: $bankDataString");
    // print("reason: ${dpid == '' ? 'no' : 'yes'}");
    // print(
    // "address: ${fulldataprf.toJson()['CL_RESI_ADD1']},${fulldataprf.toJson()['CL_RESI_ADD2']},${fulldataprf.toJson()['CL_RESI_ADD3']}");
    // print("transfer_client_id: $dpid");
    // print("transfer_dp_id: $boid");
    try {
      globalfulldata = fulldataprf;
      final uri = Uri.parse(apiLinks.closureURL);

      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(funddefaultHeaders);
      request.fields['client_id'] = "${prefs.clientId}";
      request.fields['client_name'] = "${prefs.clientName}";
      request.fields['client_email'] =
          "${fulldataprf.toJson()['CLIENT_ID_MAIL']}";
      request.fields['dp_code'] = "${fulldataprf.toJson()['CLIENT_DP_CODE']}";
      request.fields['segments'] = bankDataString;
      request.fields['reason'] = reason;
      request.fields['transfer'] = hasHoldings ? 'yes' : 'no';

      request.fields['address'] =
          "${fulldataprf.toJson()['CL_RESI_ADD1']},${fulldataprf.toJson()['CL_RESI_ADD2']},${fulldataprf.toJson()['CL_RESI_ADD3']}";
      request.fields['transfer_client_id'] = dpid;
      request.fields['transfer_dp_id'] = boid;
      // request.fields['cmr_file'] = "";
//  request.files
//             .add(await http.MultipartFile.fromPath('cmr_file', filepath));
      if (fileBytes != null && fileBytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'cmr_file',
          fileBytes,
          filename: fileName ?? 'cmr_file.pdf',
        ));
      } else if (filepath.isNotEmpty) {
        request.files
            .add(await http.MultipartFile.fromPath('cmr_file', filepath));
      }

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Mobile OTP verify (no auto file_write) ───
  Future<String?> mobileOtpVerifyWebApi(String newMobile, String otp, dynamic clientData) async {
    try {
      final uri = Uri.parse(apiLinks.mobotpver);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "pres_mobile_no": newMobile,
            "client_id": "${prefs.clientId}",
            "mobile_otp": otp,
            "prev_mobile_no": "${clientData.toJson()['MOBILE_NO']}",
            "client_name": "${prefs.clientName}",
            "client_email": "${clientData.toJson()['CLIENT_ID_MAIL']}",
            "dp_code": "${clientData.toJson()['CLIENT_DP_CODE']}"
          }));
      final json = jsonDecode(res.body);
      return json['msg']?.toString();
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Email OTP verify (no auto file_write) ───
  Future<String?> emailOtpVerifyWebApi(String otp, String newEmail) async {
    try {
      final uri = Uri.parse(apiLinks.verifyOTPEmailURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "present_email": newEmail,
            "emailotp": otp
          }));
      final json = jsonDecode(res.body);
      return json['msg']?.toString();
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Mobile file write (callable separately) ───
  Future<Map<String, dynamic>?> mobileFileWriteWebApi(String newMobile, dynamic clientData) async {
    try {
      DateTime nowUtc = DateTime.now().toUtc();
      String formattedDateUtc =
          "${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}.${nowUtc.millisecond.toString().padLeft(3, '0')}Z";

      final uri = Uri.parse(apiLinks.filewritemob);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "pres_mobile_no": newMobile,
            "client_id": "${prefs.clientId}",
            "prev_mobile_no": "${clientData.toJson()['MOBILE_NO']}",
            "client_name": "${prefs.clientName}",
            "client_email": "${clientData.toJson()['CLIENT_ID_MAIL']}",
            "dp_code": "${clientData.toJson()['CLIENT_DP_CODE']}",
            "date_time": formattedDateUtc
          }));
      final json = jsonDecode(res.body);
      return json as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ─── Web: Email file write (callable separately) ───
  Future<Map<String, dynamic>?> emailFileWriteWebApi(String newEmail, String oldEmail, String dpCode) async {
    try {
      DateTime nowUtc = DateTime.now().toUtc();
      String formattedDateUtc =
          "${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}.${nowUtc.millisecond.toString().padLeft(3, '0')}Z";

      final uri = Uri.parse(apiLinks.filewriteemailURL);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "client_id": "${prefs.clientId}",
            "client_email": oldEmail,
            "dp_code": dpCode,
            "date_time": formattedDateUtc,
            "present_email": newEmail,
            "previous_email": oldEmail,
            "client_name": "${prefs.clientName}",
          }));
      final json = jsonDecode(res.body);
      return json as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ─── KRA Image Check ───
  Future<bool> kraImageCheckApi() async {
    try {
      final uri = Uri.parse('${apiLinks.checkingImgURL}/${prefs.clientId}');
      final res = await apiClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      final json = jsonDecode(res.body);
      return json['data'] == true;
    } catch (e) {
      return false;
    }
  }

  // ─── KRA Image Upload ───
  Future<String?> imgUploadApi({required List<int> imageBytes}) async {
    try {
      final uri = Uri.parse(apiLinks.imgUploadURL);
      var request = http.MultipartRequest('POST', uri);
      request.fields['client_id'] = "${prefs.clientId}";
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'photo.jpg',
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final json = jsonDecode(responseBody);
        return json['data']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

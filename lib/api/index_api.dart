import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart';

import '../locator/constant.dart';
import '../models/indices/all_index_model.dart';
import '../models/indices/index_list_model.dart';
import 'core/api_core.dart';

mixin IndexApi on ApiCore {
// Push notification

  Future<Response> getNotifyMsg() async {
    try {
      // Self-heal the FCM token if main.dart's getToken() hasn't resolved yet.
      // On web, getToken() is slower than mobile (depends on SW + permission +
      // Google FCM round-trip), so it can lose the race against login. By the
      // time addtoken fires post-login, FCM is ready — refetching here populates
      // the cached value so the backend gets a real token instead of "".
      if ((ConstantName.msgToken ?? '').isEmpty) {
        ConstantName.msgToken = await FirebaseMessaging.instance.getToken();
      }

      final uri = Uri.parse("https://besim.mynt.in/nlog/addtoken");
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body: jsonEncode({
            "token": ConstantName.msgToken,
            "clientid": prefs.clientId,
          }));

      //  print("Message - ${res.body}");

      return res;
    } catch (e) {
      rethrow;
    }
  }

// Get Index lists exchange wise from kambala

  Future<IndexListModel?> getIndexList(String exch) async {
    try {
      final uri = Uri.parse(apiLinks.marketIndex);

      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}","exch":"$exch" }&jKey=${prefs.clientSession}''');

      // log("Index List ===> ${res.body}");
      if (res.statusCode == 401) {
        // ref.read(userProvider).sessionLogout(context);
      } else {
        final resp = IndexListModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        return resp;
      }
    } catch (e) {
      // log(e.toString());
      rethrow;
    }
    return null;
  }

// get group of scrip LTP and more info



  Future<Response> getLTP(List ltpArgs) async {
    try {
      final uri = Uri.parse("https://asvr.mynt.in/bcast/GetLtp");
      final response = await apiClient.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"data": ltpArgs}));

     //   print("Top Indices Data ${response.body}");

      return response;
    } catch (e) {
     // print("Error LTP: " + e.toString());
      rethrow;
    }
  }

  Future<AllIndexModel> getAllIndex() async {
    try {
      final uri = Uri.parse(apiLinks.getAllIndx);
      final res = await apiClient.post(uri, headers: defaultHeaders);
      // print("All Indices Data ${res.body}");
      final json = jsonDecode(res.body);

      return AllIndexModel.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}

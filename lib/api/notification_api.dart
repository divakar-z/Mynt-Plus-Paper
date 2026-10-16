import '../models/notification_model/broker_message_model.dart';
import '../models/notification_model/exchange_message_model.dart';
import '../models/notification_model/exchange_status_model.dart';
import '../models/notification_model/information_message_model.dart';
import 'core/api_core.dart';

mixin NotificationApi on ApiCore {
  //  Get exch message from kambala

  Future<List<ExchangeMessageModel>> getexchmsg() async {
    try {
      final uri = Uri.parse(apiLinks.exchMsg);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

      //log("Exchange message=>${res.body} ");
      final List<ExchangeMessageModel> data = [];
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        // Check if response is an error (Map with stat field) or success (List of items)
        if (json is Map && json['stat']?.toString() == 'Not_Ok') {
          final ExchangeMessageModel ord =
              ExchangeMessageModel.fromJson(json as Map<String, dynamic>);
          return [ord];
        } else if (json is List) {
          for (final item in json) {
            data.add(
                ExchangeMessageModel.fromJson(item as Map<String, dynamic>));
          }
        }
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

// Get exch status  from kambala

  Future<List<ExchangeStatusModel>> getexchstatus() async {
    try {
      final uri = Uri.parse(apiLinks.exchStatus);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

      final List<ExchangeStatusModel> data = [];
      //log("Exchange Status=>${res.body} ");
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        // Check if response is an error (Map with stat field) or success (List of items)
        if (json is Map && json['stat']?.toString() == 'Not_Ok') {
          final ExchangeStatusModel ord =
              ExchangeStatusModel.fromJson(json as Map<String, dynamic>);
          return [ord];
        } else if (json is List) {
          for (final item in json) {
            data.add(
                ExchangeStatusModel.fromJson(item as Map<String, dynamic>));
          }
        }
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

// Get Broker Message from kambala

  Future<List<BrokerMessage>> getbrokermsg() async {
    try {
      final uri = Uri.parse(apiLinks.brokermsg);
      final res = await apiClient.post(uri,
          headers: defaultHeaders,
          body:
              '''jData={"uid":"${prefs.clientId}"}&jKey=${prefs.clientSession}''');

      final List<BrokerMessage> data = [];
      // log("broker msg=>${res.body} ");
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        // Check if response is an error (Map with stat field) or success (List of items)
        if (json is Map && json['stat']?.toString() == 'Not_Ok') {
          final BrokerMessage ord =
              BrokerMessage.fromJson(json as Map<String, dynamic>);
          return [ord];
        } else if (json is List) {
          for (final item in json) {
            data.add(BrokerMessage.fromJson(item as Map<String, dynamic>));
          }
        }
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

// Get Information Messages from nlog
  Future<List<InformationMessageModel>> getInformationMessages() async {
    try {
      final uri = Uri.parse('https://besim.mynt.in/nlog/get_messages');
      final res = await apiClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userid": prefs.clientId}),
      );

      final List<InformationMessageModel> data = [];
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json is List) {
          for (final item in json) {
            data.add(InformationMessageModel.fromJson(item as Map<String, dynamic>));
          }
        }
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }
}

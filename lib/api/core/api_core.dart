import 'dart:async';
import 'package:http/http.dart'
    show BaseClient, BaseRequest, Client, StreamedResponse;

import '../../locator/locator.dart';
import '../../locator/preference.dart';
import 'api_link.dart';
import '../paper/paper_network_guard.dart';
// import '../../global/preferences.dart';
// import '../../locator/locator.dart';
// import 'api_link.dart';
export 'dart:convert';

class _ConditionalTimeoutClient extends BaseClient {
  final Client _inner;
  final Duration _timeout;

  final List<String> _timeoutBaseUrls = const [
    // 'https://go.mynt.in/NorenWClient',
    // 'https://be.mynt.in/',
    // 'https://ws.mynt.in/'
  ];

  _ConditionalTimeoutClient(this._inner,
      {Duration timeout = const Duration(seconds: 10)})
      : _timeout = timeout;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Paper trading: never let an order / money request leave the device.
    if (isPaperTrading && PaperNetworkGuard.isBlocked(request.url)) {
      return PaperNetworkGuard.blockedResponse(request);
    }

    final urlString = request.url.toString();

    final bool shouldApplyTimeout =
        _timeoutBaseUrls.any((baseUrl) => urlString.startsWith(baseUrl));

    if (shouldApplyTimeout) {
      return _inner.send(request).timeout(_timeout);
    } else {
      return _inner.send(request);
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

mixin ApiCore {
  
  // http request
  final _apiClient = Client();
  // get local storage data
  final prefs = locator<Preferences>();
  // get local variable datas from class
  final apiLinks = locator<ApiLinks>();

  Client get apiClient => _ConditionalTimeoutClient(_apiClient);

  Map<String, String> get defaultHeaders {
    return {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
      'Accept': 'application/json',
    };
  }

  Map<String, String> get funddefaultHeaders {
    return {
      'Authorization': "${prefs.token}",
      'clientid': "${prefs.clientId}",
      'Content-Type': 'application/json'
    };
  }

  
  Map<String, String> get testingrameshheader {
    return {
      'Authorization': "ce41ee8b908c1a297cec6f5c061821c2490b5ee0e2a1fb81a305501e12d01123",
      'clientid': "TN1V2",
      'Content-Type': 'application/json'
    };
  }

  Map<String, String> get razorpaytHeaders {
    return {
      'Authorization': "${prefs.token}",
      'clientid': "${prefs.clientId}",
    };
  }

  void dispose() {
    _apiClient.close();
  }
}

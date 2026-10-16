import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';
import 'package:mynt_plus/models/insta_options/option_chain/expiry_option.dart';
import 'package:mynt_plus/models/insta_options/option_chain/option_chain_data.dart';

/// HTTP client for the date-based **Option Chain** backend (Screen 2):
/// - `GET /api/v1/dates` → global trading-day calendar (shared by all screens).
/// - `GET /api/v1/option-chain/expiries?underlying=&date=` → expiries (near first).
/// - `GET /api/v1/option-chain?underlying=&date=&expiry=` → the full chain.
///
/// Same zdf backend + [DashboardApiException] as [DashboardApi]; omitting
/// `date` = latest day, omitting `expiry` = the near expiry.
class OptionChainApi {
  final DashboardApiConfig _config = locator<DashboardApiConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  OptionChainApi({http.Client? client}) : _http = client ?? http.Client();

  /// `GET /api/v1/dates` — the global trading-day calendar (shared by every
  /// date-based screen; the old `/api/v1/option-chain/dates` was removed).
  Future<DatesResponse> getDates() async {
    final body = await _getUrl(_config.datesUrl);
    return DatesResponse.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/v1/option-chain/expiries?underlying=&date=` (omit [date] = latest).
  Future<List<ExpiryOption>> getExpiries({
    required String underlying,
    String? date,
    bool live = false,
  }) async {
    final body = await _get('/expiries', query: {
      'underlying': underlying,
      if (date != null) 'date': date,
      if (live) 'live': 'true',
    });
    final list = body as List<dynamic>? ?? const [];
    return list
        .map((e) => ExpiryOption.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /api/v1/option-chain?underlying=&date=&expiry=`
  /// (omit [date] = latest, omit [expiry] = near).
  Future<OptionChainData> getChain({
    required String underlying,
    String? date,
    String? expiry,
    bool live = false,
  }) async {
    final body = await _get('', query: {
      'underlying': underlying,
      if (date != null) 'date': date,
      if (expiry != null) 'expiry': expiry,
      if (live) 'live': 'true',
    });
    return OptionChainData.fromJson(body as Map<String, dynamic>);
  }

  // -------- internal helpers --------

  Future<dynamic> _get(String path, {Map<String, String>? query}) =>
      _getUrl('${_config.optionChainBase}$path', query: query);

  /// GET an absolute URL (used for both the section base and the global
  /// `/api/v1/dates` calendar, which sits outside the option-chain prefix).
  Future<dynamic> _getUrl(String url, {Map<String, String>? query}) async {
    final uri = Uri.parse(url).replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(_timeout);
    } catch (e) {
      throw DashboardApiException('Network error: $e');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) {
      String message = 'Backend error (status ${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic>) {
          message = (body['detail'] ?? body['message'] ?? message).toString();
        }
      } on FormatException {
        // Non-JSON error body — keep the default message.
      }
      throw DashboardApiException(message, statusCode: res.statusCode);
    }
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw DashboardApiException(
        'Malformed JSON response',
        statusCode: res.statusCode,
      );
    }
  }
}

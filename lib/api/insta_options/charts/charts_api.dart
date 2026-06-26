import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_by_strike.dart';
import 'package:mynt_plus/models/insta_options/charts/oi_timeline.dart';
import 'package:mynt_plus/models/insta_options/charts/pcr_timeline.dart';

/// HTTP client for the date-based **OI chart** endpoints (Screens: OI
/// Statistics / PCR Ratio / Trending OI), all under `<origin>/api/v1/charts`:
/// - `GET /oi-by-strike?underlying=&date=&expiry=`
/// - `GET /pcr-timeline?underlying=&date=&expiry=&interval=`
/// - `GET /oi-timeline?underlying=&date=&expiry=&interval=&strikes=`
///
/// Omitting `date` = latest day, `expiry` = near. Same zdf backend +
/// [DashboardApiException] as the other date-based clients.
class ChartsApi {
  final DashboardApiConfig _config = locator<DashboardApiConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  ChartsApi({http.Client? client}) : _http = client ?? http.Client();

  Future<OiByStrike> getOiByStrike({
    required String underlying,
    String? date,
    String? expiry,
  }) async {
    final body = await _getUrl('${_config.chartsBase}/oi-by-strike', query: {
      'underlying': underlying,
      if (date != null) 'date': date,
      if (expiry != null) 'expiry': expiry,
    });
    return OiByStrike.fromJson(body as Map<String, dynamic>);
  }

  Future<PcrTimeline> getPcrTimeline({
    required String underlying,
    String? date,
    String? expiry,
    String interval = '5m',
  }) async {
    final body = await _getUrl('${_config.chartsBase}/pcr-timeline', query: {
      'underlying': underlying,
      if (date != null) 'date': date,
      if (expiry != null) 'expiry': expiry,
      'interval': interval,
    });
    return PcrTimeline.fromJson(body as Map<String, dynamic>);
  }

  Future<OiTimeline> getOiTimeline({
    required String underlying,
    String? date,
    String? expiry,
    String interval = '5m',
    List<double>? strikes,
  }) async {
    final body = await _getUrl('${_config.chartsBase}/oi-timeline', query: {
      'underlying': underlying,
      if (date != null) 'date': date,
      if (expiry != null) 'expiry': expiry,
      'interval': interval,
      if (strikes != null && strikes.isNotEmpty)
        'strikes': strikes.map(_fmtStrike).join(','),
    });
    return OiTimeline.fromJson(body as Map<String, dynamic>);
  }

  /// `24000.0` → `"24000"`, `24050.5` → `"24050.5"`.
  static String _fmtStrike(double s) =>
      s == s.roundToDouble() ? s.toInt().toString() : s.toString();

  // -------- internal helpers --------

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

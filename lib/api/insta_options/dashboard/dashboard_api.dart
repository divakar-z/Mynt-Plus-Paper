import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dashboard_data.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';

/// Typed failure from the F&O Dashboard backend.
class DashboardApiException implements Exception {
  final String message;
  final int? statusCode;

  DashboardApiException(this.message, {this.statusCode});

  @override
  String toString() => 'DashboardApiException($statusCode): $message';
}

/// HTTP client for the date-based F&O Dashboard backend.
///
/// Endpoints (INSTAOPTIONS dashboard v2):
/// - `GET /api/v1/dates` → global trading-day calendar (shared by all screens).
/// - `GET /api/v1/dashboard?date=YYYY-MM-DD` → the whole dashboard for a day
///   (omit `date` = latest).
///
/// Separate from [InstaOptionsApi] — serves only the Markets Dashboard.
class DashboardApi {
  final DashboardApiConfig _config = locator<DashboardApiConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 15);

  DashboardApi({http.Client? client}) : _http = client ?? http.Client();

  /// `GET /api/v1/dates` — the global trading-day calendar (shared by every
  /// date-based screen; the old `/api/v1/dashboard/dates` was removed).
  Future<DatesResponse> getDates() async {
    final body = await _getUrl(_config.datesUrl);
    return DatesResponse.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/v1/dashboard?date=...` (omit [date] for the latest day). Pass
  /// [live] to request today's intraday snapshot (`?live=true`, no `date`).
  Future<DashboardData> getDashboard({String? date, bool live = false}) async {
    final body = await _get('', query: {
      if (date != null) 'date': date,
      if (live) 'live': 'true',
    });
    return DashboardData.fromJson(body as Map<String, dynamic>);
  }

  // -------- internal helpers --------

  Future<dynamic> _get(String path, {Map<String, String>? query}) =>
      _getUrl('${_config.dashboardBase}$path', query: query);

  /// GET an absolute URL (used for both the section base and the global
  /// `/api/v1/dates` calendar, which sits outside the dashboard prefix).
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

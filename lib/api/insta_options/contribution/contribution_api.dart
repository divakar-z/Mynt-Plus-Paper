import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/contribution/index_contribution.dart';
import 'package:mynt_plus/models/insta_options/dashboard/dates_response.dart';

/// HTTP client for the date-based **Index Contribution** backend (Screen 3):
/// - `GET /api/v1/dates` → global trading-day calendar (shared by all screens).
/// - `GET /api/v1/contribution?index=&date=` → the whole screen for one index +
///   day (omit `date` = latest day).
///
/// Same zdf backend + [DashboardApiException] as the dashboard / chain clients.
class ContributionApi {
  final DashboardApiConfig _config = locator<DashboardApiConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  ContributionApi({http.Client? client}) : _http = client ?? http.Client();

  /// `GET /api/v1/dates` — the global trading-day calendar.
  Future<DatesResponse> getDates() async {
    final body = await _getUrl(_config.datesUrl);
    return DatesResponse.fromJson(body as Map<String, dynamic>);
  }

  /// `GET /api/v1/contribution?index=&date=` (omit [date] for the latest day).
  Future<IndexContribution> getContribution({
    required String index,
    String? date,
  }) async {
    final body = await _getUrl(_config.contributionBase, query: {
      'index': index,
      if (date != null) 'date': date,
    });
    return IndexContribution.fromJson(body as Map<String, dynamic>);
  }

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

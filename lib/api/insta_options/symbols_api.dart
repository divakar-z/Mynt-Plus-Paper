import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api.dart'
    show DashboardApiException;
import 'package:mynt_plus/api/insta_options/dashboard/dashboard_api_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/instrument_symbol.dart';

/// Client for the global `GET /api/v1/symbols` list — the full F&O underlying
/// universe (indices + stocks). Shared by any screen that needs the underlying
/// set (e.g. the Option Chain underlying picker). Same backend as the date-based
/// dashboard, so it reuses [DashboardApiConfig] + [DashboardApiException].
class SymbolsApi {
  final DashboardApiConfig _config = locator<DashboardApiConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 15);

  SymbolsApi({http.Client? client}) : _http = client ?? http.Client();

  /// `GET /api/v1/symbols` → `{count, symbols: [...]}`.
  Future<List<InstrumentSymbol>> getSymbols() async {
    final uri = Uri.parse(_config.symbolsUrl);
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(_timeout);
    } catch (e) {
      throw DashboardApiException('Network error: $e');
    }
    final body = _decode(res);
    final list = (body is Map<String, dynamic> ? body['symbols'] : body)
            as List<dynamic>? ??
        const [];
    return list
        .map((e) => InstrumentSymbol.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) {
      throw DashboardApiException(
        'Backend error (status ${res.statusCode})',
        statusCode: res.statusCode,
      );
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

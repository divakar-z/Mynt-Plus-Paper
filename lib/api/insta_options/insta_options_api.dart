import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/insta_options_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/buildup_row.dart';
import 'package:mynt_plus/models/insta_options/buildup_symbol.dart';
import 'package:mynt_plus/models/insta_options/chain_row.dart';
import 'package:mynt_plus/models/insta_options/contributor_row.dart';
import 'package:mynt_plus/models/insta_options/expiries_response.dart';
import 'package:mynt_plus/models/insta_options/health_status.dart';
import 'package:mynt_plus/models/insta_options/market_snapshot.dart';
import 'package:mynt_plus/models/insta_options/oi_aggregate.dart';
import 'package:mynt_plus/models/insta_options/oi_timeseries_point.dart';
import 'package:mynt_plus/models/insta_options/pcr_point.dart';
import 'package:mynt_plus/models/insta_options/spot_timeseries_point.dart';
import 'package:mynt_plus/models/insta_options/symbols_response.dart';

/// Typed exception for OI Data backend failures.
class InstaOptionsApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? detail;
  final int? statusCode;

  InstaOptionsApiException({
    required this.code,
    required this.message,
    this.detail,
    this.statusCode,
  });

  @override
  String toString() =>
      'InstaOptionsApiException($code, $statusCode): $message';
}

/// HTTP client for the OI Data analytics backend.
///
/// One method per endpoint in INSTAOPTIONS_FEATURE_README.md §8. Phase 2 adds
/// `getSymbols` / `getExpiries` / `getSpot` / `getAnalyticsChain`. Remaining
/// endpoints land in later phases as their screens need them.
class InstaOptionsApi {
  final InstaOptionsConfig _config = locator<InstaOptionsConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 10);

  InstaOptionsApi({http.Client? client}) : _http = client ?? http.Client();

  // -------- §8.24 GET /health --------
  Future<InstaOptionsHealth> getHealth() async {
    final body = await _get(path: '/health');
    return InstaOptionsHealth.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.1 GET /symbols --------
  Future<SymbolsResponse> getSymbols({required String exchange}) async {
    final body = await _get(path: '/symbols', query: {'exchange': exchange});
    return SymbolsResponse.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.2 GET /expiries --------
  Future<ExpiriesResponse> getExpiries({
    required String exchange,
    required String symbol,
  }) async {
    final body = await _get(
      path: '/expiries',
      query: {'exchange': exchange, 'symbol': symbol},
    );
    return ExpiriesResponse.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.3 GET /spot --------
  Future<double> getSpot({
    required String exchange,
    required String symbol,
  }) async {
    final body = await _get(
      path: '/spot',
      query: {'exchange': exchange, 'symbol': symbol},
    );
    final map = body as Map<String, dynamic>;
    return (map['spot'] as num?)?.toDouble() ?? 0;
  }

  // -------- §8.4 GET /spot/timeseries --------
  Future<List<SpotTimeseriesPoint>> getSpotTimeseries({
    required String exchange,
    required String symbol,
    String? date,
  }) async {
    final body = await _get(
      path: '/spot/timeseries',
      query: {
        'exchange': exchange,
        'symbol': symbol,
        if (date != null) 'date': date,
      },
    );
    final map = body as Map<String, dynamic>;
    final bars = map['bars'] as List<dynamic>? ?? const [];
    return bars
        .map((e) => SpotTimeseriesPoint.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- §8.13 GET /buildup/symbols --------
  Future<BuildupSymbolsResponse> getBuildupSymbols({
    required String exchange,
  }) async {
    final body = await _get(
      path: '/buildup/symbols',
      query: {'exchange': exchange},
    );
    return BuildupSymbolsResponse.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.15 GET /market/snapshot --------
  Future<MarketSnapshot> getMarketSnapshot() async {
    final body = await _get(path: '/market/snapshot');
    return MarketSnapshot.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.16 GET /contributors/{index} --------
  Future<List<ContributorRow>> getContributors({required String index}) async {
    final body = await _get(path: '/contributors/$index');
    final list = body as List<dynamic>;
    return list
        .map((e) => ContributorRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- §8.17 GET /analytics/chain --------
  Future<List<ChainRow>> getAnalyticsChain({
    required String exchange,
    required String symbol,
    required String expiry,
  }) async {
    final body = await _get(
      path: '/analytics/chain',
      query: {'exchange': exchange, 'symbol': symbol, 'expiry': expiry},
    );
    final list = body as List<dynamic>;
    return list
        .map((e) => ChainRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- §8.9 GET /oi/timeseries --------
  Future<List<OiTimeseriesPoint>> getOiTimeseries({
    required String exchange,
    required String symbol,
    required String expiry,
    required String optionType,
    double? strike,
    String? date,
  }) async {
    final body = await _get(
      path: '/oi/timeseries',
      query: {
        'exchange': exchange,
        'symbol': symbol,
        'expiry': expiry,
        'option_type': optionType,
        if (strike != null && optionType != 'FUT')
          'strike': strike.toStringAsFixed(0),
        if (date != null) 'date': date,
      },
    );
    final list = body as List<dynamic>;
    return list
        .map((e) => OiTimeseriesPoint.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- §8.10 GET /oi/aggregate --------
  Future<OiAggregate> getOiAggregate({
    required String exchange,
    required String symbol,
    required String expiry,
  }) async {
    final body = await _get(
      path: '/oi/aggregate',
      query: {'exchange': exchange, 'symbol': symbol, 'expiry': expiry},
    );
    return OiAggregate.fromJson(body as Map<String, dynamic>);
  }

  // -------- §8.11 GET /oi/pcr/timeseries --------
  Future<List<PcrPoint>> getPcrTimeseries({
    required String exchange,
    required String symbol,
    required String expiry,
    String? date,
  }) async {
    final body = await _get(
      path: '/oi/pcr/timeseries',
      query: {
        'exchange': exchange,
        'symbol': symbol,
        'expiry': expiry,
        if (date != null) 'date': date,
      },
    );
    final list = body as List<dynamic>;
    return list
        .map((e) => PcrPoint.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- §8.12 GET /oi/buildup --------
  Future<List<BuildupRow>> getBuildup({
    required String exchange,
    required String symbol,
    required String expiry,
  }) async {
    final body = await _get(
      path: '/oi/buildup',
      query: {'exchange': exchange, 'symbol': symbol, 'expiry': expiry},
    );
    final list = body as List<dynamic>;
    return list
        .map((e) => BuildupRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // -------- internal helpers --------

  Future<dynamic> _get({
    required String path,
    Map<String, String>? query,
  }) async {
    final base = await _config.httpBaseUrl();
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final res = await _http.get(uri).timeout(_timeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final err = body['error'] as Map<String, dynamic>?;
        throw InstaOptionsApiException(
          code: err?['code'] as String? ?? 'INTERNAL',
          message: err?['message'] as String? ?? 'Backend error',
          detail: err?['detail'] as Map<String, dynamic>?,
          statusCode: res.statusCode,
        );
      } on FormatException {
        throw InstaOptionsApiException(
          code: 'INTERNAL',
          message: 'Malformed error response (status ${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
    }
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw InstaOptionsApiException(
        code: 'INTERNAL',
        message: 'Malformed JSON response',
        statusCode: res.statusCode,
      );
    }
  }
}

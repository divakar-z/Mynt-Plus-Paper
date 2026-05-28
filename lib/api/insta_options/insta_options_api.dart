import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/insta_options/insta_options_config.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/insta_options/health_status.dart';

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
/// Phase 1 ships a minimal surface (`getHealth()`) so the shell can render a
/// backend-reachability indicator. Later phases (Option Chain, etc.) extend
/// this class with the remaining endpoints in INSTAOPTIONS_FEATURE_README.md §8.
class InstaOptionsApi {
  final InstaOptionsConfig _config = locator<InstaOptionsConfig>();
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 5);

  InstaOptionsApi({http.Client? client}) : _http = client ?? http.Client();

  Future<InstaOptionsHealth> getHealth() async {
    final base = await _config.httpBaseUrl();
    final uri = Uri.parse('$base/health');
    final res = await _http.get(uri).timeout(_timeout);
    final body = _decode(res);
    return InstaOptionsHealth.fromJson(body);
  }

  Map<String, dynamic> _decode(http.Response res) {
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
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw InstaOptionsApiException(
        code: 'INTERNAL',
        message: 'Malformed JSON response',
        statusCode: res.statusCode,
      );
    }
  }
}

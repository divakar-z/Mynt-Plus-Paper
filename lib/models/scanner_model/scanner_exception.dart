/// Exception thrown by [StockScannerApi] methods on non-2xx responses or
/// network failures. Carries a user-presentable [message] plus the original
/// HTTP [statusCode] and parsed [errorCode] from the backend's
/// `{error, message, detail}` envelope.
class StockScannerException implements Exception {
  /// HTTP status code (0 if the request never reached the server).
  final int statusCode;

  /// The `error` field from the backend envelope (e.g. `"validation_error"`).
  /// Empty when the response was not a JSON envelope.
  final String errorCode;

  /// User-presentable message — already mapped by [StockScannerException.fromResponse].
  final String message;

  /// The original `detail` map from the backend, if any. Useful for debugging.
  final Map<String, dynamic>? detail;

  StockScannerException({
    required this.statusCode,
    required this.message,
    this.errorCode = '',
    this.detail,
  });

  /// Build a user-facing exception from an HTTP response + parsed body.
  factory StockScannerException.fromResponse({
    required int statusCode,
    required String backendMessage,
    String errorCode = '',
    Map<String, dynamic>? detail,
  }) {
    final mapped = _mapMessage(statusCode, backendMessage);
    return StockScannerException(
      statusCode: statusCode,
      errorCode: errorCode,
      message: mapped,
      detail: detail,
    );
  }

  /// Network-level failure (DNS / connection refused / timeout).
  factory StockScannerException.network(Object cause) {
    return StockScannerException(
      statusCode: 0,
      message: 'Could not reach StockScanner — check your connection.',
      detail: {'cause': cause.toString()},
    );
  }

  static String _mapMessage(int status, String backend) {
    switch (status) {
      case 401:
        return 'Authentication required — please reload the app.';
      case 404:
        return backend.isEmpty ? 'Not found.' : 'Not found — $backend';
      case 422:
        return backend.isEmpty ? 'Invalid input.' : 'Invalid input — $backend';
      case 429:
        return 'Rate limit exceeded — try again in a few seconds.';
      default:
        if (status >= 500) return 'Backend error — please retry.';
        return backend.isEmpty ? 'Request failed (HTTP $status).' : backend;
    }
  }

  @override
  String toString() => 'StockScannerException($statusCode, $errorCode): $message';
}

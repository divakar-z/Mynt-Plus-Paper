/// Thrown by `JournalNotesApi` on genuine failures.
///
/// Not every non-2xx from these routes is a failure. `404 NOTE_NOT_FOUND` is the
/// ordinary "no note written yet" state, `409 TAG_EXISTS` is the create-or-attach
/// path, and `409 TAG_IN_USE` is a confirm prompt. Those are returned as domain
/// outcomes by the API methods and never reach here.
class JournalNotesException implements Exception {
  /// HTTP status code (0 if the request never reached the server).
  final int statusCode;

  /// The `code` field from the failure envelope, e.g. `BAD_DATE`.
  ///
  /// This is the stable contract — branch on it. Never branch on [message],
  /// which is prose and will change. Empty when the body was not the expected
  /// envelope (a proxy error page, say).
  final String code;

  /// User-presentable message.
  final String message;

  /// The `data` object some failures carry, e.g. `TAG_EXISTS` returns the
  /// existing tag and `TAG_IN_USE` returns the note count.
  final Map<String, dynamic>? data;

  JournalNotesException({
    required this.statusCode,
    required this.message,
    this.code = '',
    this.data,
  });

  factory JournalNotesException.fromResponse({
    required int statusCode,
    required String backendMessage,
    String code = '',
    Map<String, dynamic>? data,
  }) {
    return JournalNotesException(
      statusCode: statusCode,
      code: code,
      message: _mapMessage(statusCode, code, backendMessage),
      data: data,
    );
  }

  /// Network-level failure (DNS / connection refused / timeout).
  ///
  /// On web this is also what a blocked CORS preflight looks like — the browser
  /// fails the request before any status reaches Dart, so it is indistinguishable
  /// from the server being down.
  factory JournalNotesException.network(Object cause) {
    return JournalNotesException(
      statusCode: 0,
      message: 'Could not reach the journal service — check your connection.',
      data: {'cause': cause.toString()},
    );
  }

  /// The session is gone and the user must re-authenticate.
  ///
  /// Only ever true for 401. Notably NOT true for 503 [isRetriable], where the
  /// auth service is merely unreachable and the session may well be fine.
  bool get isAuthFailure => statusCode == 401;

  /// Worth retrying as-is: the auth service was unreachable, not rejecting.
  /// Do not log the user out on this.
  bool get isRetriable => statusCode == 503 || code == 'AUTH_UNAVAILABLE';

  static String _mapMessage(int status, String code, String backend) {
    switch (status) {
      case 401:
        return 'Your session has expired — please log in again.';
      case 413:
        return 'That file is over the 5 MB limit.';
      case 415:
        return 'Only JPEG, PNG and PDF files are supported.';
      case 503:
        return 'The service is temporarily unavailable — please try again.';
      default:
        if (status >= 500) return 'Something went wrong — please try again.';
        // 400s here are client bugs or bad input; the backend `msg` is specific
        // and safe to surface.
        if (backend.isNotEmpty) return backend;
        return code.isEmpty
            ? 'Request failed (HTTP $status).'
            : 'Request failed ($code).';
    }
  }

  @override
  String toString() => 'JournalNotesException($statusCode, $code): $message';
}

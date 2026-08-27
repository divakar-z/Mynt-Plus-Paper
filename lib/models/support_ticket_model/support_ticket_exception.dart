/// Thrown by `SupportClientApi` when a call to the client support API fails.
///
/// The API answers `{"error": {"code": "...", "message": "..."}}`. [code] is the
/// stable contract — branch on it, never on [message], which is prose and will
/// be reworded. [statusCode] is kept for the cases where the body is not the
/// envelope at all.
class SupportTicketException implements Exception {
  SupportTicketException({
    required this.statusCode,
    required this.message,
    this.code = '',
    this.fields = const {},
  });

  /// HTTP status (0 if the request never reached the server).
  final int statusCode;

  /// The API's `error.code` slug, e.g. `validation`, `rate_limited`.
  ///
  /// Empty when the response was not the JSON envelope — see
  /// [SupportTicketException.malformed].
  final String code;

  /// User-presentable message.
  final String message;

  /// On a `validation` failure, which fields were rejected, keyed by field
  /// name. Often present but **not guaranteed** — some failure paths return a
  /// bare message, so callers must cope with this being empty on a 422.
  final Map<String, String> fields;

  factory SupportTicketException.fromResponse({
    required int statusCode,
    required String code,
    required String backendMessage,
    Map<String, String> fields = const {},
  }) {
    return SupportTicketException(
      statusCode: statusCode,
      code: code,
      message: _mapMessage(statusCode, code, backendMessage),
      fields: fields,
    );
  }

  /// Network-level failure (DNS, connection refused, timeout).
  ///
  /// On web a blocked CORS preflight also lands here — the browser fails the
  /// request before any status reaches Dart, so it cannot be told apart from
  /// the service being down.
  factory SupportTicketException.network(Object cause) {
    return SupportTicketException(
      statusCode: 0,
      message: "Couldn't reach support — check your connection and try again.",
    );
  }

  /// A non-2xx whose body was not the error envelope.
  ///
  /// osTicket's shared dispatcher answers an unrouted path or an unaccepted
  /// method with `400 URL not supported` as `text/html`, so not every failure
  /// body parses as JSON. Treated as a bug in our routing rather than something
  /// to explain to the client.
  factory SupportTicketException.malformed(int statusCode) {
    return SupportTicketException(
      statusCode: statusCode,
      message: "Couldn't raise this — please try again.",
    );
  }

  /// The support session is gone and must be re-established.
  ///
  /// Applies to a missing, expired or wrong-type access token, and to a dead
  /// refresh token on `/auth/refresh`. The fix is a refresh, then a fresh
  /// exchange — not a message to the client.
  bool get isAuthFailure => code == 'authentication_required';

  /// The mint token failed verification at `/auth/exchange`.
  ///
  /// Deliberately undiagnosable: bad signature, wrong issuer, expired, replayed
  /// `jti`, unknown `kid` all look identical from here. Means go back to the
  /// trading backend for a new one.
  bool get isMintTokenRejected => code == 'invalid_token';

  /// Over a rate limit. There is no `Retry-After`, so back off locally: the
  /// create window is 10 minutes, the exchange window 1 minute.
  bool get isRateLimited => code == 'rate_limited';

  /// A field the client can correct.
  bool get isValidationFailure => code == 'validation';

  /// Not found, or not theirs — the API will not say which.
  bool get isNotFound => code == 'not_found';

  static String _mapMessage(int status, String code, String backend) {
    switch (code) {
      case 'rate_limited':
        // The create window is 10 minutes; naming a wait beats "try again",
        // which invites an immediate retry that fails the same way.
        return "You've raised several tickets just now — please try again in a "
            'few minutes.';
      case 'authentication_required':
      case 'invalid_token':
        return 'Your support session has expired — please try again.';
      case 'not_found':
        return "That ticket couldn't be found.";
      case 'validation':
        // The API names what failed and its wording is safe to surface.
        return backend.isNotEmpty ? backend : 'Please check what you entered.';
      case 'bad_json':
        // Always our bug, never the client's.
        return "Couldn't send that — please try again.";
      case 'server_error':
        // May have half-succeeded, so do not invite a blind retry.
        return 'Something went wrong at our end. Please check your tickets '
            'before trying again.';
      default:
        if (backend.isNotEmpty) return backend;
        if (status >= 500) return "Something went wrong — please try again.";
        return "Couldn't complete that — please try again.";
    }
  }

  @override
  String toString() =>
      'SupportTicketException($statusCode, $code): $message';
}

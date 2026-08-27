/// A support session, as returned by `POST /auth/exchange`.
///
/// This is osTicket's own pair, not the trading session. It is obtained by
/// handing over a short-lived JWT minted by the trading backend, and it is what
/// authorises every other call to `/api/client.php`.
class SupportSession {
  SupportSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.clientCode,
    this.clientName,
    this.clientEmail,
  });

  /// Sent as `Authorization: Bearer <accessToken>`. Lives 30 minutes.
  final String accessToken;

  /// Buys a new access token at `/auth/refresh` for 30 days.
  ///
  /// Not rotated: `/auth/refresh` returns an access token only, so this same
  /// value is reused until it expires and the client has to exchange again.
  final String refreshToken;

  /// Absolute expiry, derived from `expires_in` at the moment of the response.
  final DateTime expiresAt;

  /// Who the API resolved the mint token to. Returned by `/auth/exchange`
  /// only — `/auth/refresh` carries no client block.
  final String? clientCode;
  final String? clientName;
  final String? clientEmail;

  /// Treated as expired slightly early, so a call is not fired off with a token
  /// that dies in transit. The server allows 30 seconds of skew; this stays
  /// inside that.
  static const Duration _kExpiryGuard = Duration(seconds: 30);

  bool get isExpired => DateTime.now().isAfter(
        expiresAt.subtract(_kExpiryGuard),
      );

  factory SupportSession.fromJson(
    Map<String, dynamic> json, {
    String? existingRefreshToken,
  }) {
    final client = json['client'];
    final expiresIn = json['expires_in'];
    return SupportSession(
      accessToken: '${json['access_token'] ?? ''}',
      // `/auth/refresh` answers without one, so the caller passes the token it
      // already holds rather than losing it on every refresh.
      refreshToken:
          '${json['refresh_token'] ?? existingRefreshToken ?? ''}',
      expiresAt: DateTime.now().add(
        Duration(seconds: expiresIn is int ? expiresIn : 1800),
      ),
      clientCode: client is Map ? client['code'] as String? : null,
      clientName: client is Map ? client['name'] as String? : null,
      clientEmail: client is Map ? client['email'] as String? : null,
    );
  }

  /// Copy carrying a newly minted access token, keeping the client details and
  /// refresh token the refresh response does not return.
  SupportSession withAccess(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'];
    return SupportSession(
      accessToken: '${json['access_token'] ?? ''}',
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(
        Duration(seconds: expiresIn is int ? expiresIn : 1800),
      ),
      clientCode: clientCode,
      clientName: clientName,
      clientEmail: clientEmail,
    );
  }

  /// Only the refresh token is persisted.
  ///
  /// The access token is good for 30 minutes and cheap to re-mint, so storing
  /// it buys nothing and leaves a second bearer credential on disk. The mint
  /// token from the trading backend is never persisted at all — it is spent on
  /// the exchange call and discarded.
  Map<String, dynamic> toStorageJson() => {'refresh_token': refreshToken};
}

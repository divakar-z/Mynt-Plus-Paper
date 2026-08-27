import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mynt_plus/api/core/api_link.dart';
import 'package:mynt_plus/models/profile_model/client_detail_model.dart';
import 'package:mynt_plus/models/support_ticket_model/support_session.dart';
import 'package:mynt_plus/models/support_ticket_model/support_ticket.dart';
import 'package:mynt_plus/models/support_ticket_model/support_ticket_exception.dart';

import 'core/api_core.dart';
import 'user_profile_api.dart';

/// osTicket's client-facing support API (`/api/client.php`).
///
/// Lets a logged-in client raise, track and reply to tickets that land in the
/// same osTicket console the helpdesk works in, replacing the phone call where
/// an agent listens and files the ticket on the client's behalf.
///
/// **Two hops, two credentials.** The client's trading session gets them a
/// short-lived JWT from the trading backend ([mintSupportToken]); that JWT is
/// exchanged once for an osTicket session ([exchangeToken]), and everything
/// after runs on the osTicket access token. The two never mix, which is why the
/// client never needs an osTicket password.
///
/// Three things here differ from most of this app's API layer:
///
///  * **Real HTTP status codes and a different envelope.** `{"data": ...}` on
///    success, `{"error": {"code", "message"}}` on failure — not `stat: "Ok"`.
///  * **Not every failure body is JSON.** An unrouted path or an unaccepted
///    method returns `400 URL not supported` as `text/html` from osTicket's
///    shared dispatcher.
///  * **Ownership is server-side.** A ticket id belonging to another client
///    returns `404`, never `403` — the API will not confirm it exists.
mixin SupportClientApi on ApiCore, UserProfileAPI {
  /// `_ConditionalTimeoutClient` is currently a no-op (its URL list is empty),
  /// so without this there is no timeout at all.
  static const Duration _kTimeout = Duration(seconds: 30);

  /// Uploads carry up to osTicket's own file cap and are slower than a JSON
  /// round trip.
  static const Duration _kUploadTimeout = Duration(seconds: 60);

  // --- Session -------------------------------------------------------------

  /// The live support session, held in memory only.
  ///
  /// Deliberately not persisted whole: the access token is good for 30 minutes
  /// and cheap to re-mint, so storing it buys nothing and leaves a second
  /// bearer credential on disk.
  SupportSession? _supportSession;
  SupportSession? get supportSession => _supportSession;

  /// Drops the session. Call on logout — the tokens outlive the trading
  /// session otherwise, and the refresh token is good for 30 days.
  void clearSupportSession() {
    _supportSession = null;
    _sessionForClient = null;
  }

  /// The client code the current session belongs to, so a session cannot
  /// survive an account switch.
  String? _sessionForClient;

  /// Syntactic check only — the server rejects an address it cannot parse, and
  /// answers a bare `401 invalid_token` that says nothing about why.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Builds the short-lived JWT that `/auth/exchange` accepts.
  ///
  /// Signed in the app rather than fetched from a backend. Four things must be
  /// exact or the server answers a bare `401 invalid_token` without saying
  /// which: the issuer, the audience, a lifetime no longer than 120 seconds,
  /// and a `jti` never seen before.
  ///
  /// The e-mail matters as much as the signature. Verified against the live
  /// API: an empty or malformed address is rejected exactly like a bad key, so
  /// it is fetched and checked here rather than read from whatever a provider
  /// happens to be holding — a profile that has not loaded yet would otherwise
  /// send an empty string and produce a 401 that looks like a key problem.
  ///
  /// Single-use and two minutes old at most, so it is built immediately before
  /// the exchange and never stored — caching it would guarantee a replay
  /// rejection on the second use.
  Future<String> mintSupportToken() async {
    if (kSupportAppKey.isEmpty) {
      // A build without the key cannot sign anything. Saying so beats emitting
      // a token signed with an empty secret and reporting the server's 401.
      throw SupportTicketException(
        statusCode: 0,
        message: 'Support is not available in this build.',
      );
    }

    final clientCode = (prefs.clientId ?? '').trim();
    if (clientCode.isEmpty) {
      throw SupportTicketException(
        statusCode: 0,
        message: 'Support is unavailable — please sign in again.',
      );
    }

    final ClientDetailModel detail;
    try {
      detail = await getClientDetail();
    } catch (e) {
      throw SupportTicketException.network(e);
    }

    final email = (detail.email ?? '').trim();
    if (!_emailPattern.hasMatch(email)) {
      // Nothing the client can do from this screen, but naming the real cause
      // at least points them somewhere. The server's own answer would be an
      // undiagnosable 401.
      throw SupportTicketException(
        statusCode: 0,
        message: 'No valid email is registered on your account, so a support '
            'request cannot be raised. Please update your email in Profile '
            'first.',
      );
    }
    final name = (detail.cliname ?? '').trim();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final random = Random.secure();
    final jti = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final header = _base64Url(utf8.encode(jsonEncode({
      'alg': 'HS256',
      'typ': 'JWT',
      'kid': kSupportKeyId,
    })));

    final payload = _base64Url(utf8.encode(jsonEncode({
      'iss': kSupportIssuer,
      'aud': kSupportAudience,
      // The trading client code is the identity. The e-mail below is contact
      // and display data only — two client codes can share one address, and
      // the server tags the duplicate rather than merging them.
      'sub': clientCode,
      'email': email,
      // Blank is accepted — the server falls back to the client code — but
      // sending it means an agent sees a name instead of a code.
      'name': name.isEmpty ? clientCode : name,
      'iat': now,
      // 120 is the server's hard ceiling with no clock-skew leeway, so this
      // sits under it rather than on it.
      'exp': now + 90,
      'jti': jti,
    })));

    final signature = _base64Url(
      Hmac(sha256, utf8.encode(kSupportAppKey))
          .convert(utf8.encode('$header.$payload'))
          .bytes,
    );

    _sessionForClient = clientCode;
    return '$header.$payload.$signature';
  }

  /// base64url with the padding stripped, as JWT requires.
  String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Trades a mint token for an osTicket support session.
  ///
  /// One of only two routes that need no support access token. Do this once
  /// when the client opens Support, not on every screen — it is rate limited to
  /// 100 per minute per IP, which is sized for one exchange per app-open.
  Future<SupportSession> exchangeToken(String mintToken) async {
    try {
      final data = await _postJson('/auth/exchange', {'token': mintToken});
      final session = SupportSession.fromJson(data);
      _supportSession = session;
      return session;
    } on SupportTicketException catch (e) {
      if (e.isMintTokenRejected) _debugDumpRejectedToken(mintToken);
      rethrow;
    }
  }

  /// Prints the claims of a token the server refused.
  ///
  /// `401 invalid_token` is deliberately undiagnosable — bad signature, wrong
  /// issuer, stale clock and a malformed e-mail all look identical. Everything
  /// needed to tell them apart is in the token we just built, so it is dumped
  /// rather than left to guesswork.
  ///
  /// Debug builds only: these claims identify a client, and a release build has
  /// no business writing them to a console.
  void _debugDumpRejectedToken(String token) {
    if (!kDebugMode) return;
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('[support] malformed token: ${parts.length} segments');
        return;
      }
      Map<String, dynamic> decode(String segment) {
        final padded = segment.padRight((segment.length + 3) ~/ 4 * 4, '=');
        return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(base64Url.decode(padded))) as Map,
        );
      }

      final header = decode(parts[0]);
      final claims = decode(parts[1]);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final email = '${claims['email'] ?? ''}';
      final sub = '${claims['sub'] ?? ''}';

      debugPrint('[support] /auth/exchange rejected the mint token.');
      debugPrint('[support]   kid      : ${header['kid']}  (server holds k1)');
      debugPrint('[support]   iss/aud  : ${claims['iss']} / ${claims['aud']}');
      debugPrint('[support]   sub      : '
          '${sub.isEmpty ? "EMPTY — this alone causes a 401" : sub}');
      debugPrint('[support]   email    : '
          '${email.isEmpty ? "EMPTY — this alone causes a 401" : email}');
      debugPrint('[support]   lifetime : '
          '${(claims['exp'] ?? 0) - (claims['iat'] ?? 0)}s (must be <= 120)');
      debugPrint('[support]   clock    : iat is ${now - (claims['iat'] ?? 0)}s '
          'behind this device (no skew is allowed)');
      debugPrint('[support]   key set  : ${kSupportAppKey.isNotEmpty}');
    } catch (e) {
      debugPrint('[support] could not decode the rejected token: $e');
    }
  }

  /// Mints a new access token from the stored refresh token.
  ///
  /// The response carries no new refresh token — they are not rotated — so the
  /// existing one is carried forward rather than being lost.
  Future<SupportSession> refreshSupportSession() async {
    final current = _supportSession;
    if (current == null || current.refreshToken.isEmpty) {
      throw SupportTicketException(
        statusCode: 401,
        code: 'authentication_required',
        message: 'Your support session has expired — please try again.',
      );
    }
    final data = await _postJson(
      '/auth/refresh',
      {'refresh_token': current.refreshToken},
    );
    final session = current.withAccess(data);
    _supportSession = session;
    return session;
  }

  /// Establishes a session if there is not a usable one already.
  ///
  /// Tries the cheapest route first: an unexpired session is reused, an expired
  /// one is refreshed, and only a dead refresh token costs a round trip to the
  /// trading backend. Callers can invoke this freely — it is a no-op in the
  /// common case.
  Future<SupportSession> ensureSupportSession() async {
    final current = _supportSession;
    // A session minted for a different client belongs to whoever was signed in
    // before, so it is never reused across an account switch.
    if (current != null &&
        !current.isExpired &&
        _sessionForClient == (prefs.clientId ?? '').trim()) {
      return current;
    }

    // Opening Support fires the topic list and the ticket list at the same
    // moment. Without this they would each start their own handshake, minting
    // two tokens and racing to overwrite the session — and the second exchange
    // can invalidate the first. Concurrent callers wait on one handshake.
    final inFlight = _authInFlight;
    if (inFlight != null) return inFlight;

    final run = _establishSession();
    _authInFlight = run;
    try {
      return await run;
    } finally {
      _authInFlight = null;
    }
  }

  Future<SupportSession>? _authInFlight;

  Future<SupportSession> _establishSession() async {
    var current = _supportSession;

    // Drop a session belonging to somebody else *before* considering a
    // refresh. Without this, signing out of one account and into another kept
    // the first client's session alive: the caller correctly saw the mismatch
    // and asked for a new session, and this then renewed the old one — a fresh
    // access token still carrying the previous client's identity, so the new
    // client saw the previous client's ticket list.
    final signedIn = (prefs.clientId ?? '').trim();
    if (current != null && _sessionForClient != signedIn) {
      _supportSession = null;
      _sessionForClient = null;
      current = null;
    }

    if (current != null && current.refreshToken.isNotEmpty) {
      try {
        return await refreshSupportSession();
      } on SupportTicketException catch (e) {
        // A dead refresh token is an ordinary expiry, not a failure worth
        // surfacing — fall through and exchange again. Anything else (the
        // service being down, say) should not be masked by a second attempt.
        if (!e.isAuthFailure) rethrow;
        _supportSession = null;
      }
    }
    return exchangeToken(await mintSupportToken());
  }

  // --- Endpoints -----------------------------------------------------------

  /// Help topics a client may raise under.
  ///
  /// Needs the access token like everything else, despite being reference data.
  Future<List<SupportTopic>> fetchSupportTopics() async {
    final data = await getData('/topics');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => SupportTopic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// The fields to render for [topicId].
  ///
  /// `topic_id` is required — omitting it is a `422` — and a topic outside the
  /// public set is a `404`. Never assume a fixed set of fields: help topics
  /// change in the admin panel without a release.
  Future<List<SupportTicketField>> fetchTicketForm(int topicId) async {
    final data = await getData('/tickets/form', {'topic_id': topicId});
    final fields = data is Map ? data['fields'] : null;
    if (fields is! List) return const [];
    return fields
        .whereType<Map>()
        .map((e) => SupportTicketField.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Raise a ticket.
  ///
  /// JSON only — this route does not take multipart. Files go up afterwards
  /// through [uploadTicketAttachment], one per request, which is also why a
  /// failed upload can never fail the ticket itself.
  ///
  /// Every key in [customFields] must be a field the topic offers **and** be
  /// editable; an unknown or locked one is a `422` naming the field. Send
  /// choice **keys**, not the labels the API hands back on read.
  ///
  /// Rate limited to 8 per 10 minutes, keyed by trading client code — a fresh
  /// exchange does not reset it. The limit is checked after validation, so a
  /// rejected request costs the client nothing.
  Future<SupportTicket> createTicket({
    required int topicId,
    required String subject,
    required String message,
    Map<String, String> customFields = const {},
  }) async {
    final data = await postData('/tickets', {
      'topic_id': topicId,
      'subject': subject,
      'message': message,
      if (customFields.isNotEmpty) 'custom_fields': customFields,
    });
    return SupportTicket.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  /// The client's own tickets, newest first.
  ///
  /// [limit] is clamped server-side into 1..50, and the echoed pagination block
  /// reports what was actually applied.
  Future<SupportTicketPage> fetchTickets({int page = 1, int limit = 20}) async {
    // Which client the server thinks is asking, and what it returned.
    //
    // A ticket visible on one platform but not another is almost always the two
    // sending a different `sub`: it is an opaque string the server does not
    // normalise, so `Z72439`, `z72439` and ` Z72439` are three separate
    // identities with three separate ticket lists.
    if (kDebugMode) {
      debugPrint('[support] listing tickets as '
          'sub="${_supportSession?.clientCode}" '
          '(prefs.clientId="${prefs.clientId}")');
    }
    final response = await _authed(
      (token) => apiClient
          .get(
            _uri('/tickets', {'page': page, 'limit': limit}),
            headers: _bearer(token, json: false),
          )
          .timeout(_kTimeout),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFrom(response);
    }
    // Read whole: unlike every other route the pagination block sits beside
    // `data`, not inside it.
    final page_ = SupportTicketPage.fromEnvelope(_decode(response) ?? const {});
    if (kDebugMode) {
      debugPrint('[support]   -> ${page_.tickets.length} rows, '
          'server total ${page_.total}');
    }
    return page_;
  }

  /// One ticket with its full conversation.
  ///
  /// A ticket that is not theirs returns `404`, indistinguishable from one that
  /// does not exist.
  Future<SupportTicket> fetchTicket(int id) async {
    final data = await getData('/tickets/$id');
    return SupportTicket.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  /// Post a client reply.
  ///
  /// A closed-but-reopenable ticket is silently reopened by this, exactly as on
  /// the web portal; a closed, non-reopenable one accepts the reply and stays
  /// closed. There is no refusal to handle.
  Future<SupportThreadEntry> replyToTicket(int id, String message) async {
    final data = await postData('/tickets/$id/reply', {'message': message});
    return SupportThreadEntry.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  /// Files on a ticket, unpaginated.
  ///
  /// Only files on client-visible entries appear. Anything attached to an
  /// internal agent note is invisible here and 404s on download.
  Future<List<SupportAttachment>> fetchTicketAttachments(int id) async {
    final data = await getData('/tickets/$id/attachments');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => SupportAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Upload one file to a ticket.
  ///
  /// **One file per request** — the route takes a single `file` part, so a
  /// multi-file selection is several calls. Size and MIME are enforced by
  /// osTicket's own rules, and a rejection is a `422`.
  ///
  /// This posts a visible thread message `Attachment: <filename>`: that is how
  /// osTicket models a client-attached file. There is no silent attach, and no
  /// way to supply your own text on this route — use [replyToTicket] for that.
  Future<SupportAttachment> uploadTicketAttachment(
    int ticketId, {
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await postFile(
      '/tickets/$ticketId/attachments',
      bytes: bytes,
      filename: filename,
    );
    return SupportAttachment.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  /// Downloads one attachment's bytes.
  ///
  /// Streamed through the API rather than fetched from a storage URL: there is
  /// deliberately no `download_url` on the attachment object, because such a
  /// URL would carry its own auth that knows nothing about ticket ownership.
  /// This route re-checks ownership on every request.
  ///
  /// Returns bytes, not JSON — the only route that does — so it bypasses the
  /// envelope helpers entirely.
  Future<List<int>> downloadTicketAttachment(
      int ticketId, int attachmentId) async {
    final response = await _authed(
      (token) => apiClient
          .get(
            _uri('/tickets/$ticketId/attachments/$attachmentId/download'),
            headers: _bearer(token, json: false),
          )
          .timeout(_kUploadTimeout),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFrom(response);
    }
    return response.bodyBytes;
  }

  // --- Request plumbing ----------------------------------------------------

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = '${apiLinks.supportClientApi}$path';
    if (query == null || query.isEmpty) return Uri.parse(base);
    final pairs = query.entries
        .where((e) => e.value != null)
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
        .join('&');
    return Uri.parse(pairs.isEmpty ? base : '$base?$pairs');
  }

  /// Unauthenticated POST, for the two `/auth/*` routes.
  Future<Map<String, dynamic>> _postJson(
      String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await apiClient
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
    } catch (e) {
      throw SupportTicketException.network(e);
    }
    return _dataOrThrow(response);
  }

  /// Runs an authenticated request, refreshing once on `authentication_required`.
  ///
  /// The retry is deliberately single. A refresh that yields a token the server
  /// still rejects means something is wrong beyond expiry, and looping on it
  /// would turn one bad session into a request storm.
  Future<http.Response> _authed(
    Future<http.Response> Function(String accessToken) send,
  ) async {
    var session = await ensureSupportSession();

    http.Response response;
    try {
      response = await send(session.accessToken);
    } catch (e) {
      throw SupportTicketException.network(e);
    }
    if (response.statusCode != 401) return response;

    // 401 despite a session we believed was live — the token may have been
    // invalidated server-side (a SECRET_SALT rotation logs everyone out).
    try {
      session = await refreshSupportSession();
    } on SupportTicketException {
      _supportSession = null;
      session = await exchangeToken(await mintSupportToken());
    }
    try {
      return await send(session.accessToken);
    } catch (e) {
      throw SupportTicketException.network(e);
    }
  }

  Map<String, String> _bearer(String accessToken, {bool json = true}) => {
        'Authorization': 'Bearer $accessToken',
        if (json) 'Content-Type': 'application/json',
      };

  /// GET returning the `data` payload.
  Future<dynamic> getData(String path, [Map<String, dynamic>? query]) async {
    final response = await _authed(
      (token) => apiClient
          .get(_uri(path, query), headers: _bearer(token, json: false))
          .timeout(_kTimeout),
    );
    return _payloadOrThrow(response);
  }

  /// POST returning the `data` payload.
  Future<dynamic> postData(String path, Map<String, dynamic> body) async {
    final response = await _authed(
      (token) => apiClient
          .post(_uri(path), headers: _bearer(token), body: jsonEncode(body))
          .timeout(_kTimeout),
    );
    return _payloadOrThrow(response);
  }

  /// Multipart POST for a single file.
  ///
  /// One file per request is the API's rule, not a simplification here — the
  /// upload route takes exactly one `file` part.
  Future<dynamic> postFile(
    String path, {
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _authed((token) async {
      final request = http.MultipartRequest('POST', _uri(path));
      // Only the Authorization header: MultipartRequest sets its own
      // Content-Type with the boundary, and an inherited `application/json`
      // makes the server parse the body as JSON and find nothing.
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final streamed = await apiClient.send(request).timeout(_kUploadTimeout);
      return http.Response.fromStream(streamed);
    });
    return _payloadOrThrow(response);
  }

  // --- Responses -----------------------------------------------------------

  /// The `data` object of a success envelope, throwing on any failure.
  Map<String, dynamic> _dataOrThrow(http.Response response) {
    final payload = _payloadOrThrow(response);
    return payload is Map ? Map<String, dynamic>.from(payload) : {};
  }

  /// The `data` payload — a Map for most routes, a List for `/topics` and
  /// `/tickets`. Throws on any non-2xx.
  dynamic _payloadOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failureFrom(response);
    }
    final body = _decode(response);
    if (body == null) return const {};
    return body.containsKey('data') ? body['data'] : body;
  }

  SupportTicketException _failureFrom(http.Response response) {
    final body = _decode(response);
    final error = body?['error'];
    if (error is! Map) {
      // No envelope: the dispatcher's `400 URL not supported`, an HTML error
      // page from a proxy, or an empty body.
      return SupportTicketException.malformed(response.statusCode);
    }
    return SupportTicketException.fromResponse(
      statusCode: response.statusCode,
      code: '${error['code'] ?? ''}',
      backendMessage: '${error['message'] ?? ''}',
      fields: _fieldsFrom(error['fields']),
    );
  }

  /// The `fields` object on a validation failure.
  ///
  /// Often present but not guaranteed — several failure paths return a bare
  /// message, so this yields an empty map rather than assuming.
  ///
  /// The values are **not consistently typed**, verified against the live API:
  ///
  ///   {"57": ["Account Name is a required field"]}   a list, keyed by field id
  ///   {"priority": "Not editable"}                   a string, keyed by name
  ///
  /// A list stringified with `'$value'` renders as `[Account Name is…]`,
  /// brackets and all, so it is joined instead. The key being sometimes a
  /// numeric field id is handled by the caller, which cannot match it to a
  /// widget and falls back to a toast.
  Map<String, String> _fieldsFrom(dynamic fields) {
    if (fields is! Map) return const {};
    final out = <String, String>{};
    for (final entry in fields.entries) {
      final value = entry.value;
      out['${entry.key}'] = value is List
          ? value.map((v) => '$v').where((v) => v.isNotEmpty).join(' ')
          : '$value';
    }
    return out;
  }

  /// Decodes the body, or null if it was absent or not a JSON object.
  ///
  /// Always decodes UTF-8 from bytes: `response.body` uses Latin-1 unless the
  /// response sets `charset=utf-8` explicitly, which mangles anything non-ASCII
  /// the API echoes back from what the client typed.
  Map<String, dynamic>? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}

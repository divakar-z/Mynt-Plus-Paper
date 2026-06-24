import 'dart:convert';
import 'dart:developer';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../api/core/api_link.dart';
import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../routes/web_router.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../utils/responsive_snackbar.dart';

enum _OAuthStage { checking, validating, ready, invalid, restricted }

class OAuthLoginScreen extends ConsumerStatefulWidget {
  const OAuthLoginScreen({super.key, this.clientId});

  final String? clientId;

  @override
  ConsumerState<OAuthLoginScreen> createState() => _OAuthLoginScreenState();
}

class _OAuthLoginScreenState extends ConsumerState<OAuthLoginScreen> {
  String get _validateUrl => locator<ApiLinks>().myntValidate;
  String get _authUrl => locator<ApiLinks>().myntAuth;

  _OAuthStage _stage = _OAuthStage.checking;
  String _dname = '';
  String _uid = '';
  // The session (nwc_id) that actually validated — main web session or the
  // OAuth-only session. Used when submitting the authorize (mynt-auth) call.
  String? _authNwcId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didUpdateWidget(OAuthLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the URL's client_id changes, GoRouter reuses this widget but passes a
    // new clientId. Reset and re-bootstrap so validate runs against the new value.
    if (oldWidget.clientId != widget.clientId) {
      setState(() {
        _stage = _OAuthStage.checking;
        _dname = '';
        _uid = '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
  }

  String get _clientId => (widget.clientId ?? '').trim();

  /// Sessions to try for validate/auth, in priority order:
  ///   1. the main web session (clientSession), then
  ///   2. the OAuth-only session.
  /// We do NOT filter the OAuth session locally — mynt-validate is the single
  /// source of truth: each session is sent and only a uid means "owns this key".
  /// Keeping the OAuth session separate is what lets the main web session survive
  /// while an OAuth login for a different account is in play.
  List<String> get _candidateSessions {
    final pref = locator<Preferences>();
    final out = <String>[];
    final main = (pref.clientSession ?? '').trim();
    if (main.isNotEmpty) out.add(main);
    final oauth = (pref.oauthSession ?? '').trim();
    if (oauth.isNotEmpty) out.add(oauth);
    return out;
  }

  Future<void> _bootstrap() async {
    if (_clientId.isEmpty) {
      setState(() => _stage = _OAuthStage.invalid);
      return;
    }

    // Validate first — always, even with no session (an empty nwc_id) — so an
    // invalid app key shows Restricted immediately instead of after a pointless
    // login, matching the vendor. No local account comparison; the backend's
    // response (uid / "no data" / neither) decides the screen.
    setState(() => _stage = _OAuthStage.validating);
    await _validate();
  }

  Future<void> _validate() async {
    // Try the real sessions in priority order (main web session first, then the
    // OAuth session). When there are none, still make ONE attempt with a throwaway
    // random nwc_id so the backend can tell us whether the app key is even valid.
    // (Our mynt-validate rejects an empty nwc_id, but a non-empty random one lets
    // the session-independent key check run: an invalid key returns "no data" →
    // Restricted; a valid key returns no uid → login.)
    final sessions = _candidateSessions;
    final toTry = sessions.isEmpty ? [const Uuid().v4()] : sessions;

    // The first session that returns a uid wins; a session that doesn't own the
    // key (Ok, no uid) just falls through to the next.
    for (final nwcId in toTry) {
      final json = await _postValidate(nwcId);
      if (!mounted) return;

      if (json == null) {
        // Hard error (non-200 / exception). The endpoint is the same for every
        // session, so retrying with another won't help — surface it.
        setState(() => _stage = _OAuthStage.invalid);
        return;
      }

      final stat = json['stat'];
      final uid = (json['uid'] ?? '').toString();
      final emsg = (json['emsg'] ?? '').toString().toLowerCase();

      if (stat == 'Ok' && uid.isNotEmpty) {
        setState(() {
          _stage = _OAuthStage.ready;
          _dname = (json['dname'] ?? '').toString();
          _uid = uid;
          _authNwcId = nwcId; // remember the session that authorised
        });
        return;
      }
      if (stat == 'Not_Ok' && emsg.contains('no data')) {
        // App key not valid for OAuth at all — session-independent, so stop.
        setState(() => _stage = _OAuthStage.restricted);
        return;
      }
      // stat=Ok but no uid → this session doesn't own the key; try the next one.
    }

    // No session could authorise the key — send the user to /login to sign in as
    // the owning account. No logout: the main web session must stay alive.
    _redirectToLogin();
  }

  /// POSTs one validate attempt. Returns the parsed JSON, or null on a hard
  /// error (non-200 status or exception).
  Future<Map<String, dynamic>?> _postValidate(String nwcId) async {
    final payload = {'client_id': _clientId, 'nwc_id': nwcId};
    if (kDebugMode) log('mynt-validate Request => $payload');
    try {
      final res = await http.post(
        Uri.parse(_validateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (kDebugMode) {
        log('mynt-validate status => ${res.statusCode}');
        log('mynt-validate body => ${res.body}');
      }
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) log('mynt-validate error => $e');
      return null;
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    // Send the user to /login WITHOUT logging out — the session is shared across
    // tabs, so we must not invalidate it server-side. /login skips its auto-login
    // redirect when a client_id is present, so the login form is shown (not the
    // dashboard), and after a successful login the user is routed back here.
    context.go(
      '${WebRoutes.login}?client_id=${Uri.encodeQueryComponent(_clientId)}',
    );
  }

  void _onAuthorisePressed() {
    final nwcId = _authNwcId;
    if (_clientId.isEmpty || nwcId == null) {
      ResponsiveSnackBar.showError(context, 'Session not found.');
      return;
    }

    if (kDebugMode) log('mynt-auth submit => client_id=$_clientId, nwc_id=$nwcId');

    final form = html.FormElement()
      ..action = _authUrl
      ..method = 'POST'
      ..target = '_self'
      ..style.display = 'none';

    form.append(
      html.InputElement()
        ..type = 'hidden'
        ..name = 'client_id'
        ..value = _clientId,
    );

    form.append(
      html.InputElement()
        ..type = 'hidden'
        ..name = 'nwc_id'
        ..value = nwcId,
    );

    html.document.body?.append(form);
    form.submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyntColors.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 48),
                child: _buildBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _OAuthStage.checking:
      case _OAuthStage.validating:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      case _OAuthStage.invalid:
        return _buildInvalidView();
      case _OAuthStage.ready:
        return _buildAuthoriseView();
      case _OAuthStage.restricted:
        return _buildRestrictedView();
    }
  }

  // Backend returns dname like "ZP00285 s apikey". Product wants it shown as
  // "ZP00285 API Key" — drop the possessive "s" and uppercase "API Key".
  String _prettyDname(String raw) {
    return raw.replaceAll(
      RegExp(r'\s+s\s+api\s*key\s*$', caseSensitive: false),
      ' API Key',
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/icon/Mynt New logo.svg',
          width: 120,
          height: 44,
        ),
      ),
    );
  }

  Widget _buildInvalidView() {
    final cardColor = resolveThemeColor(
      context,
      dark: MyntColors.cardDark,
      light: MyntColors.card,
    );
    final borderColor = resolveThemeColor(
      context,
      dark: MyntColors.cardBorderDark,
      light: MyntColors.cardBorder,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          Text(
            'Invalid link',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.head(
              context,
              fontWeight: MyntFonts.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This authorization link is missing required information.',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.body(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedView() {
    final cardColor = resolveThemeColor(
      context,
      dark: MyntColors.cardDark,
      light: MyntColors.card,
    );
    final borderColor = resolveThemeColor(
      context,
      dark: MyntColors.cardBorderDark,
      light: MyntColors.cardBorder,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          Text(
            'Access Restricted for API Only Users',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 44,
            child: MyntOutlinedButton(
              label: 'Close',
              isFullWidth: true,
              onPressed: () {
                if (!mounted) return;
                context.go(WebRoutes.home);
              },
              textColor: resolveThemeColor(
                context,
                dark: MyntColors.textWhite,
                light: MyntColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthoriseView() {
    final cardColor = resolveThemeColor(
      context,
      dark: MyntColors.cardDark,
      light: MyntColors.card,
    );
    final borderColor = resolveThemeColor(
      context,
      dark: MyntColors.cardBorderDark,
      light: MyntColors.cardBorder,
    );
    final secondaryText = resolveThemeColor(
      context,
      dark: MyntColors.textTertiaryDark,
      light: MyntColors.textTertiary,
    );

    final appName = _dname.isEmpty ? 'this app' : _prettyDname(_dname);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          Text(
            appName,
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.head(
              context,
              fontWeight: MyntFonts.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'wants to access your account${_uid.isEmpty ? '' : ' $_uid'}',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.body(
              context,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'This will allow $appName to :',
            style: MyntWebTextStyles.title(
              context,
              fontWeight: MyntFonts.bold,
            ),
          ),
          const SizedBox(height: 14),
          _buildBullet('View your profile details, including account balance.'),
          _buildBullet(
              'Access your portfolio, including positions and holdings.'),
          _buildBullet('Place, modify, and cancel orders.'),
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _onAuthorisePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyntColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Authorize',
                style: MyntWebTextStyles.title(
                  context,
                  fontWeight: MyntFonts.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 12),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: MyntWebTextStyles.body(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// In-memory hand-off for URL token-based auto-login
/// (app.mynt.in/?uid=clientId&token=noren-session).
///
/// main.dart reads the launch URL's uid/token and stashes them here — never in
/// persistent storage — before the router and SplashScreen run. SplashScreen
/// then validates them and commits a real session ONLY on success. Keeping the
/// values out of stored prefs until validated means a wrong or expired link can
/// never overwrite or log out the user who is already signed in.
class AutoLoginHandoff {
  AutoLoginHandoff._();

  static String? uid;
  static String? token;

  static bool get hasPending =>
      (uid?.isNotEmpty ?? false) && (token?.isNotEmpty ?? false);

  static void clear() {
    uid = null;
    token = null;
  }
}

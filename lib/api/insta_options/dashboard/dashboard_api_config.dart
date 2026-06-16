/// Configuration for the F&O **Dashboard** analytics backend
/// (`zdf-dashboard-api`).
///
/// This is a SEPARATE service from both the Mynt Noren APIs and the older
/// InstaOptions OI-Data backend ([InstaOptionsConfig]). Screen 1 — the Markets
/// Dashboard — is the only consumer; every other InstaOptions sub-screen keeps
/// talking to the legacy OI-Data service, so this config must never be merged
/// into [InstaOptionsConfig].
///
/// The origin resolves from `--dart-define=API_BASE=...` at build/run time,
/// falling back to the documented local default. All dashboard endpoints sit
/// under the `/api/v1/dashboard` prefix; `/health` sits at the service root.
class DashboardApiConfig {
  const DashboardApiConfig();

  /// Override at build/run time, e.g.:
  /// `flutter run -d chrome --dart-define=API_BASE=http://10.0.0.5:8000`
  static const String _envBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  /// Service origin without a trailing slash, e.g. `http://localhost:8000`.
  String get origin {
    final raw = _envBase.trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Base for all dashboard endpoints: `<origin>/api/v1/dashboard`.
  String get dashboardBase => '$origin/api/v1/dashboard';

  /// Health probe, served at the root: `<origin>/health`.
  String get healthUrl => '$origin/health';
}

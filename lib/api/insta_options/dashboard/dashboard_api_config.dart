/// Configuration for the F&O **Dashboard** analytics backend
/// (`zdf-dashboard-api`).
///
/// This is a SEPARATE service from both the Mynt Noren APIs and the older
/// InstaOptions OI-Data backend ([InstaOptionsConfig]). The date-based screens
/// (Markets Dashboard, Option Chain) and the global `/symbols` list consume it;
/// the remaining legacy InstaOptions sub-screens keep talking to the OI-Data
/// service, so this config must never be merged into [InstaOptionsConfig].
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

  /// Base for all option-chain endpoints: `<origin>/api/v1/option-chain`.
  String get optionChainBase => '$origin/api/v1/option-chain';

  /// Global F&O symbol universe (indices + stocks): `<origin>/api/v1/symbols`.
  String get symbolsUrl => '$origin/api/v1/symbols';

  /// Health probe, served at the root: `<origin>/health`.
  String get healthUrl => '$origin/health';
}

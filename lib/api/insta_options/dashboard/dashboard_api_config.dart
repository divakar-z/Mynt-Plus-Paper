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
/// falling back to the hosted production origin
/// (`https://oaapi.zebuetrade.com/data`). All endpoints sit under the
/// `/api/v1/...` prefix (e.g. `<origin>/api/v1/dashboard`).
class DashboardApiConfig {
  const DashboardApiConfig();

  /// Defaults to the hosted production service. Override at build/run time for
  /// local development, e.g.:
  /// `flutter run -d chrome --dart-define=API_BASE=http://localhost:8000`
  static const String _envBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://oaapi.zebuetrade.com/data',
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

  /// Base for all index-contribution endpoints: `<origin>/api/v1/contribution`.
  String get contributionBase => '$origin/api/v1/contribution';

  /// Base for the OI chart endpoints: `<origin>/api/v1/charts`
  /// (`/oi-by-strike`, `/pcr-timeline`, `/oi-timeline`).
  String get chartsBase => '$origin/api/v1/charts';

  /// Global F&O symbol universe (indices + stocks): `<origin>/api/v1/symbols`.
  String get symbolsUrl => '$origin/api/v1/symbols';

  /// Global trading-day calendar shared by every date-based screen:
  /// `<origin>/api/v1/dates`. The per-section `/dates` endpoints were removed —
  /// all screens (dashboard, option-chain, contribution) read this one calendar.
  String get datesUrl => '$origin/api/v1/dates';

  /// Health probe, served at the root: `<origin>/health`.
  String get healthUrl => '$origin/health';
}

import 'package:get_it/get_it.dart';

import '../api/core/api_export.dart';
import '../api/core/api_link.dart';
import '../api/paper/paper_api_exporter.dart';
import '../api/insta_options/charts/charts_api.dart';
import '../api/insta_options/contribution/contribution_api.dart';
import '../api/insta_options/dashboard/dashboard_api.dart';
import '../api/insta_options/dashboard/dashboard_api_config.dart';
import '../api/insta_options/insta_options_api.dart';
import '../api/insta_options/option_chain/option_chain_api.dart';
import '../api/insta_options/symbols_api.dart';
import '../api/insta_options/insta_options_config.dart';
import 'preference.dart';

GetIt locator = GetIt.instance;

/// This build is a paper-trading-only platform.
///
/// A compile-time constant on purpose: it can never be flipped at runtime
/// (no toggle, no saved preference, no URL param), so the app can never reach
/// live order or money APIs. PaperApiExporter is always registered.
/// Market data (quotes, watchlists, charts) still uses real APIs.
const bool isPaperTrading = true;

void setupLocator() {
  locator.registerLazySingleton(() => Preferences());
  locator.registerLazySingleton(() => ApiLinks());
  locator.registerLazySingleton<ApiExporter>(
    () => isPaperTrading ? PaperApiExporter() : ApiExporter(),
  );
  // InstaOptions Analytics — separate OI Data backend.
  locator.registerLazySingleton(() => InstaOptionsConfig());
  locator.registerLazySingleton(() => InstaOptionsApi());
  // F&O Dashboard (Screen 1) — separate zdf-dashboard-api backend.
  locator.registerLazySingleton(() => const DashboardApiConfig());
  locator.registerLazySingleton(() => DashboardApi());
  // Option Chain (Screen 2) + global symbols — same zdf backend.
  locator.registerLazySingleton(() => SymbolsApi());
  locator.registerLazySingleton(() => OptionChainApi());
  // Index Contribution (Screen 3) — same zdf backend, global dates.
  locator.registerLazySingleton(() => ContributionApi());
  // OI Charts (OI Statistics / PCR Ratio / Trending OI) — same zdf backend.
  locator.registerLazySingleton(() => ChartsApi());
}

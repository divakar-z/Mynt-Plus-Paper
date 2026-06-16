import 'package:get_it/get_it.dart';

import '../api/core/api_export.dart';
import '../api/core/api_link.dart';
import '../api/insta_options/dashboard/dashboard_api.dart';
import '../api/insta_options/dashboard/dashboard_api_config.dart';
import '../api/insta_options/insta_options_api.dart';
import '../api/insta_options/insta_options_config.dart';
import 'preference.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => Preferences());
  locator.registerLazySingleton(() => ApiLinks());
  locator.registerLazySingleton(() => ApiExporter());
  // InstaOptions Analytics — separate OI Data backend.
  locator.registerLazySingleton(() => InstaOptionsConfig());
  locator.registerLazySingleton(() => InstaOptionsApi());
  // F&O Dashboard (Screen 1) — separate zdf-dashboard-api backend.
  locator.registerLazySingleton(() => const DashboardApiConfig());
  locator.registerLazySingleton(() => DashboardApi());
}

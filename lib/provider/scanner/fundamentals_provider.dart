import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_categories.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/models/scanner_model/saved_screen.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';

ApiExporter get _api => locator<ApiExporter>();

final fundamentalFieldsProvider = FutureProvider<List<FundamentalField>>(
    (_) => _api.fetchFundamentalFields());

final fundamentalPresetsProvider = FutureProvider<List<FundamentalPreset>>(
    (_) => _api.fetchFundamentalPresets());

/// Sector + industry option lists for the Sector/Industry multiselect filters.
/// Fetched once and cached.
final fundamentalCategoriesProvider = FutureProvider<FundamentalCategories>(
    (_) => _api.fetchFundamentalCategories());

final savedScreensProvider = FutureProvider<List<SavedFundamentalScreen>>(
    (_) => _api.listSavedScreens());

/// The result of the most recent ad-hoc run. Cleared/refreshed by the UI.
class LastFundamentalResultNotifier
    extends Notifier<AsyncValue<FundamentalScanResponse>?> {
  @override
  AsyncValue<FundamentalScanResponse>? build() => null;
  void set(AsyncValue<FundamentalScanResponse>? v) => state = v;
}

final lastFundamentalResultProvider = NotifierProvider<
    LastFundamentalResultNotifier, AsyncValue<FundamentalScanResponse>?>(
  LastFundamentalResultNotifier.new,
);

/// Persistent session state for the Fundamentals pane — builder inputs and
/// the most recent scan result, kept alive across navigation away/back.
class FundamentalsSession {
  final FundamentalsBuilderState builder;
  final AsyncValue<FundamentalScanResponse>? result;
  const FundamentalsSession({
    this.builder = const FundamentalsBuilderState(),
    this.result,
  });

  FundamentalsSession copyWith({
    FundamentalsBuilderState? builder,
    Object? result = _fSentinel,
  }) =>
      FundamentalsSession(
        builder: builder ?? this.builder,
        result: identical(result, _fSentinel)
            ? this.result
            : result as AsyncValue<FundamentalScanResponse>?,
      );
}

const Object _fSentinel = Object();

class FundamentalsSessionNotifier extends Notifier<FundamentalsSession> {
  @override
  FundamentalsSession build() => const FundamentalsSession();

  void setBuilder(FundamentalsBuilderState b) =>
      state = state.copyWith(builder: b);

  void setResult(AsyncValue<FundamentalScanResponse>? r) =>
      state = state.copyWith(result: r);
}

final fundamentalsSessionProvider =
    NotifierProvider<FundamentalsSessionNotifier, FundamentalsSession>(
  FundamentalsSessionNotifier.new,
);

/// Independent session for the redesigned Fundamentals tab, so building a
/// screen there never disturbs the current Fundamentals tab (separate provider
/// instance, same notifier class → isolated state).
final fundamentalsNewSessionProvider =
    NotifierProvider<FundamentalsSessionNotifier, FundamentalsSession>(
  FundamentalsSessionNotifier.new,
);

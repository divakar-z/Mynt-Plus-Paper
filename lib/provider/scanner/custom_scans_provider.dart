import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Static metadata — fetch once per app session and cache forever. Anything
/// that needs to render predicate-builder UI should watch this provider.
final indicatorCatalogProvider = FutureProvider<IndicatorCatalog>((ref) async {
  ref.keepAlive(); // never auto-dispose
  return _api.fetchIndicatorCatalog();
});

final savedCustomScansProvider = FutureProvider<List<SavedCustomScan>>(
    (_) => _api.listSavedCustomScans());

class LastCustomRunNotifier extends Notifier<AsyncValue<CustomScanRunResult>?> {
  @override
  AsyncValue<CustomScanRunResult>? build() => null;
  void set(AsyncValue<CustomScanRunResult>? v) => state = v;
}

final lastCustomRunProvider = NotifierProvider<LastCustomRunNotifier,
    AsyncValue<CustomScanRunResult>?>(
  LastCustomRunNotifier.new,
);

/// Persistent session state for the Custom Scans pane. Holds enough
/// information to reconstruct exactly what the user was looking at — list
/// vs builder vs run-results — so navigating away (e.g. clicking a result
/// symbol to view its chart) and coming back doesn't wipe their work.
///
/// View precedence: [builder] wins over [results] wins over the cards list.
class CustomScansSession {
  /// `null` = the saved-scans list (or the results view if [results] is set).
  /// Non-null = builder mode.
  final CustomScanBuilderDraft? builder;

  /// `null` = no saved-scan run open. Non-null = render the results pane
  /// for this saved scan with the current async result.
  final SavedScanResultsView? results;

  const CustomScansSession({this.builder, this.results});

  CustomScansSession copyWith({
    Object? builder = _sentinel,
    Object? results = _sentinel,
  }) =>
      CustomScansSession(
        builder: identical(builder, _sentinel)
            ? this.builder
            : builder as CustomScanBuilderDraft?,
        results: identical(results, _sentinel)
            ? this.results
            : results as SavedScanResultsView?,
      );
}

/// Snapshot of "user clicked Run on this saved scan; here's what came back."
/// The results live in session state (not a FutureProvider) because the
/// user might dismiss + reopen the same scan and we don't want to lose
/// their place — and because re-running on demand is cheaper than caching
/// when each saved scan typically yields ≤ a few hundred rows.
class SavedScanResultsView {
  final SavedCustomScan scan;
  final AsyncValue<CustomScanRunResult> result;
  const SavedScanResultsView({required this.scan, required this.result});
}

const Object _sentinel = Object();

class CustomScanBuilderDraft {
  /// The existing saved scan being edited; `null` when creating a new one.
  final SavedCustomScan? editing;
  final String name;
  final Map<String, dynamic> predicate;
  final bool showJson;
  final AsyncValue<CustomScanRunResult>? result;

  const CustomScanBuilderDraft({
    this.editing,
    this.name = '',
    this.predicate = const {'all': []},
    this.showJson = false,
    this.result,
  });

  CustomScanBuilderDraft copyWith({
    Object? editing = _sentinel,
    String? name,
    Map<String, dynamic>? predicate,
    bool? showJson,
    Object? result = _sentinel,
  }) =>
      CustomScanBuilderDraft(
        editing: identical(editing, _sentinel)
            ? this.editing
            : editing as SavedCustomScan?,
        name: name ?? this.name,
        predicate: predicate ?? this.predicate,
        showJson: showJson ?? this.showJson,
        result: identical(result, _sentinel)
            ? this.result
            : result as AsyncValue<CustomScanRunResult>?,
      );
}

class CustomScansSessionNotifier extends Notifier<CustomScansSession> {
  @override
  CustomScansSession build() => const CustomScansSession();

  void openNewBuilder() {
    state = state.copyWith(builder: const CustomScanBuilderDraft());
  }

  void openExistingBuilder(SavedCustomScan scan) {
    state = state.copyWith(
      builder: CustomScanBuilderDraft(
        editing: scan,
        name: scan.name,
        predicate: scan.predicateJson,
      ),
    );
  }

  void closeBuilder() {
    state = state.copyWith(builder: null);
  }

  void updateBuilder(CustomScanBuilderDraft Function(CustomScanBuilderDraft) f) {
    final cur = state.builder;
    if (cur == null) return;
    state = state.copyWith(builder: f(cur));
  }

  /// Enter the saved-scan results view, starting in the loading state.
  /// Caller is expected to fire the API call and then update via
  /// [setResults] when the response (or error) lands.
  void openResults(SavedCustomScan scan) {
    state = state.copyWith(
      results: SavedScanResultsView(
        scan: scan,
        result: const AsyncValue.loading(),
      ),
    );
  }

  void setResults(AsyncValue<CustomScanRunResult> r) {
    final cur = state.results;
    if (cur == null) return;
    state = state.copyWith(
      results: SavedScanResultsView(scan: cur.scan, result: r),
    );
  }

  void closeResults() {
    state = state.copyWith(results: null);
  }
}

final customScansSessionProvider =
    NotifierProvider<CustomScansSessionNotifier, CustomScansSession>(
  CustomScansSessionNotifier.new,
);

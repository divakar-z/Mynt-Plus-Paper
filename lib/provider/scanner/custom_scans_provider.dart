import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';

ApiExporter get _api => locator<ApiExporter>();

/// Static metadata — fetch once per app session and cache forever. Anything
/// that needs to render predicate-builder UI should watch this provider.
final indicatorCatalogProvider = FutureProvider<IndicatorCatalog>((ref) async {
  ref.keepAlive(); // never auto-dispose
  return _api.fetchIndicatorCatalog();
});

/// One client's saved scans, keyed by client id — callers pass
/// [savedCustomScansKey].
///
/// The key is what separates accounts, not a way for a screen to ask for
/// somebody else's scans. It exists because a single shared cache slot leaked
/// across logins: invalidating it on logout makes it refetch *immediately*,
/// and at that moment the Scanner is still mounted while `apiToken` and
/// `clientId` are still in prefs ([Preferences.clearClientSession] only drops
/// `clientSession`). The refetch therefore succeeded as the outgoing account
/// and re-cached its scans right after the invalidation, and the next login on
/// the same browser read them straight out of the cache without a request.
///
/// Keying by client id removes the shared slot altogether, so correctness no
/// longer depends on the order of steps in any logout path. Same fix, and same
/// reasoning, as `journalTagsProvider`.
///
/// `autoDispose` on top of that keeps the per-account entries from piling up
/// for the life of the tab, and makes each fresh mount of the Scanner refetch.
///
/// Invalidate after save / delete / run.
final savedCustomScansProvider =
    FutureProvider.autoDispose.family<List<SavedCustomScan>, String>(
        (_, __) => _api.listSavedCustomScans());

/// The current account's key for [savedCustomScansProvider].
String savedCustomScansKey() => locator<Preferences>().clientId ?? '';

/// Bumped on every logout. Any scanner request that is still in flight
/// captures this before its `await` and compares afterwards — see
/// [scannerSessionEpoch] and [isSameScannerSession].
int _scannerSessionEpoch = 0;

/// Identity of the current logged-in scanner session.
///
/// Clearing providers on logout is not enough on its own: a `/scans/run` that
/// was already in flight when the user logged out still completes, and its
/// `setResults` lands *after* the clear — re-filling the new user's screen
/// with the previous user's scan. Worse, the scan id it carries belongs to the
/// old account, so the next run of it 404s with `custom_not_found`.
///
/// `clientId` cannot be used for this: [Preferences.clearClientSession] only
/// removes the session key and deliberately keeps the client id around to
/// pre-fill the login field. A counter is unambiguous.
int get scannerSessionEpoch => _scannerSessionEpoch;

/// True when [epoch] (captured before an await) is still the live session.
/// A response that fails this check must be dropped, not rendered.
bool isSameScannerSession(int epoch) => epoch == _scannerSessionEpoch;

/// Drops the per-account scanner state that is NOT already separated by
/// client id. Called from every logout path in `AuthProvider` (explicit
/// logout, session expiry, network failure).
///
/// [savedCustomScansProvider] is deliberately NOT invalidated here. It is
/// keyed by client id, so the next login reads a different entry and can never
/// see these scans — and invalidating it while the Scanner is still mounted is
/// precisely what used to fire a `/scans/saved` request *after* logout and
/// re-cache the outgoing account's list.
///
/// [indicatorCatalogProvider] is also left alone: it is static reference data,
/// identical for every account, and refetching it costs a round trip on the
/// next login for nothing.
void clearCustomScansOnLogout(Ref ref) {
  // Bump FIRST, so anything already awaiting a response is invalidated before
  // the providers are reset — otherwise a reply that lands in between would
  // repopulate what we just cleared.
  _scannerSessionEpoch++;
  ref.invalidate(customScansSessionProvider);
  ref.invalidate(lastCustomRunProvider);
  // Send the scanner back to its dashboard, so the next login opens on the
  // landing page instead of the previous user's sub-page or open scan.
  ref.invalidate(scannerShellProvider);
}

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

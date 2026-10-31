import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;
import 'package:mynt_plus/screens/web/scanner/utils/export_scan_rows.dart';
import 'package:mynt_plus/screens/web/scanner/utils/scanner_tokens.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_chips.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/index_filter_dropdown.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';
import 'custom_scan_builder_pane.dart';

/// Default index filter — NIFTY 50 pre-selected so both the initial run and
/// the pane's filter dropdown start on the smallest, fastest universe. The
/// dropdown widens it to NIFTY 500 or the full catalog on demand; a broad
/// default made every first run slow enough to hit gateway timeouts.
const List<String> _kDefaultCustomScanIndices = ['NIFTY 50'];

/// Runs a saved scan into the session's results slot (showing a loader
/// first). A result is dropped if the user picked a different scan while it
/// was in flight, or if the session it belongs to has ended.
///
/// [preload] is the background run made when the scanner page opens (the
/// shell's IndexedStack builds this page off-screen). It evaluates the saved
/// predicate via the ad-hoc run endpoint so it doesn't count as a user run
/// (run count / last run stay untouched). User clicks use the saved-scan run
/// and refresh the list so runs / last-run update.
Future<void> _runSavedScan(
  WidgetRef ref,
  SavedCustomScan scan, {
  List<String> indices = _kDefaultCustomScanIndices,
  bool preload = false,
}) async {
  final api = locator<ApiExporter>();
  final notifier = ref.read(customScansSessionProvider.notifier);
  // Captured before the await. If the user logs out mid-flight this scan
  // belongs to an account that is no longer signed in, and its reply must be
  // dropped rather than written into the next user's screen.
  final epoch = scannerSessionEpoch;
  bool stillActive() =>
      isSameScannerSession(epoch) &&
      ref.read(customScansSessionProvider).results?.scan.id == scan.id;
  final idx = indices.isEmpty ? null : indices;
  // A predicate that failed to decode falls back to the saved-scan run.
  final adHoc = preload && scan.predicateJson.isNotEmpty;
  notifier.openResults(scan);
  try {
    final r = adHoc
        ? await api.runCustomScan(predicate: scan.predicateJson, indices: idx)
        : await api.runSavedCustomScan(scan.id, indices: idx);
    if (stillActive()) notifier.setResults(AsyncValue.data(r));
    // Only refresh the saved list for the account that asked for the run.
    if (!adHoc && isSameScannerSession(epoch)) {
      ref.invalidate(savedCustomScansProvider(savedCustomScansKey()));
    }
  } catch (e, st) {
    if (stillActive()) notifier.setResults(AsyncValue.error(e, st));
  }
}

/// The scan to open by default — the most recently run one, else the first.
SavedCustomScan _defaultScan(List<SavedCustomScan> list) {
  SavedCustomScan best = list.first;
  for (final s in list) {
    final a = s.lastRunAt;
    final b = best.lastRunAt;
    if (a != null && (b == null || a.compareTo(b) > 0)) best = s;
  }
  return best;
}

/// Custom Scans — toolbar on top, then saved scans on the left and the
/// selected scan's results on the right. Opens on the most recently run
/// scan. The builder (new / edit) takes over the whole page while open.
class CustomScansSubPage extends ConsumerStatefulWidget {
  const CustomScansSubPage({super.key});

  @override
  ConsumerState<CustomScansSubPage> createState() => _CustomScansSubPageState();
}

class _CustomScansSubPageState extends ConsumerState<CustomScansSubPage> {
  bool _autoRunQueued = false;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  // No explicit refetch on mount. `savedCustomScansProvider` is keyed by
  // client id, so this page can only ever read the signed-in account's scans,
  // and it is autoDispose, so a fresh mount of the Scanner has no cache to
  // serve and fetches on its own. Invalidating here as well would throw that
  // in-flight fetch away and start a second identical request on every open.

  // The search field's X button only empties the text box; it never calls
  // onClear. Reset the query here when the box goes empty.
  void _onSearchTextChanged() {
    if (_search.text.isEmpty && _query.isNotEmpty) {
      setState(() => _query = '');
    }
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchTextChanged);
    _search.dispose();
    super.dispose();
  }

  /// Nothing selected yet — open the default scan after this frame.
  ///
  /// This is a deliberate prefetch: the shell's IndexedStack builds this page
  /// even while the user is on the Dashboard, so by the time they click into
  /// Custom Scans the results are already there and the page feels instant.
  /// The caller gates it on the Dashboard's own list having arrived first, so
  /// the prefetch never competes with the page actually on screen.
  void _queueDefaultRun(List<SavedCustomScan> list) {
    if (_autoRunQueued) return;
    _autoRunQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoRunQueued = false;
      if (!mounted) return;
      final session = ref.read(customScansSessionProvider);
      if (session.results != null || session.builder != null) return;
      _runSavedScan(ref, _defaultScan(list), preload: true);
    });
  }

  Future<void> _delete(SavedCustomScan scan) async {
    if (!await _confirmDelete(context, scan.name)) return;
    try {
      await locator<ApiExporter>().deleteSavedCustomScan(scan.id);
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Could not delete "${scan.name}"');
      return;
    }
    if (!mounted) return;
    final notifier = ref.read(customScansSessionProvider.notifier);
    // Deleting the open scan clears the right side; the default re-opens.
    if (ref.read(customScansSessionProvider).results?.scan.id == scan.id) {
      notifier.closeResults();
    }
    ref.invalidate(savedCustomScansProvider(savedCustomScansKey()));
    ResponsiveSnackBar.showSuccess(context, 'Deleted "${scan.name}"');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(customScansSessionProvider);
    if (session.builder != null) {
      return CustomScanBuilderPane(
        onClose: () => ref
            .read(customScansSessionProvider.notifier)
            .closeBuilder(),
      );
    }

    final async = ref.watch(savedCustomScansProvider(savedCustomScansKey()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar — the Fundamental Screener's slab: back + title/subtitle on
        // the left, primary "New custom scan" on the right.
        Container(
          padding: ScannerTokens.toolbarPadding,
          decoration: ScannerTokens.toolbar(context),
          child: Row(children: [
            CustomBackBtn(
              onBack: () => ref
                  .read(scannerShellProvider.notifier)
                  .setActiveSubPage(ScannerSubPage.scannersNew),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Custom Scans',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScannerTokens.pageTitle(context)),
                  const SizedBox(height: 2),
                  Text(
                    'Scan the market on technicals — RSI, moving averages, '
                    'price action and candlestick patterns',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScannerTokens.pageSubtitle(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            MyntButton(
              type: MyntButtonType.primary,
              label: 'New custom scan',
              icon: Icons.add,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              onPressed: () => ref
                  .read(customScansSessionProvider.notifier)
                  .openNewBuilder(),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => Center(child: MyntLoader.branded()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load custom scans',
              message: e.toString(),
              onRetry: () => ref
                  .invalidate(savedCustomScansProvider(savedCustomScansKey())),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No custom scans yet',
                  message:
                      'Click "+ New custom scan" above to build your first scan.',
                );
              }
              final results = session.results;
              // Hold the prefetch until the Dashboard's scanner list has
              // landed. Without this it fires on the very first frame of the
              // Scanner opening and races the list the user is waiting to
              // see — on a slow connection that is the one request that must
              // not be queued behind anything else. Watched, not polled: the
              // page rebuilds by itself when the list resolves.
              final dashboardReady = ref.watch(scannerListProvider).hasValue;
              if (results == null && dashboardReady) _queueDefaultRun(list);
              final q = _query.trim().toLowerCase();
              final shown = q.isEmpty
                  ? list
                  : list
                      .where((s) => s.name.toLowerCase().contains(q))
                      .toList();
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidebar — one white panel: a search field, then the
                    // saved scans as compact tab rows.
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        color: ScannerTokens.surface(context),
                        borderRadius:
                            BorderRadius.circular(ScannerTokens.rCard),
                        border:
                            Border.all(color: ScannerTokens.border(context)),
                        boxShadow: ScannerTokens.lift(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            child: SizedBox(
                              height: 40,
                              child: MyntSearchTextField.withSmartClear(
                                controller: _search,
                                placeholder: 'Search',
                                leadingIcon: assets.searchIcon,
                                textCapitalization: TextCapitalization.none,
                                onChanged: (v) => setState(() => _query = v),
                                onClear: () => setState(() => _query = ''),
                              ),
                            ),
                          ),
                          Divider(
                              height: 1,
                              color: ScannerTokens.border(context)),
                          Expanded(
                            child: shown.isEmpty
                                ? Center(
                                    child: Text('No scans match',
                                        style: MyntWebTextStyles.body(context,
                                            color: ScannerTokens.textSecondary(
                                                context))),
                                  )
                                : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: shown.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 12,
                                  endIndent: 12,
                                  color: ScannerTokens.border(context)),
                              itemBuilder: (_, i) {
                                final s = shown[i];
                                return _ScanRow(
                                  scan: s,
                                  active: results?.scan.id == s.id,
                                  onRun: () => _runSavedScan(ref, s),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: results == null
                          ? Center(child: MyntLoader.branded())
                          : _SavedScanResultsPane(
                              view: results,
                              onDelete: () => _delete(results.scan),
                            ),
                    ),
                  ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One saved scan in the sidebar — a tab row: the name, its created date,
/// then runs · last run. Tapping runs it into the right side; the active row
/// takes the accent tint. Edit / Delete live in the results header.
class _ScanRow extends StatelessWidget {
  final SavedCustomScan scan;
  final bool active;
  final VoidCallback onRun;
  const _ScanRow({
    required this.scan,
    required this.active,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = ScannerTokens.textSecondary(context);
    final hasRun = scan.lastRunAt != null;
    final lastRunLabel =
        hasRun ? 'Last run ${formatDate(scan.lastRunAt)}' : 'Never run';
    final runsLabel =
        '${scan.runCount} ${scan.runCount == 1 ? "run" : "runs"}';
    final metaStyle = MyntWebTextStyles.caption(context, color: textSecondary);
    final accent = ScannerTokens.accent(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: active ? null : onRun,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(ScannerTokens.rTag),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scan.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.body(context,
                    fontWeight: active ? MyntFonts.semiBold : MyntFonts.medium,
                    color:
                        active ? accent : ScannerTokens.textPrimary(context)),
              ),
              const SizedBox(height: 4),
              Text('Created ${formatDate(scan.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle),
              const SizedBox(height: 2),
              Text('$runsLabel · $lastRunLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// App-style delete confirm (shadcn.Card → header + centered text + red
/// full-width Delete) — matches the MF Strategy / Fundamental Screener dialog.
Future<bool> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(dCtx,
                  dark: MyntColors.dialogDark, light: MyntColors.dialog),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: shadcn.Theme.of(dCtx).colorScheme.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delete custom scan',
                          style: MyntWebTextStyles.title(dCtx,
                              color: resolveThemeColor(dCtx,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary))),
                      MyntCloseButton(
                          onPressed: () => Navigator.of(dCtx).pop(false)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Are you sure you want to delete "$name"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(dCtx,
                            fontWeight: MyntFonts.medium,
                            color: resolveThemeColor(dCtx,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary)),
                      ),
                      const SizedBox(height: 24),
                      MyntButton(
                        type: MyntButtonType.primary,
                        size: MyntButtonSize.large,
                        label: 'Delete',
                        isFullWidth: true,
                        backgroundColor: resolveThemeColor(dCtx,
                            dark: MyntColors.errorDark,
                            light: MyntColors.tertiary),
                        onPressed: () => Navigator.of(dCtx).pop(true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ok == true;
}

/// Right side of the Custom Scans page — the selected scan's name and match
/// count, the index filter, Edit and Delete, then its results table.
class _SavedScanResultsPane extends ConsumerStatefulWidget {
  final SavedScanResultsView view;
  final VoidCallback onDelete;
  const _SavedScanResultsPane({required this.view, required this.onDelete});

  @override
  ConsumerState<_SavedScanResultsPane> createState() =>
      _SavedScanResultsPaneState();
}

class _SavedScanResultsPaneState extends ConsumerState<_SavedScanResultsPane> {
  /// Per-scan index filter, owned by this pane only. Switching to a
  /// different saved scan (via `didUpdateWidget`) resets to the default.
  List<String> _selectedIndices = _kDefaultCustomScanIndices;

  @override
  void didUpdateWidget(covariant _SavedScanResultsPane old) {
    super.didUpdateWidget(old);
    if (old.view.scan.id != widget.view.scan.id) {
      setState(() => _selectedIndices = _kDefaultCustomScanIndices);
    }
  }

  /// Re-runs the saved scan with the supplied index filter. Used by both
  /// the dropdown's onChanged and the error state's retry button.
  Future<void> _rerun(List<String> indices) =>
      _runSavedScan(ref, widget.view.scan, indices: indices);

  void _onFilterChanged(List<String> next) {
    setState(() => _selectedIndices = List.unmodifiable(next));
    _rerun(next);
  }

  /// Downloads the rows on screen. There is no server-side export for a saved
  /// custom scan, and the run is index-filtered client-side anyway, so the
  /// only correct source is the result in hand.
  Future<void> _exportResults() async {
    final r = widget.view.result.asData?.value;
    if (r == null || r.matches.isEmpty) return;
    try {
      await exportScanRowsXlsx(
        columns: [
          for (final c in r.columns)
            ScanColumn(key: c.key, label: c.label, fmt: 'raw'),
        ],
        rows: [
          for (final m in r.matches)
            ScanRow(
              ticker: m.ticker,
              name: m.name,
              values: Map<String, dynamic>.from(m.values),
            ),
        ],
        sheetName: widget.view.scan.name,
        fileName: '${scanFileSlug(widget.view.scan.name)}.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final scan = view.scan;
    final selectedIndices = _selectedIndices;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ScannerTokens.surface(context),
        borderRadius: BorderRadius.circular(ScannerTokens.rCard),
        border: Border.all(color: ScannerTokens.border(context)),
        boxShadow: ScannerTokens.lift(context),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.semiBold,
                      color: ScannerTokens.textPrimary(context)),
                ),
                // Match count only once results are in — nothing while
                // the scan runs.
                ...view.result.maybeWhen(
                  data: (r) => [
                    const SizedBox(height: 2),
                    Text(
                      '${r.matches.length} matches · as of ${formatDate(r.asOf)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.caption(context,
                          color: ScannerTokens.textSecondary(context)),
                    ),
                  ],
                  orElse: () => const <Widget>[],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IndexFilterDropdown(
            selected: selectedIndices,
            onChanged: _onFilterChanged,
            matchCounts: view.result.maybeWhen(
              data: (r) => r.indexCounts,
              orElse: () => const <String, int>{},
            ),
          ),
          const SizedBox(width: 8),
          ScannerChipButton(
            icon: shadcn.LucideIcons.download,
            tooltip: 'Download results',
            height: 34,
            // Disabled until a run has landed — there is nothing to write yet.
            onTap: view.result.asData?.value.matches.isNotEmpty == true
                ? _exportResults
                : null,
          ),
          const SizedBox(width: 8),
          ScannerChipButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit this scan',
            height: 34,
            onTap: () => ref
                .read(customScansSessionProvider.notifier)
                .openExistingBuilder(scan),
          ),
          const SizedBox(width: 8),
          ScannerChipButton(
            icon: shadcn.LucideIcons.trash2,
            tooltip: 'Delete this scan',
            height: 34,
            iconColor: resolveThemeColor(context,
                dark: MyntColors.errorDark, light: MyntColors.error),
            onTap: widget.onDelete,
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: view.result.when(
            loading: () => Center(child: MyntLoader.branded()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not run scan',
              message: e.toString(),
              onRetry: () => _rerun(selectedIndices),
            ),
            data: (r) {
              if (r.matches.isEmpty) {
                if (selectedIndices.isNotEmpty) {
                  return EmptyState(
                    kind: EmptyStateKind.empty,
                    title: 'No matches in the selected indices',
                    message:
                        'No stocks in ${selectedIndices.join(", ")} match this scan today.',
                  );
                }
                return const EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No matches today',
                );
              }
              // Predicate-derived columns — server gave us key+label, no
              // fmt. Default 'raw' renders as 2-decimal fixed via the
              // table's built-in formatter, which is right for indicator
              // values like `rsi(14) = 28.13`.
              final cols = [
                for (final c in r.columns)
                  ScanColumn(key: c.key, label: c.label, fmt: 'raw'),
              ];
              final rows = [
                for (final m in r.matches)
                  ScanRow(ticker: m.ticker, name: m.name, values: m.values),
              ];
              final filterSuffix = selectedIndices.isEmpty
                  ? ''
                  : ' · filtered by ${selectedIndices.join(", ")}';
              return ScannerResultsTable(
                columns: cols,
                rows: rows,
                footer: '${r.matches.length} matches$filterSuffix',
                onTickerTap: (t) =>
                    openScannerScripFromContext(context, ref, ticker: t),
                onExplainTap: (t) => ref
                    .read(scannerShellProvider.notifier)
                    .openExplain(ExplainKey(
                      scope: ExplainScope.custom,
                      id: scan.id.toString(),
                      ticker: t,
                    )),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}


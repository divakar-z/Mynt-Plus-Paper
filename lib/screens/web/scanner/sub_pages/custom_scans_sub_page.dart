import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/index_filter_dropdown.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';
import 'custom_scan_builder_pane.dart';

class CustomScansSubPage extends ConsumerWidget {
  const CustomScansSubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(customScansSessionProvider);
    if (session.builder != null) {
      return CustomScanBuilderPane(
        onClose: () => ref
            .read(customScansSessionProvider.notifier)
            .closeBuilder(),
      );
    }
    if (session.results != null) {
      return _SavedScanResultsPane(view: session.results!);
    }

    final async = ref.watch(savedCustomScansProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New custom scan'),
            onPressed: () => ref
                .read(customScansSessionProvider.notifier)
                .openNewBuilder(),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => Center(child: MyntLoader.branded()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load custom scans',
              message: e.toString(),
              onRetry: () => ref.invalidate(savedCustomScansProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No custom scans yet',
                  message:
                      'Click "+ New custom scan" above to write your first predicate.',
                );
              }
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final s in list)
                      _ScanCard(
                        scan: s,
                        onEdit: () => ref
                            .read(customScansSessionProvider.notifier)
                            .openExistingBuilder(s),
                        onChanged: () =>
                            ref.invalidate(savedCustomScansProvider),
                      )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends ConsumerWidget {
  final SavedCustomScan scan;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  const _ScanCard({
    required this.scan,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(scan.name,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.semiBold)),
              const SizedBox(height: 4),
              Text('Created ${formatDateTime(scan.createdAt)}',
                  style: MyntWebTextStyles.caption(context)),
              Text(
                  'Runs: ${scan.runCount}  ·  Last ${formatDateTime(scan.lastRunAt)}',
                  style: MyntWebTextStyles.caption(context)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('Run'),
                  // Switch the sub-page into results view (which shows a
                  // loading spinner) and fire the run in the background.
                  // The notifier handles success/error; `onChanged` refreshes
                  // the saved-scans list so the run-count + lastRunAt update
                  // the next time the user pops back to the card grid.
                  onPressed: () async {
                    final notifier =
                        ref.read(customScansSessionProvider.notifier);
                    // Fresh run = no filter. The results pane owns its
                    // own filter state from this point on; the user can
                    // narrow inline without their previous selection
                    // leaking in from somewhere else.
                    notifier.openResults(scan);
                    try {
                      final r = await locator<ApiExporter>()
                          .runSavedCustomScan(scan.id);
                      notifier.setResults(AsyncValue.data(r));
                      onChanged();
                    } catch (e, st) {
                      notifier.setResults(AsyncValue.error(e, st));
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: MyntColors.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete custom scan?'),
                        content: Text('"${scan.name}" will be removed.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await locator<ApiExporter>()
                          .deleteSavedCustomScan(scan.id);
                      onChanged();
                    }
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Results view for "user clicked Run on a saved custom scan". Replaces
/// the cards list while open; back arrow returns to the cards. Mirrors
/// the layout of `ScannersDetailPane` so users get the same UX whether
/// they're viewing a built-in or a custom scanner.
class _SavedScanResultsPane extends ConsumerStatefulWidget {
  final SavedScanResultsView view;
  const _SavedScanResultsPane({required this.view});

  @override
  ConsumerState<_SavedScanResultsPane> createState() =>
      _SavedScanResultsPaneState();
}

class _SavedScanResultsPaneState extends ConsumerState<_SavedScanResultsPane> {
  /// Per-scan index filter, owned by this pane only. Switching to a
  /// different saved scan (via `didUpdateWidget`) resets the selection
  /// so each Run starts on the full universe.
  List<String> _selectedIndices = const [];

  @override
  void didUpdateWidget(covariant _SavedScanResultsPane old) {
    super.didUpdateWidget(old);
    if (old.view.scan.id != widget.view.scan.id &&
        _selectedIndices.isNotEmpty) {
      setState(() => _selectedIndices = const []);
    }
  }

  /// Re-runs the saved scan with the supplied index filter. Used by both
  /// the dropdown's onChanged and the error state's retry button.
  Future<void> _rerun(List<String> indices) async {
    final scan = widget.view.scan;
    final notifier = ref.read(customScansSessionProvider.notifier);
    notifier.openResults(scan);
    try {
      final r = await locator<ApiExporter>().runSavedCustomScan(
        scan.id,
        indices: indices.isEmpty ? null : indices,
      );
      notifier.setResults(AsyncValue.data(r));
    } catch (e, st) {
      notifier.setResults(AsyncValue.error(e, st));
    }
  }

  void _onFilterChanged(List<String> next) {
    setState(() => _selectedIndices = List.unmodifiable(next));
    _rerun(next);
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final scan = view.scan;
    final selectedIndices = _selectedIndices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row + filter dropdown — wrapped in a Wrap so the
        // dropdown drops onto a second line on narrow viewports
        // instead of being pushed off the right edge by the Expanded
        // column. Matches the built-in scanner detail pane's layout.
        Row(children: [
          IconButton(
            onPressed: () => ref
                .read(customScansSessionProvider.notifier)
                .closeResults(),
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: 'Back to custom scans',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.name,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.bold)),
                view.result.maybeWhen(
                  data: (r) => Text(
                    '${r.matches.length} matches · as of ${r.asOf}',
                    style: MyntWebTextStyles.caption(context),
                  ),
                  orElse: () => const Text(''),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IndexFilterDropdown(
            selected: selectedIndices,
            onChanged: _onFilterChanged,
            matchCounts: view.result.maybeWhen(
              data: (r) => r.indexCounts,
              orElse: () => const <String, int>{},
            ),
          ),
        ]),
        if (selectedIndices.isNotEmpty) ...[
          const SizedBox(height: 12),
          ActiveIndexFilterChips(
            selected: selectedIndices,
            onChanged: _onFilterChanged,
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: view.result.when(
            loading: () => Center(child: MyntLoader.simple()),
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
    );
  }
}


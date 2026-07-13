import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
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

/// Default index filter — NIFTY 500 pre-selected so both the initial run
/// and the pane's filter dropdown start on a liquid, actionable universe
/// instead of the full NSE catalog.
const List<String> _kDefaultCustomScanIndices = ['NIFTY 500'];

/// Custom Scans tab — saved-scans list, "New custom scan" builder, and the
/// results view for a saved scan. The predicate builder handles both
/// fundamental and technical conditions (the old chip-based Technicals tab
/// has been retired).
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
        // Header — title on the left, primary "New custom scan" on the right
        // (matches the MF Strategy dashboard / Fundamental Screener header).
        Row(children: [
          Text('Custom Scans',
              style:
                  MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold)),
          const Spacer(),
          MyntButton(
            type: MyntButtonType.primary,
            label: 'New custom scan',
            icon: Icons.add,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onPressed: () => ref
                .read(customScansSessionProvider.notifier)
                .openNewBuilder(),
          ),
        ]),
        const SizedBox(height: 16),
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
              return _ScansTable(
                list: list,
                onChanged: () => ref.invalidate(savedCustomScansProvider),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Responsive card grid for saved custom scans — 4 / 3 / 2 / 1 columns based
/// on available width. Cards use a fixed height so every card in the grid
/// aligns cleanly regardless of column count or content length. Border only
/// (no drop shadow) so the surface stays flat and matches the rest of the
/// screener chrome.
class _ScansTable extends ConsumerWidget {
  final List<SavedCustomScan> list;
  final VoidCallback onChanged;
  const _ScansTable({required this.list, required this.onChanged});

  /// Uniform card height keeps every row of the grid aligned even when the
  /// meta line ("Never run" vs. "Last run 10 Jul 2026") differs across cards.
  static const double _kCardHeight = 118.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (ctx, c) {
        const spacing = 14.0;
        // 4 up on wide screens, gracefully falling back to 3 / 2 / 1.
        final columns = c.maxWidth >= 1280
            ? 4
            : c.maxWidth >= 960
                ? 3
                : c.maxWidth >= 640
                    ? 2
                    : 1;
        final cardWidth =
            (c.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final s in list)
              SizedBox(
                width: cardWidth,
                height: _kCardHeight,
                child: _ScanRow(
                  scan: s,
                  onEdit: () => ref
                      .read(customScansSessionProvider.notifier)
                      .openExistingBuilder(s),
                  onChanged: onChanged,
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// A single saved-scan row in the table — identity icon + name on the left,
/// Created / Runs / Last-run metadata across, and a 3-dot Edit / Delete menu
/// at the trailing edge. Row click runs the scan.
class _ScanRow extends ConsumerStatefulWidget {
  final SavedCustomScan scan;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  const _ScanRow({
    required this.scan,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  ConsumerState<_ScanRow> createState() => _ScanRowState();
}

class _ScanRowState extends ConsumerState<_ScanRow> {
  bool _hover = false;

  /// Run the saved scan — switch the sub-page into results view (which shows a
  /// loading spinner) and fire the run. The notifier handles success/error;
  /// `onChanged` refreshes the saved-scans list so the run-count + lastRunAt
  /// update the next time the user pops back to the card grid.
  Future<void> _run() async {
    final scan = widget.scan;
    final notifier = ref.read(customScansSessionProvider.notifier);
    notifier.openResults(scan);
    try {
      // First run uses the same default the results pane pre-selects, so the
      // table and the filter dropdown agree from the first frame.
      final r = await locator<ApiExporter>().runSavedCustomScan(
        scan.id,
        indices: _kDefaultCustomScanIndices,
      );
      notifier.setResults(AsyncValue.data(r));
      widget.onChanged();
    } catch (e, st) {
      notifier.setResults(AsyncValue.error(e, st));
    }
  }

  Future<void> _delete() async {
    if (await _confirmDelete(widget.scan.name)) {
      await locator<ApiExporter>().deleteSavedCustomScan(widget.scan.id);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    // Portfolio card chrome — divider-tone border, dashboard-card BG in dark,
    // shadcn card BG in light. Copied verbatim so the two card families look
    // like siblings.
    final cardBg = isDarkMode(context)
        ? MyntColors.dashboardCarColor
        : shadcn.Theme.of(context).colorScheme.card;
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final textSecondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final chipBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final hasRun = scan.lastRunAt != null;
    final lastRunLabel =
        hasRun ? 'Last run ${formatDate(scan.lastRunAt)}' : 'Never run';
    final runsLabel =
        '${scan.runCount} ${scan.runCount == 1 ? "run" : "runs"}';
    final createdLabel = 'Created ${formatDate(scan.createdAt)}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _run,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _hover ? primary.withValues(alpha: 0.55) : borderColor,
                width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — icon + (name, created-date subtitle) + menu.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(shadcn.LucideIcons.code,
                          size: 16, color: primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            scan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.symbol(context,
                                fontWeight: MyntFonts.semiBold,
                                color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            createdLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.exch(context,
                                color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _menu(textSecondary),
                  ],
                ),
              ),
              const Spacer(),
              // Footer strip — divider on top, runs count on the left, and a
              // status pill on the right. Fills the card's bottom so every
              // card lines up regardless of name length.
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(shadcn.LucideIcons.play,
                        size: 12, color: textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      runsLabel,
                      style: MyntWebTextStyles.exch(context,
                          fontWeight: MyntFonts.medium,
                          color: textSecondary),
                    ),
                    const Spacer(),
                    Flexible(
                      child: _statusPill(
                        context,
                        label: lastRunLabel,
                        muted: textSecondary,
                        chipBg: chipBg,
                        accent: hasRun ? null : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact status pill for the footer's last-run label. Subtle background
  /// + secondary text; keeps the footer readable without competing with the
  /// scan name in the header.
  Widget _statusPill(
    BuildContext context, {
    required String label,
    required Color muted,
    required Color chipBg,
    Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.exch(context,
            fontWeight: FontWeight.w500, color: accent ?? muted),
      ),
    );
  }

  // 3-dot trigger → opens the app's standard dropdown popover (the same
  // shadcn popover the MF Strategy cards use).
  Widget _menu(Color iconColor) {
    return Builder(
      builder: (buttonContext) {
        return Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: resolveThemeColor(context,
                dark: MyntColors.rippleDark, light: MyntColors.rippleLight),
            highlightColor: resolveThemeColor(context,
                dark: MyntColors.highlightDark,
                light: MyntColors.highlightLight),
            onTap: () => _showCardPopover(buttonContext),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_vert, size: 20, color: iconColor),
            ),
          ),
        );
      },
    );
  }

  void _showCardPopover(BuildContext buttonContext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final loss = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    shadcn.showPopover(
      context: buttonContext,
      alignment: Alignment.topLeft,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(buttonContext).borderRadiusLg,
      ),
      builder: (popCtx) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popCtx).borderRadiusLg,
            boxShadow:
                isDark ? MyntShadows.dropdownDark : MyntShadows.dropdown,
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: 160,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPopoverItem(
                    popCtx,
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    iconColor: primary,
                    textColor: textPrimary,
                    onTap: () {
                      shadcn.closeOverlay(popCtx);
                      widget.onEdit();
                    },
                  ),
                  _buildPopoverItem(
                    popCtx,
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    iconColor: loss,
                    textColor: loss,
                    onTap: () {
                      shadcn.closeOverlay(popCtx);
                      _delete();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopoverItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: resolveThemeColor(context,
            dark: MyntColors.rippleDark, light: MyntColors.rippleLight),
        highlightColor: resolveThemeColor(context,
            dark: MyntColors.highlightDark, light: MyntColors.highlightLight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Text(label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  /// App-style delete confirm (shadcn.Card → header + centered text + red
  /// full-width Delete) — matches the MF Strategy / Fundamental Screener dialog.
  Future<bool> _confirmDelete(String name) async {
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
        // Header — back + scan name (head bold) with a match-count subtitle,
        // and the index filter on the right. Matches the other screen headers.
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconButton(
            onPressed: () => ref
                .read(customScansSessionProvider.notifier)
                .closeResults(),
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: 'Back to custom scans',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  scan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.head(context,
                      fontWeight: MyntFonts.bold,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary)),
                ),
                view.result.maybeWhen(
                  data: (r) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${r.matches.length} matches · as of ${r.asOf}',
                      style: MyntWebTextStyles.para(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IndexFilterDropdown(
            selected: selectedIndices,
            onChanged: _onFilterChanged,
            matchCounts: view.result.maybeWhen(
              data: (r) => r.indexCounts,
              orElse: () => const <String, int>{},
            ),
          ),
        ]),
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


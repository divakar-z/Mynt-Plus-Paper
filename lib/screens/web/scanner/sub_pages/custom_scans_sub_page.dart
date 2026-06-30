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
              // Responsive card grid (3 / 2 / 1 columns) like the MF Strategy
              // dashboard — cards fill the row width instead of a fixed size.
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: LayoutBuilder(builder: (ctx, c) {
                  const spacing = 16.0;
                  final columns = c.maxWidth > 900
                      ? 3
                      : c.maxWidth > 500
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
                          child: _ScanCard(
                            scan: s,
                            onEdit: () => ref
                                .read(customScansSessionProvider.notifier)
                                .openExistingBuilder(s),
                            onChanged: () =>
                                ref.invalidate(savedCustomScansProvider),
                          ),
                        ),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// MF-Strategy-style card: identity icon + name + 3-dot (Edit / Delete) menu,
/// a divider, and a Created / Runs / Last-run stat row. Tap the card to Run the
/// scan (the play hint at the bottom signals this).
class _ScanCard extends ConsumerStatefulWidget {
  final SavedCustomScan scan;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  const _ScanCard({
    required this.scan,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  ConsumerState<_ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends ConsumerState<_ScanCard> {
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
      final r = await locator<ApiExporter>().runSavedCustomScan(scan.id);
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
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _run,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hover
                ? resolveThemeColor(context,
                    dark: MyntColors.cardHoverDark, light: MyntColors.cardHover)
                : resolveThemeColor(context,
                    dark: MyntColors.cardDark, light: MyntColors.card),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? primary : border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Identity icon + name + 3-dot (Edit / Delete).
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.code, size: 18, color: primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(scan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.title(context,
                            fontWeight: MyntFonts.semiBold, color: textColor)),
                  ),
                  _menu(muted),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              // Created / Runs / Last run — mirrors the MF card's stat row.
              IntrinsicHeight(
                child: Row(
                  children: [
                    _stat('Created', formatDateTime(scan.createdAt), muted,
                        textColor),
                    VerticalDivider(width: 20, thickness: 1, color: border),
                    _stat('Runs', '${scan.runCount}', muted, textColor),
                    VerticalDivider(width: 20, thickness: 1, color: border),
                    _stat('Last run', formatDateTime(scan.lastRunAt), muted,
                        textColor),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tap-to-run hint.
              Row(
                children: [
                  Icon(Icons.play_arrow_rounded, size: 16, color: primary),
                  const SizedBox(width: 4),
                  Text('Run scan',
                      style: MyntWebTextStyles.caption(context,
                          color: primary, fontWeight: MyntFonts.semiBold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(
      String label, String value, Color labelColor, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: MyntWebTextStyles.caption(context, color: labelColor)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold, color: valueColor)),
        ],
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


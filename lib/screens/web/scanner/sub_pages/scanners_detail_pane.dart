import 'package:flutter/material.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/models/scanner_model/indicator_catalog.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_chips.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/scan_explain.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/index_filter_dropdown.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/utils/export_scan_rows.dart';
import 'package:mynt_plus/screens/web/scanner/utils/scanner_tokens.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

/// "Save as custom scan" name prompt — same dialog as the fundamental
/// screener's "Save screen". Returns the trimmed name, or null if dismissed.
/// Shared by this pane and the custom scan builder.
Future<String?> showScanNameDialog(BuildContext context,
        {String initial = '',
        String title = 'Save as custom scan',
        String prompt = 'Enter a name for this scan',
        String placeholder = 'Scan name'}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ScanNameDialog(
        initial: initial,
        title: title,
        prompt: prompt,
        placeholder: placeholder,
      ),
    );

/// Owns its text controller so it is disposed only when the dialog is
/// unmounted. Disposing it as soon as `showDialog` returns is too early: the
/// route is still animating out, and when the focused field then loses focus
/// it writes to the dead controller and tears the tree down mid-frame.
class _ScanNameDialog extends StatefulWidget {
  final String initial;
  final String title;
  final String prompt;
  final String placeholder;
  const _ScanNameDialog({
    required this.initial,
    required this.title,
    required this.prompt,
    required this.placeholder,
  });

  @override
  State<_ScanNameDialog> createState() => _ScanNameDialogState();
}

class _ScanNameDialogState extends State<_ScanNameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _errorText;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _trySave() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter a name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: shadcn.Card(
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.zero,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
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
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.title,
                        style: MyntWebTextStyles.title(context,
                            color: textPrimary)),
                    MyntCloseButton(
                        onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.prompt,
                        style: MyntWebTextStyles.body(context,
                            color: textPrimary)),
                    const SizedBox(height: 12),
                    MyntFormTextField(
                      controller: _ctrl,
                      placeholder: widget.placeholder,
                      height: 40,
                      autofocus: true,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      onSubmitted: (_) => _trySave(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorText!,
                          style: MyntWebTextStyles.caption(context,
                              color: resolveThemeColor(context,
                                  dark: MyntColors.lossDark,
                                  light: MyntColors.loss))),
                    ],
                    const SizedBox(height: 20),
                    MyntButton(
                      type: MyntButtonType.primary,
                      label: 'Save',
                      isFullWidth: true,
                      onPressed: _trySave,
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
}

class ScannersDetailPane extends ConsumerStatefulWidget {
  final String code;
  final VoidCallback onBack;
  const ScannersDetailPane({super.key, required this.code, required this.onBack});

  @override
  ConsumerState<ScannersDetailPane> createState() => _ScannersDetailPaneState();
}

class _ScannersDetailPaneState extends ConsumerState<ScannersDetailPane> {
  /// Default index filter — NIFTY 50 is the smallest, fastest universe most
  /// scanners are meant to run against, so pre-selecting it keeps the first
  /// view actionable — and fast — instead of dumping the entire NSE catalog.
  /// Widened from the dropdown when the user wants more names.
  static const List<String> _kDefaultIndices = ['NIFTY 50'];

  /// Per-scanner index filter. Each scanner detail has its own filter
  /// state so switching scanners always starts fresh — sharing one filter
  /// across scanners caused stale chips to bleed into unrelated scanners.
  List<String> _selectedIndices = _kDefaultIndices;

  /// Editable copy of the scanner's predicate. The filter chips mutate its
  /// leaves in place; [_origPred] is kept for Reset.
  Map<String, dynamic>? _pred;
  Map<String, dynamic>? _origPred;
  bool _edited = false;

  /// Non-null once the user runs an edited predicate — the results area then
  /// shows this custom run instead of the scanner's precomputed results.
  AsyncValue<CustomScanRunResult>? _customRun;

  @override
  void didUpdateWidget(covariant ScannersDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Different scanner = fresh filter (reset back to the NIFTY 50 default).
    if (oldWidget.code != widget.code) {
      setState(() {
        _selectedIndices = _kDefaultIndices;
        _pred = null;
        _origPred = null;
        _edited = false;
        _customRun = null;
      });
    }
  }

  void _setIndices(List<String> next) {
    setState(() => _selectedIndices = List.unmodifiable(next));
    if (_customRun != null) _runEdited();
  }

  void _resetFilters() {
    setState(() {
      _pred = _origPred == null ? null : copyPredicate(_origPred!);
      _edited = false;
      _customRun = null;
    });
  }

  /// Runs the edited predicate through the custom-scan endpoint. With no
  /// edits it just drops back to the scanner's own results.
  Future<void> _runEdited() async {
    final pred = _pred;
    if (pred == null) return;
    if (!_edited) {
      setState(() => _customRun = null);
      return;
    }
    // Dropped if the session ends mid-flight — see [scannerSessionEpoch].
    final epoch = scannerSessionEpoch;
    setState(() => _customRun = const AsyncLoading());
    try {
      final r = await locator<ApiExporter>().runCustomScan(
        predicate: cleanPredicate(pred),
        indices: _selectedIndices.isEmpty ? null : _selectedIndices,
      );
      if (!mounted || !isSameScannerSession(epoch)) return;
      setState(() => _customRun = AsyncData(r));
    } catch (e, st) {
      if (!mounted || !isSameScannerSession(epoch)) return;
      setState(() => _customRun = AsyncError(e, st));
    }
  }

  /// Saves the current (possibly edited) conditions as a custom scan, which
  /// then shows up under Custom Scans.
  Future<void> _save() async {
    final pred = _pred;
    if (pred == null) return;
    final meta = ref.read(scannerDetailProvider(code)).asData?.value;
    final name = await showScanNameDialog(context,
        initial: meta == null ? '' : '${meta.displayName} (custom)');
    if (name == null || !mounted) return;
    try {
      await locator<ApiExporter>()
          .saveCustomScan(name: name, predicate: cleanPredicate(pred));
      ref.invalidate(savedCustomScansProvider(savedCustomScansKey()));
      if (!mounted) return;
      ResponsiveSnackBar.showSuccess(
          context, 'Saved "$name" — find it under Custom Scans');
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Save failed: $e');
    }
  }

  String get code => widget.code;
  VoidCallback get onBack => widget.onBack;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final meta = ref.watch(scannerDetailProvider(code));
    final selectedIndices = _selectedIndices;
    final results = ref.watch(scannerResultsProvider(
      ScannerResultsKey(code: code, indices: selectedIndices),
    ));
    final catalog = ref.watch(indicatorCatalogProvider).asData?.value;
    final p = meta.asData?.value.predicate;
    if (_pred == null && p != null) {
      _origPred = p;
      _pred = copyPredicate(p);
    }
    final customRun = _customRun;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page toolbar — the same raised slab the full scanner browser opens
        // with: back button + title + one-line subtitle on the left, the
        // page's controls on the right.
        Container(
          padding: ScannerTokens.toolbarPadding,
          decoration: ScannerTokens.toolbar(context),
          child: Row(children: [
            CustomBackBtn(onBack: onBack),
            const SizedBox(width: 10),
            Expanded(
              child: meta.when(
                loading: () => Text('Loading…',
                    style: ScannerTokens.pageTitle(context)),
                error: (_, __) => Text(code,
                    style: ScannerTokens.pageTitle(context)),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScannerTokens.pageTitle(context),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _groupColor(s.groupName)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(ScannerTokens.rTag),
                          ),
                          child: Text(
                            s.groupName,
                            style: MyntWebTextStyles.caption(context,
                                color: _groupColor(s.groupName),
                                fontWeight: MyntFonts.semiBold),
                          ),
                        ),
                        if (s.subGroup != null &&
                            s.subGroup!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              s.subGroup!,
                              overflow: TextOverflow.ellipsis,
                              style: ScannerTokens.pageSubtitle(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            IndexFilterDropdown(
              selected: selectedIndices,
              onChanged: _setIndices,
              // Empty map = old backend without match counts → dropdown
              // falls back to universe size; auto-updates when it ships.
              matchCounts: customRun != null
                  ? customRun.maybeWhen(
                      data: (r) => r.indexCounts,
                      orElse: () => const <String, int>{},
                    )
                  : results.maybeWhen(
                      data: (r) => r.indexCounts,
                      orElse: () => const <String, int>{},
                    ),
            ),
            const SizedBox(width: 8),
            _HoverIconButton(
              icon: Icons.download,
              tooltip: 'Export',
              onTap: () => _export(context),
            ),
            // Save / Run — same pair, same place as the Custom Scan toolbar.
            if (_pred != null) ...[
              const SizedBox(width: 8),
              ScannerChipButton(
                icon: shadcn.LucideIcons.save,
                label: 'Save',
                tooltip: 'Save this scan',
                height: 34,
                onTap: _save,
              ),
              const SizedBox(width: 8),
              MyntButton(
                type: MyntButtonType.primary,
                label: 'Run scan',
                icon: Icons.play_arrow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isLoading: customRun?.isLoading ?? false,
                onPressed: (customRun?.isLoading ?? false) ? null : _runEdited,
              ),
            ],
          ]),
        ),
        // What this scanner looks for, on the same recessed tray the full
        // scanner browser uses for its category panels.
        meta.maybeWhen(
          data: (s) {
            final text = (s.descriptionLong?.isNotEmpty ?? false)
                ? s.descriptionLong!
                : s.description;
            if (text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: ScannerTokens.tray(context),
                child: Text(
                  text,
                  style: MyntWebTextStyles.body(context,
                      color: ScannerTokens.textBody(context)),
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        if (_pred != null) _filterPanel(catalog),
        // Active filter chips row hidden — the select-style trigger already
        // surfaces the current selection ("<first> +N"), so the chip row
        // below the banner is redundant.
        // if (selectedIndices.isNotEmpty) ...[
        //   const SizedBox(height: 12),
        //   ActiveIndexFilterChips(
        //     selected: selectedIndices,
        //     onChanged: _setIndices,
        //   ),
        // ],
        const SizedBox(height: 16),
        Expanded(
          child: customRun != null
              ? _customResults(customRun)
              : results.when(
            loading: () => Center(child: MyntLoader.branded()),
            error: (e, _) => EmptyState(
              kind: EmptyStateKind.error,
              title: 'Could not load results',
              message: e.toString(),
              onRetry: () => ref.invalidate(scannerResultsProvider(
                ScannerResultsKey(code: code, indices: selectedIndices),
              )),
            ),
            data: (r) {
              if (r.matches.isEmpty) {
                // Index filter empties the result set — the API still
                // returned a clean 200, so surface a contextual hint
                // rather than the generic "no matches today" message.
                if (selectedIndices.isNotEmpty) {
                  return EmptyState(
                    kind: EmptyStateKind.empty,
                    title: 'No matches in the selected indices',
                    message:
                        'No stocks in ${selectedIndices.join(", ")} match this scanner today.',
                  );
                }
                return const EmptyState(
                  kind: EmptyStateKind.empty,
                  title: 'No matches today',
                );
              }
              final cols = _builtinColumns(r);
              final rows = _builtinRows(r);
              final visible = r.matches.length;
              final total = r.total;
              final filterSuffix = selectedIndices.isEmpty
                  ? ''
                  : ' · filtered by ${selectedIndices.join(", ")}';
              final footer = total > visible
                  ? 'Showing $visible of $total matches — increase limit or refine$filterSuffix'
                  : 'Showing $visible matches$filterSuffix';
              return ScannerResultsTable(
                columns: cols,
                rows: rows,
                footer: footer,
                onTickerTap: (t) =>
                    openScannerScripFromContext(context, ref, ticker: t),
                onExplainTap: (t) => ref
                    .read(scannerShellProvider.notifier)
                    .openExplain(ExplainKey(
                      scope: ExplainScope.builtin,
                      id: code,
                      ticker: t,
                    )),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Columns for the scanner's own (unedited) results. Shared by the table
  /// and the export so the file can never disagree with the screen.
  List<ScanColumn> _builtinColumns(ScanResultsDetail r) {
    final cols = [
      for (final c in r.columns)
        ScanColumn(
          key: c.key,
          label: c.label,
          fmt: c.fmt,
          description: c.description,
        ),
    ];
    // When the scanner surfaces both close and chg_pct (the common pair on
    // candlestick/price/momentum scanners), append an absolute rupee-change
    // column — traders read Chg (₹) alongside Chg (%) to gauge the move's
    // magnitude in real money.
    if (_hasCloseAndChg(r)) {
      cols.add(const ScanColumn(
        key: 'chg_abs',
        label: 'Chg (₹)',
        fmt: 'signed_price',
        description:
            'Absolute price change in rupees, derived from Close × Chg% / (100 + Chg%).',
      ));
    }
    return cols;
  }

  bool _hasCloseAndChg(ScanResultsDetail r) =>
      r.columns.any((c) => c.key == 'close') &&
      r.columns.any((c) => c.key == 'chg_pct');

  List<ScanRow> _builtinRows(ScanResultsDetail r) {
    final derived = _hasCloseAndChg(r);
    return [
      for (final m in r.matches)
        ScanRow(
          ticker: m.ticker,
          name: m.name,
          values: derived ? _withChgAbs(m.values) : m.values,
        ),
    ];
  }

  /// Fundamentals-style filter tray: + / Reset on the left, one chip per
  /// predicate condition. Save and Run scan live in the page toolbar.
  Widget _filterPanel(IndicatorCatalog? catalog) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PredicateFilterTray(
        predicate: _pred!,
        catalog: catalog,
        keepOne: true,
        // AND / OR / NOT grouping is a Custom Scans feature only.
        allowGroups: false,
        resetTooltip: 'Reset to scanner defaults',
        onReset: _edited || _customRun != null ? _resetFilters : null,
        onChanged: (p) => setState(() {
          _pred = p;
          _edited = true;
        }),
      ),
    );
  }

  /// Results of an edited run — same table the Custom Scans page uses.
  Widget _customResults(AsyncValue<CustomScanRunResult> run) {
    return run.when(
      loading: () => Center(child: MyntLoader.branded()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not run scan',
        message: e.toString(),
        onRetry: _runEdited,
      ),
      data: (r) {
        if (r.matches.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No matches for the edited filters',
          );
        }
        final filterSuffix = _selectedIndices.isEmpty
            ? ''
            : ' · filtered by ${_selectedIndices.join(", ")}';
        return ScannerResultsTable(
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
          footer: 'Showing ${r.matches.length} matches (edited filters)'
              '$filterSuffix',
          customCellFormatter: (ctx, col, raw) =>
              formatCustomScanCell(ctx, col.key, raw),
          onTickerTap: (t) =>
              openScannerScripFromContext(context, ref, ticker: t),
        );
      },
    );
  }

  // Category accent — mirrors the dashboard section colors.
  Color _groupColor(String g) {
    switch (g.toLowerCase()) {
      case 'candlestick':
        return const Color(0xFFDB7C26);
      case 'price':
        return resolveThemeColor(context, dark: MyntColors.secondaryDark, light: MyntColors.primary);
      case 'technical':
        return const Color(0xFF0F9D7A);
      case 'volume':
        return MyntColors.warning;
      default:
        return const Color(0xFF2F6FED);
    }
  }

  /// Downloads exactly what the table is showing.
  ///
  /// The server endpoint takes a scanner code and nothing else, so it returns
  /// the scanner's own rows over the full universe. That only matches the
  /// screen when the user has neither edited the filters nor picked an index —
  /// and the index filter defaults to NIFTY 50, so in practice it almost
  /// never matches. Every other case is exported from the rows in hand.
  Future<void> _export(BuildContext context) async {
    final edited = _customRun != null;
    final filtered = _selectedIndices.isNotEmpty;
    final name =
        ref.read(scannerDetailProvider(code)).asData?.value.displayName ?? code;

    // Untouched view — let the server build the file. It can include columns
    // the table doesn't render, so this is still the richer export.
    if (!edited && !filtered) {
      final res = await showExportModal(context);
      if (res == null) return;
      try {
        final blob = await locator<ApiExporter>().downloadScannerExportXlsx(
          code,
          columns: res.mode == ExportColumnsMode.all ? 'all' : 'visible',
        );
        triggerXlsxDownload(
          bytes: Uint8List.fromList(blob.bytes),
          filename: blob.filename,
          fallbackName: '${code}_export.xlsx',
        );
      } catch (e) {
        if (!context.mounted) return;
        ResponsiveSnackBar.showError(context, 'Export failed: $e');
      }
      return;
    }

    // Edited and/or index-filtered — export the rows on screen. No column
    // choice to offer: the view holds every column it has.
    final List<ScanColumn> cols;
    final List<ScanRow> rows;
    if (edited) {
      final r = _customRun!.asData?.value;
      if (r == null) {
        ResponsiveSnackBar.showWarning(context, 'Run the scan before exporting');
        return;
      }
      cols = [
        for (final c in r.columns)
          ScanColumn(key: c.key, label: c.label, fmt: 'raw'),
      ];
      rows = [
        for (final m in r.matches)
          ScanRow(
            ticker: m.ticker,
            name: m.name,
            values: Map<String, dynamic>.from(m.values),
          ),
      ];
    } else {
      final r = ref
          .read(scannerResultsProvider(
              ScannerResultsKey(code: code, indices: _selectedIndices)))
          .asData
          ?.value;
      if (r == null) {
        ResponsiveSnackBar.showWarning(context, 'Results are still loading');
        return;
      }
      cols = _builtinColumns(r);
      rows = _builtinRows(r);
    }

    if (rows.isEmpty) {
      ResponsiveSnackBar.showWarning(context, 'Nothing to export');
      return;
    }

    try {
      await exportScanRowsXlsx(
        columns: cols,
        rows: rows,
        sheetName: name,
        fileName: '${scanFileSlug(name)}${edited ? '_edited' : ''}.xlsx',
      );
    } catch (e) {
      if (!context.mounted) return;
      ResponsiveSnackBar.showError(context, 'Export failed: $e');
    }
  }
}


/// Derives the absolute rupee change from close and chg_pct and returns a
/// new values map that includes it under `chg_abs`. Close/chg_pct arrive
/// from the backend as num; if either is missing or non-numeric the abs
/// change is left null so the cell renders "—".
Map<String, dynamic> _withChgAbs(Map<String, dynamic> values) {
  final closeRaw = values['close'];
  final chgPctRaw = values['chg_pct'];
  double? chgAbs;
  if (closeRaw is num && chgPctRaw is num) {
    // close_now = prev_close × (1 + chg_pct/100)
    // ⇒ prev_close = close_now / (1 + chg_pct/100)
    // ⇒ chg_abs   = close_now − prev_close
    final denom = 1 + chgPctRaw.toDouble() / 100.0;
    if (denom != 0) {
      chgAbs = closeRaw.toDouble() - (closeRaw.toDouble() / denom);
    }
  }
  return {
    ...values,
    'chg_abs': chgAbs,
  };
}

/// Compact icon button with a grey hover circle — visually pairs with the
/// Index filter icon in the detail header.
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            // Toolbar control height, so it sits on the same baseline as the
            // index filter beside it.
            width: ScannerTokens.hControl,
            height: ScannerTokens.hControl,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover
                  ? resolveThemeColor(context,
                      dark: MyntColors.cardHoverDark,
                      light: MyntColors.cardHover)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: resolveThemeColor(context,
                  dark: MyntColors.iconDark, light: MyntColors.icon),
            ),
          ),
        ),
      ),
    );
  }
}

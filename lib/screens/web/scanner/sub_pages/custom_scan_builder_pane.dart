import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/utils/export_scan_rows.dart';
import 'package:mynt_plus/screens/web/scanner/utils/scanner_tokens.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/index_filter_dropdown.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_builder.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_chips.dart'
    show ScannerChipButton;
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';
import 'scanners_detail_pane.dart' show showScanNameDialog;

/// Builder + inline-runner for a custom scan, in the other scanner pages'
/// chrome: a toolbar (back, title, Save, JSON, Run inline), the condition
/// builder on the page tray, then the inline results. Save asks for the name
/// in a dialog. All user-visible state (name, predicate,
/// result, edited scan) lives in [customScansSessionProvider] so navigating
/// away (e.g. opening a result symbol) and coming back restores the screen.
class CustomScanBuilderPane extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const CustomScanBuilderPane({super.key, required this.onClose});

  @override
  ConsumerState<CustomScanBuilderPane> createState() =>
      _CustomScanBuilderPaneState();
}

class _CustomScanBuilderPaneState extends ConsumerState<CustomScanBuilderPane> {
  /// Same default universe as the saved-scan results view — the smallest,
  /// fastest one. Widened from the dropdown when the user wants more.
  static const List<String> _kDefaultIndices = ['NIFTY 50'];

  List<String> _indices = _kDefaultIndices;

  void _setPredicate(Map<String, dynamic> p) {
    ref
        .read(customScansSessionProvider.notifier)
        .updateBuilder((b) => b.copyWith(predicate: p));
  }

  void _setResult(AsyncValue<CustomScanRunResult>? r) {
    ref
        .read(customScansSessionProvider.notifier)
        .updateBuilder((b) => b.copyWith(result: r));
  }

  @override
  Widget build(BuildContext context) {
    final builder = ref.watch(customScansSessionProvider).builder;
    if (builder == null) {
      // Defensive: session was reset elsewhere — bail to the list.
      return const SizedBox.shrink();
    }

    final running = builder.result?.isLoading ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(builder, running),
        const SizedBox(height: 14),
        // Scrolling body — the condition builder on the page tray, then the
        // inline results once a run has been made.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ScannerTokens.tray(context),
                  child: PredicateBuilder(
                    // Re-seed when a different scan is opened for editing.
                    key: ValueKey(builder.editing?.id),
                    initial: builder.predicate,
                    onChange: _setPredicate,
                  ),
                ),
                if (builder.result != null) ...[
                  const SizedBox(height: 20),
                  if (builder.result!.asData?.value case final r?) ...[
                    _matchCount(r),
                    const SizedBox(height: 12),
                  ],
                  // Fixed height — the results sit inside the builder's scroll view.
                  SizedBox(height: 520, child: _results(builder.result!)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Toolbar — same slab as the other scanner pages: back + title/subtitle on
  // the left; Save, Preview JSON and Run inline on the right. The scan name is
  // asked for in a dialog on Save.
  Widget _header(CustomScanBuilderDraft builder, bool running) {
    final editing = builder.editing != null;
    return Container(
      padding: ScannerTokens.toolbarPadding,
      decoration: ScannerTokens.toolbar(context),
      child: Row(children: [
        CustomBackBtn(onBack: widget.onClose),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Custom Scan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ScannerTokens.pageTitle(context)),
              const SizedBox(height: 2),
              Text(
                'Build conditions, run inline to preview matches, then save',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ScannerTokens.pageSubtitle(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ..._resultControls(builder.result),
        const SizedBox(width: 12),
        ScannerChipButton(
          icon: shadcn.LucideIcons.save,
          label: editing ? 'Save changes' : 'Save',
          tooltip: 'Save this scan',
          height: 34,
          onTap: _save,
        ),
        const SizedBox(width: 8),
        // Builder gives the popover the button's own context to anchor to.
        Builder(
          builder: (buttonContext) => ScannerChipButton(
            icon: shadcn.LucideIcons.code,
            tooltip: 'Preview JSON',
            height: 34,
            onTap: () => _showJsonPopover(buttonContext, builder.predicate),
          ),
        ),
        const SizedBox(width: 8),
        MyntButton(
          type: MyntButtonType.primary,
          label: 'Run inline',
          icon: Icons.play_arrow,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          isLoading: running,
          onPressed: running ? null : _run,
        ),
      ]),
    );
  }

  Future<void> _run() async {
    final predicate =
        ref.read(customScansSessionProvider).builder?.predicate ?? const {};
    // Dropped if the user logs out while this is in flight — the draft belongs
    // to the account that wrote it, not to whoever logs in next.
    final epoch = scannerSessionEpoch;
    _setResult(const AsyncLoading());
    try {
      final r = await locator<ApiExporter>().runCustomScan(
        predicate: Map<String, dynamic>.from(predicate),
        indices: _indices.isEmpty ? null : _indices,
      );
      if (!mounted || !isSameScannerSession(epoch)) return;
      _setResult(AsyncData(r));
    } catch (e, st) {
      if (!mounted || !isSameScannerSession(epoch)) return;
      _setResult(AsyncError(e, st));
    }
  }

  void _setIndices(List<String> next) {
    setState(() => _indices = List.unmodifiable(next));
    // Re-run only once there are results to refresh.
    if (ref.read(customScansSessionProvider).builder?.result != null) _run();
  }

  /// Asks for the scan name (pre-filled with the draft's / edited scan's
  /// name), then saves.
  Future<void> _save() async {
    final draft = ref.read(customScansSessionProvider).builder;
    final name = await showScanNameDialog(context, initial: draft?.name ?? '');
    if (name == null || !mounted) return;
    ref
        .read(customScansSessionProvider.notifier)
        .updateBuilder((b) => b.copyWith(name: name));
    final predicate = draft?.predicate ?? const {};
    try {
      await locator<ApiExporter>().saveCustomScan(
          name: name, predicate: Map<String, dynamic>.from(predicate));
      ref.invalidate(savedCustomScansProvider(savedCustomScansKey()));
      if (!mounted) return;
      ResponsiveSnackBar.showSuccess(context, 'Saved "$name"');
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Save failed: $e');
    }
  }

  /// Match-count line (the Fundamental Screener's "N of N matches") above the
  /// results table.
  Widget _matchCount(CustomScanRunResult r) => Align(
        alignment: Alignment.centerRight,
        child: Text('${r.matches.length} matches · as of ${r.asOf}',
            style: MyntWebTextStyles.body(context,
                color: ScannerTokens.textSecondary(context))),
      );

  /// Universe filter + download, shown in the toolbar next to Save.
  List<Widget> _resultControls(AsyncValue<CustomScanRunResult>? result) {
    return [
      // The run is scoped to these indices, not the whole market. Labelled
      // because the scope is a default the user never chose — without this
      // a short match list reads as "my filters are too tight" when it is
      // really "I only scanned NIFTY 50".
      Text('Universe',
          style: MyntWebTextStyles.bodySmall(context,
              color: ScannerTokens.textSecondary(context))),
      const SizedBox(width: 8),
      IndexFilterDropdown(
        selected: _indices,
        onChanged: _setIndices,
        matchCounts: result?.maybeWhen(
              data: (r) => r.indexCounts,
              orElse: () => const <String, int>{},
            ) ??
            const <String, int>{},
      ),
      const SizedBox(width: 8),
      ScannerChipButton(
        icon: shadcn.LucideIcons.download,
        tooltip: 'Download these matches',
        height: 34,
        onTap: (result?.asData?.value.matches.isNotEmpty ?? false)
            ? () => _exportPreview(result!.asData!.value)
            : null,
      ),
    ];
  }

  /// Downloads the preview run. An unsaved draft has no server-side export,
  /// so the rows in hand are the only source.
  Future<void> _exportPreview(CustomScanRunResult r) async {
    final draftName =
        ref.read(customScansSessionProvider).builder?.name.trim() ?? '';
    final name = draftName.isEmpty ? 'custom_scan' : draftName;
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
        sheetName: name,
        fileName: '${scanFileSlug(name)}_preview.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Export failed: $e');
    }
  }

  Widget _results(AsyncValue<CustomScanRunResult> result) {
    return result.when(
      loading: () => Center(child: MyntLoader.branded()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
        onRetry: _run,
      ),
      data: (r) {
        if (r.matches.isEmpty) {
          // Name the universe — an empty list usually means the scan only
          // looked at NIFTY 50, not that the filters are wrong.
          return EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No matches',
            message: _indices.isEmpty
                ? 'No stocks match these filters today.'
                : 'No stocks in ${_indices.join(", ")} match these filters '
                    'today. Widen the universe from the dropdown above to '
                    'scan more stocks.',
          );
        }
        final filterSuffix =
            _indices.isEmpty ? '' : ' · filtered by ${_indices.join(", ")}';
        return ScannerResultsTable(
          columns: [
            for (final c in r.columns)
              ScanColumn(
                key: c.key,
                label: c.label,
                fmt: 'raw',
                description: c.key,
              ),
          ],
          rows: [
            for (final m in r.matches)
              ScanRow(
                ticker: m.ticker,
                name: m.name,
                values: Map<String, dynamic>.from(m.values),
              ),
          ],
          footer: '${r.matches.length} matches$filterSuffix',
          customCellFormatter: (ctx, col, raw) =>
              formatCustomScanCell(ctx, col.key, raw),
          onTickerTap: (t) =>
              openScannerScripFromContext(context, ref, ticker: t),
        );
      },
    );
  }

  /// Show the current predicate as formatted JSON in a popover dropped below
  /// the `<>` button, right edges aligned (header: title, copy, close;
  /// scrollable body). Closes on an outside click.
  void _showJsonPopover(
      BuildContext buttonContext, Map<String, dynamic> predicate) {
    final json = const JsonEncoder.withIndent('  ').convert(predicate);
    final border = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final dark = isDarkMode(context);
    shadcn.showPopover(
      context: buttonContext,
      alignment: Alignment.topRight,
      anchorAlignment: Alignment.bottomRight,
      offset: const Offset(0, 6),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: BorderRadius.circular(8),
      ),
      builder: (dCtx) => Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: resolveThemeColor(dCtx,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            boxShadow: dark ? MyntShadows.dropdownDark : MyntShadows.dropdown,
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
                    Text('Predicate JSON',
                        style:
                            MyntWebTextStyles.title(dCtx, color: textPrimary)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy JSON',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: json));
                          ResponsiveSnackBar.showSuccess(
                              context, 'JSON copied to clipboard');
                        },
                      ),
                      MyntCloseButton(
                          onPressed: () => shadcn.closeOverlay(dCtx)),
                    ]),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    json,
                    style: MyntWebTextStyles.para(dCtx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

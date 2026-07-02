import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';
import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/filter_inputs.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/fundamental_filter_row.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/screens_browser_modal.dart';

/// Redesigned Fundamental Screener (Tickertape-inspired): a fixed top toolbar,
/// a left filter sidebar (stacked filter rows), and a right results area.
/// Runs on [fundamentalsNewSessionProvider] so it's fully independent from the
/// current Fundamentals tab. Reuses the same providers / API — no new backend.
/// Layout: header toolbar (Screens / Save / Export / Run), a collapsible left
/// filter sidebar (stacked rows + missing-data rule), and a right results area
/// (match count + "Show top N"; sorting via column headers).
class FundamentalsNewSubPage extends ConsumerStatefulWidget {
  const FundamentalsNewSubPage({super.key});

  @override
  ConsumerState<FundamentalsNewSubPage> createState() =>
      _FundamentalsNewSubPageState();
}

class _FundamentalsNewSubPageState
    extends ConsumerState<FundamentalsNewSubPage> {
  final ScrollController _filtersScroll = ScrollController();
  // Source of truth for the "Show top N" limit field; synced to the builder.
  late final TextEditingController _limitCtrl =
      TextEditingController(text: _state.limit.toString());
  // Local view state (UI only) — collapse the filter sidebar for more table room.
  bool _sidebarCollapsed = false;

  FundamentalsBuilderState get _state =>
      ref.read(fundamentalsNewSessionProvider).builder;
  AsyncValue<FundamentalScanResponse>? get _result =>
      ref.read(fundamentalsNewSessionProvider).result;
  void _setBuilder(FundamentalsBuilderState b) =>
      ref.read(fundamentalsNewSessionProvider.notifier).setBuilder(b);
  void _setResult(AsyncValue<FundamentalScanResponse>? r) =>
      ref.read(fundamentalsNewSessionProvider.notifier).setResult(r);

  @override
  void dispose() {
    _filtersScroll.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fundamentalsNewSessionProvider);
    final fields = ref.watch(fundamentalFieldsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sidebarCollapsed
                  ? _collapsedSidebar()
                  : SizedBox(width: 400, child: _filterSidebar(fields)),
              const SizedBox(width: 16),
              Expanded(child: _resultsArea()),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Header — title + one consolidated toolbar.
  // ---------------------------------------------------------------------
  Widget _header() {
    return Row(children: [
      Expanded(
        child: Text('Fundamental Screener',
            style: MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold)),
      ),
      const SizedBox(width: 12),
      MyntButton(
        type: MyntButtonType.outlined,
        label: 'Screens',
        icon: Icons.bookmark_border,
        onPressed: _openScreens,
      ),
      const SizedBox(width: 8),
      MyntButton(
        type: MyntButtonType.outlined,
        label: 'Save as…',
        icon: shadcn.LucideIcons.save,
        onPressed: _save,
      ),
      const SizedBox(width: 8),
      MyntButton(
        type: MyntButtonType.outlined,
        label: 'Export',
        icon: Icons.download,
        onPressed: _export,
      ),
      const SizedBox(width: 8),
      MyntButton(
        type: MyntButtonType.primary,
        label: 'Run scan',
        icon: shadcn.LucideIcons.play,
        onPressed: _run,
      ),
    ]);
  }

  void _openScreens() {
    showScreensBrowser(
      context,
      onLoad: (filters, treatNullAs) {
        // Apply the screen's filters into the builder, then run it so results
        // show immediately (Load = load + run).
        _setBuilder(
            _state.copyWith(filters: filters, treatNullAs: treatNullAs));
        _run();
      },
    );
  }

  // ---------------------------------------------------------------------
  // Left filter sidebar — stacked filter rows + Add filter.
  // ---------------------------------------------------------------------
  Widget _filterSidebar(AsyncValue<List<FundamentalField>> fields) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('FILTERS',
                style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium, color: tertiary)
                    .copyWith(letterSpacing: 0.8)),
            if (_state.filters.isNotEmpty) ...[
              const SizedBox(width: 6),
              _filterCountBadge(),
            ],
            const Spacer(),
            if (_state.filters.isNotEmpty)
              InkWell(
                onTap: () => _setBuilder(_state.copyWith(filters: const [])),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Reset all',
                      style: MyntWebTextStyles.caption(context,
                          color: secondary)),
                ),
              ),
            const SizedBox(width: 2),
            IconButton(
              onPressed: () => setState(() => _sidebarCollapsed = true),
              icon: const Icon(Icons.chevron_left, size: 18),
              tooltip: 'Collapse filters',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: fields.when(
              loading: () => Center(child: MyntLoader.branded()),
              error: (e, _) => EmptyState(
                kind: EmptyStateKind.error,
                title: 'Could not load fields',
                message: e.toString(),
                onRetry: () => ref.invalidate(fundamentalFieldsProvider),
              ),
              data: (fList) {
                if (_state.filters.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'No filters yet.\nAdd one to build your screen.',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context,
                                color: secondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _addFilterButton(fList),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: const MaterialScrollBehavior()
                            .copyWith(scrollbars: false),
                        child: RawScrollbar(
                          controller: _filtersScroll,
                          thumbVisibility: true,
                          thickness: 6,
                          radius: const Radius.circular(8),
                          thumbColor: secondary.withValues(alpha: 0.5),
                          child: SingleChildScrollView(
                            controller: _filtersScroll,
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0;
                                    i < _state.filters.length;
                                    i++) ...[
                                  FundamentalFilterRow(
                                    stacked: true,
                                    fields: fList,
                                    filter: _state.filters[i],
                                    onChange: (f) {
                                      final nf = [..._state.filters]..[i] = f;
                                      _setBuilder(
                                          _state.copyWith(filters: nf));
                                    },
                                    onRemove: () {
                                      final nf = [..._state.filters]
                                        ..removeAt(i);
                                      _setBuilder(
                                          _state.copyWith(filters: nf));
                                    },
                                  ),
                                  if (i < _state.filters.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Divider(
                                          height: 1,
                                          color:
                                              border.withValues(alpha: 0.5)),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _addFilterButton(fList),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: border.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          _missingDataRow(secondary),
        ],
      ),
    );
  }

  Widget _addFilterButton(List<FundamentalField> fList) {
    return MyntButton(
      type: MyntButtonType.outlined,
      label: 'Add filter',
      icon: Icons.add,
      isFullWidth: true,
      onPressed: () {
        if (fList.isEmpty) return;
        final nf = [
          ..._state.filters,
          FundamentalFilter(field: fList.first.key, op: '<'),
        ];
        _setBuilder(_state.copyWith(filters: nf));
      },
    );
  }

  /// Missing-data (Exclude / Include) — a match rule, so it lives with the
  /// filters. Changing it re-runs the scan if there are already results.
  Widget _missingDataRow(Color secondary) {
    return Row(children: [
      Text('Missing data',
          style: MyntWebTextStyles.caption(context, color: secondary)),
      const Spacer(),
      SizedBox(
        width: 130,
        child: FilterSelect(
          value: _state.treatNullAs,
          hint: 'Missing',
          options: const [
            FilterSelectOption('fail', 'Exclude'),
            FilterSelectOption('pass', 'Include'),
          ],
          onChanged: (v) {
            _setBuilder(_state.copyWith(treatNullAs: v));
            if (_result != null) _run();
          },
        ),
      ),
    ]);
  }

  /// Small pill showing how many filters are active.
  Widget _filterCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: MyntColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('${_state.filters.length}',
          style: MyntWebTextStyles.caption(context,
              color: MyntColors.primary, fontWeight: MyntFonts.semiBold)),
    );
  }

  /// The filter sidebar collapsed to a thin rail — an expand button plus the
  /// active-filter count, giving the results table more room.
  Widget _collapsedSidebar() {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Container(
      width: 44,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          IconButton(
            onPressed: () => setState(() => _sidebarCollapsed = false),
            icon: const Icon(Icons.chevron_right, size: 18),
            tooltip: 'Show filters',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(height: 8),
          if (_state.filters.isNotEmpty) _filterCountBadge(),
          const SizedBox(height: 12),
          RotatedBox(
            quarterTurns: 3,
            child: Text('FILTERS',
                style: MyntWebTextStyles.caption(context, color: tertiary)
                    .copyWith(letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Right results area.
  // ---------------------------------------------------------------------
  Widget _resultsArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _resultsToolbar(),
        const SizedBox(height: 8),
        Expanded(child: _resultsBody()),
      ],
    );
  }

  /// Above the results table: the match count on the left, and a "Show top N"
  /// limit on the right (applied on the next Run). Sorting is done by clicking
  /// the results-table column headers.
  Widget _resultsToolbar() {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final count = _result?.maybeWhen(
        data: (r) => '${r.returned} of ${r.total} matches',
        orElse: () => null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (count != null)
          Text(count,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold)),
        const Spacer(),
        Text('Show top',
            style: MyntWebTextStyles.caption(context, color: secondary)),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: FilterTextField(
            controller: _limitCtrl,
            hint: '100',
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) _setBuilder(_state.copyWith(limit: n));
            },
          ),
        ),
      ],
    );
  }

  Widget _resultsBody() {
    final result = _result;
    if (result == null) {
      return const EmptyState(
        kind: EmptyStateKind.empty,
        title: 'Add filters and Run scan',
        message:
            'Build a screen on the left, then Run scan to see matching stocks here.',
      );
    }
    return result.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
      ),
      data: (resp) => _buildResultsTable(resp),
    );
  }

  Widget _buildResultsTable(FundamentalScanResponse resp) {
    if (resp.matches.isEmpty) {
      return const EmptyState(
        kind: EmptyStateKind.empty,
        title: 'No stocks match these filters',
      );
    }
    final standard = <ScanColumn>[
      const ScanColumn(
          key: 'sector', label: 'Sector', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'industry', label: 'Industry', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'market_cap',
          label: 'Market Cap (Cr)',
          fmt: 'int',
          isStandard: true),
    ];
    final dynamicCols = <ScanColumn>[
      for (final cl in resp.columnLabels)
        ScanColumn(key: cl.field, label: cl.label, fmt: 'ratio'),
    ];
    final rows = [
      for (final m in resp.matches)
        ScanRow(
          ticker: m.ticker,
          name: m.name,
          values: {
            ...m.values,
            'sector': m.sector ?? '',
            'industry': m.industry ?? '',
            'market_cap':
                m.marketCap == null ? null : (m.marketCap! / 1e7).round(),
          },
        ),
    ];
    return ScannerResultsTable(
      columns: dynamicCols,
      standardPrefixColumns: standard,
      rows: rows,
      footer: '${resp.returned} of ${resp.total} matches',
      onTickerTap: (t) =>
          openScannerScripFromContext(context, ref, ticker: t),
    );
  }

  // ---------------------------------------------------------------------
  // Actions (same behaviour as the current screen, on the new session).
  // ---------------------------------------------------------------------
  Future<void> _run() async {
    for (final f in _state.filters) {
      final needsValue = f.op != 'is_null' && f.op != 'is_not_null';
      if (needsValue && f.value == null) {
        if (!mounted) return;
        ResponsiveSnackBar.showWarning(
            context, 'Set a value for "${f.field}" (${f.op})');
        return;
      }
    }
    _setResult(const AsyncLoading());
    try {
      final r = await locator<ApiExporter>()
          .runFundamentalScan(_state.toRequest());
      _setResult(AsyncData(r));
    } catch (e, st) {
      _setResult(AsyncError(e, st));
    }
  }

  Future<void> _export() async {
    final res = await showExportModal(context, allowCustom: false);
    if (res == null) return;
    try {
      final blob = await locator<ApiExporter>().downloadFundamentalExportXlsx(
        req: _state.toRequest(),
        columns: res.mode == ExportColumnsMode.all ? 'all' : 'visible',
      );
      triggerXlsxDownload(
        bytes: Uint8List.fromList(blob.bytes),
        filename: blob.filename,
        fallbackName: 'fundamental_screen.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Export failed: $e');
    }
  }

  Future<void> _save() async {
    final ctrl = TextEditingController();
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = shadcn.Theme.of(context).colorScheme.border;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        String? errorText;
        return StatefulBuilder(builder: (dCtx, setLocal) {
          void trySave() {
            if (ctrl.text.trim().isEmpty) {
              setLocal(() => errorText = 'Please enter a name');
              return;
            }
            Navigator.of(dCtx).pop(true);
          }

          return Dialog(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Save screen',
                              style: MyntWebTextStyles.title(dCtx,
                                  color: textPrimary)),
                          MyntCloseButton(
                              onPressed: () => Navigator.of(dCtx).pop(false)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enter a name for this screen',
                              style: MyntWebTextStyles.body(dCtx,
                                  color: textPrimary)),
                          const SizedBox(height: 12),
                          MyntFormTextField(
                            controller: ctrl,
                            placeholder: 'Screen name',
                            height: 40,
                            autofocus: true,
                            onChanged: (_) {
                              if (errorText != null) {
                                setLocal(() => errorText = null);
                              }
                            },
                            onSubmitted: (_) => trySave(),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(errorText!,
                                style: MyntWebTextStyles.caption(dCtx,
                                    color: resolveThemeColor(dCtx,
                                        dark: MyntColors.lossDark,
                                        light: MyntColors.loss))),
                          ],
                          const SizedBox(height: 20),
                          MyntButton(
                            type: MyntButtonType.primary,
                            label: 'Save',
                            isFullWidth: true,
                            onPressed: trySave,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await locator<ApiExporter>().saveScreen(
        name: ctrl.text.trim(),
        filters: _state.filters,
        treatNullAs: _state.treatNullAs,
        orderBy: _state.orderBy,
        orderDir: _state.orderDir,
        limit: _state.limit,
      );
      ref.invalidate(savedScreensProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Saved "${ctrl.text.trim()}"');
      }
    }
  }
}

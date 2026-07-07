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
import 'package:mynt_plus/screens/web/scanner/widgets/metric_picker_modal.dart';

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
  // Which metric accordion rows are expanded (field keys).
  final Set<String> _expanded = {};
  // Operator chosen for a metric that has no value yet, so the choice sticks
  // while the row is open even though it isn't an active filter.
  final Map<String, String> _draftOps = {};
  // Which metrics are shown in the sidebar (a managed subset, like Tickertape).
  // Populated from a default set on first load; edited via the Add-filter picker.
  final List<String> _shown = [];
  bool _didInitShown = false;
  // Bumped per metric on Reset so the open condition control rebuilds fresh
  // (its text controllers re-hydrate from the now-empty filter).
  final Map<String, int> _rowNonce = {};

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
  // Left filter sidebar — Tickertape-style accordion of metrics. Each metric
  // is a collapsible row; expanding it reveals the condition (operator + value
  // / multiselect). A metric with a value set becomes an active filter.
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
                onTap: _resetAll,
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
          const SizedBox(height: 6),
          Expanded(
            child: fields.when(
              loading: () => Center(child: MyntLoader.branded()),
              error: (e, _) => EmptyState(
                kind: EmptyStateKind.error,
                title: 'Could not load fields',
                message: e.toString(),
                onRetry: () => ref.invalidate(fundamentalFieldsProvider),
              ),
              data: (fList) => _metricList(fList, _effectiveShown(fList)),
            ),
          ),
          if (fields.asData != null) ...[
            const SizedBox(height: 10),
            _addMetricButton(fields.asData!.value),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: border.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          _missingDataRow(secondary),
        ],
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _draftOps.clear();
      _expanded.clear();
    });
    _setBuilder(_state.copyWith(filters: const []));
  }

  /// Metrics shown in the sidebar (a managed subset). Defaults to the first few
  /// fields until the user adds / removes via the picker.
  List<String> _effectiveShown(List<FundamentalField> fList) =>
      _didInitShown ? _shown : fList.take(6).map((f) => f.key).toList();

  void _ensureShownInit(List<FundamentalField> fList) {
    if (_didInitShown) return;
    _didInitShown = true;
    _shown
      ..clear()
      ..addAll(fList.take(6).map((f) => f.key));
  }

  Future<void> _openMetricPicker(List<FundamentalField> fList) async {
    _ensureShownInit(fList);
    final result = await showMetricPicker(
      context,
      fields: fList,
      selected: _shown.toSet(),
    );
    if (result == null) return;
    // Keep existing order for still-selected metrics; append newly-added ones.
    final kept = _shown.where(result.contains).toList();
    for (final k in result) {
      if (!kept.contains(k)) kept.add(k);
    }
    setState(() {
      _shown
        ..clear()
        ..addAll(kept);
    });
    // Drop active filters for metrics that are no longer shown.
    final nextFilters =
        _state.filters.where((f) => result.contains(f.field)).toList();
    if (nextFilters.length != _state.filters.length) {
      _setBuilder(_state.copyWith(filters: nextFilters));
    }
  }

  void _removeMetric(String key, List<FundamentalField> fList) {
    _ensureShownInit(fList);
    setState(() {
      _shown.remove(key);
      _expanded.remove(key);
      _draftOps.remove(key);
    });
    final next = _state.filters.where((f) => f.field != key).toList();
    if (next.length != _state.filters.length) {
      _setBuilder(_state.copyWith(filters: next));
    }
  }

  /// Clear a metric's value but keep the row (bump its nonce so the open input
  /// rebuilds empty).
  void _resetMetric(String key) {
    setState(() {
      _draftOps.remove(key);
      _rowNonce[key] = (_rowNonce[key] ?? 0) + 1;
    });
    final next = _state.filters.where((f) => f.field != key).toList();
    if (next.length != _state.filters.length) {
      _setBuilder(_state.copyWith(filters: next));
    }
  }

  Widget _addMetricButton(List<FundamentalField> fList) {
    return MyntButton(
      type: MyntButtonType.outlined,
      label: 'Add filter',
      icon: Icons.add,
      isFullWidth: true,
      onPressed: () => _openMetricPicker(fList),
    );
  }

  /// Scrollable list of the shown metrics (a managed subset), each a
  /// collapsible accordion row. Add / remove metrics via the picker.
  Widget _metricList(List<FundamentalField> fList, List<String> shown) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    if (shown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'No filters added.\nTap "Add filter" to choose metrics.',
            textAlign: TextAlign.center,
            style: MyntWebTextStyles.caption(context, color: secondary),
          ),
        ),
      );
    }
    final byKey = {for (final f in fList) f.key: f};
    final children = <Widget>[];
    for (final key in shown) {
      final f = byKey[key];
      if (f == null) continue;
      children.add(_metricTile(f, fList));
      children.add(Divider(height: 1, color: border.withValues(alpha: 0.5)));
    }
    // Drop the trailing divider so it doesn't double up with the bottom rule.
    if (children.isNotEmpty && children.last is Divider) children.removeLast();

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
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
            children: children,
          ),
        ),
      ),
    );
  }

  /// One metric row. The header + hover-Remove + chevron live in [_MetricTile];
  /// when open, the inline condition control (reused from [FundamentalFilterRow]).
  Widget _metricTile(FundamentalField f, List<FundamentalField> fList) {
    final existing = _filterFor(f.key);
    final isOpen = _expanded.contains(f.key);
    return _MetricTile(
      label: f.label,
      active: existing != null,
      isOpen: isOpen,
      summary: (existing != null && !isOpen) ? _summary(existing, f) : null,
      onToggle: () => setState(() {
        if (isOpen) {
          _expanded.remove(f.key);
        } else {
          _expanded.add(f.key);
        }
      }),
      onRemove: () => _removeMetric(f.key, fList),
      onReset: () => _resetMetric(f.key),
      body: isOpen
          ? FundamentalFilterRow(
              key: ValueKey('${f.key}#${_rowNonce[f.key] ?? 0}'),
              stacked: true,
              hideField: true,
              fields: fList,
              filter: existing ??
                  FundamentalFilter(
                      field: f.key, op: _draftOps[f.key] ?? _defaultOp(f)),
              onChange: _onMetricChange,
              onRemove: () {},
            )
          : null,
    );
  }

  // --- accordion filter plumbing (state shuffling only, no new logic) -------

  FundamentalFilter? _filterFor(String key) {
    for (final f in _state.filters) {
      if (f.field == key) return f;
    }
    return null;
  }

  String _defaultOp(FundamentalField f) {
    if (f.key == 'sector' || f.key == 'industry') return 'in';
    final ops = validOpsForDtype(f.dtype, multiYear: isMultiYearField(f.key));
    return ops.isNotEmpty ? ops.first : '>';
  }

  /// A filter counts as active (and is stored) once it has a usable value —
  /// null-checks need none; lists/strings must be non-empty.
  bool _isActiveFilter(FundamentalFilter f) {
    if (f.op == 'is_null' || f.op == 'is_not_null') return true;
    if (f.op == 'min_years') return f.years != null;
    final v = f.value;
    if (v == null) return false;
    if (v is List) return v.isNotEmpty;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  void _onMetricChange(FundamentalFilter nf) {
    final next = _state.filters.where((x) => x.field != nf.field).toList();
    if (_isActiveFilter(nf)) next.add(nf);
    setState(() => _draftOps[nf.field] = nf.op);
    _setBuilder(_state.copyWith(filters: next));
  }

  /// Compact one-line summary of an active filter, shown on the collapsed row.
  String _summary(FundamentalFilter f, FundamentalField field) {
    if (f.op == 'is_null') return 'is empty';
    if (f.op == 'is_not_null') return 'not empty';
    if (f.op == 'min_years') return 'min ${f.years ?? ''}y';
    final pct = field.dtype == 'pct';
    final v = f.value;
    if (v is List) {
      if (f.op == 'between' && v.length == 2) {
        return '${_num(v[0], pct)} to ${_num(v[1], pct)}';
      }
      final n = v.length;
      if (field.key == 'sector') return '$n sector${n == 1 ? '' : 's'} selected';
      if (field.key == 'industry') {
        return '$n ${n == 1 ? 'industry' : 'industries'} selected';
      }
      return '$n selected';
    }
    final yrs = f.years != null ? ' · ${f.years}y' : '';
    return '${_opSymbol(f.op)} ${_num(v, pct)}$yrs'.trim();
  }

  String _opSymbol(String op) {
    switch (op) {
      case '<':
        return '<';
      case '<=':
        return '≤';
      case '>':
        return '>';
      case '>=':
        return '≥';
      case '==':
        return '=';
      case '!=':
        return '≠';
      case 'min_years':
        return 'min';
      default:
        return op;
    }
  }

  String _num(dynamic v, bool pct) {
    if (v is! num) return v?.toString() ?? '';
    final n = pct ? v * 100 : v;
    final s = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
    return pct ? '$s%' : s;
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

/// A single metric row in the filter sidebar: a tappable header showing the
/// metric name, its value summary (when collapsed + active) or a Remove
/// affordance (on hover), and a chevron; plus the inline condition [body]
/// when expanded.
class _MetricTile extends StatefulWidget {
  final String label;
  final bool active;
  final bool isOpen;
  final String? summary;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onReset;
  final Widget? body;

  const _MetricTile({
    required this.label,
    required this.active,
    required this.isOpen,
    required this.summary,
    required this.onToggle,
    required this.onRemove,
    required this.onReset,
    required this.body,
  });

  @override
  State<_MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends State<_MetricTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const primary = MyntColors.primary;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Row(children: [
                Expanded(
                  child: Text(widget.label,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: widget.active
                              ? MyntFonts.semiBold
                              : MyntFonts.regular,
                          color: widget.active ? primary : textPrimary)),
                ),
                if (_hover)
                  InkWell(
                    onTap: widget.active ? widget.onReset : widget.onRemove,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(widget.active ? 'Reset' : 'Remove',
                          style: MyntWebTextStyles.caption(context,
                              color: secondary)),
                    ),
                  )
                else if (widget.summary != null) ...[
                  Flexible(
                    child: Text(widget.summary!,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.caption(context,
                            color: secondary)),
                  ),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 2),
                Icon(
                    widget.isOpen
                        ? shadcn.LucideIcons.chevronUp
                        : shadcn.LucideIcons.chevronDown,
                    size: 16,
                    color: secondary),
              ]),
            ),
          ),
        ),
        if (widget.isOpen && widget.body != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 2),
            child: widget.body!,
          ),
      ],
    );
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_field.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/models/scanner_model/saved_screen.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
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
  // Source of truth for the "Show top N" limit field; synced to the builder.
  late final TextEditingController _limitCtrl =
      TextEditingController(text: _state.limit.toString());
  // Screen name input in the header — used by the Options → Save as menu so
  // the user can name a screen inline instead of the intermediate dialog.
  final TextEditingController _screenNameCtrl = TextEditingController();
  // Operator chosen for a metric that has no value yet, so the choice sticks
  // in a chip's popover even though it isn't an active filter.
  final Map<String, String> _draftOps = {};
  // Which metrics are shown as chips (a managed subset, like Tickertape).
  // Populated from a default set on first load; edited via the Add-filter picker.
  final List<String> _shown = [];
  bool _didInitShown = false;
  // Bumped per metric on Reset so the popover's condition control rebuilds
  // fresh (its text controllers re-hydrate from the now-empty filter).
  final Map<String, int> _rowNonce = {};
  // Guard so we auto-load the first preset only once per mount, even if
  // `fundamentalPresetsProvider` rebuilds (data refresh, etc.).
  bool _didAutoLoadPreset = false;
  // Column keys the user has hidden via the Manage Columns checkboxes.
  // Applies to Market Cap, Sector, Industry, and each dynamic filter column.
  final Set<String> _hiddenColumns = {};
  // User-preferred column order (drag-reordered inside the Manage Columns
  // menu). Empty on first mount → columns render in their "natural" order
  // (Market Cap, Sector, Industry, dynamic filter cols). Any key already
  // dragged is respected; new keys not yet in the list append to the end.
  List<String> _columnOrder = [];

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
    _limitCtrl.dispose();
    _screenNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fundamentalsNewSessionProvider);
    final fields = ref.watch(fundamentalFieldsProvider);
    _maybeAutoLoadFirstPreset();
    // Screener body — chip-based fundamental filters + results below.
    // Technical predicates are authored in the Custom Scans builder.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(fields),
        const SizedBox(height: 10),
        _filterPanel(fields),
        const SizedBox(height: 20),
        Expanded(child: _resultsArea()),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Header — title, an inline screen-name field, an Options menu that
  // consolidates the low-frequency actions (Screens / Save as / Download),
  // and the primary Run scan CTA on the right.
  // ---------------------------------------------------------------------
  Widget _header(AsyncValue<List<FundamentalField>> fields) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Fundamental Screener',
            style: MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold)),
        const Spacer(),
        // Screen-name pill (with the Options dropdown chevron) sits on the
        // right, followed by a standalone Save shortcut so users don't have
        // to open the dropdown to persist the current name.
        _OptionsMenu(
          controller: _screenNameCtrl,
          onSaveAs: _save,
          onDownload: _export,
          onLoadScreen: _loadScreenFromMenu,
        ),
        const SizedBox(width: 8),
        _chipButton(
          icon: shadcn.LucideIcons.save,
          label: 'Save',
          tooltip: 'Save this screen',
          // Matches the screen-name pill height so the two sit as siblings.
          height: 34,
          onTap: _save,
        ),
        const SizedBox(width: 8),
        // Icon-only Download shortcut — moved out of the Options dropdown so
        // exporting the current screen takes one tap.
        _chipButton(
          icon: shadcn.LucideIcons.download,
          tooltip: 'Download results',
          height: 34,
          onTap: _export,
        ),
      ],
    );
  }

  /// Load a screen (saved or preset) selected from the inline menu.
  /// Applies its filters + missing-data rule into the builder, writes the
  /// name back to the header field, and runs so results show immediately.
  /// Also replaces the shown-chip list with just the screen's filter fields
  /// so users see exactly what the loaded screen configures — nothing more.
  void _loadScreenFromMenu(
      List<FundamentalFilter> filters, String treatNullAs, String name) {
    _screenNameCtrl.text = name;
    setState(() {
      _shown
        ..clear()
        ..addAll(filters.map((f) => f.field));
      _didInitShown = true;
      // Reset any dangling draft ops from a previous config.
      _draftOps.clear();
    });
    _setBuilder(_state.copyWith(filters: filters, treatNullAs: treatNullAs));
    _run();
  }

  /// Auto-loads the first predefined screen on initial mount so users land
  /// on a working example instead of an empty screener. Runs only once, and
  /// only when the builder is truly empty (no filters, no name) so a returning
  /// session or a link-shared screen doesn't get clobbered.
  void _maybeAutoLoadFirstPreset() {
    if (_didAutoLoadPreset) return;
    if (_state.filters.isNotEmpty || _screenNameCtrl.text.isNotEmpty) {
      _didAutoLoadPreset = true;
      return;
    }
    final presets = ref.read(fundamentalPresetsProvider);
    presets.whenData((list) {
      if (list.isEmpty || _didAutoLoadPreset) return;
      _didAutoLoadPreset = true;
      final first = list.first;
      // Defer to the next frame so we don't call setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadScreenFromMenu(first.filters, first.treatNullAs, first.name);
      });
    });
  }

  // ---------------------------------------------------------------------
  // Bordered filter section — visually separates from the header and the
  // results table. Layout: [+ / reset / delete on the left] · [filter chips
  // in the middle, wrapping onto extra rows as needed] · [Run scan + settings
  // 3-dot on the right]. Missing-data + Show-top used to be inline chips;
  // they're now hidden behind the settings menu.
  // ---------------------------------------------------------------------
  Widget _filterPanel(AsyncValue<List<FundamentalField>> fields) {
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: fields.when(
        loading: () => const SizedBox(height: 32),
        error: (e, _) => EmptyState(
          kind: EmptyStateKind.error,
          title: 'Could not load fields',
          message: e.toString(),
          onRetry: () => ref.invalidate(fundamentalFieldsProvider),
        ),
        data: _chipSection,
      ),
    );
  }

  Widget _chipSection(List<FundamentalField> fList) {
    final shown = _effectiveShown(fList);
    final byKey = {for (final f in fList) f.key: f};
    final shownEmpty = shown.isEmpty;
    final filtersEmpty = _state.filters.isEmpty;
    // Top-align so the left action group (+ / reset / delete) and the right
    // Run scan CTA stay on the first row even when the middle chip Wrap grows
    // to multiple lines. Chips have room to breathe while the actions stay
    // anchored where the user first found them.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left-edge action group — Add filter (+), Reset, Delete.
        _addFilterChip(fList),
        const SizedBox(width: 8),
        _chipButton(
          icon: shadcn.LucideIcons.rotateCcw,
          labelColor: resolveThemeColor(context,
              dark: MyntColors.secondaryDark, light: MyntColors.primary),
          tooltip: 'Reset all values',
          onTap: filtersEmpty ? null : _resetAll,
        ),
        const SizedBox(width: 8),
        _chipButton(
          icon: shadcn.LucideIcons.trash2,
          labelColor: resolveThemeColor(context,
              dark: MyntColors.errorDark, light: MyntColors.error),
          tooltip: 'Delete all filters',
          onTap: shownEmpty ? null : _removeAllFilters,
        ),
        const SizedBox(width: 12),
        // Middle — filter chips flow / wrap onto extra rows as more are added.
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final key in shown)
                if (byKey[key] != null)
                  _FilterChip(
                    key: ValueKey(key),
                    field: byKey[key]!,
                    filter: _filterFor(key),
                    allFields: fList,
                    nonce: _rowNonce[key] ?? 0,
                    draftOp: _draftOps[key],
                    onChange: _onMetricChange,
                    onDelete: () => _removeMetric(key, fList),
                  ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right-edge — primary Run CTA using MyntButton so it reads as a
        // proper app-style primary action rather than a chip. Padding-based
        // height (~34px) mirrors the New-custom-scan / Save-changes buttons.
        MyntButton(
          type: MyntButtonType.primary,
          label: 'Run scan',
          icon: shadcn.LucideIcons.play,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          onPressed: _run,
        ),
      ],
    );
  }

  /// Bordered action button that mirrors a filter chip's shape — used for
  /// "Reset all" (label variant) and "Remove all filters" (icon variant) so
  /// the two row-actions read as siblings of the chips above. When [filled]
  /// is true the button paints a primary background with white foreground,
  /// matching the header's Run scan button.
  Widget _chipButton({
    String? label,
    IconData? icon,
    Color? labelColor,
    String? tooltip,
    bool filled = false,
    double? height,
    required VoidCallback? onTap,
  }) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final primaryBg = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);
    final disabled = onTap == null;
    final resolvedLabelColor = filled
        ? Colors.white
        : disabled
            ? secondary.withValues(alpha: 0.4)
            : (labelColor ?? textPrimary);
    final resolvedIconColor = filled
        ? Colors.white
        : disabled
            ? secondary.withValues(alpha: 0.4)
            : (labelColor ?? secondary);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: filled ? primaryBg.withValues(alpha: 0.85) : hoverBg,
        // Default matches [_FilterChip] (~28px). Pass [height] to align with
        // the taller (34px) screen-name pill in the header, so the Save chip
        // reads as a sibling of the pill rather than of the filter chips.
        child: Container(
          height: height,
          alignment: height != null ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 10 : 6, vertical: 4),
          decoration: BoxDecoration(
            color: filled ? primaryBg : null,
            border: filled ? null : Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 18, color: resolvedIconColor),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Text(
                  label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium,
                      color: resolvedLabelColor),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: button);
    return button;
  }

  /// Trailing chip on the filter row: opens the metric picker to add a new
  /// filter. Icon-only (label commented out) so the row stays tight; the
  /// tooltip surfaces the meaning of the "+".
  Widget _addFilterChip(List<FundamentalField> fList) {
    return _chipButton(
      icon: Icons.add,
      tooltip: 'Add filter',
      onTap: () => _openMetricPicker(fList),
    );
  }

  void _resetAll() {
    setState(() {
      _draftOps.clear();
      // Bump every row's nonce so open popovers rebuild with empty values.
      for (final k in _shown) {
        _rowNonce[k] = (_rowNonce[k] ?? 0) + 1;
      }
    });
    _setBuilder(_state.copyWith(filters: const []));
  }

  void _removeAllFilters() {
    setState(() {
      _draftOps.clear();
      _shown.clear();
      _didInitShown = true;
    });
    _setBuilder(_state.copyWith(filters: const []));
  }

  /// Metrics shown as chips (a managed subset). Defaults to the first few
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
    // catalog: null → picker's left rail hides the Technicals categories,
    // since this screen only builds fundamental filters. Technical predicates
    // are authored in the Custom Scans builder.
    final result = await showMetricPicker(
      context,
      fields: fList,
      catalog: null,
      selectedFundamentals: _shown.toSet(),
      selectedTechnicals: const {},
    );
    if (result == null) return;
    // Keep existing order for still-selected metrics; append newly-added ones.
    final keptFund = _shown.where(result.fundamentalKeys.contains).toList();
    for (final k in result.fundamentalKeys) {
      if (!keptFund.contains(k)) keptFund.add(k);
    }
    setState(() {
      _shown
        ..clear()
        ..addAll(keptFund);
    });
    // Drop active filters for metrics that are no longer shown.
    final nextFilters = _state.filters
        .where((f) => result.fundamentalKeys.contains(f.field))
        .toList();
    if (nextFilters.length != _state.filters.length) {
      _setBuilder(_state.copyWith(filters: nextFilters));
    }
  }

  void _removeMetric(String key, List<FundamentalField> fList) {
    _ensureShownInit(fList);
    setState(() {
      _shown.remove(key);
      _draftOps.remove(key);
    });
    final next = _state.filters.where((f) => f.field != key).toList();
    if (next.length != _state.filters.length) {
      _setBuilder(_state.copyWith(filters: next));
    }
  }

  // --- chip filter plumbing (state shuffling only, no new logic) -------

  FundamentalFilter? _filterFor(String key) {
    for (final f in _state.filters) {
      if (f.field == key) return f;
    }
    return null;
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

  // Missing data + Show top now live inside the [_SettingsMenu] 3-dot popover
  // at the right edge of the filter row — they used to be inline chips.

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
    final count = _result?.maybeWhen(
        data: (r) => '${r.returned} of ${r.total} matches',
        orElse: () => null);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    // Build the manageable-columns list from the current scan result and
    // apply the user's preferred order. Empty before the first scan → the
    // Manage Columns section renders empty.
    // Symbol / Exch are structural columns owned by ScannerResultsTable but
    // still surface in the Manage Columns list so users can hide them via
    // the same checkbox UI as the rest. Order in this list reflects the
    // fixed table layout (Symbol, Exch always sit right after Stock Name).
    final rawCols = _result?.maybeWhen<List<({String key, String label})>>(
          data: (r) => <({String key, String label})>[
            (key: 'ticker', label: 'Symbol'),
            (key: 'exch', label: 'Exch'),
            (key: 'sector', label: 'Sector'),
            (key: 'industry', label: 'Industry'),
            (key: 'market_cap', label: 'Market Cap (Cr)'),
            for (final cl in r.columnLabels)
              (key: cl.field, label: cl.label),
          ],
          orElse: () => const <({String key, String label})>[],
        ) ??
        const <({String key, String label})>[];
    final rawByKey = {for (final c in rawCols) c.key: c};
    final orderedKeys =
        _effectiveColumnOrder(rawCols.map((c) => c.key).toList());
    final manageableCols = <({String key, String label})>[
      for (final k in orderedKeys)
        if (rawByKey[k] != null) rawByKey[k]!,
    ];
    // Always render the row so the settings menu is available (Missing data
    // / Show top affect the next Run) — even before the first scan. Match
    // count sits immediately to the left of the menu so both read as one
    // right-edge cluster.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        if (count != null) ...[
          Text(count,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.regular, color: muted)),
          const SizedBox(width: 10),
        ],
        _SettingsMenu(
          treatNullAs: _state.treatNullAs,
          limit: _state.limit,
          limitCtrl: _limitCtrl,
          manageableColumns: manageableCols,
          hiddenColumns: _hiddenColumns,
          onReorderColumn: (oldIdx, newIdx) {
            setState(() {
              // Snapshot the currently-displayed order, apply the reorder to
              // it, and persist as the new `_columnOrder`. ReorderableListView
              // passes newIdx as the position AFTER removal, so bump it down
              // by 1 when moving forward.
              final effective = manageableCols.map((c) => c.key).toList();
              if (newIdx > oldIdx) newIdx -= 1;
              final moved = effective.removeAt(oldIdx);
              effective.insert(newIdx, moved);
              _columnOrder = effective;
            });
          },
          onToggleColumn: (key, visible) {
            setState(() {
              if (visible) {
                _hiddenColumns.remove(key);
              } else {
                _hiddenColumns.add(key);
              }
            });
          },
          onResetColumns: () {
            setState(() {
              _hiddenColumns.clear();
              _columnOrder = [];
            });
          },
          onTreatNullAs: (v) {
            _setBuilder(_state.copyWith(treatNullAs: v));
            if (_result != null) _run();
          },
          onLimit: (n) => _setBuilder(_state.copyWith(limit: n)),
          onApplyLimit: _run,
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
    // Full catalog of manageable columns in their "natural" order — Symbol,
    // Exch and the standard fundamentals up front, then dynamic filter
    // columns. Symbol / Exch flow through here (not the table's pinned slots)
    // so users can drag them anywhere in the Manage Columns menu.
    final allCols = <ScanColumn>[
      const ScanColumn(
          key: 'ticker', label: 'Symbol', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'exch', label: 'Exch', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'sector', label: 'Sector', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'industry', label: 'Industry', fmt: 'string', isStandard: true),
      const ScanColumn(
          key: 'market_cap',
          label: 'Market Cap (Cr)',
          fmt: 'int',
          isStandard: true),
      for (final cl in resp.columnLabels)
        ScanColumn(key: cl.field, label: cl.label, fmt: 'ratio'),
    ];
    final byKey = {for (final c in allCols) c.key: c};
    final orderedKeys = _effectiveColumnOrder(allCols.map((c) => c.key).toList());
    final visibleOrdered = <ScanColumn>[
      for (final k in orderedKeys)
        if (!_hiddenColumns.contains(k) && byKey[k] != null) byKey[k]!,
    ];
    final rows = [
      for (final m in resp.matches)
        ScanRow(
          ticker: m.ticker,
          name: m.name,
          values: {
            ...m.values,
            'ticker': m.ticker,
            'exch': 'NSE',
            'sector': m.sector ?? '',
            'industry': m.industry ?? '',
            'market_cap':
                m.marketCap == null ? null : (m.marketCap! / 1e7).round(),
          },
        ),
    ];
    return ScannerResultsTable(
      // Everything flows through `columns` including Symbol / Exch — the
      // table's pinned Symbol / Exch slots are turned off so the drag order
      // from Manage Columns fully controls the render sequence.
      columns: visibleOrdered,
      standardPrefixColumns: const [],
      showSymbol: false,
      showExch: false,
      rows: rows,
      footer: '${resp.returned} of ${resp.total} matches',
      onTickerTap: (t) =>
          openScannerScripFromContext(context, ref, ticker: t),
    );
  }

  /// Combines the user-preferred order (`_columnOrder`) with the current
  /// catalog of column keys. Preserves the drag-order for keys the user has
  /// touched and appends any brand-new keys (e.g. columns introduced by a
  /// newly-added filter) to the end.
  List<String> _effectiveColumnOrder(List<String> availableKeys) {
    final avail = availableKeys.toSet();
    return <String>[
      for (final k in _columnOrder)
        if (avail.contains(k)) k,
      for (final k in availableKeys)
        if (!_columnOrder.contains(k)) k,
    ];
  }

  // ---------------------------------------------------------------------
  // Actions (same behaviour as the current screen, on the new session).
  // ---------------------------------------------------------------------
  Future<void> _run() async {
    final hasFund = _shown.isNotEmpty || _state.filters.isNotEmpty;
    if (!hasFund) {
      ResponsiveSnackBar.showWarning(context, 'Add a filter first.');
      return;
    }
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

  /// Persist the current screen under the name typed in the header field.
  /// The header textfield is the single source of truth for the screen name —
  /// no dialog is shown. If it's empty, we surface a warning snackbar so the
  /// user knows why the save didn't happen.
  Future<void> _save() async {
    final name = _screenNameCtrl.text.trim();
    if (name.isEmpty) {
      ResponsiveSnackBar.showWarning(
          context, 'Please enter a name');
      return;
    }
    await locator<ApiExporter>().saveScreen(
      name: name,
      filters: _state.filters,
      treatNullAs: _state.treatNullAs,
      orderBy: _state.orderBy,
      orderDir: _state.orderDir,
      limit: _state.limit,
    );
    ref.invalidate(savedScreensProvider);
    if (mounted) {
      ResponsiveSnackBar.showSuccess(context, 'Saved "$name"');
    }
  }

  Future<void> _deleteSavedScreen(int id, String name) async {
    try {
      await locator<ApiExporter>().deleteSavedScreen(id);
      ref.invalidate(savedScreensProvider);
      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Deleted "$name"');
      }
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Could not delete: $e');
    }
  }
}

/// A compact, intrinsic-width filter chip — shows the metric label + a
/// chevron; taps open a popover overlay with the condition editor. For
/// sector / industry the popover renders the searchable checkbox list
/// directly (no intermediate "Select sectors…" dropdown); for numeric
/// metrics it embeds [FundamentalFilterRow] in stacked / hideField mode.
class _FilterChip extends ConsumerStatefulWidget {
  final FundamentalField field;
  final FundamentalFilter? filter;
  final List<FundamentalField> allFields;
  final int nonce;
  final String? draftOp;
  final ValueChanged<FundamentalFilter> onChange;
  final VoidCallback onDelete;

  const _FilterChip({
    super.key,
    required this.field,
    required this.filter,
    required this.allFields,
    required this.nonce,
    required this.draftOp,
    required this.onChange,
    required this.onDelete,
  });

  @override
  ConsumerState<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends ConsumerState<_FilterChip> {
  final GlobalKey _key = GlobalKey();
  final TextEditingController _search = TextEditingController();
  OverlayEntry? _overlay;
  bool _hover = false;

  bool get _isCategory =>
      widget.field.key == 'sector' || widget.field.key == 'industry';

  @override
  void dispose() {
    _remove();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FilterChip old) {
    super.didUpdateWidget(old);
    // Parent Riverpod state changes trigger didUpdateWidget synchronously
    // during the build phase — deferring markNeedsBuild avoids the
    // "widget marked as needing to build during build" assert on the
    // (separately-rooted) overlay entry.
    if (old.nonce != widget.nonce || old.filter != widget.filter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlay?.markNeedsBuild();
      });
    }
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggle() {
    if (_overlay != null) {
      _remove();
      if (mounted) setState(() {});
      return;
    }
    _search.clear();
    _open();
  }

  String _defaultOp(FundamentalField f) {
    if (f.key == 'sector' || f.key == 'industry') return 'in';
    final ops = validOpsForDtype(f.dtype, multiYear: isMultiYearField(f.key));
    return ops.isNotEmpty ? ops.first : '>';
  }

  void _open() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final screenW = MediaQuery.of(context).size.width;
    // Panel width adapts to what the popover actually renders:
    //  - category (sector/industry): a wider list of long names + search
    //  - multi-year numeric: op + value + years input on one row
    //  - simple numeric: op + value only, the tightest of the three
    final double panelW;
    if (_isCategory) {
      panelW = 380.0;
    } else if (isMultiYearField(widget.field.key)) {
      panelW = 380.0;
    } else {
      panelW = 340.0;
    }
    // Flip against the right edge so wide popovers on right-side chips don't
    // clip; leaves a 12px margin from the viewport edge.
    final left = (pos.dx + panelW > screenW - 12)
        ? (screenW - panelW - 12).clamp(12.0, double.infinity)
        : pos.dx;

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _remove();
              if (mounted) setState(() {});
            },
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: pos.dy + size.height + 6,
          width: panelW,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bg,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _popoverBody(),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  Widget _popoverBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _popoverHeader(),
        const SizedBox(height: 10),
        if (_isCategory)
          _categoryPickerBody()
        else
          FundamentalFilterRow(
            key: ValueKey('${widget.field.key}#${widget.nonce}'),
            stacked: true,
            hideField: true,
            fields: widget.allFields,
            filter: widget.filter ??
                FundamentalFilter(
                  field: widget.field.key,
                  op: widget.draftOp ?? _defaultOp(widget.field),
                ),
            onChange: (f) {
              widget.onChange(f);
              _overlay?.markNeedsBuild();
            },
            onRemove: () {},
          ),
      ],
    );
  }

  Widget _popoverHeader() {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Row(children: [
      Expanded(
        child: Text(
          widget.field.label,
          style: MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.semiBold, color: textPrimary),
        ),
      ),
      // Close only — the chip's own inline × handles filter removal, so this
      // header × just dismisses the popover.
      InkWell(
        onTap: () {
          _remove();
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(shadcn.LucideIcons.x, size: 14, color: secondary),
        ),
      ),
    ]);
  }

  /// Sector / Industry picker rendered directly in the popover — a search
  /// field over a scrollable checkbox list. Matches the FilterMultiSelect
  /// look, but skips its nested-dropdown trigger so a single chip tap gets
  /// the user straight to the options.
  ///
  /// Wrapped in a Consumer so the async categories provider subscribes and
  /// rebuilds inside the overlay tree directly. Watching via the parent
  /// ConsumerState only rebuilt the trigger chip — the overlay stayed on its
  /// initial (empty) frame and showed "No matches" until re-opened.
  Widget _categoryPickerBody() {
    return Consumer(builder: (context, ref, _) {
      final catsAsync = ref.watch(fundamentalCategoriesProvider);
      return catsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load options',
              style: MyntWebTextStyles.body(context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary))),
        ),
        data: (c) => _categoryPickerList(
            widget.field.key == 'sector' ? c.sectors : c.industries),
      );
    });
  }

  Widget _categoryPickerList(List<String> options) {
    final selected = widget.filter?.value is List
        ? (widget.filter!.value as List)
            .map((e) => e.toString())
            .toSet()
        : <String>{};
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? options
        : options.where((o) => o.toLowerCase().contains(q)).toList();
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final borderColor = resolveThemeColor(context,
        dark: MyntColors.borderMutedDark, light: MyntColors.borderMuted);
    final searchShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: borderColor),
    );

    void emit(Set<String> next) {
      widget.onChange(FundamentalFilter(
        field: widget.field.key,
        op: 'in',
        value: next.isEmpty ? null : next.toList(),
      ));
      _overlay?.markNeedsBuild();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            controller: _search,
            autofocus: true,
            style: MyntWebTextStyles.body(context),
            onChanged: (_) => _overlay?.markNeedsBuild(),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18, color: muted),
              hintText: 'Search…',
              hintStyle: MyntWebTextStyles.body(context,
                  color: muted.withValues(alpha: 0.6)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: searchShape,
              focusedBorder: searchShape,
              border: searchShape,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No matches',
                      style: MyntWebTextStyles.body(context, color: muted)),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in filtered)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final next = {...selected};
                              if (next.contains(o)) {
                                next.remove(o);
                              } else {
                                next.add(o);
                              }
                              emit(next);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                              child: Row(children: [
                                Icon(
                                  selected.contains(o)
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 18,
                                  color: selected.contains(o)
                                      ? resolveThemeColor(context, dark: MyntColors.secondaryDark, light: MyntColors.primary)
                                      : muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(o,
                                      style: MyntWebTextStyles.body(context,
                                          color: textPrimary),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// One-line preview of the filter's current value, shown next to the chip
  /// label. Numeric ops render as "op value" (`> 20`, `≥ 15`), category
  /// filters as a comma list truncated after 2 items (`Bank, IT +3`),
  /// between as `a – b`, and null-checks as human-readable text.
  String _valueSummary(FundamentalFilter f) {
    final op = f.op;
    if (op == 'is_null') return 'is empty';
    if (op == 'is_not_null') return 'not empty';
    if (op == 'min_years') return 'min ${f.value ?? f.years ?? '?'} yrs';
    final v = f.value;
    if (v == null) return '';
    if (op == 'between') {
      if (v is List && v.length == 2) return '${_fmt(v[0])} – ${_fmt(v[1])}';
      return '';
    }
    if (op == 'in' || op == 'not_in') {
      if (v is List) {
        if (v.isEmpty) return '';
        final head = v.take(2).map((e) => e.toString()).join(', ');
        final extra = v.length - 2;
        final joined = extra > 0 ? '$head +$extra' : head;
        return op == 'not_in' ? 'not $joined' : joined;
      }
      return '';
    }
    const sym = {
      '<': '<',
      '<=': '≤',
      '>': '>',
      '>=': '≥',
      '==': '=',
      '!=': '≠',
    };
    final s = sym[op] ?? op;
    return '$s ${_fmt(v)}';
  }

  /// Format a scalar for chip display — drops the ".0" tail on ints, keeps a
  /// couple of decimals for fractions, and leaves strings untouched.
  String _fmt(Object? v) {
    if (v is num) {
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(2);
    }
    return v?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.filter != null;
    final isOpen = _overlay != null;
    final border = shadcn.Theme.of(context).colorScheme.border;
    // Accent used for active chip border / label / chevron — brighter blue in
    // dark theme so the highlight reads against the dark surface.
    final primary = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final borderColor =
        active || isOpen ? primary.withValues(alpha: 0.55) : border;
    final labelColor = active ? primary : textPrimary;
    final chevronColor = active ? primary : secondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        key: _key,
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(6),
          color: _hover || isOpen ? hoverBg : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label + selected-value summary + chevron open the popover.
            GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.field.label,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium, color: labelColor),
                  ),
                  if (widget.filter != null) ...[
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        _valueSummary(widget.filter!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.medium,
                            color: textPrimary),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  // Compact Lucide chevron so the chip's open/close indicator
                  // reads at the same visual weight as the header's Options
                  // dropdown, not the heavier Material keyboard arrow.
                  Icon(
                    isOpen
                        ? shadcn.LucideIcons.chevronUp
                        : shadcn.LucideIcons.chevronDown,
                    size: 14,
                    color: chevronColor,
                  ),
                ],
              ),
            ),
            // Inline × removes just this chip; separate hit target so it does
            // not toggle the popover.
            InkWell(
              onTap: () {
                if (isOpen) _remove();
                widget.onDelete();
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(shadcn.LucideIcons.x,
                    size: 12, color: secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact chip-styled popover trigger — used by the Missing data / Show top
/// controls so they read as siblings of the filter chips. Renders "[label]
/// [value] chevron" and opens the given `contentBuilder` in an overlay.
class _PopoverChip extends StatefulWidget {
  final String label;
  final String value;
  final double panelWidth;
  final Widget Function(BuildContext, VoidCallback close) contentBuilder;

  const _PopoverChip({
    required this.label,
    required this.value,
    required this.panelWidth,
    required this.contentBuilder,
  });

  @override
  State<_PopoverChip> createState() => _PopoverChipState();
}

class _PopoverChipState extends State<_PopoverChip> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlay;
  bool _hover = false;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PopoverChip old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlay?.markNeedsBuild();
      });
    }
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _close() {
    _remove();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
      return;
    }
    _open();
  }

  void _open() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final screenW = MediaQuery.of(context).size.width;
    final left = (pos.dx + widget.panelWidth > screenW - 12)
        ? (screenW - widget.panelWidth - 12).clamp(12.0, double.infinity)
        : pos.dx;

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: pos.dy + size.height + 6,
          width: widget.panelWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bg,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.contentBuilder(context, _close),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        key: _key,
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding:
              const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1),
            borderRadius: BorderRadius.circular(6),
            color: _hover || isOpen ? hoverBg : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium, color: secondary),
              ),
              const SizedBox(width: 6),
              Text(
                widget.value,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold, color: accent),
              ),
              const SizedBox(width: 4),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact 3-dot settings trigger at the right end of the filter row. Opens
/// a small popover with Missing data (Exclude/Include) and Show top (int)
/// controls — used to live as inline chips, now consolidated so the row can
/// dedicate its horizontal space to the actual filter chips.
class _SettingsMenu extends StatefulWidget {
  final String treatNullAs;
  final int limit;
  final TextEditingController limitCtrl;
  final ValueChanged<String> onTreatNullAs;
  final ValueChanged<int> onLimit;
  /// Fires when the user hits Apply next to the Show top field — the parent
  /// re-runs the scan with the latest limit. `onLimit` has already saved the
  /// number by the time this fires, so the callback just needs to trigger
  /// the run (no argument needed).
  final VoidCallback onApplyLimit;
  /// Columns currently available in the results table. Passed from the parent
  /// so the checkbox list mirrors exactly what's rendered. Empty before the
  /// first Run scan → the Manage Columns section is skipped.
  final List<({String key, String label})> manageableColumns;
  final Set<String> hiddenColumns;
  final void Function(String key, bool visible) onToggleColumn;
  /// Fired when the user drags a column row in the Manage Columns list. Uses
  /// the standard `ReorderableListView` (oldIndex, newIndex) contract.
  final void Function(int oldIdx, int newIdx) onReorderColumn;
  /// Restore both visibility and drag-order for all columns to the defaults
  /// (natural order, everything visible).
  final VoidCallback onResetColumns;

  const _SettingsMenu({
    required this.treatNullAs,
    required this.limit,
    required this.limitCtrl,
    required this.onTreatNullAs,
    required this.onLimit,
    required this.onApplyLimit,
    required this.manageableColumns,
    required this.hiddenColumns,
    required this.onToggleColumn,
    required this.onReorderColumn,
    required this.onResetColumns,
  });

  @override
  State<_SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<_SettingsMenu> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlay;
  bool _hover = false;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SettingsMenu old) {
    super.didUpdateWidget(old);
    // Parent rebuilds after `onTreatNullAs` fire with the new value — mark
    // the overlay so it re-reads `widget.treatNullAs` on the next frame.
    // Without this the segmented button flips only on a second click.
    if (old.treatNullAs != widget.treatNullAs || old.limit != widget.limit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlay?.markNeedsBuild();
      });
    }
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _close() {
    _remove();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
      return;
    }
    _open();
  }

  void _open() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final screenW = MediaQuery.of(context).size.width;
    const panelW = 240.0;
    // Right-align the panel to the trigger so it grows leftward.
    final anchorRight = pos.dx + size.width;
    final left = (anchorRight - panelW).clamp(12.0, screenW - panelW - 12.0);

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: pos.dy + size.height + 6,
          width: panelW,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bg,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel('Missing data'),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _segButton('Exclude', 'fail')),
                    const SizedBox(width: 6),
                    Expanded(child: _segButton('Include', 'pass')),
                  ]),
                  const SizedBox(height: 12),
                  _sectionLabel('Show top'),
                  const SizedBox(height: 6),
                  // Number field + Apply button share the row — Apply
                  // re-runs the scan with the current limit. onChanged still
                  // saves the value so the header's Run scan picks it up
                  // too; the button is just a same-popover shortcut.
                  Row(children: [
                    Expanded(
                      child: FilterTextField(
                        controller: widget.limitCtrl,
                        hint: '100',
                        height: 34,
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) {
                            widget.onLimit(n);
                            _overlay?.markNeedsBuild();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    _applyButton(),
                  ]),
                  // Manage Columns — a drag-reorderable checkbox next to
                  // each currently-available column. Skipped before the
                  // first Run scan when there's nothing to manage yet.
                  if (widget.manageableColumns.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _manageColumnsHeader(),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        physics: const ClampingScrollPhysics(),
                        itemCount: widget.manageableColumns.length,
                        onReorder: (o, n) {
                          widget.onReorderColumn(o, n);
                          // The parent rebuilds asynchronously; mark our
                          // overlay so the reordered list paints before the
                          // next frame propagates through didUpdateWidget.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _overlay?.markNeedsBuild();
                          });
                        },
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.transparent,
                          child: child,
                        ),
                        itemBuilder: (context, i) {
                          final col = widget.manageableColumns[i];
                          return _columnCheckRow(
                            col.key,
                            col.label,
                            index: i,
                            key: ValueKey('col-${col.key}'),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  /// One row inside Manage Columns: drag-handle grip on the left (long-press
  /// to reorder), checkbox + label on the right. Tapping the checkbox / label
  /// toggles visibility; dragging the grip fires `onReorderColumn` upstream.
  Widget _columnCheckRow(
    String colKey,
    String label, {
    required int index,
    required Key key,
  }) {
    final visible = !widget.hiddenColumns.contains(colKey);
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        // Explicit drag handle — long-press anywhere on the grip icon to
        // start reordering. Using `buildDefaultDragHandles: false` on the
        // ReorderableListView so this custom handle is the only drag source.
        ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(Icons.drag_indicator, size: 16, color: muted),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              widget.onToggleColumn(colKey, !visible);
              _overlay?.markNeedsBuild();
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                Icon(
                  visible ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 16,
                  color: visible ? accent : muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.medium, color: textPrimary),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  /// "Manage columns" heading with a trailing reset icon. Tap restores the
  /// natural order and un-hides every column.
  Widget _manageColumnsHeader() {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Row(children: [
      Expanded(child: _sectionLabel('Manage columns')),
      Tooltip(
        message: 'Reset columns',
        child: InkWell(
          onTap: () {
            widget.onResetColumns();
            _overlay?.markNeedsBuild();
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(shadcn.LucideIcons.rotateCcw,
                size: 13, color: muted),
          ),
        ),
      ),
    ]);
  }

  Widget _sectionLabel(String label) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Text(label,
        style: MyntWebTextStyles.caption(context,
            fontWeight: MyntFonts.medium, color: muted));
  }

  /// Small filled Apply button next to the Show top field. Fires the parent
  /// callback which re-runs the scan with the current limit + closes the
  /// popover so the user sees the fresh results immediately.
  Widget _applyButton() {
    final primary = resolveThemeColor(context,
        dark: MyntColors.secondary, light: MyntColors.primary);
    return InkWell(
      onTap: () {
        widget.onApplyLimit();
        _close();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Apply',
            style: MyntWebTextStyles.body(context,
                fontWeight: MyntFonts.semiBold, color: Colors.white)),
      ),
    );
  }

  Widget _segButton(String label, String value) {
    final selected = widget.treatNullAs == value;
    final border = shadcn.Theme.of(context).colorScheme.border;
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return InkWell(
      onTap: () {
        widget.onTreatNullAs(value);
        _overlay?.markNeedsBuild();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? accent : border,
              width: selected ? 1.2 : 1),
          borderRadius: BorderRadius.circular(6),
          color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.body(context,
              fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
              color: selected ? accent : textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    final border = shadcn.Theme.of(context).colorScheme.border;
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Tooltip(
      message: 'Missing data & Show top',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          key: _key,
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
              color: _hover || isOpen ? hoverBg : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.more_vert, size: 18, color: secondary),
          ),
        ),
      ),
    );
  }
}

/// Combined screen-name field + Options menu — the trigger renders as one
/// pill with an inline text input on the left (typed name is used by
/// "Save as…") and a chevron on the right that opens a small overlay list.
/// The menu inlines the Saved and Predefined screen lists (Tickertape-style)
/// so switching screens takes one tap instead of opening a separate modal.
class _OptionsMenu extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSaveAs;
  final VoidCallback onDownload;
  final void Function(List<FundamentalFilter> filters, String treatNullAs,
      String name) onLoadScreen;

  const _OptionsMenu({
    required this.controller,
    required this.onSaveAs,
    required this.onDownload,
    required this.onLoadScreen,
  });

  @override
  ConsumerState<_OptionsMenu> createState() => _OptionsMenuState();
}

class _OptionsMenuState extends ConsumerState<_OptionsMenu> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlay;
  bool _hover = false;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _close() {
    _remove();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_overlay != null) {
      _close();
      return;
    }
    _open();
  }

  void _open() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final screenW = MediaQuery.of(context).size.width;
    // Panel aligns to the trigger's left edge and matches its width so the
    // dropdown reads as a direct extension of the pill.
    final panelW = size.width;
    final left = pos.dx.clamp(12.0, screenW - panelW - 12.0);

    _overlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left.toDouble(),
          top: pos.dy + size.height + 6,
          width: panelW,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bg,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // "Save as…" moved out of the dropdown — the header
                        // now has a standalone Save chip next to the pill.
                        _sectionHeader('SAVED'),
                        _SavedScreensList(
                          onLoad: (s) {
                            _close();
                            widget.onLoadScreen(
                                s.filters, s.treatNullAs, s.name);
                          },
                          onEdit: (s) {
                            // Edit = load into the builder + populate the
                            // name field, so the user can tweak and re-save.
                            _close();
                            widget.onLoadScreen(
                                s.filters, s.treatNullAs, s.name);
                          },
                          onDelete: _confirmAndDelete,
                        ),
                        _divider(),
                        _sectionHeader('PREDEFINED'),
                        _PresetScreensList(
                          onLoad: (p) {
                            _close();
                            widget.onLoadScreen(
                                p.filters, p.treatNullAs, p.name);
                          },
                        ),
                        // Download moved out of this dropdown — it now lives
                        // as a top-level chip next to Save in the header.
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  Widget _divider() {
    final border = shadcn.Theme.of(context).colorScheme.border;
    return Container(height: 1, color: border);
  }

  /// Small uppercase subtitle marking each list section ("SAVED",
  /// "PREDEFINED"). Uses the tertiary text color so it recedes against the
  /// screen-name rows below.
  Widget _sectionHeader(String label) {
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        label,
        style: MyntWebTextStyles.caption(context,
                fontWeight: MyntFonts.semiBold, color: tertiary)
            .copyWith(letterSpacing: 1.0),
      ),
    );
  }

  Future<void> _confirmAndDelete(SavedFundamentalScreen s) async {
    // The parent state owns delete + snackbar, but we need to close our
    // popover first so it doesn't sit on top of the confirmation snackbar.
    _close();
    final parent =
        context.findAncestorStateOfType<_FundamentalsNewSubPageState>();
    if (parent == null) return;
    await parent._deleteSavedScreen(s.id, s.name);
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return Container(
      key: _key,
      width: 280,
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
        color: isOpen ? hoverBg : Colors.transparent,
      ),
      child: Row(
        children: [
          // Editable screen-name input — tap-to-focus, doesn't open the menu.
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: TextField(
                controller: widget.controller,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium, color: textPrimary),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Screen name',
                  hintStyle: MyntWebTextStyles.body(context,
                      color: secondary.withValues(alpha: 0.7)),
                ),
                onSubmitted: (_) => widget.onSaveAs(),
              ),
            ),
          ),
          // Divider so the chevron button reads as a discrete affordance.
          Container(width: 1, height: 20, color: border),
          // Chevron button opens the options menu.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: double.infinity,
                alignment: Alignment.center,
                color: _hover ? hoverBg : Colors.transparent,
                child: Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Async list of the user's saved screens rendered inside the Options menu.
/// Each row: screen name on the left, edit + delete icons on the right.
/// Row tap loads the screen (same as clicking the pencil).
class _SavedScreensList extends ConsumerWidget {
  final void Function(SavedFundamentalScreen) onLoad;
  final void Function(SavedFundamentalScreen) onEdit;
  final void Function(SavedFundamentalScreen) onDelete;

  const _SavedScreensList({
    required this.onLoad,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedScreensProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => _emptyRow(context, 'Could not load saved screens'),
      data: (list) {
        if (list.isEmpty) {
          return _emptyRow(context, 'No saved screens yet');
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in list)
              _SavedRow(
                screen: s,
                onLoad: () => onLoad(s),
                onEdit: () => onEdit(s),
                onDelete: () => onDelete(s),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyRow(BuildContext context, String label) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Text(label,
          style: MyntWebTextStyles.caption(context, color: secondary)),
    );
  }
}

class _SavedRow extends StatefulWidget {
  final SavedFundamentalScreen screen;
  final VoidCallback onLoad;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavedRow({
    required this.screen,
    required this.onLoad,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SavedRow> createState() => _SavedRowState();
}

class _SavedRowState extends State<_SavedRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final errorColor = resolveThemeColor(context,
        dark: MyntColors.errorDark, light: MyntColors.error);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover ? hoverBg : Colors.transparent,
        child: InkWell(
          onTap: widget.onLoad,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  widget.screen.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium, color: textPrimary),
                ),
              ),
              _iconAction(
                icon: shadcn.LucideIcons.pencil,
                tooltip: 'Edit',
                color: secondary,
                onTap: widget.onEdit,
              ),
              const SizedBox(width: 2),
              _iconAction(
                icon: shadcn.LucideIcons.trash2,
                tooltip: 'Delete',
                color: errorColor,
                onTap: widget.onDelete,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

/// Async list of predefined preset screens rendered inside the Options menu.
/// Presets are read-only, so rows carry just the name — tap to load.
class _PresetScreensList extends ConsumerWidget {
  final void Function(FundamentalPreset) onLoad;

  const _PresetScreensList({required this.onLoad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fundamentalPresetsProvider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Text('Could not load presets',
            style: MyntWebTextStyles.caption(context, color: secondary)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text('No presets available',
                style: MyntWebTextStyles.caption(context, color: secondary)),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in list)
              InkWell(
                onTap: () => onLoad(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.medium, color: textPrimary),
                      ),
                    ),
                    // Info icon only when the preset carries a description —
                    // no point flashing an empty tooltip on hover.
                    if (p.description.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _PresetInfoIcon(description: p.description),
                    ],
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small info affordance next to a preset's name — an "i" icon that opens a
/// styled description card to the right of the icon on hover. Uses a custom
/// overlay (not Flutter's Tooltip) because Tooltip only picks above/below,
/// and we want the card to sit alongside the icon so the row list underneath
/// stays visible while hovering.
class _PresetInfoIcon extends StatefulWidget {
  final String description;
  const _PresetInfoIcon({required this.description});

  @override
  State<_PresetInfoIcon> createState() => _PresetInfoIconState();
}

class _PresetInfoIconState extends State<_PresetInfoIcon> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _show() {
    if (_overlay != null) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final screenW = MediaQuery.of(context).size.width;
    const panelW = 240.0;
    // Right of the icon by default; flip to the left if we'd clip the viewport.
    double left = pos.dx + size.width + 8;
    if (left + panelW > screenW - 12) {
      left = pos.dx - panelW - 8;
    }
    if (left < 12) left = 12;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        // Center vertically on the icon.
        top: pos.dy + size.height / 2 - 20,
        width: panelW,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.description,
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.medium, color: textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return MouseRegion(
      onEnter: (_) => _show(),
      onExit: (_) => _remove(),
      child: GestureDetector(
        // Swallow taps so hovering / clicking the icon doesn't trigger the
        // parent row's "load preset" action.
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Padding(
          key: _key,
          padding: const EdgeInsets.all(2),
          child: Icon(shadcn.LucideIcons.info, size: 14, color: muted),
        ),
      ),
    );
  }
}


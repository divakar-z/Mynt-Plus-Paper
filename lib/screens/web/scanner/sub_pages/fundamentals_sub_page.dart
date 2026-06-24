import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/fundamental_scan.dart';
import 'package:mynt_plus/provider/scanner/fundamentals_provider.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/fundamentals_builder_state.dart';
import 'package:mynt_plus/screens/web/scanner/utils/download_xlsx.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/fundamental_filter_row.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

class FundamentalsSubPage extends ConsumerStatefulWidget {
  const FundamentalsSubPage({super.key});

  @override
  ConsumerState<FundamentalsSubPage> createState() =>
      _FundamentalsSubPageState();
}

class _FundamentalsSubPageState extends ConsumerState<FundamentalsSubPage> {
  // Builder inputs and result live in `fundamentalsSessionProvider` so they
  // survive navigation away from this pane (e.g. opening a result symbol's
  // chart) and back. These accessors keep the rest of the build code tidy.
  FundamentalsBuilderState get _state =>
      ref.read(fundamentalsSessionProvider).builder;
  AsyncValue<FundamentalScanResponse>? get _result =>
      ref.read(fundamentalsSessionProvider).result;
  void _setBuilder(FundamentalsBuilderState b) =>
      ref.read(fundamentalsSessionProvider.notifier).setBuilder(b);
  void _setResult(AsyncValue<FundamentalScanResponse>? r) =>
      ref.read(fundamentalsSessionProvider.notifier).setResult(r);

  @override
  Widget build(BuildContext context) {
    // Watch so the body rebuilds when builder/result change.
    ref.watch(fundamentalsSessionProvider);
    final fields = ref.watch(fundamentalFieldsProvider);
    final presets = ref.watch(fundamentalPresetsProvider);
    final saved = ref.watch(savedScreensProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header row with title + actions
          _topBar(),
          const SizedBox(height: 16),
          _SectionCard(
            label: 'SAVED SCREENS',
            child: saved.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString(),
                  style: MyntWebTextStyles.caption(context)),
              data: (list) => list.isEmpty
                  ? Text('None yet — save a screen to reuse it.',
                      style: MyntWebTextStyles.caption(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)))
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in list)
                        InputChip(
                          avatar: const Icon(shadcn.LucideIcons.bookmark, size: 12),
                          label: Text(s.name),
                          onPressed: () => _setBuilder(_state.copyWith(
                                    filters: s.filters,
                                    treatNullAs: s.treatNullAs,
                                  )),
                          onDeleted: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete saved screen?'),
                                content: Text('"${s.name}" will be removed.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await locator<ApiExporter>()
                                  .deleteSavedScreen(s.id);
                              ref.invalidate(savedScreensProvider);
                            }
                          },
                        ),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'PRESETS',
            child: presets.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString(),
                  style: MyntWebTextStyles.caption(context)),
              data: (list) => Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in list)
                  ActionChip(
                    avatar: const Icon(shadcn.LucideIcons.layers, size: 12),
                    label: Text(p.name),
                    onPressed: () => _setBuilder(_state.copyWith(
                              filters: p.filters,
                              treatNullAs: p.treatNullAs,
                            )),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'FILTERS',
            trailing: fields.maybeWhen(
              data: (fList) => TextButton.icon(
                icon: const Icon(shadcn.LucideIcons.plus, size: 14),
                label: const Text('Add filter'),
                onPressed: () {
                  if (fList.isEmpty) return;
                  final nf = [
                    ..._state.filters,
                    FundamentalFilter(field: fList.first.key, op: '<'),
                  ];
                  _setBuilder(_state.copyWith(filters: nf));
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            child: fields.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => EmptyState(
                kind: EmptyStateKind.error,
                title: 'Could not load field catalog',
                message: e.toString(),
                onRetry: () => ref.invalidate(fundamentalFieldsProvider),
              ),
              data: (fList) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_state.filters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No filters yet — click + Add filter to begin, or pick a preset.',
                        style: MyntWebTextStyles.caption(context,
                            color: resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary)),
                      ),
                    ),
                  for (int i = 0; i < _state.filters.length; i++) ...[
                    FundamentalFilterRow(
                      fields: fList,
                      filter: _state.filters[i],
                      onChange: (f) {
                        final nf = [..._state.filters]..[i] = f;
                        _setBuilder(_state.copyWith(filters: nf));
                      },
                      onRemove: () {
                        final nf = [..._state.filters]..removeAt(i);
                        _setBuilder(_state.copyWith(filters: nf));
                      },
                    ),
                    if (i < _state.filters.length - 1)
                      const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: shadcn.Theme.of(context).colorScheme.border),
                  const SizedBox(height: 12),
                  _bottomToolbar(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_result != null) _buildResults(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Top bar: title + Save as / Download / Run scan
  // ---------------------------------------------------------------------
  Widget _topBar() {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text('Fundamental Screener',
            style:
                MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold)),
        Text('Filter by any combination of fundamental metrics',
            style: MyntWebTextStyles.caption(context, color: secondary)),
        const SizedBox(width: 200), // pushes actions right when wrap fits
        Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            icon: const Icon(shadcn.LucideIcons.save, size: 14),
            label: const Text('Save as…'),
            onPressed: _save,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(shadcn.LucideIcons.download, size: 14),
            label: const Text('Download'),
            onPressed: _export,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(shadcn.LucideIcons.play, size: 14),
            label: const Text('Run scan'),
            onPressed: _run,
          ),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Bottom toolbar inside the FILTERS card
  // ---------------------------------------------------------------------
  Widget _bottomToolbar() {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final labelStyle = MyntWebTextStyles.caption(context, color: secondary);
    final controls = <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Missing data:', style: labelStyle),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Exclude'),
          selected: _state.treatNullAs == 'fail',
          onSelected: (_) =>
              _setBuilder(_state.copyWith(treatNullAs: 'fail')),
        ),
        const SizedBox(width: 4),
        ChoiceChip(
          label: const Text('Include'),
          selected: _state.treatNullAs == 'pass',
          onSelected: (_) =>
              _setBuilder(_state.copyWith(treatNullAs: 'pass')),
        ),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Sort by', style: labelStyle),
        const SizedBox(width: 6),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            isDense: true,
            isExpanded: true,
            value: _state.orderBy,
            decoration: _denseFieldDecoration(),
            items: const [
              DropdownMenuItem(
                  value: 'market_cap', child: Text('Market Cap')),
              DropdownMenuItem(
                  value: 'pe_trailing', child: Text('P/E (TTM)')),
              DropdownMenuItem(
                  value: 'return_on_equity', child: Text('ROE')),
              DropdownMenuItem(
                  value: 'dividend_yield', child: Text('Dividend Yield')),
              DropdownMenuItem(value: 'name', child: Text('Name')),
            ],
            onChanged: (v) {
              if (v != null) _setBuilder(_state.copyWith(orderBy: v));
            },
          ),
        ),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Dir', style: labelStyle),
        const SizedBox(width: 6),
        SizedBox(
          width: 110,
          child: DropdownButtonFormField<String>(
            isDense: true,
            isExpanded: true,
            value: _state.orderDir,
            decoration: _denseFieldDecoration(),
            items: const [
              DropdownMenuItem(value: 'desc', child: Text('Desc')),
              DropdownMenuItem(value: 'asc', child: Text('Asc')),
            ],
            onChanged: (v) {
              if (v != null) _setBuilder(_state.copyWith(orderDir: v));
            },
          ),
        ),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Limit', style: labelStyle),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: TextFormField(
            initialValue: _state.limit.toString(),
            keyboardType: TextInputType.number,
            decoration: _denseFieldDecoration(),
            style: MyntWebTextStyles.body(context),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) _setBuilder(_state.copyWith(limit: n));
            },
          ),
        ),
      ]),
    ];

    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        icon: const Icon(shadcn.LucideIcons.save, size: 14),
        label: const Text('Save as…'),
        onPressed: _save,
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        icon: const Icon(shadcn.LucideIcons.play, size: 14),
        label: const Text('Run scan'),
        onPressed: _run,
      ),
    ]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          ),
        ),
        const SizedBox(width: 16),
        actions,
      ],
    );
  }

  InputDecoration _denseFieldDecoration() => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: shadcn.Theme.of(context).colorScheme.border),
        ),
      );

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------
  Future<void> _run() async {
    for (final f in _state.filters) {
      final needsValue = f.op != 'is_null' && f.op != 'is_not_null';
      if (needsValue && f.value == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set a value for "${f.field}" (${f.op})')),
        );
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

  Future<void> _save() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save screen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Screen name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Widget _buildResults() {
    return _result!.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
      ),
      data: (resp) {
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
              key: 'industry',
              label: 'Industry',
              fmt: 'string',
              isStandard: true),
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
        return SizedBox(
          height: 520,
          child: ScannerResultsTable(
            columns: dynamicCols,
            standardPrefixColumns: standard,
            rows: rows,
            footer: '${resp.returned} of ${resp.total} matches',
            onTickerTap: (t) =>
                openScannerScripFromContext(context, ref, ticker: t),
          ),
        );
      },
    );
  }
}

/// Reusable bordered card with a small caps label in the top-left and an
/// optional trailing widget on the right.
class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
        color: resolveThemeColor(context,
            dark: MyntColors.cardDark, light: MyntColors.card),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(label,
                style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.semiBold, color: tertiary)
                    .copyWith(letterSpacing: 0.8)),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

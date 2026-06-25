import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
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
                        _SavedScreenChip(
                          name: s.name,
                          onApply: () => _setBuilder(_state.copyWith(
                                filters: s.filters,
                                treatNullAs: s.treatNullAs,
                              )),
                          onDelete: () async {
                            if (await _confirmDelete(s.name)) {
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
              loading: () => Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: MyntLoader.branded()),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title on the left; Expanded pushes the actions to the far right.
        Expanded(
          child: Text('Fundamental Screener',
              style:
                  MyntWebTextStyles.head(context, fontWeight: MyntFonts.bold)),
        ),
        const SizedBox(width: 16),
        // Action buttons — right-aligned.
        Row(mainAxisSize: MainAxisSize.min, children: [
          // Save as… — outlined blue (the MF "Backtest" button style).
          MyntButton(
            type: MyntButtonType.outlined,
            label: 'Save as…',
            icon: shadcn.LucideIcons.save,
            onPressed: _save,
          ),
          const SizedBox(width: 8),
          // Download — icon-only hover button (the scanner-detail download style).
          _HoverIconButton(
            icon: Icons.download,
            tooltip: 'Download',
            onTap: _export,
          ),
          const SizedBox(width: 8),
          // Run scan — filled blue primary (the MF "Place Order" button style).
          MyntButton(
            type: MyntButtonType.primary,
            label: 'Run scan',
            icon: shadcn.LucideIcons.play,
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
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final border = shadcn.Theme.of(context).colorScheme.border;
    // Same shell + name field as the MF "Create Strategy" dialog: shadcn.Card →
    // bordered header (title + close) → MyntFormTextField (40px) with inline
    // validation → full-width primary Save (the button always fires).
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
                    // Header — title + close, bottom border.
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
                    // Content — name field with inline validation.
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
    }
  }

  /// Watchlist-style delete confirmation: shadcn.Card → header (title + close)
  /// → centered confirm text → full-width red Delete. Returns true if confirmed.
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
                      Text('Delete saved screen',
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
      loading: () => Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: MyntLoader.simple())),
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

/// Saved-screen chip — the boxed scalper-style chip used by the scanner index
/// filter (light fill, primary border, radius 6): tap the body to apply the
/// screen, the × to delete it.
class _SavedScreenChip extends StatelessWidget {
  final String name;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  const _SavedScreenChip({
    required this.name,
    required this.onApply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: Colors.transparent, light: const Color(0xFFF1F3F8)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark, light: MyntColors.primary),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tap the body to apply the saved screen.
          InkWell(
            onTap: onApply,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [                  
                  Text(name,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium, color: textColor)),
                ],
              ),
            ),
          ),
          // × to delete.
          InkWell(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 7, 8, 7),
              child: Icon(shadcn.LucideIcons.x, size: 14, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact icon button with a grey hover circle — the same download/export
/// button style used in the scanner-detail header.
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
            width: 40,
            height: 40,
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

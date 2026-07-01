import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/models/scanner_model/custom_scan.dart';
import 'package:mynt_plus/provider/scanner/custom_scans_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/predicate_builder.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

/// Builder + inline-runner for a custom scan. All user-visible state
/// (name, predicate, result, JSON-preview flag, edited scan) lives in
/// [customScansSessionProvider] so that navigating away (e.g. clicking a
/// result row to view the symbol detail) and coming back restores exactly
/// what was on screen, including the result list.
class CustomScanBuilderPane extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const CustomScanBuilderPane({super.key, required this.onClose});

  @override
  ConsumerState<CustomScanBuilderPane> createState() =>
      _CustomScanBuilderPaneState();
}

class _CustomScanBuilderPaneState extends ConsumerState<CustomScanBuilderPane> {
  late final TextEditingController _nameCtl;

  @override
  void initState() {
    super.initState();
    // Seed the controller from the persisted session.
    final initialName =
        ref.read(customScansSessionProvider).builder?.name ?? '';
    _nameCtl = TextEditingController(text: initialName);
    _nameCtl.addListener(_pushName);
  }

  @override
  void dispose() {
    _nameCtl.removeListener(_pushName);
    _nameCtl.dispose();
    super.dispose();
  }

  void _pushName() {
    final notifier = ref.read(customScansSessionProvider.notifier);
    notifier.updateBuilder((b) => b.copyWith(name: _nameCtl.text));
  }

  void _setPredicate(Map<String, dynamic> p) {
    ref
        .read(customScansSessionProvider.notifier)
        .updateBuilder((b) => b.copyWith(predicate: p));
  }

  /// Show the current predicate as formatted JSON in a dialog (app-style
  /// shell: header + close, scrollable monospace body).
  void _showJsonDialog(Map<String, dynamic> predicate) {
    final json = const JsonEncoder.withIndent('  ').convert(predicate);
    final border = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    showDialog<void>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: resolveThemeColor(dCtx,
                dark: MyntColors.dialogDark, light: MyntColors.dialog),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
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
                          onPressed: () => Navigator.of(dCtx).pop()),
                    ]),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    json,
                    style: MyntWebTextStyles.para(dCtx)
                        ,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // Keep the text controller in sync with provider state when something
    // outside this widget changes the draft (e.g. user clicks "Edit" on a
    // different scan card without unmounting).
    if (_nameCtl.text != builder.name) {
      _nameCtl.removeListener(_pushName);
      _nameCtl.text = builder.name;
      _nameCtl.selection =
          TextSelection.collapsed(offset: _nameCtl.text.length);
      _nameCtl.addListener(_pushName);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed header — back + live title + name field + the Run / Save /
        // Preview JSON actions. Stays put while the builder body scrolls.
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: widget.onClose,
            tooltip: 'Back to list',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              builder.name.trim().isEmpty ? 'New scan' : builder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.head(context,
                  fontWeight: MyntFonts.bold,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary)),
            ),
          ),
          // Name field only while the scan is new (unsaved). Once saved, the
          // name shows as the title above, so the field would just repeat it.
          if (builder.editing == null) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: 260,
              child: MyntFormTextField(
                controller: _nameCtl,
                placeholder: 'Scan name',
                height: 40,
              ),
            ),
          ],
          const SizedBox(width: 16),
          MyntButton(
            type: MyntButtonType.primary,
            label: 'Run inline',
            icon: Icons.play_arrow,
            onPressed: _runInline,
          ),
          const SizedBox(width: 8),
          MyntButton(
            type: MyntButtonType.outlined,
            label: builder.editing == null ? 'Save' : 'Save changes',
            icon: Icons.save,
            onPressed: _save,
          ),
          const SizedBox(width: 8),
          MyntButton(
            type: MyntButtonType.outlined,
            label: 'Preview JSON',
            icon: Icons.code,
            onPressed: () => _showJsonDialog(builder.predicate),
          ),
        ]),
        const SizedBox(height: 16),
        // Scrolling body — the predicate builder, optional JSON preview and
        // the inline results.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PredicateBuilder(
                  initial: builder.predicate,
                  onChange: _setPredicate,
                ),
                const SizedBox(height: 24),
                if (builder.result != null) _resultArea(builder.result!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runInline() async {
    final predicate =
        ref.read(customScansSessionProvider).builder?.predicate ?? const {};
    _setResult(const AsyncLoading());
    try {
      final r = await locator<ApiExporter>()
          .runCustomScan(predicate: Map<String, dynamic>.from(predicate));
      _setResult(AsyncData(r));
    } catch (e, st) {
      _setResult(AsyncError(e, st));
    }
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ResponsiveSnackBar.showWarning(context, 'Give the scan a name first.');
      return;
    }
    final predicate =
        ref.read(customScansSessionProvider).builder?.predicate ?? const {};
    try {
      await locator<ApiExporter>().saveCustomScan(
          name: name, predicate: Map<String, dynamic>.from(predicate));
      ref.invalidate(savedCustomScansProvider);
      if (!mounted) return;
      ResponsiveSnackBar.showSuccess(context, 'Saved "$name"');
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ResponsiveSnackBar.showError(context, 'Save failed: $e');
    }
  }

  Widget _resultArea(AsyncValue<CustomScanRunResult> result) {
    return result.when(
      loading: () => Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: MyntLoader.simple()),
      ),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Run failed',
        message: e.toString(),
      ),
      data: (r) {
        if (r.matches.isEmpty) {
          return const EmptyState(
              kind: EmptyStateKind.empty, title: 'No matches');
        }
        final cols = [
          for (final c in r.columns)
            ScanColumn(
              key: c.key,
              label: c.label,
              fmt: 'raw',
              description: c.key,
            ),
        ];
        final rows = [
          for (final m in r.matches)
            ScanRow(
              ticker: m.ticker,
              name: m.name,
              values: Map<String, dynamic>.from(m.values),
            ),
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Results — ${r.matches.length} matches  ·  as of ${r.asOf}',
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.bold,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary))),
              const SizedBox(height: 12),
              SizedBox(
                height: 520,
                child: ScannerResultsTable(
                  columns: cols,
                  rows: rows,
                  footer: '${r.matches.length} matches  ·  as of ${r.asOf}',
                  customCellFormatter: (ctx, col, raw) =>
                      formatCustomScanCell(ctx, col.key, raw),
                  onTickerTap: (t) =>
                      openScannerScripFromContext(context, ref, ticker: t),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

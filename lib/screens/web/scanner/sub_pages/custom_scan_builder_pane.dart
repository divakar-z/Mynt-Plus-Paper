import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
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

    final headerBorder = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed header — back + live title + name field + the Run / Save /
        // Preview JSON actions. Stays put while the builder body scrolls.
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: headerBorder.withValues(alpha: 0.6)),
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: widget.onClose,
              tooltip: 'Back to list',
            ),
            const SizedBox(width: 4),
            // Static page title — mirrors "Fundamental Screener" on the sibling
            // tab so the two pages read as siblings.
            Text('Custom Scan',
                style: MyntWebTextStyles.head(context,
                    fontWeight: MyntFonts.bold)),
            const Spacer(),
            // Name pill on the right — editable for a new scan, read-only pill
            // for an existing saved scan (rename happens from the list, not
            // from within the builder). Placed just left of the action cluster,
            // matching the Fundamentals header's screen-name pill placement.
            if (builder.editing == null)
              _NamePill(controller: _nameCtl)
            else
              _ReadOnlyNamePill(name: builder.name),
            const SizedBox(width: 8),
            // Save + Preview JSON — chip-buttons matching the Fundamentals
            // header (34px tall so they sit as siblings of the name pill).
            // Save is icon+label, Preview JSON is icon-only.
            _chipButton(
              icon: shadcn.LucideIcons.save,
              label: builder.editing == null ? 'Save' : 'Save changes',
              tooltip: 'Save this scan',
              height: 34,
              onTap: _save,
            ),
            const SizedBox(width: 8),
            _chipButton(
              icon: shadcn.LucideIcons.code,
              tooltip: 'Preview JSON',
              height: 34,
              onTap: () => _showJsonDialog(builder.predicate),
            ),
            const SizedBox(width: 8),
            // Run inline — primary MyntButton kept as the header's CTA (mirrors
            // Fundamentals' "Run scan" pattern).
            MyntButton(
              type: MyntButtonType.primary,
              label: 'Run inline',
              icon: Icons.play_arrow,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              onPressed: _runInline,
            ),
          ]),
        ),
        const SizedBox(height: 12),
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
              const SizedBox(height: 4),
              Text('Results : ${r.matches.length} matches  ·  as of ${r.asOf}',
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.medium,
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

  /// Bordered action button that mirrors the Fundamentals header's chip
  /// button — icon+label variant for Save, icon-only variant for Preview
  /// JSON. Sized by [height] (34px) so it sits as a sibling of the name pill.
  Widget _chipButton({
    String? label,
    IconData? icon,
    String? tooltip,
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
    final disabled = onTap == null;
    final labelColor =
        disabled ? secondary.withValues(alpha: 0.4) : textPrimary;
    final iconColor =
        disabled ? secondary.withValues(alpha: 0.4) : secondary;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverBg,
        child: Container(
          height: height,
          alignment: height != null ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 10 : 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 18, color: iconColor),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Text(
                  label,
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium, color: labelColor),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// Read-only sibling of [_NamePill] — same pill chrome, plain Text inside.
/// Used when editing an existing saved scan so the name occupies the same
/// slot on the right as the editable pill does for a new scan.
class _ReadOnlyNamePill extends StatelessWidget {
  final String name;
  const _ReadOnlyNamePill({required this.name});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Container(
      width: 280,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MyntWebTextStyles.body(context,
            fontWeight: MyntFonts.medium, color: textPrimary),
      ),
    );
  }
}

/// Outlined pill for the scan name — mirrors the "Screen name" field in the
/// Fundamentals header. A bare TextField sits inside a bordered container so
/// the name reads as one control alongside the header's Run / Save buttons.
class _NamePill extends StatelessWidget {
  final TextEditingController controller;
  const _NamePill({required this.controller});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return Container(
      width: 280,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        style: MyntWebTextStyles.body(context,
            fontWeight: MyntFonts.medium, color: textPrimary),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: 'Untitled scan',
          hintStyle: MyntWebTextStyles.body(context,
              color: secondary.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

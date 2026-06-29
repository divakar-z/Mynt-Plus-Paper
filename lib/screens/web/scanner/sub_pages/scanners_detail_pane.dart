import 'package:flutter/material.dart';
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
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/scanner/utils/open_scanner_scrip.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/export_modal.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/scanner_results_table.dart';

class ScannersDetailPane extends ConsumerStatefulWidget {
  final String code;
  final VoidCallback onBack;
  const ScannersDetailPane({super.key, required this.code, required this.onBack});

  @override
  ConsumerState<ScannersDetailPane> createState() => _ScannersDetailPaneState();
}

class _ScannersDetailPaneState extends ConsumerState<ScannersDetailPane> {
  /// Per-scanner index filter. Each scanner detail has its own filter
  /// state so switching scanners always starts fresh — sharing one filter
  /// across scanners caused stale chips to bleed into unrelated scanners.
  List<String> _selectedIndices = const [];

  @override
  void didUpdateWidget(covariant ScannersDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Different scanner = fresh filter. Without this the new scanner
    // would inherit the previous one's chips, hiding the fact that the
    // filter is still narrowing the universe.
    if (oldWidget.code != widget.code && _selectedIndices.isNotEmpty) {
      setState(() => _selectedIndices = const []);
    }
  }

  void _setIndices(List<String> next) {
    setState(() => _selectedIndices = List.unmodifiable(next));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with a bottom divider line (matches the MF detail header).
        Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: resolveThemeColor(context,
                    dark: MyntColors.dividerDark, light: MyntColors.divider),
                width: 1,
              ),
            ),
          ),
          child: Row(children: [
            CustomBackBtn(onBack: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: meta.when(
              loading: () =>
                  Text('Loading…', style: MyntWebTextStyles.title(context)),
              error: (_, __) => Text(code,
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.semiBold)),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.displayName,
                      style: MyntWebTextStyles.title(context,
                          fontWeight: MyntFonts.semiBold)),
                  Text(
                    '${s.groupName}${s.subGroup == null ? "" : " · ${s.subGroup}"}',
                    style: MyntWebTextStyles.caption(context),
                  ),
                ],
              ),
            ),
          ),
          IndexFilterDropdown(
            selected: selectedIndices,
            onChanged: _setIndices,
            // Use whatever counts the API just returned. Empty map = old
            // backend without the feature → dropdown falls back to
            // universe size. When backend ships, the counts arrive and
            // the dropdown auto-updates per scanner with no UI change.
            matchCounts: results.maybeWhen(
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
          ]),
        ),
        // const SizedBox(height: 12),
        meta.maybeWhen(
          data: (s) {
            // Prefer the backend's layman-language long description when
            // present; fall back to the brief tagline otherwise. Either
            // way the technical predicate JSON is no longer shown — end
            // users don't read it and it added intimidating clutter.
            final text =
                (s.descriptionLong?.isNotEmpty ?? false)
                    ? s.descriptionLong!
                    : s.description;
            if (text.isEmpty) return const SizedBox.shrink();
            return _InfoCard(text: text);
          },
          orElse: () => const SizedBox.shrink(),
        ),
        if (selectedIndices.isNotEmpty) ...[
          const SizedBox(height: 12),
          ActiveIndexFilterChips(
            selected: selectedIndices,
            onChanged: _setIndices,
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: results.when(
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
              final cols = [
                for (final c in r.columns)
                  ScanColumn(
                    key: c.key,
                    label: c.label,
                    fmt: c.fmt,
                    description: c.description,
                  ),
              ];
              final rows = [
                for (final m in r.matches)
                  ScanRow(ticker: m.ticker, name: m.name, values: m.values),
              ];
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

  Future<void> _export(BuildContext context) async {
    final res = await showExportModal(context);
    if (res == null) return;
    final api = locator<ApiExporter>();
    try {
      final blob = await api.downloadScannerExportXlsx(
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
  }
}

/// Subtle violet/blue tinted info card that wraps the scanner description.
class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final tint = MyntColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      // decoration: BoxDecoration(
      //   color: tint.withValues(alpha: 0.06),
      //   borderRadius: BorderRadius.circular(10),
      //   border: Border.all(color: tint.withValues(alpha: 0.15)),
      // ),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon(shadcn.LucideIcons.info, size: 14, color: tint),
          // const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: MyntWebTextStyles.body(context,
                    color: resolveThemeColor(context,
                    
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary))),
          ),
        ],
      ),
    );
  }
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


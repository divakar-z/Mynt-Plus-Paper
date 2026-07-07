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
        // Grey banner holding the header (back + title + subtitle + actions)
        // with the scanner description tucked inside it.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Flat light-blue to match the dashboard hero banner.
            color: resolveThemeColor(context,
                dark: MyntColors.sidebarBgDark, light: const Color(0xFFEAF1FE)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: resolveThemeColor(context,
                    dark: MyntColors.dividerDark, light: MyntColors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CustomBackBtn(onBack: onBack),
                const SizedBox(width: 8),
                Expanded(
                  child: meta.when(
                    loading: () => Text('Loading…',
                        style: MyntWebTextStyles.title(context)),
                    error: (_, __) => Text(code,
                        style: MyntWebTextStyles.title(context,
                            fontWeight: MyntFonts.semiBold)),
                    data: (s) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.displayName,
                            style: MyntWebTextStyles.title(context,
                                fontWeight: MyntFonts.semiBold)),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _groupColor(s.groupName)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
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
                                  style: MyntWebTextStyles.caption(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IndexFilterDropdown(
                  selected: selectedIndices,
                  onChanged: _setIndices,
                  // Empty map = old backend without match counts → dropdown
                  // falls back to universe size; auto-updates when it ships.
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
              // Description inside the same banner.
              meta.maybeWhen(
                data: (s) {
                  final text = (s.descriptionLong?.isNotEmpty ?? false)
                      ? s.descriptionLong!
                      : s.description;
                  if (text.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      text,
                      style: MyntWebTextStyles.body(context,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary)),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
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

  // Category accent — mirrors the dashboard section colors.
  Color _groupColor(String g) {
    switch (g.toLowerCase()) {
      case 'candlestick':
        return const Color(0xFFDB7C26);
      case 'price':
        return MyntColors.primary;
      case 'technical':
        return const Color(0xFF0F9D7A);
      case 'volume':
        return MyntColors.warning;
      default:
        return const Color(0xFF2F6FED);
    }
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


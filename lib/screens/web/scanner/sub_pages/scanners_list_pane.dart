import 'package:flutter/material.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/responsive_extensions.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

class ScannersListPane extends ConsumerStatefulWidget {
  final ValueChanged<String> onSelect;
  const ScannersListPane({super.key, required this.onSelect});

  @override
  ConsumerState<ScannersListPane> createState() => _ScannersListPaneState();
}

class _ScannersListPaneState extends ConsumerState<ScannersListPane> {
  String? _activeGroup; // null = All
  /// Sentiment pill filter. null = all sentiments. Driven entirely by
  /// the backend's `sentiment` field — scanners with no sentiment yet
  /// (older payloads) show only when "All" is active so we never
  /// invent a classification client-side.
  ScannerSentiment? _activeSentiment;
  final TextEditingController _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild (and thus re-filter the list) on any change to the search
    // field — covers both typing and the smart-clear (×) button, which
    // clears the controller without firing onChanged.
    _q.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scannerListProvider);
    return async.when(
      loading: () => Center(child: MyntLoader.branded()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanners',
        message: e.toString(),
        onRetry: () => ref.invalidate(scannerListProvider),
      ),
      data: (resp) {
        final groups = <String, int>{};
        final sentimentCounts = <ScannerSentiment, int>{
          ScannerSentiment.bullish: 0,
          ScannerSentiment.bearish: 0,
          ScannerSentiment.neutral: 0,
        };
        for (final s in resp.items) {
          groups.update(s.groupName, (n) => n + 1, ifAbsent: () => 1);
          // Only count scanners whose backend `sentiment` field is set.
          // Unclassified scanners show under "All" but contribute 0 to
          // any specific pill — no client-side guessing.
          final sent = s.sentiment;
          if (sent != null) {
            sentimentCounts.update(sent, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        final filtered = resp.items.where((s) {
          if (_activeGroup != null && s.groupName != _activeGroup) return false;
          if (_activeSentiment != null && s.sentiment != _activeSentiment) {
            return false;
          }
          if (_q.text.isEmpty) return true;
          final q = _q.text.toLowerCase();
          // Search still matches against `code` even though the column
          // is no longer rendered — users typing "RSI14" expect a hit.
          return s.displayName.toLowerCase().contains(q) ||
              s.code.toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(context),
            const SizedBox(height: 16),
            _filterTabsRow(
                context, sentimentCounts, groups, resp.items.length),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      kind: EmptyStateKind.search,
                      title: 'No scanners match this filter',
                    )
                  : _ScannerTable(
                      items: filtered,
                      onTap: widget.onSelect,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _sentimentPills(
    BuildContext ctx,
    Map<ScannerSentiment, int> counts,
    int total,
  ) {
    final entries = <(String, ScannerSentiment?, int)>[
      ('All', null, total),
      ('Bullish', ScannerSentiment.bullish,
          counts[ScannerSentiment.bullish] ?? 0),
      ('Bearish', ScannerSentiment.bearish,
          counts[ScannerSentiment.bearish] ?? 0),
      ('Neutral', ScannerSentiment.neutral,
          counts[ScannerSentiment.neutral] ?? 0),
    ];
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 8));
      final (label, value, count) = entries[i];
      children.add(_SentimentPill(
        label: label,
        count: count,
        active: _activeSentiment == value,
        onTap: () => setState(() => _activeSentiment = value),
      ));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  // Title only — the Scanners heading stays untouched on its own line.
  Widget _topBar(BuildContext context) {
    return Text(
      'Scanners',
      style: MyntWebTextStyles.hero(context, fontWeight: MyntFonts.bold),
    );
  }

  // Positions-style controls row: sentiment tabs on the left, filter + search
  // on the right (filter to the left of search), at opposite ends.
  Widget _filterTabsRow(
    BuildContext context,
    Map<ScannerSentiment, int> sentimentCounts,
    Map<String, int> groups,
    int total,
  ) {
    return Row(
      children: [
        Expanded(child: _sentimentPills(context, sentimentCounts, total)),
        const SizedBox(width: 16),
        _groupFilterButton(context, groups, total),
        const SizedBox(width: 8),
        SizedBox(
          width: context.responsiveValue<double>(
            mobile: 140,
            smallTablet: 180,
            tablet: 220,
            desktop: 300,
            largeDesktop: 350,
            widescreen: 400,
          ),
          child: MyntSearchTextField.withSmartClear(
            controller: _q,
            placeholder: 'Search scanners…',
            leadingIcon: assets.searchIcon,
            textCapitalization: TextCapitalization.none,
          ),
        ),
      ],
    );
  }

  // Filter icon button (Positions pattern) — opens the Group popover. The
  // icon tints primary while a non-"All" group filter is active.
  Widget _groupFilterButton(
      BuildContext context, Map<String, int> groups, int total) {
    final iconColor = _activeGroup != null
        ? resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary)
        : resolveThemeColor(context,
            dark: MyntColors.iconDark, light: MyntColors.icon);
    return Builder(
      builder: (buttonContext) {
        return Tooltip(
          message: 'Filter',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showGroupFilterPopup(buttonContext, groups, total),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    assets.searchFilter,
                    width: 20,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGroupFilterPopup(
      BuildContext context, Map<String, int> groups, int total) {
    final entries = <(String, String?, int)>[
      ('All', null, total),
      for (final e in groups.entries) (e.key, e.key, e.value),
    ];
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in entries)
                    _groupFilterMenuItem(popoverContext, e.$1, e.$2, e.$3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Single popover row (Positions pattern): selected = light-blue fill +
  // primary semibold text; trailing muted count.
  Widget _groupFilterMenuItem(
      BuildContext overlayContext, String label, String? value, int count) {
    final isSelected = _activeGroup == value;
    final primary = resolveThemeColor(overlayContext,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _activeGroup = value);
          shadcn.closeOverlay(overlayContext);
        },
        splashColor: resolveThemeColor(overlayContext,
            dark: MyntColors.rippleDark, light: MyntColors.rippleLight),
        highlightColor: resolveThemeColor(overlayContext,
            dark: MyntColors.highlightDark, light: MyntColors.highlightLight),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isSelected
                ? resolveThemeColor(overlayContext,
                    dark: MyntColors.primaryDark.withValues(alpha: 0.12),
                    light: const Color(0xFFE8F0FE))
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: MyntWebTextStyles.body(overlayContext,
                        fontWeight:
                            isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                        color: isSelected
                            ? primary
                            : resolveThemeColor(overlayContext,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary))),
              ),
              const SizedBox(width: 12),
              Text('$count',
                  style: MyntWebTextStyles.caption(overlayContext,
                      color: isSelected
                          ? primary
                          : resolveThemeColor(overlayContext,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentimentPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _SentimentPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = shadcn.Theme.of(context).colorScheme;
    final textColor = active ? scheme.foreground : scheme.mutedForeground;
    final weight = active ? MyntFonts.semiBold : MyntFonts.medium;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? resolveThemeColor(context,
                    dark: Colors.white.withValues(alpha: 0.1),
                    light: Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MyntWebTextStyles.body(context, fontWeight: weight)
                    .copyWith(color: textColor),
              ),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Text(
                  '$count',
                  style: MyntWebTextStyles.bodySmall(context, fontWeight: weight)
                      .copyWith(fontSize: 13, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact data-dense table — Group chip | Sub-group | Display name.
/// The CODE column was removed because end users don't read the codes
/// (RSI14_OVERSOLD, MACD_BULL_CROSS, …); the search box still matches
/// against code under the hood so typing "RSI" still works.
class _ScannerTable extends StatelessWidget {
  final List items;
  final ValueChanged<String> onTap;
  const _ScannerTable({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    return shadcn.OutlinedContainer(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          // Fixed column widths shared by the header table and every row
          // table so independent shadcn.Tables stay column-aligned. NAME
          // absorbs the leftover width (same approach as the Holdings table).
          // Column order: NAME, GROUP, SUB-GROUP, chevron. The three text
          // columns split the available width proportionally so the table
          // fills edge-to-edge; the chevron stays a fixed trailing cell.
          const chevW = 44.0;
          final dataW = (c.maxWidth - chevW).clamp(0.0, double.infinity);
          final nameW = dataW * 0.55;
          final groupW = dataW * 0.15;
          final subW = dataW * 0.30;
          final widths = <int, double>{0: nameW, 1: groupW, 2: subW, 3: chevW};
          return Column(
            children: [
              // Header — a single shadcn.Table row on a muted band.
              Container(
                color: headerBg,
                child: shadcn.Table(
                  columnWidths: {
                    0: shadcn.FixedTableSize(widths[0]!),
                    1: shadcn.FixedTableSize(widths[1]!),
                    2: shadcn.FixedTableSize(widths[2]!),
                    3: shadcn.FixedTableSize(widths[3]!),
                  },
                  defaultRowHeight: const shadcn.FixedTableSize(40),
                  rows: [
                    shadcn.TableHeader(cells: [
                      _headerCell(context, 'Name',
                          const EdgeInsets.only(left: 16, right: 8)),
                      _headerCell(context, 'Group',
                          const EdgeInsets.symmetric(horizontal: 8)),
                      _headerCell(context, 'Sub-group',
                          const EdgeInsets.symmetric(horizontal: 8)),
                      _headerCell(context, '', const EdgeInsets.only(right: 16)),
                    ]),
                  ],
                ),
              ),
              Divider(height: 1, color: border),
              // Body — lazy ListView so only the visible rows build; each row
              // is its own 1-row shadcn.Table (keeps virtualization).
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: border.withValues(alpha: 0.4)),
                  itemBuilder: (_, i) {
                    final s = items[i];
                    return _ScannerRow(
                      group: s.groupName as String,
                      subGroup: (s.subGroup as String?) ?? '—',
                      name: s.displayName as String,
                      tertiary: tertiary,
                      widths: widths,
                      onTap: () => onTap(s.code as String),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  shadcn.TableCell _headerCell(BuildContext ctx, String t, EdgeInsets padding) =>
      shadcn.TableCell(
        theme: const shadcn.TableCellTheme(
          border: shadcn.WidgetStatePropertyAll(
            shadcn.Border(
              top: shadcn.BorderSide.none,
              bottom: shadcn.BorderSide.none,
              left: shadcn.BorderSide.none,
              right: shadcn.BorderSide.none,
            ),
          ),
        ),
        child: Container(
          padding: padding,
          alignment: Alignment.centerLeft,
          child: Text(t,
              style: MyntWebTextStyles.tableHeader(ctx,
                  fontWeight: MyntFonts.semiBold,
                  color: resolveThemeColor(ctx,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary))),
        ),
      );
}

class _ScannerRow extends StatefulWidget {
  final String group;
  final String subGroup;
  final String name;
  final Color tertiary;
  final Map<int, double> widths;
  final VoidCallback onTap;
  const _ScannerRow({
    required this.group,
    required this.subGroup,
    required this.name,
    required this.tertiary,
    required this.widths,
    required this.onTap,
  });

  @override
  State<_ScannerRow> createState() => _ScannerRowState();
}

class _ScannerRowState extends State<_ScannerRow> {
  bool _hover = false;

  Color _groupColor(String g) {
    switch (g.toLowerCase()) {
      case 'candlestick': return const Color(0xFFA855F7); // violet
      case 'price': return MyntColors.primary;
      case 'technical': return const Color(0xFF10B981); // emerald
      case 'volume': return MyntColors.warning;
      default: return MyntColors.primary;
    }
  }

  // Borderless shadcn cell — row separation comes from the ListView divider.
  shadcn.TableCell _cell(Widget child) => shadcn.TableCell(
        theme: const shadcn.TableCellTheme(
          border: shadcn.WidgetStatePropertyAll(
            shadcn.Border(
              top: shadcn.BorderSide.none,
              bottom: shadcn.BorderSide.none,
              left: shadcn.BorderSide.none,
              right: shadcn.BorderSide.none,
            ),
          ),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final gc = _groupColor(widget.group);
    final w = widget.widths;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _hover ? hoverBg : Colors.transparent,
          child: shadcn.Table(
            columnWidths: {
              0: shadcn.FixedTableSize(w[0]!),
              1: shadcn.FixedTableSize(w[1]!),
              2: shadcn.FixedTableSize(w[2]!),
              3: shadcn.FixedTableSize(w[3]!),
            },
            defaultRowHeight: const shadcn.FixedTableSize(40),
            rows: [
              shadcn.TableRow(cells: [
                // NAME — truncates to "…" when narrow; full text on hover.
                _cell(Container(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: widget.name,
                    child: Text(widget.name,
                        style: MyntWebTextStyles.tableCell(context,
                            fontWeight: MyntFonts.medium),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis),
                  ),
                )),
                // GROUP chip
                _cell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(widget.group,
                        style: MyntWebTextStyles.caption(context,
                            fontWeight: MyntFonts.semiBold, color: gc)),
                  ),
                )),
                // SUB-GROUP — same truncate + tooltip flow.
                _cell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: widget.subGroup,
                    child: Text(widget.subGroup,
                        style: MyntWebTextStyles.tableCell(context),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis),
                  ),
                )),
                // Chevron
                _cell(Container(
                  padding: const EdgeInsets.only(right: 16),
                  alignment: Alignment.centerRight,
                  child: Icon(shadcn.LucideIcons.chevronRight,
                      size: 14, color: widget.tertiary),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

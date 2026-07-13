import 'package:flutter/material.dart';
import 'package:flutter_expanded_tile/flutter_expanded_tile.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/scan_details.dart';
import 'package:mynt_plus/models/scanner_model/scan_result.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/symbols_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/screens/web/scanner/utils/formatters.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';

/// Scans this symbol currently matches.
///
/// Backed by `GET /symbols/{ticker}/scan-details` (via [scanDetailsProvider]),
/// which returns each matched scanner self-contained: readable name, sentiment,
/// its own result `columns` and this symbol's computed `values`. A soft-fill
/// pill selector groups the scans by sentiment (Bullish / Bearish / Neutral /
/// Other, with counts); the chosen group's scans render as collapsible rows
/// using the same accordion the Positions group screen uses
/// (`flutter_expanded_tile` — soft-fill header when expanded, chevron, single-
/// open, thin divider). Expanding a row shows the explanation (with an inline
/// "Why it matched" drill) and the column/value table.
class ScansTab extends ConsumerStatefulWidget {
  final String ticker;
  const ScansTab({super.key, required this.ticker});

  @override
  ConsumerState<ScansTab> createState() => _ScansTabState();
}

class _ScansTabState extends ConsumerState<ScansTab> {
  /// Index into the visible (non-empty) sentiment groups.
  int _group = 0;

  /// Own scroll controller so we can attach an always-visible scrollbar.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = widget.ticker;
    final async = ref.watch(scanDetailsProvider(ticker));
    return async.when(
      loading: () => Center(child: MyntLoader.simple()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanner matches',
        message: e.toString(),
        onRetry: () => ref.invalidate(scanDetailsProvider(ticker)),
      ),
      data: (resp) {
        if (resp.scans.isEmpty) {
          return const EmptyState(
            kind: EmptyStateKind.empty,
            title: 'No active scanner matches today',
          );
        }

        // Bucket by sentiment, alphabetical within each bucket.
        final bySentiment = <ScannerSentiment?, List<ScanDetail>>{};
        for (final s in resp.scans) {
          bySentiment.putIfAbsent(s.sentiment, () => []).add(s);
        }
        for (final list in bySentiment.values) {
          list.sort((a, b) => a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase()));
        }

        // Visible groups in fixed order; "Other" (null) last, empties dropped.
        const order = <ScannerSentiment?>[
          ScannerSentiment.bullish,
          ScannerSentiment.bearish,
          ScannerSentiment.neutral,
          null,
        ];
        final groups = <_Group>[
          for (final sent in order)
            if ((bySentiment[sent] ?? const []).isNotEmpty)
              _Group(sentiment: sent, scans: bySentiment[sent]!),
        ];

        final selected = _group.clamp(0, groups.length - 1);
        final scans = groups[selected].scans;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sentiment group selector — soft-fill pills (the top tabs' old style).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _sentimentTab(context, i, selected, groups[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              // Always-visible scrollbar in its own gutter (matches the market
              // depth section): the list keeps a right inset so the bar never
              // overlaps the row chevrons.
              child: ScrollConfiguration(
                behavior:
                    const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(8),
                  thumbColor: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)
                      .withValues(alpha: 0.5),
                  child: ExpandedTileList.separated(
                    key:
                        ValueKey('scans_${ticker}_${selected}_${scans.length}'),
                    scrollController: _scrollController,
                    shrinkWrap: false,
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                    itemCount: scans.length,
                    // Single-open accordion: opening a row auto-closes the other.
                    maxOpened: 1,
                    itemBuilder: (context, index, controller) =>
                        _tile(context, controller, scans[index]),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One collapsible scan row, styled exactly like a Positions group tile
  /// (soft-fill header when expanded, no arrow, no internal borders).
  ExpandedTile _tile(
      BuildContext context, ExpandedTileController controller, ScanDetail scan) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final headerFill = resolveThemeColor(context,
        dark: const Color(0xffB5C0CF).withValues(alpha: 0.15),
        light: const Color(0xffF1F3F8));
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return ExpandedTile(
      contentseparator: 0.0,
      controller: controller,
      onTap: () => setState(() {}),
      // Chevron indicates open/closed; we swap the icon ourselves, so disable
      // the package's auto-rotation (which would skew the swapped icon).
      trailingRotation: 0,
      trailing: Icon(
        controller.isExpanded
            ? Icons.keyboard_arrow_up
            : Icons.keyboard_arrow_down,
        size: 20,
        color: secondary,
      ),
      theme: ExpandedTileThemeData(
        headerColor: controller.isExpanded ? headerFill : Colors.transparent,
        headerPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        contentBackgroundColor: Colors.transparent,
        contentSeparatorColor: Colors.transparent,
        headerBorder: const OutlineInputBorder(borderSide: BorderSide.none),
        contentBorder: const OutlineInputBorder(borderSide: BorderSide.none),
        footerBorder:
            const OutlineInputBorder(borderSide: BorderSide.none),
        fullExpandedBorder:
            const OutlineInputBorder(borderSide: BorderSide.none),
        contentPadding: EdgeInsets.zero,
        trailingPadding: const EdgeInsets.only(left: 8),
      ),
      title: Text(scan.displayName,
          style: MyntWebTextStyles.body(context,
              fontWeight: MyntFonts.medium, color: primary)),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _explanation(context, scan),
            if (_hasExplanation(scan)) const SizedBox(height: 12),
            if (scan.columns.isNotEmpty)
              _ScanValuesTable(columns: scan.columns, values: scan.values),
          ],
        ),
      ),
    );
  }

  bool _hasExplanation(ScanDetail scan) =>
      (scan.description != null && scan.description!.trim().isNotEmpty) ||
      scan.explainAvailable;

  /// The description sentence with the "Why it matched" drill inline at its end
  /// (or the link on its own when there's no description).
  Widget _explanation(BuildContext context, ScanDetail scan) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hasDesc =
        scan.description != null && scan.description!.trim().isNotEmpty;

    if (!hasDesc) {
      return scan.explainAvailable
          ? _whyLink(context, scan)
          : const SizedBox.shrink();
    }

    return Text.rich(
      TextSpan(
        style: MyntWebTextStyles.body(context, color: primary),
        children: [
          TextSpan(text: scan.description),
          if (scan.explainAvailable) ...[
            const TextSpan(text: '   '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _whyLink(context, scan),
            ),
          ],
        ],
      ),
    );
  }

  Widget _whyLink(BuildContext context, ScanDetail scan) {
    final accent = resolveThemeColor(context,
        dark: MyntColors.secondaryDark, light: MyntColors.primary);
    return InkWell(
      onTap: () => ref
          .read(scannerShellProvider.notifier)
          .navigateToScannerDetail(scan.code),
      borderRadius: BorderRadius.circular(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Why it matched',
            style: MyntWebTextStyles.para(context,
                fontWeight: MyntFonts.semiBold, color: accent)),
        const SizedBox(width: 4),
        Icon(shadcn.LucideIcons.arrowUpRight, size: 13, color: accent),
      ]),
    );
  }

  /// Sentiment group pill — the soft-fill style the top tabs used to have:
  /// selected = soft grey fill + primary semibold text, inactive = muted.
  Widget _sentimentTab(
      BuildContext context, int index, int selectedIndex, _Group group) {
    final selected = index == selectedIndex;
    final scheme = shadcn.Theme.of(context).colorScheme;
    final textColor = selected ? scheme.foreground : scheme.mutedForeground;
    final weight = selected ? MyntFonts.semiBold : MyntFonts.medium;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _group = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? resolveThemeColor(context,
                    dark: Colors.white.withValues(alpha: 0.1),
                    light: Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          // Count as a small superscript after the label — same as the
          // Scanners list sentiment pills (_SentimentPill).
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _groupLabel(group.sentiment),
                style: MyntWebTextStyles.body(context, fontWeight: weight)
                    .copyWith(color: textColor),
              ),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Text(
                  '${group.scans.length}',
                  style:
                      MyntWebTextStyles.bodySmall(context, fontWeight: weight)
                          .copyWith(fontSize: 13, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _groupLabel(ScannerSentiment? s) {
    switch (s) {
      case ScannerSentiment.bullish:
        return 'Bullish';
      case ScannerSentiment.bearish:
        return 'Bearish';
      case ScannerSentiment.neutral:
        return 'Neutral';
      case null:
        return 'Other';
    }
  }
}

/// A visible sentiment group: its key (null = "Other") and its scans.
class _Group {
  final ScannerSentiment? sentiment;
  final List<ScanDetail> scans;
  const _Group({required this.sentiment, required this.scans});
}

/// The expanded scan's columns + this symbol's values as a `shadcn.Table` —
/// the same table component the app uses elsewhere (peers / results tables):
/// an [shadcn.OutlinedContainer] shell, a `cardHover` header band with the
/// server's column labels (verbatim, like the results table) in
/// [MyntWebTextStyles.tableHeader] + a header divider, and
/// [MyntWebTextStyles.tableCell] values formatted by each column's `fmt`.
///
/// Pinned to a single [_width] with equal columns so every scan's table lines
/// up down the list regardless of column count or value length.
class _ScanValuesTable extends StatelessWidget {
  final List<ScanResultColumn> columns;
  final Map<String, dynamic> values;
  const _ScanValuesTable({required this.columns, required this.values});

  static const double _width = 460;

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final headerBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: MyntColors.cardHover);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    final colW = _width / columns.length;

    return shadcn.OutlinedContainer(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _width,
        child: shadcn.Table(
          columnWidths: {
            for (int i = 0; i < columns.length; i++)
              i: shadcn.FixedTableSize(colW),
          },
          defaultRowHeight: const shadcn.FixedTableSize(44),
          rows: [
            shadcn.TableHeader(
              cells: [
                for (final col in columns)
                  _cell(
                    background: headerBg,
                    bottomBorder: border,
                    child: Text(col.label,
                        style: MyntWebTextStyles.tableHeader(context,
                            fontWeight: MyntFonts.semiBold, color: secondary)),
                  ),
              ],
            ),
            shadcn.TableRow(
              cells: [
                for (final col in columns)
                  _cell(
                    child: _valueText(context, col, values[col.key], primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A borderless [shadcn.TableCell] (the [shadcn.OutlinedContainer] supplies the
  /// outer frame). [background] paints the header band; [bottomBorder] draws the
  /// header divider.
  shadcn.TableCell _cell({
    required Widget child,
    Color? background,
    Color? bottomBorder,
  }) {
    return shadcn.TableCell(
      theme: shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: bottomBorder != null
                ? shadcn.BorderSide(color: bottomBorder)
                : shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: Container(
        color: background,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: child,
      ),
    );
  }

  Widget _valueText(
      BuildContext context, ScanResultColumn col, dynamic raw, Color primary) {
    final ({String text, Color? color}) v;
    if (raw == null) {
      v = (text: kEmDash, color: null);
    } else if (raw is num) {
      v = formatColumn(context, raw, col.fmt);
    } else {
      final n = num.tryParse(raw.toString());
      v = n != null
          ? formatColumn(context, n, col.fmt)
          : (text: raw.toString(), color: null);
    }
    return Text(v.text,
        style: MyntWebTextStyles.tableCell(context, color: v.color ?? primary));
  }
}

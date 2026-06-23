import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/scanner_model/market_index.dart';
import 'package:mynt_plus/provider/scanner/market_indices_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Multi-select dropdown that lets the user narrow scanner / custom-scan
/// results to one or more NSE indices.
///
/// Trigger: an OutlinedButton that shows either "Index filter" (empty) or
/// "Indices · N selected" (active). On tap it opens a follower panel
/// anchored below the button containing a search field, the index list
/// grouped by category (Broad market / Cap-size / Sectoral / Thematic /
/// Strategy / Corporate group / Other), and a Clear-all footer.
///
/// The picker emits a new list of names via [onChanged] on every checkbox
/// toggle — the parent decides how to persist (typically `scannerShell
/// Provider.notifier.setSelectedIndices`).
class IndexFilterDropdown extends ConsumerStatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  /// Optional per-index match counts for the current scanner/scan. When
  /// non-empty the dropdown shows these instead of universe size next to
  /// each option (e.g. "5 matches" instead of "98"). Falls back to universe
  /// size when the entry is absent — backwards-compatible while backend
  /// rolls out the `include_index_counts` feature.
  final Map<String, int> matchCounts;
  const IndexFilterDropdown({
    super.key,
    required this.selected,
    required this.onChanged,
    this.matchCounts = const {},
  });

  @override
  ConsumerState<IndexFilterDropdown> createState() =>
      _IndexFilterDropdownState();
}

class _IndexFilterDropdownState extends ConsumerState<IndexFilterDropdown> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  String _query = '';

  void _toggleIndex(String name) {
    final next = [...widget.selected];
    final i = next.indexOf(name);
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.add(name);
    }
    widget.onChanged(next);
  }

  void _clearAll() {
    if (widget.selected.isEmpty) return;
    widget.onChanged(const []);
  }

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final hasSelection = widget.selected.isNotEmpty;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: OutlinedButton.icon(
          icon: Icon(
            shadcn.LucideIcons.listFilter,
            size: 14,
            color: hasSelection ? MyntColors.primary : primary,
          ),
          label: Text(
            hasSelection
                ? 'Indices · ${widget.selected.length} selected'
                : 'Index filter',
            style: MyntWebTextStyles.caption(context,
                fontWeight: MyntFonts.semiBold,
                color: hasSelection ? MyntColors.primary : primary),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: hasSelection
                  ? MyntColors.primary.withValues(alpha: 0.5)
                  : border,
            ),
            backgroundColor: hasSelection
                ? MyntColors.primary.withValues(alpha: 0.06)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () {
            // Reset the search box every time we re-open — feels fresher
            // than carrying yesterday's query forward when the user
            // returns to the panel.
            if (!_portal.isShowing) setState(() => _query = '');
            _portal.toggle();
          },
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext ctx) {
    // Anchor the popup to the button's bottom-right corner — the filter
    // sits in the right half of every header row in this app, so growing
    // leftward from there keeps the panel on-screen. A nested
    // FractionalTranslation guard would be needed if the trigger ever
    // moves to the left edge, but that's not the layout today.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _portal.hide,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            child: _buildPanel(ctx),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext ctx) {
    final indicesAsync = ref.watch(marketIndicesProvider);
    final cardBg = resolveThemeColor(ctx,
        dark: MyntColors.cardDark,
        light: MyntColors.card);
    final border = shadcn.Theme.of(ctx).colorScheme.border;

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: indicesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not load indices — $e',
            style: MyntWebTextStyles.caption(ctx),
          ),
        ),
        data: (indices) => _buildLoaded(ctx, indices),
      ),
    );
  }

  Widget _buildLoaded(BuildContext ctx, List<MarketIndex> indices) {
    final border = shadcn.Theme.of(ctx).colorScheme.border;
    final secondary = resolveThemeColor(ctx,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    if (indices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No indices available',
                style: MyntWebTextStyles.body(ctx,
                    fontWeight: MyntFonts.semiBold)),
            const SizedBox(height: 6),
            Text(
              'The backend hasn\'t loaded the NSE index universe yet. '
              'Check back later — the daily refresh runs at 18:35 IST.',
              style: MyntWebTextStyles.caption(ctx, color: secondary),
            ),
          ],
        ),
      );
    }

    final groups = _groupIndices(indices);
    final selectedSet = widget.selected.toSet();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search box at the top — case-insensitive substring match.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search 86 indices…',
              hintStyle:
                  MyntWebTextStyles.caption(ctx, color: secondary),
              prefixIcon: Icon(shadcn.LucideIcons.search,
                  size: 14, color: secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: MyntWebTextStyles.body(ctx),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Divider(height: 1, color: border),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              for (final entry in groups.entries)
                ..._buildGroup(ctx, entry.key, entry.value, selectedSet),
            ],
          ),
        ),
        Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Text(
              widget.selected.isEmpty
                  ? 'No filter — full universe'
                  : '${widget.selected.length} selected',
              style: MyntWebTextStyles.caption(ctx, color: secondary),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.selected.isEmpty ? null : _clearAll,
              child: const Text('Clear all'),
            ),
          ]),
        ),
      ],
    );
  }

  List<Widget> _buildGroup(
    BuildContext ctx,
    String label,
    List<MarketIndex> entries,
    Set<String> selectedSet,
  ) {
    final visible = entries.where((idx) {
      if (_query.isEmpty) return true;
      return idx.name.toLowerCase().contains(_query);
    }).toList();
    if (visible.isEmpty) return const [];
    final secondary = resolveThemeColor(ctx,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          label.toUpperCase(),
          style: MyntWebTextStyles.caption(ctx,
                  fontWeight: MyntFonts.bold, color: secondary)
              .copyWith(letterSpacing: 0.6),
        ),
      ),
      for (final idx in visible)
        _IndexRow(
          index: idx,
          selected: selectedSet.contains(idx.name),
          matchCount: widget.matchCounts[idx.name],
          onTap: () => _toggleIndex(idx.name),
        ),
    ];
  }
}

class _IndexRow extends StatelessWidget {
  final MarketIndex index;
  final bool selected;
  /// Per-current-scanner match count when the backend has supplied one.
  /// Null = no count available → fall back to the catalog's member_count
  /// (universe size). Zero is shown as "0 matches" — distinguishes
  /// "explicitly empty for this scanner" from "no data".
  final int? matchCount;
  final VoidCallback onTap;
  const _IndexRow({
    required this.index,
    required this.selected,
    required this.matchCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    // Always show the per-scanner match count next to each index.
    // Indices that don't match the current scanner show "0" in muted
    // grey; matching indices show the count in brand color + semibold.
    // When the backend hasn't shipped the feature yet, every count is
    // absent so every row reads "0" — preferable to displaying a
    // universe-size number that could be confused for a match count.
    final int effective = matchCount ?? 0;
    final String label = '$effective';
    final Color labelColor =
        effective > 0 ? MyntColors.primary : secondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          // Custom small checkbox — avoids the heavy default Checkbox.
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: selected ? MyntColors.primary : Colors.transparent,
              border: Border.all(
                color: selected
                    ? MyntColors.primary
                    : secondary.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              index.name,
              style: MyntWebTextStyles.body(context, color: primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            label,
            style: MyntWebTextStyles.caption(context,
                fontWeight:
                    effective > 0 ? MyntFonts.semiBold : MyntFonts.regular,
                color: labelColor),
          ),
        ]),
      ),
    );
  }
}

/// Categorize indices for the dropdown. Mirrors the JS helper in the
/// spec — exposed as a top-level function so it can be unit-tested
/// independently if we add tests later. Returns a `LinkedHashMap`-style
/// ordering: groups appear in the order listed below.
Map<String, List<MarketIndex>> _groupIndices(List<MarketIndex> indices) {
  final groups = <String, List<MarketIndex>>{
    'Broad market': [],
    'Cap-size': [],
    'Sectoral': [],
    'Thematic': [],
    'Strategy': [],
    'Corporate group': [],
    'Other': [],
  };
  const sectoralNames = <String>{
    'NIFTY BANK', 'NIFTY IT', 'NIFTY FMCG', 'NIFTY PHARMA', 'NIFTY AUTO',
    'NIFTY METAL', 'NIFTY REALTY', 'NIFTY ENERGY', 'NIFTY OIL AND GAS INDEX',
    'NIFTY MEDIA', 'NIFTY CONSUMER DURABLES', 'NIFTY PSU BANK',
    'NIFTY PRIVATE BANK', 'NIFTY FINANCIAL SERVICES', 'NIFTY INFRASTRUCTURE',
    'NIFTY COMMODITIES', 'NIFTY SERVICES SECTOR', 'NIFTY PSE',
    'Nifty HEALTHCARE', 'Nifty Core Housing', 'Nifty Housing',
    'Nifty MidSmall Healthcare', 'Nifty MidSmall Financial Services',
    'Nifty MidSmall IT & Telecom', 'Nifty Financial Services Ex Bank',
  };
  final strategy = RegExp(
    r'QUALITY|MOMENTUM|ALPHA|LOW VOLATILITY|VALUE|EQUAL WEIGHT|HIGH BETA|DIVIDEND',
    caseSensitive: false,
  );
  final capSize = RegExp(
    r'MIDCAP|SMALLCAP|MICROCAP|LargeMid|MIDSMALL|Midcap|Smallcap',
  );
  final broad = RegExp(
    r'^(NIFTY 50|NIFTY NEXT 50|NIFTY 100|NIFTY 200|NIFTY 500|Nifty Total Market|NIFTY500 MULTICAP)',
  );
  final thematic = RegExp(
    r'Defence|Digital|Manufacturing|Mobility|EV|Housing|Consumption|REIT|Non-Cyclical|Transportation',
  );

  for (final idx in indices) {
    final n = idx.name;
    if (n.contains('CORPORATE GROUP')) {
      groups['Corporate group']!.add(idx);
    } else if (strategy.hasMatch(n)) {
      groups['Strategy']!.add(idx);
    } else if (sectoralNames.contains(n)) {
      groups['Sectoral']!.add(idx);
    } else if (capSize.hasMatch(n)) {
      groups['Cap-size']!.add(idx);
    } else if (broad.hasMatch(n)) {
      groups['Broad market']!.add(idx);
    } else if (thematic.hasMatch(n)) {
      groups['Thematic']!.add(idx);
    } else {
      groups['Other']!.add(idx);
    }
  }
  // Drop empty groups so the panel doesn't render lonely headers.
  groups.removeWhere((_, list) => list.isEmpty);
  return groups;
}

/// Compact horizontal list of removable chips, one per active filter.
/// Drop in next to / under the IndexFilterDropdown trigger to show the
/// user what's currently narrowing their results. Tapping the X on any
/// chip drops that index from the selection.
class ActiveIndexFilterChips extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const ActiveIndexFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) return const SizedBox.shrink();
    final primary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final name in selected)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              color: MyntColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MyntColors.primary.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.semiBold,
                        color: MyntColors.primary)),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    final next = [...selected]..remove(name);
                    onChanged(next);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      shadcn.LucideIcons.x,
                      size: 12,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

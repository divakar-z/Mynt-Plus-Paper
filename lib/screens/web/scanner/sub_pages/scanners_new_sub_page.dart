import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/scanners_detail_pane.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Redesigned Scanners tab: a research dashboard instead of a flat list.
/// Scanners are grouped into category panels, with a hero area and
/// sentiment-focused insight cards up top.
class ScannersNewSubPage extends ConsumerStatefulWidget {
  const ScannersNewSubPage({super.key});

  @override
  ConsumerState<ScannersNewSubPage> createState() => _ScannersNewSubPageState();
}

class _ScannersNewSubPageState extends ConsumerState<ScannersNewSubPage> {
  String? _selectedCode;
  final TextEditingController _q = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ScannerSentiment? _activeSentiment;
  // Per-category keys so the hero jump-chips can scroll to each section.
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _q.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCode != null) {
      return ScannersDetailPane(
        code: _selectedCode!,
        onBack: () => setState(() => _selectedCode = null),
      );
    }

    final async = ref.watch(scannerListProvider);
    return async.when(
      loading: () => Center(child: MyntLoader.branded()),
      error: (e, _) => EmptyState(
        kind: EmptyStateKind.error,
        title: 'Could not load scanners',
        message: e.toString(),
        onRetry: () => ref.invalidate(scannerListProvider),
      ),
      data: (resp) => _dashboard(resp.items),
    );
  }

  Widget _dashboard(List<Scanner> all) {
    final counts = <ScannerSentiment, int>{
      ScannerSentiment.bullish: 0,
      ScannerSentiment.bearish: 0,
      ScannerSentiment.neutral: 0,
    };
    for (final s in all) {
      final sent = s.sentiment;
      if (sent != null) counts[sent] = (counts[sent] ?? 0) + 1;
    }

    final byGroup = <String, List<Scanner>>{};
    for (final s in all) {
      if (!_matches(s)) continue;
      byGroup.putIfAbsent(s.groupName, () => []).add(s);
    }
    final filteredTotal =
        byGroup.values.fold<int>(0, (sum, list) => sum + list.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heroPanel(byGroup.keys.toList()),
        const SizedBox(height: 16),
        _summaryStrip(all.length, filteredTotal, counts),
        const SizedBox(height: 20),
        Expanded(
          child: byGroup.isEmpty
              ? const EmptyState(
                  kind: EmptyStateKind.search,
                  title: 'No scanners match this filter',
                )
              : _sections(byGroup),
        ),
      ],
    );
  }

  bool _matches(Scanner s) {
    if (_activeSentiment != null && s.sentiment != _activeSentiment) {
      return false;
    }
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.displayName.toLowerCase().contains(q) ||
        s.code.toLowerCase().contains(q) ||
        (s.subGroup?.toLowerCase().contains(q) ?? false);
  }

  Widget _heroPanel(List<String> groups) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final panelBg = resolveThemeColor(context,
        dark: MyntColors.sidebarBgDark, light: const Color(0xFFF1F5FE));
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        // Left→right gradient (not diagonal) so a wide banner stays even — blue
        // near the title, fading to near-white by the search. No dark middle.
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFDCE7FC), Color(0xFFF0F5FE)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final overview = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //   decoration: BoxDecoration(
              //     color: primary.withValues(alpha: 0.10),
              //     borderRadius: BorderRadius.circular(999),
              //   ),
              //   child: Text(
              //     'RESEARCH DASHBOARD',
              //     style: MyntWebTextStyles.caption(
              //       context,
              //       color: primary,
              //       fontWeight: MyntFonts.semiBold,
              //     ).copyWith(letterSpacing: 1.0),
              //   ),
              // ),
              // const SizedBox(height: 14),
              Text(
                'Scanners',
                style: MyntWebTextStyles.hero(context,
                        fontWeight: MyntFonts.bold, color: textPrimary)
                    .copyWith(fontSize: 28),
              ),
              const SizedBox(height: 10),
              Text(
                'A curated set of pre-built market scans that flag stocks matching specific patterns and signals, organised by category.',
                style: MyntWebTextStyles.body(context, color: secondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final g in groups) _jumpChip(g)],
              ),
            ],
          );
          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) overview else Expanded(flex: 3, child: overview),
              SizedBox(width: stacked ? 0 : 20, height: stacked ? 16 : 0),
              SizedBox(
                width: stacked ? double.infinity : 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        // borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: border),
                      ),
                      child: MyntSearchTextField.withSmartClear(
                        controller: _q,
                        placeholder: 'Search scanners, codes, groups...',
                        leadingIcon: assets.searchIcon,
                        textCapitalization: TextCapitalization.none,
                      ),
                    ),
                    // const SizedBox(height: 12),
                    // Container(
                    //   padding: const EdgeInsets.all(14),
                    //   decoration: BoxDecoration(
                    //     color: cardBg,
                    //     borderRadius: BorderRadius.circular(14),
                    //     border: Border.all(color: border),
                    //   ),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Text(
                    //         'Current view',
                    //         style: MyntWebTextStyles.caption(context,
                    //             color: secondary),
                    //       ),
                    //       const SizedBox(height: 8),
                    //       Text(
                    //         activeFilter,
                    //         style: MyntWebTextStyles.title(context,
                    //             fontWeight: MyntFonts.semiBold,
                    //             color: textPrimary),
                    //       ),
                    //       const SizedBox(height: 4),
                    //       Text(
                    //         query.isEmpty
                    //             ? 'Use search or the sentiment modules below to narrow the catalog.'
                    //             : 'Searching for "$query"',
                    //         style: MyntWebTextStyles.caption(context,
                    //             color: secondary),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  GlobalKey _keyFor(String group) =>
      _sectionKeys.putIfAbsent(group, () => GlobalKey());

  void _jumpToSection(String group) {
    final ctx = _sectionKeys[group]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  /// Category quick-jump chip in the hero — a category icon + name that
  /// scrolls to that section.
  Widget _jumpChip(String group) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final accent = _groupColor(group);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _jumpToSection(group),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: resolveThemeColor(context,
                dark: MyntColors.cardDark, light: MyntColors.card),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_groupIcon(group), size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                group,
                style: MyntWebTextStyles.para(context,
                    color: textPrimary, fontWeight: MyntFonts.semiBold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryStrip(
      int total, int filteredTotal, Map<ScannerSentiment, int> counts) {
    final items = [
      (
        label: 'All Setups',
        helper: '$filteredTotal visible now',
        count: total,
        value: null as ScannerSentiment?,
        accent: resolveThemeColor(context,
            dark: MyntColors.primaryDark, light: MyntColors.primary),
        image: assets.scannerAll,
      ),
      (
        label: 'Bullish',
        helper: 'Momentum upside',
        count: counts[ScannerSentiment.bullish] ?? 0,
        value: ScannerSentiment.bullish,
        accent: _sentColor(ScannerSentiment.bullish),
        image: assets.scannerBullish,
      ),
      (
        label: 'Bearish',
        helper: 'Weakness / breakdowns',
        count: counts[ScannerSentiment.bearish] ?? 0,
        value: ScannerSentiment.bearish,
        accent: _sentColor(ScannerSentiment.bearish),
        image: assets.scannerBearish,
      ),
      (
        label: 'Neutral',
        helper: 'Balanced / range setups',
        count: counts[ScannerSentiment.neutral] ?? 0,
        value: ScannerSentiment.neutral,
        accent: _sentColor(ScannerSentiment.neutral),
        image: assets.scannerNeutral,
      ),
    ];

    // Fixed-width cards (left-aligned) instead of stretching to fill the row;
    // they wrap to the next line on narrower screens.
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final item in items)
          SizedBox(
            width: 240,
            child: _StatCard(
              label: item.label,
              helper: item.helper,
              count: item.count,
              image: item.image,
              accent: item.accent,
              active: _activeSentiment == item.value,
              onTap: () => setState(() => _activeSentiment =
                  _activeSentiment == item.value ? null : item.value),
            ),
          ),
      ],
    );
  }

  Widget _sections(Map<String, List<Scanner>> byGroup) {
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: _scroll,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(8),
        thumbColor: secondary.withValues(alpha: 0.4),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.only(right: 12, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in byGroup.entries)
                _section(entry.key, entry.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String group, List<Scanner> list) {
    final accent = _groupColor(group);
    final border = shadcn.Theme.of(context).colorScheme.border;
    final panelBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: const Color(0xFFFDFEFF));

    return Container(
      key: _keyFor(group),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(group, list.length),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1280
                  ? 4
                  : constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 580
                          ? 2
                          : 1;
              const spacing = 14.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final s in list)
                    SizedBox(
                      width: cardWidth,
                      child: _ScannerCard(
                        name: s.displayName,
                        description: s.description,
                        subGroup: s.subGroup,
                        sentiment: s.sentiment,
                        accent: accent,
                        onTap: () => setState(() => _selectedCode = s.code),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String group, int count) {
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final accent = _groupColor(group);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_groupIcon(group), color: accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    group,
                    style: MyntWebTextStyles.title(context,
                        fontWeight: MyntFonts.semiBold, color: textPrimary),
                  ),
                  _groupPill('$count', accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _groupDescription(group),
                style: MyntWebTextStyles.para(context, color: secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }


  String _groupDescription(String group) {
    switch (group.toLowerCase()) {
      case 'candlestick':
        return 'Pattern-driven setups based on candle formations and reversal structures.';
      case 'price':
        return 'Pure price-action scans focused on structure, breakouts, and trend continuation.';
      case 'technical':
        return 'Indicator-led scanners for momentum, strength, and signal confirmation.';
      case 'volume':
        return 'Participation and activity-based setups highlighting unusual market interest.';
      default:
        return 'Pre-built scanners collected under this research category.';
    }
  }

  IconData _groupIcon(String group) {
    switch (group.toLowerCase()) {
      case 'candlestick':
        return Icons.candlestick_chart_rounded;
      case 'price':
        return Icons.show_chart_rounded;
      case 'technical':
        return Icons.tune_rounded;
      case 'volume':
        return Icons.stacked_bar_chart_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Widget _groupPill(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: MyntWebTextStyles.caption(context,
            color: accent, fontWeight: MyntFonts.semiBold),
      ),
    );
  }

  Color _sentColor(ScannerSentiment s) {
    switch (s) {
      case ScannerSentiment.bullish:
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      case ScannerSentiment.bearish:
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      case ScannerSentiment.neutral:
        return resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary);
    }
  }

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
}

class _StatCard extends StatefulWidget {
  final String label;
  final String helper;
  final int count;
  final String image;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.helper,
    required this.count,
    required this.image,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final hoverBg = resolveThemeColor(context,
        dark: MyntColors.cardHoverDark, light: const Color(0xFFF8FBFF));
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Active state is always blue (primary) for every card; hover just
            // lightens the background.
            color: widget.active
                ? primary.withValues(alpha: 0.08)
                : (_hover ? hoverBg : cardBg),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.active ? primary : border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Image.asset(widget.image, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 6),

                       Text(
                    widget.label,
                    style: MyntWebTextStyles.body(context,
                        fontWeight: MyntFonts.semiBold, color: textPrimary),
                  ),
                      
                      
                    ],
                  ),

                   Text(
                        '${widget.count}',
                        style: MyntWebTextStyles.body(context,
                            fontWeight: MyntFonts.bold, color: textPrimary),
                      ),

                 

                  // const Spacer(),
                  // if (widget.active)
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(
                  //         horizontal: 8, vertical: 4),
                  //     decoration: BoxDecoration(
                  //       color: widget.accent.withValues(alpha: 0.14),
                  //       borderRadius: BorderRadius.circular(999),
                  //     ),
                  //     child: Text(
                  //       'Active',
                  //       style: MyntWebTextStyles.caption(context,
                  //           color: widget.accent,
                  //           fontWeight: MyntFonts.semiBold),
                  //     ),
                  //   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerCard extends StatefulWidget {
  final String name;
  final String description;
  final String? subGroup;
  final ScannerSentiment? sentiment;
  final Color accent;
  final VoidCallback onTap;

  const _ScannerCard({
    required this.name,
    required this.description,
    required this.subGroup,
    required this.sentiment,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ScannerCard> createState() => _ScannerCardState();
}

class _ScannerCardState extends State<_ScannerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final border = shadcn.Theme.of(context).colorScheme.border;
    final cardBg = resolveThemeColor(context,
        dark: MyntColors.cardDark, light: MyntColors.card);
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final tertiary = resolveThemeColor(context,
        dark: MyntColors.textTertiaryDark, light: MyntColors.textTertiary);
    final sub = widget.subGroup;
    final desc = widget.description;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          // Fixed height so every card lines up regardless of description
          // length; the footer is pinned to the bottom via the Spacer below.
          height: 208,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Hover cue is just the accent border — no background lighten, no
            // drop shadow.
            color: cardBg,
            border: Border.all(
                color: _hover ? widget.accent.withValues(alpha: 0.55) : border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.title(context,
                              fontWeight: MyntFonts.semiBold,
                              color: textPrimary),
                        ),
                        if (sub != null && sub.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MyntWebTextStyles.para(context,
                                color: tertiary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sentimentBanner(context),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                Tooltip(
                  message: desc,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.para(context,
                        color: secondary, fontWeight: MyntFonts.regular),
                  ),
                ),
              ],
              const Spacer(),
              Divider(height: 1, color: border.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _hover ? 'Open scanner' : 'View matches',
                    style: MyntWebTextStyles.para(context,
                        color: widget.accent, fontWeight: MyntFonts.semiBold),
                  ),
                  const Spacer(),
                  Icon(
                    _hover
                        ? shadcn.LucideIcons.arrowUpRight
                        : shadcn.LucideIcons.chevronRight,
                    size: 16,
                    color: widget.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTile(BuildContext context) {
    final (icon, color) = _tileStyle(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  /// Ribbon/flag-shaped sentiment tag (notched left end) sitting in the pill's
  /// spot. Colored by sentiment, white bold label.
  Widget _sentimentBanner(BuildContext context) {
    final sentiment = widget.sentiment;
    final color = switch (sentiment) {
      ScannerSentiment.bullish => resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit),
      ScannerSentiment.bearish => resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss),
      ScannerSentiment.neutral => resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary),
      null => widget.accent,
    };
    final label = switch (sentiment) {
      ScannerSentiment.bullish => 'Bullish',
      ScannerSentiment.bearish => 'Bearish',
      ScannerSentiment.neutral => 'Neutral',
      null => 'General',
    };
    return ClipPath(
      clipper: _BannerClipper(),
      child: Container(
        color: color,
        padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
        child: Text(
          label,
          style: MyntWebTextStyles.caption(context,
              color: Colors.white, fontWeight: MyntFonts.medium).copyWith(letterSpacing: 0.8),
        ),
      ),
    );
  }

  (IconData, Color) _tileStyle(BuildContext context) {
    switch (widget.sentiment) {
      case ScannerSentiment.bullish:
        return (
          shadcn.LucideIcons.trendingUp,
          resolveThemeColor(context,
              dark: MyntColors.profitDark, light: MyntColors.profit)
        );
      case ScannerSentiment.bearish:
        return (
          shadcn.LucideIcons.trendingDown,
          resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss)
        );
      case ScannerSentiment.neutral:
        return (
          shadcn.LucideIcons.minus,
          resolveThemeColor(context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.textSecondary)
        );
      case null:
        return (shadcn.LucideIcons.activity, widget.accent);
    }
  }
}

/// Clips a rectangle into a ribbon/flag shape with a triangular notch cut into
/// the left edge (the sentiment banner on each scanner card).
class _BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notch = 8.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(notch, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

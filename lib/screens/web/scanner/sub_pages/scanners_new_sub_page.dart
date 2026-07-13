import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/responsive_extensions.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = shadcn.Theme.of(context).colorScheme.border;
    final textPrimary = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final gradientColors = isDark
        ? const [Color(0xFF161B22), Color(0xFF0D1117)]
        : const [Color(0xFFDCE7FC), Color(0xFFF0F5FE)];

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: gradientColors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanners',
            style: MyntWebTextStyles.hero(context,
                    fontWeight: MyntFonts.bold, color: textPrimary)
                .copyWith(fontSize: 28),
          ),
          const SizedBox(height: 15),
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

  /// Single filled candle body — used for Bullish (green) and Bearish (red).
  /// Sized to 20px so the tab height matches the positions-page tab strip.
  Widget _candleIcon(Color color) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1.5, height: 16, color: color),
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// All-Setups: a green + red candle pair side by side.
  Widget _allSetupsIcon(Color bull, Color bear) {
    Widget candle(Color c) => Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 1, height: 14, color: c),
            Container(
              width: 3.5,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        );
    return SizedBox(
      width: 20,
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          candle(bull),
          const SizedBox(width: 3),
          candle(bear),
        ],
      ),
    );
  }

  /// Doji shape drawn as a thin vertical wick with a horizontal crossbar.
  Widget _dojiIcon(Color color) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1.5, height: 15, color: color),
          Container(width: 8, height: 1.5, color: color),
        ],
      ),
    );
  }

  Widget _summaryStrip(
      int total, int filteredTotal, Map<ScannerSentiment, int> counts) {
    // Draw all four icons ourselves — the PNGs have too much transparent
    // padding, scaling any visible content to sub-pixel size at 32px.
    final bull = resolveThemeColor(context,
        dark: MyntColors.profitDark, light: MyntColors.profit);
    final bear = resolveThemeColor(context,
        dark: MyntColors.lossDark, light: MyntColors.loss);
    final neutralColor = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final items = [
      (
        label: 'All Setups',
        count: total,
        value: null as ScannerSentiment?,
        icon: _allSetupsIcon(bull, bear),
      ),
      (
        label: 'Bullish',
        count: counts[ScannerSentiment.bullish] ?? 0,
        value: ScannerSentiment.bullish,
        icon: _candleIcon(bull),
      ),
      (
        label: 'Bearish',
        count: counts[ScannerSentiment.bearish] ?? 0,
        value: ScannerSentiment.bearish,
        icon: _candleIcon(bear),
      ),
      (
        label: 'Neutral',
        count: counts[ScannerSentiment.neutral] ?? 0,
        value: ScannerSentiment.neutral,
        icon: _dojiIcon(neutralColor),
      ),
    ];

    // Positions-page pattern: scrollable tabs on the left, Spacer, then the
    // search field pinned to the right end of the row.
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  _TabItem(
                    label: item.label,
                    count: item.count,
                    icon: item.icon,
                    active: _activeSentiment == item.value,
                    onTap: () => setState(() => _activeSentiment =
                        _activeSentiment == item.value ? null : item.value),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: context.responsiveValue<double>(
            mobile: 140,
            smallTablet: 180,
            tablet: 220,
            desktop: 300,
            largeDesktop: 350,
            widescreen: 400,
          ),
          height: 40,
          child: MyntSearchTextField.withSmartClear(
            controller: _q,
            placeholder: 'Search scanners, codes, groups...',
            leadingIcon: assets.searchIcon,
            textCapitalization: TextCapitalization.none,
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

  Color _groupColor(String g) {
    switch (g.toLowerCase()) {
      case 'candlestick':
        return const Color(0xFFDB7C26);
      case 'price':
        return resolveThemeColor(context, dark: MyntColors.secondaryDark, light: MyntColors.primary);
      case 'technical':
        return const Color(0xFF0F9D7A);
      case 'volume':
        return MyntColors.warning;
      default:
        return const Color(0xFF2F6FED);
    }
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final Widget icon;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final foreground = shadcn.Theme.of(context).colorScheme.foreground;
    final mutedForeground = shadcn.Theme.of(context).colorScheme.mutedForeground;
    final textColor = active ? foreground : mutedForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight:
                      active ? MyntFonts.semiBold : MyntFonts.medium,
                ).copyWith(color: textColor),
              ),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Text(
                  '$count',
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    fontWeight:
                        active ? MyntFonts.semiBold : MyntFonts.medium,
                  ).copyWith(fontSize: 13, color: textColor),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark
                ? widget.accent.withValues(alpha: 0.06)
                : Colors.white,
            border: Border.all(
              color: _hover
                  ? widget.accent.withValues(alpha: isDark ? 0.45 : 0.40)
                  : widget.accent.withValues(alpha: isDark ? 0.20 : 0.15),
              width: 1,
            ),
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

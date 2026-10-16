import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/models/scanner_model/scanner.dart';
import 'package:mynt_plus/provider/scanner/scanner_shell_provider.dart';
import 'package:mynt_plus/provider/scanner/scanners_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/responsive_extensions.dart';
import 'package:mynt_plus/screens/web/scanner/sub_pages/scanners_detail_pane.dart';
import 'package:mynt_plus/screens/web/scanner/utils/scanner_tokens.dart';
import 'package:mynt_plus/screens/web/scanner/widgets/empty_state.dart';
import 'package:mynt_plus/screens/web/customizable_split_home_screen.dart'
    show ScannerSubPage;
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';

/// The scanner design tokens, under the short name this file has always used.
typedef _Tok = ScannerTokens;

/// Redesigned Scanners tab: a research dashboard instead of a flat list.
/// Scanners are grouped into category panels, under a toolbar with search
/// and a sentiment filter dropdown.
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
  // false = landing (action cards + popular), true = full categorised list.
  bool _showAll = false;
  // Per-category keys so the jump-chips can scroll to each section.
  final Map<String, GlobalKey> _sectionKeys = {};
  // Last category chip tapped — highlighted as the active tab.
  String? _activeGroup;

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
      data: (resp) => _showAll ? _browseAll(resp.items) : _landing(resp.items),
    );
  }

  // ===========================================================================
  // LANDING
  // ===========================================================================

  /// Landing view: page header, the two action cards (Do it yourself / Full
  /// scanner) and a grid of popular scanners.
  Widget _landing(List<Scanner> all) {
    final popular = _popularScanners(all);

    // Scrollbar hidden on the landing page; wheel/trackpad scrolling still works.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        // Full bleed — the landing fills whatever width the shell gives it.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _hero(),
            const SizedBox(height: 18),
            _actionCards(all),
            const SizedBox(height: 34),
            _popularPanel(all, popular),
          ],
        ),
      ),
    );
  }

  /// Page header — the headline and its one-line pitch, nothing else. No
  /// ground, no artwork and no right-hand strapline: the landing leads
  /// straight into the action cards, which are its only tinted surfaces.
  Widget _hero() {
    final accent = _Tok.diyAccent(context);
    final textPrimary = _Tok.textPrimary(context);
    final secondary = _Tok.textSecondary(context);

    final titleSize = context.responsiveValue<double>(
      mobile: 22,
      smallTablet: 24,
      tablet: 26,
      desktop: 28,
      largeDesktop: 30,
      widescreen: 32,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Find your '),
            TextSpan(text: 'edge', style: TextStyle(color: accent)),
            const TextSpan(text: '.'),
          ]),
          style: MyntWebTextStyles.hero(context,
                  fontWeight: MyntFonts.bold, color: textPrimary)
              .copyWith(
            fontSize: titleSize,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        // Single line by design — no width cap, and it ellipsizes rather
        // than wrapping onto a second row under the headline.
        Text(
          'Scan the market in seconds and act on high-probability setups.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: MyntWebTextStyles.body(context, color: secondary)
              .copyWith(height: 1.45),
        ),
      ],
    );
  }

  /// The two large entry-point cards. Side by side above 900px, stacked below.
  Widget _actionCards(List<Scanner> all) {
    // The pair is told apart by hue, not weight: the DIY card takes the
    // design's blue ground and accent, the full scanner its green pair. Both
    // are pale enough to keep the page's own ink legible on top.
    return LayoutBuilder(builder: (context, constraints) {
      final full = _ActionCard(
        ground: _Tok.fullGround(context),
        accent: _Tok.fullAccent(context),
        eyebrow: 'FULL SCANNER',
        titleLead: 'Explore ',
        titleAccent: 'Predefined',
        titleTail: '',
        subtitle: 'Browse ready-made scanners built on popular strategies. '
            'Pick one, see the stocks it throws up today and act on them '
            'straight away.',
        tagline: 'Proven scans.\nReady to run.',
        buttonLabel: 'Browse Scanners',
        filled: false,
        onTap: () => _openBrowseAll(all),
      );
      final diy = _ActionCard(
        ground: _Tok.diyGround(context),
        accent: _Tok.diyAccent(context),
        eyebrow: 'FUNDAMENTAL SCREENER',
        titleLead: 'Screen by ',
        titleAccent: 'fundamentals',
        titleTail: '',
        subtitle: 'Filter the market on valuation, returns, debt and growth — '
            'P/E, ROE, market cap and more. Save a screen and run it again '
            'whenever you want.',
        tagline: 'Your filters.\nYour shortlist.',
        buttonLabel: 'Open Screener',
        filled: true,
        onTap: () => ref
            .read(scannerShellProvider.notifier)
            .setActiveSubPage(ScannerSubPage.fundamentalsNew),
      );
      final custom = _ActionCard(
        ground: _Tok.customGround(context),
        accent: _Tok.customAccent(context),
        eyebrow: 'CUSTOM SCANNER',
        titleLead: 'Design ',
        titleAccent: 'custom scans',
        titleTail: '',
        subtitle: 'Build your own scan from technical conditions — RSI, moving '
            'averages, price action and candlestick patterns. Save it and '
            'rerun it on any index.',
        tagline: 'Your logic.\nYour signals.',
        buttonLabel: 'Custom Scans',
        filled: false,
        onTap: () => ref
            .read(scannerShellProvider.notifier)
            .setActiveSubPage(ScannerSubPage.customScans),
      );
      // Three cards get cramped side by side below 1100px — stack them.
      if (constraints.maxWidth < 1100) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // IntrinsicHeight gives each card a bounded height so its
          // button can sit at the bottom.
          children: [
            IntrinsicHeight(child: diy),
            const SizedBox(height: 18),
            IntrinsicHeight(child: full),
            const SizedBox(height: 18),
            IntrinsicHeight(child: custom),
          ],
        );
      }
      // IntrinsicHeight keeps both cards the same height when one
      // description wraps to more lines than the other.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: diy),
            const SizedBox(width: 18),
            Expanded(child: full),
            const SizedBox(width: 18),
            Expanded(child: custom),
          ],
        ),
      );
    });
  }

  /// Popular section, laid straight on the page — no panel ground, border or
  /// hairline, same as the browse-all category sections ([_sectionSliver]).
  Widget _popularPanel(List<Scanner> all, List<Scanner> popular) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _popularHeader(all),
        if (popular.isNotEmpty) ...[
          const SizedBox(height: 20),
          _cardGrid(popular),
        ],
      ],
    );
  }

  /// "Popular Scanners" title block, with the View-all action on the right.
  Widget _popularHeader(List<Scanner> all) {
    final accent = _Tok.accent(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Popular Scanners',
                style: MyntWebTextStyles.hero(context,
                        fontWeight: MyntFonts.bold,
                        color: _Tok.textPrimary(context))
                    .copyWith(fontSize: 22, letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                'Handpicked scanners based on trader preferences and '
                'market trends.',
                style: MyntWebTextStyles.body(context,
                    color: _Tok.textSecondary(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _GhostButton(
          label: 'View all',
          icon: Icons.arrow_forward_rounded,
          accent: accent,
          onTap: () => _openBrowseAll(all),
        ),
      ],
    );
  }

  /// One scanner per category, preferring the scans shown in the design
  /// (Bullish Engulfing, RSI, Volume, 52 Week High); falls back to the first
  /// scanner of that category.
  List<Scanner> _popularScanners(List<Scanner> all) {
    const preferred = [
      ('candlestick', 'bullish engulfing'),
      ('technical', 'rsi'),
      ('volume', 'volume'),
      ('price', '52'),
    ];
    final picked = <Scanner>[];
    for (final (group, keyword) in preferred) {
      final inGroup =
          all.where((s) => s.groupName.toLowerCase() == group).toList();
      if (inGroup.isEmpty) continue;
      picked.add(inGroup.firstWhere(
        (s) => s.displayName.toLowerCase().contains(keyword),
        orElse: () => inGroup.first,
      ));
    }
    // Fill up to 12, taking one more from each category in turn for variety.
    const target = 12;
    final byGroup = <String, List<Scanner>>{};
    for (final s in all) {
      if (!picked.contains(s)) {
        byGroup.putIfAbsent(s.groupName, () => []).add(s);
      }
    }
    final queues = byGroup.values.toList();
    var round = 0;
    while (picked.length < target && queues.any((q) => q.length > round)) {
      for (final q in queues) {
        if (picked.length >= target) break;
        if (q.length > round) picked.add(q[round]);
      }
      round++;
    }
    return picked;
  }

  /// Opens the full list with the Candlestick category highlighted by
  /// default (first section in the design).
  void _openBrowseAll(List<Scanner> all) {
    String? candlestick;
    for (final s in all) {
      if (s.groupName.toLowerCase() == 'candlestick') {
        candlestick = s.groupName;
        break;
      }
    }
    setState(() {
      _showAll = true;
      _activeGroup = candlestick;
    });
  }

  // ===========================================================================
  // BROWSE ALL
  // ===========================================================================

  /// Full categorised list, reached from "Browse Scanners" / "View all".
  Widget _browseAll(List<Scanner> all) => _dashboard(all);

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
    final groupCount = <String>{
      for (final s in all)
        if (s.groupName.isNotEmpty) s.groupName
    }.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryStrip(all.length, groupCount, counts),
        const SizedBox(height: 14),
        if (byGroup.isNotEmpty) ...[
          _jumpBar(byGroup),
          const SizedBox(height: 18),
        ],
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

  /// Responsive scanner-card grid. Each row is an IntrinsicHeight Row so the
  /// cards in a row share the height of the tallest (full descriptions shown).
  /// Gap between cards, both axes.
  static const double _kCardGap = 14.0;

  int _columnsFor(double width) => width >= 1280
      ? 4
      : width >= 900
          ? 3
          : width >= 580
              ? 2
              : 1;

  /// One row of the grid. [IntrinsicHeight] is what makes every card in the
  /// row as tall as the tallest, so their footers line up.
  Widget _cardRow(List<Scanner> list, int start, int columns) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) const SizedBox(width: _kCardGap),
            Expanded(
              // Empty slot keeps the last row's cards the same width.
              child: start + c < list.length
                  ? _scannerCard(list[start + c])
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  /// Eager grid, used for the short Popular strip on the landing page. The
  /// long categorised list uses [_cardRowsSliver] so its rows stay lazy.
  Widget _cardGrid(List<Scanner> list) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = _columnsFor(constraints.maxWidth);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < list.length; r += columns) ...[
            if (r > 0) const SizedBox(height: _kCardGap),
            _cardRow(list, r, columns),
          ],
        ],
      );
    });
  }

  Widget _scannerCard(Scanner s) => _ScannerCard(
        name: s.displayName,
        description: s.description,
        subGroup: s.subGroup,
        groupName: s.groupName,
        sentiment: s.sentiment,
        accent: _groupColor(s.groupName),
        icon: _groupIcon(s.groupName),
        onTap: () => setState(() => _selectedCode = s.code),
      );

  GlobalKey _keyFor(String group) =>
      _sectionKeys.putIfAbsent(group, () => GlobalKey());

  /// Scrolls a category panel to the top of the viewport.
  ///
  /// The panels are built lazily, so the target usually does not exist yet
  /// when its chip is tapped. Walk the viewport down a screen at a time until
  /// the list has built it, then hand off to [Scrollable.ensureVisible] for
  /// the final alignment. Bounded, so a group that is filtered out
  /// can never spin.
  Future<void> _jumpToSection(String group) async {
    for (var step = 0; step < 24; step++) {
      final ctx = _sectionKeys[group]?.currentContext;
      if (ctx != null) {
        // Instant jump — no scroll animation on tab switch.
        await Scrollable.ensureVisible(ctx, alignment: 0.0);
        return;
      }
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final next =
          (pos.pixels + pos.viewportDimension).clamp(0.0, pos.maxScrollExtent);
      // Already at the bottom and still not built → the group isn't here.
      if (next <= pos.pixels) return;
      _scroll.jumpTo(next);
      // Let the list build the newly-revealed panels before looking again.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }

  /// Segmented tray holding the category quick-jump chips. The tray gives the
  /// chips a shared ground so the active one reads as a raised tab.
  Widget _jumpBar(Map<String, List<Scanner>> byGroup) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _Tok.sunken(context),
        borderRadius: BorderRadius.circular(_Tok.rControl + 5),
        border: Border.all(color: _Tok.border(context)),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final e in byGroup.entries) _jumpChip(e.key, e.value.length),
        ],
      ),
    );
  }

  /// Category quick-jump chip — a category icon + name + count that scrolls
  /// to that section.
  Widget _jumpChip(String group, int count) {
    final dark = isDarkMode(context);
    final accent = _groupColor(group);
    final active = _activeGroup == group;
    final label = active ? accent : _Tok.textSecondary(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() => _activeGroup = group);
          _jumpToSection(group);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _Tok.surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(_Tok.rControl),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: dark ? 0.45 : 0.32)
                  : Colors.transparent,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: dark ? 0.20 : 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_groupIcon(group), size: 16, color: active ? accent : label),
              const SizedBox(width: 8),
              Text(
                group,
                style: MyntWebTextStyles.bodySmall(context,
                    color: active ? accent : _Tok.textPrimary(context),
                    fontWeight: MyntFonts.semiBold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: active ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(_Tok.rPill),
                ),
                child: Text(
                  '$count',
                  style: MyntWebTextStyles.caption(context,
                      color: accent, fontWeight: MyntFonts.bold),
                ),
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

  /// Toolbar panel: back button + title/subtitle on the left, then search and
  /// the sentiment filter dropdown on the right. Below 880px the controls drop
  /// onto their own row so nothing is squeezed.
  Widget _summaryStrip(
      int total, int groupCount, Map<ScannerSentiment, int> counts) {
    // Draw all four icons ourselves — the PNGs have too much transparent
    // padding, scaling any visible content to sub-pixel size at 32px.
    final bull = _Tok.bull(context);
    final bear = _Tok.bear(context);
    final neutralColor = _Tok.textSecondary(context);
    final textPrimary = _Tok.textPrimary(context);
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
    final selected = items.firstWhere((i) => i.value == _activeSentiment);

    Widget option(
            ({
              String label,
              int count,
              ScannerSentiment? value,
              Widget icon
            }) item,
            {bool bold = false}) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item.icon,
            const SizedBox(width: 8),
            Text(
              item.label,
              style: MyntWebTextStyles.body(context,
                  color: textPrimary,
                  fontWeight: bold ? MyntFonts.semiBold : MyntFonts.medium),
            ),
            const SizedBox(width: 6),
            Text(
              '${item.count}',
              style: MyntWebTextStyles.para(context, color: neutralColor),
            ),
          ],
        );

    final title = Row(
      children: [
        CustomBackBtn(onBack: () => setState(() => _showAll = false)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scanners',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.hero(context,
                        fontWeight: MyntFonts.bold, color: textPrimary)
                    .copyWith(letterSpacing: -0.3),
              ),
              const SizedBox(height: 2),
              Text(
                '$total ready-made scans across $groupCount categories',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MyntWebTextStyles.para(context, color: neutralColor),
              ),
            ],
          ),
        ),
      ],
    );

    // Shared field; the wide layout pins it to a responsive width while the
    // stacked layout lets it fill the row.
    final searchField = SizedBox(
      height: 42,
      child: MyntSearchTextField.withSmartClear(
        controller: _q,
        placeholder: 'Search scanners, codes, groups...',
        leadingIcon: assets.searchIcon,
        textCapitalization: TextCapitalization.none,
      ),
    );

    // Items are keyed by index: PopupMenuButton treats a null value as
    // "dismissed", which would make "All Setups" unselectable.
    final filter = PopupMenuButton<int>(
      tooltip: 'Filter by sentiment',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Tok.rControl)),
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: Colors.white),
      onSelected: (i) => setState(() => _activeSentiment = items[i].value),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 42,
            child: option(items[i], bold: items[i].value == _activeSentiment),
          ),
      ],
      child: Container(
        height: 42,
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _Tok.sunken(context),
          borderRadius: BorderRadius.circular(_Tok.rControl),
          border: Border.all(color: _Tok.border(context)),
        ),
        child: Row(
          children: [
            Expanded(child: option(selected)),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: neutralColor),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _Tok.surface(context),
        borderRadius: BorderRadius.circular(_Tok.rPanel),
        border: Border.all(color: _Tok.border(context)),
        boxShadow: _Tok.lift(context),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 880) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                filter,
              ]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
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
              child: searchField,
            ),
            const SizedBox(width: 10),
            filter,
          ],
        );
      }),
    );
  }

  Widget _sections(Map<String, List<Scanner>> byGroup) {
    final secondary = _Tok.textSecondary(context);
    final entries = byGroup.entries.toList(growable: false);
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: _scroll,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(8),
        thumbColor: secondary.withValues(alpha: 0.4),
        // Slivers rather than a list of panels. A panel holds dozens of
        // cards, so building one as a single list item stalled whichever
        // frame scrolled it into view — that was the scroll judder. Split
        // into slivers, only the card rows actually on screen get built, and
        // each row's IntrinsicHeight (two layout passes over text-heavy
        // cards) is paid for the handful on screen instead of all ~160.
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            for (final e in entries) _sectionSliver(e.key, e.value),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        ),
      ),
    );
  }

  /// One category section, as a sliver group laid straight on the page (no
  /// panel ground, border or hairline) while the card rows stay lazy.
  Widget _sectionSliver(String group, List<Scanner> list) {
    return SliverPadding(
      padding: const EdgeInsets.only(right: 12, bottom: 32),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            // The jump chips scroll to this, so the key rides the part of
            // the section that is built first.
            child: Padding(
              key: _keyFor(group),
              padding: const EdgeInsets.only(bottom: 20),
              child: _sectionHeader(group, list.length),
            ),
          ),
          _cardRowsSliver(list),
        ],
      ),
    );
  }

  /// The card grid as a lazy sliver — same column breakpoints and spacing as
  /// [_cardGrid], one row per sliver child so off-screen rows cost nothing.
  Widget _cardRowsSliver(List<Scanner> list) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.crossAxisExtent);
        final rowCount = (list.length + columns - 1) ~/ columns;
        return SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, r) => Padding(
            padding: EdgeInsets.only(bottom: r == rowCount - 1 ? 0 : _kCardGap),
            child: _cardRow(list, r * columns, columns),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String group, int count) {
    final textPrimary = _Tok.textPrimary(context);
    final secondary = _Tok.textSecondary(context);
    final accent = _groupColor(group);

    return Column(
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
        borderRadius: BorderRadius.circular(_Tok.rPill),
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
        return _Tok.accent(context);
      case 'technical':
        return const Color(0xFF0F9D7A);
      case 'volume':
        return MyntColors.warning;
      default:
        return const Color(0xFF2F6FED);
    }
  }
}

/// Text action in the accent colour ("View all") — label plus a trailing
/// arrow. No chrome and no hover state: it sits beside a section title, where
/// a pill would read as a second, competing button.
class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MyntWebTextStyles.bodySmall(context,
                  color: accent, fontWeight: MyntFonts.semiBold),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

/// A single scanner tile: category medallion, sentiment pill, name,
/// description, metadata tags and an open action. The whole card is the hit
/// target; hover tints the surface with the category accent.
class _ScannerCard extends StatefulWidget {
  final String name;
  final String description;
  final String? subGroup;
  final String groupName;
  final ScannerSentiment? sentiment;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _ScannerCard({
    required this.name,
    required this.description,
    required this.subGroup,
    required this.groupName,
    required this.sentiment,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ScannerCard> createState() => _ScannerCardState();
}

class _ScannerCardState extends State<_ScannerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final accent = widget.accent;
    final textPrimary = _Tok.textPrimary(context);
    final secondary = _Tok.textSecondary(context);
    final desc = widget.description;
    // One link colour for every card; the hue no longer varies by category.
    final linkColor = _Tok.diyAccent(context);

    // One line of metadata under the name, set as plain muted text rather
    // than a chip. The sub-group is the specific label ("Pattern"); the
    // category is the fallback when a scanner has no sub-group.
    final kicker = (widget.subGroup?.isNotEmpty ?? false)
        ? widget.subGroup!
        : widget.groupName;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        // Flat tile in the style of the options "Popular strategies" cards:
        // white surface, thin border, small radius, no shadow. Only the
        // border answers the pointer.
        child: AnimatedContainer(
          duration: _Tok.fast,
          curve: _Tok.ease,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _Tok.surface(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hover
                  ? linkColor.withValues(alpha: dark ? 0.55 : 0.42)
                  : _Tok.border(context),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name with a single sentiment arrow — no label, no icon tile.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold,
                                color: textPrimary)
                            .copyWith(height: 1.3),
                      ),
                    ),
                    if (_sentimentLabel != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: _sentimentLabel!,
                        child: Icon(_sentimentIcon,
                            size: 18, color: _sentimentColor(context)),
                      ),
                    ],
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MyntWebTextStyles.para(context,
                            color: secondary, fontWeight: MyntFonts.regular)
                        .copyWith(height: 1.5),
                  ),
                ],
                // Rows stretch cards to the tallest one; the Spacer pins the
                // footer to the bottom so it lines up across a row.
                const Spacer(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (kicker.isNotEmpty)
                      Expanded(
                        child: Text(
                          kicker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.para(context,
                              color: secondary),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      'View matches',
                      style: MyntWebTextStyles.para(context,
                              color: linkColor, fontWeight: MyntFonts.semiBold)
                          .copyWith(
                        decoration: _hover
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: linkColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: linkColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _sentimentIcon => switch (widget.sentiment) {
        ScannerSentiment.bullish => Icons.north_east_rounded,
        ScannerSentiment.bearish => Icons.south_east_rounded,
        _ => Icons.arrow_forward_rounded,
      };

  String? get _sentimentLabel => switch (widget.sentiment) {
        ScannerSentiment.bullish => 'Bullish',
        ScannerSentiment.bearish => 'Bearish',
        ScannerSentiment.neutral => 'Neutral',
        null => null,
      };

  Color _sentimentColor(BuildContext context) => switch (widget.sentiment) {
        ScannerSentiment.bullish => _Tok.bull(context),
        ScannerSentiment.bearish => _Tok.bear(context),
        _ => _Tok.textSecondary(context),
      };
}

/// Frosted glass over the DIY card's blue wash: two panes slanted across the
/// right-hand side, each a translucent white fill with a brighter hairline
/// down its leading edge. Drawn under the card's content, and clipped by the
/// card's own rounded rect, so the copy stays fully legible on top.
class _GlassPanePainter extends CustomPainter {
  /// Fill of a pane.
  final Color sheen;

  /// The brighter line down a pane's leading edge — what sells it as glass.
  final Color edge;

  const _GlassPanePainter({required this.sheen, required this.edge});

  /// Each pane as (top-edge x, bottom-edge x) fractions of the card width.
  /// The slant is the difference between the two, so panes stay parallel at
  /// every card width.
  static const _panes = <({double top, double bottom})>[
    (top: 0.62, bottom: 0.38),
    (top: 0.88, bottom: 0.64),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final fill = Paint()..color = sheen;
    final line = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final pane in _panes) {
      // Parallelogram running off the right edge of the card.
      final path = Path()
        ..moveTo(w * pane.top, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(w * pane.bottom, h)
        ..close();
      canvas.drawPath(path, fill);
      // Leading edge only — the other three sides are the card's own bounds.
      canvas.drawLine(
        Offset(w * pane.top, 0),
        Offset(w * pane.bottom, h),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPanePainter old) =>
      old.sheen != sheen || old.edge != edge;
}

/// Large landing card: eyebrow label, two-tone title, descriptive paragraph,
/// CTA button and a short tagline down the right-hand side, on a pale ground
/// ("Screen by fundamentals" / "Explore Predefined" / "Design custom scans").
/// The three share one layout and are told apart by hue alone — blue for the
/// fundamental screener, green for the full scanner, purple for custom scans.
class _ActionCard extends StatefulWidget {
  final String eyebrow;

  /// The title reads as one line in three pieces: [titleLead] and [titleTail]
  /// in the page ink, [titleAccent] in the card's own hue.
  final String titleLead;
  final String titleAccent;
  final String titleTail;

  final String subtitle;
  final String tagline;
  final String buttonLabel;

  /// The card's ground — the pale colour the gradient is washed from, and the
  /// fill the outlined CTA sits on so the button reads as part of the card.
  final Color ground;

  /// The card's hue: eyebrow, title highlight, CTA, tagline rule and border.
  final Color accent;

  /// Primary action: a solid accent CTA instead of an outlined one.
  final bool filled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.ground,
    required this.accent,
    required this.eyebrow,
    required this.titleLead,
    required this.titleAccent,
    required this.titleTail,
    required this.subtitle,
    required this.tagline,
    required this.buttonLabel,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  // Both cards sit on pale grounds, so the ink is the page's own text scale.
  // The eyebrow, title highlight and tagline rule carry the card's hue.
  Color get _titleInk => _Tok.textPrimary(context);

  /// Description ink — a step darker than the page's body colour, since the
  /// paragraph is long, set small and has to hold up against a tinted ground.
  Color get _bodyInk => _Tok.cardBody(context);

  /// The card hairline: the card's hue laid over its own ground, so the edge
  /// stays in the card's family instead of falling back to the page grey.
  Color get _borderInk => Color.alphaBlend(
        widget.accent.withValues(alpha: isDarkMode(context) ? 0.26 : 0.18),
        widget.ground,
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // The whole card is clickable, matching the button it contains.
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          // No hover to animate any more, but the duration still carries the
          // card's colours across a light/dark theme switch.
          duration: _Tok.fast,
          curve: _Tok.ease,
          // Min height (not fixed) so the description can wrap on narrower
          // widths; callers wrap the card in IntrinsicHeight so it is bounded.
          constraints: const BoxConstraints(minHeight: 204),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Tok.rPanel),
            // Each card sits on its own pale ground, washed from near-white
            // at the top-left into the ground at the bottom-right where the
            // glass panes sit. Neither answers the pointer.
            gradient: _glassWash(),
          ),
          // The hairline is a tint of the card's own hue, so the border
          // belongs to the card rather than to the page. It has to ride in
          // front: the clip follows the OUTER rounded rect, so a background
          // border would be painted over by the glass panes along the curve
          // and the corners would read as unfinished.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Tok.rPanel),
            border: Border.all(color: _borderInk),
          ),
          child: _glass(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.eyebrow,
                          style: MyntWebTextStyles.para(context,
                                  color: widget.accent,
                                  fontWeight: MyntFonts.bold)
                              .copyWith(letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 5),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: widget.titleLead),
                            TextSpan(
                              text: widget.titleAccent,
                              style: TextStyle(color: widget.accent),
                            ),
                            TextSpan(text: widget.titleTail),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MyntWebTextStyles.hero(context,
                                  fontWeight: MyntFonts.bold, color: _titleInk)
                              .copyWith(fontSize: 20, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.subtitle,
                          style: MyntWebTextStyles.bodySmall(context,
                                  color: _bodyInk,
                                  fontWeight: MyntFonts.regular)
                              .copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        // Pushes the button to the bottom so both cards' buttons
                        // align.
                        const Spacer(),
                        _button(context),
                      ],
                    ),
                  ),
                  // No rule between the pitch and the tagline — the gap alone
                  // separates them.
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tagline,
                        style: MyntWebTextStyles.para(context,
                                color: _titleInk,
                                fontWeight: MyntFonts.semiBold)
                            .copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 30,
                        height: 2,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          borderRadius: BorderRadius.circular(_Tok.rPill),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card's ground, washed from a near-white top-left into the ground
  /// itself and a shade deeper at the bottom-right — enough depth for the
  /// glass panes to sit on without the tint ever getting loud. Light mode
  /// lifts with white; dark mode barely lifts and sinks instead, since there
  /// the ground already sits at the dark end of the scale.
  LinearGradient _glassWash() {
    final base = widget.ground;
    final dark = isDarkMode(context);
    final lifted = Color.alphaBlend(
        Colors.white.withValues(alpha: dark ? 0.04 : 0.45), base);
    final sunk = Color.alphaBlend(
        Colors.black.withValues(alpha: dark ? 0.16 : 0.04), base);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.55, 1.0],
      colors: [lifted, base, sunk],
    );
  }

  /// Wraps the card body in the frosted panes. Both cards carry them now that
  /// hue, not artwork, is what tells the pair apart.
  Widget _glass({required Widget child}) {
    final dark = isDarkMode(context);
    return CustomPaint(
      painter: _GlassPanePainter(
        // White in both themes — a highlight over the ground, never a second
        // colour. On a light ground it can carry real weight; on a dark one
        // it has to stay faint. The two panes overlap towards the right edge,
        // so the alphas compound there.
        sheen: Colors.white.withValues(alpha: dark ? 0.04 : 0.50),
        edge: Colors.white.withValues(alpha: dark ? 0.09 : 0.80),
      ),
      child: child,
    );
  }

  /// Static CTA — no hover state and no motion. Each reads in its own card's
  /// hue: the primary one as a solid accent slab with white ink, the secondary
  /// one outlined and filled with the card's own ground, so the button sits in
  /// the card rather than on top of it.
  Widget _button(BuildContext context) {
    final solid = widget.filled;
    final accent = widget.accent;
    final fg = solid ? Colors.white : accent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: solid ? accent : widget.ground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: solid ? accent : accent.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.buttonLabel,
              style: MyntWebTextStyles.bodySmall(context,
                  color: fg, fontWeight: MyntFonts.semiBold),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 15, color: fg),
          ],
        ),
      ),
    );
  }
}

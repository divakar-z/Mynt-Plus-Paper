import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/rupeecase_model/algo_strategy_model.dart';
import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../res/res.dart';
import '../../routes/route_names.dart';
import '../../utils/custom_navigator.dart';
import 'strategy_card_web.dart';

/// Gap between two cards in either dashboard strategy row.
const double _kColumnGap = 16;

/// Number of cards shown in a dashboard preview row (the rest are on the
/// "See all" page).
const int _kPreviewCount = 10;

/// Dashboard preview of the curated RupeeCase strategies.
class RupeeCaseStrategiesSection extends ConsumerStatefulWidget {
  const RupeeCaseStrategiesSection({super.key});

  @override
  ConsumerState<RupeeCaseStrategiesSection> createState() =>
      _RupeeCaseStrategiesSectionState();
}

class _RupeeCaseStrategiesSectionState
    extends ConsumerState<RupeeCaseStrategiesSection> {
  /// Fixed pixel width of each strategy card — identical to the Algo section
  /// so both rows render cards at the same size.
  static const double _cardWidth = 220;

  /// Approximate rendered height used only for the empty-state placeholder.
  static const double _emptyHeight = 360;

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(rupeeCaseProvider);

    // Nothing anywhere (not loaded) or loaded-but-empty → occupy no space.
    if (provider.strategies.isEmpty && !provider.loading) {
      return const SizedBox.shrink();
    }

    final sorted = provider.strategies.toList()
      ..sort((a, b) => b.cagr.compareTo(a.cagr));
    final preview = sorted.take(_kPreviewCount).toList();
    final items = [
      for (int i = 0; i < preview.length; i++)
        StrategyCardData.fromRupeeCase(
          preview[i],
          accentColor:
              kStrategyAccentPalette[i % kStrategyAccentPalette.length],
        ),
    ];

    return _StrategySection(
      title: 'Momentum Investing',
      description:
          'Explore professionally curated momentum strategies, each backed by 5 '
          'years of rolling historical performance. Browse the results below, '
          'then choose your next step.',
      seeAllRoute: Routes.curatedStrategies,
      showSeeAll: provider.strategies.isNotEmpty,
      trailingGap: 32,
      child: _buildContent(context, loading: provider.loading, items: items),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool loading,
    required List<StrategyCardData> items,
  }) {
    if (items.isEmpty && loading) return _buildSkeleton(context);
    if (items.isEmpty) return _buildEmpty(context);
    return _CardScroller(
      scrollStep: _cardWidth + _kColumnGap,
      cells: [
        for (final item in items)
          _ScrollCell(width: _cardWidth, child: StrategyCard(data: item)),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return SizedBox(
      height: _emptyHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No strategies available',
          style: MyntWebTextStyles.para(context, color: muted),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    // Show enough fixed-width skeleton cards to visually fill the row,
    // matching the real scroller so nothing jumps when data arrives.
    return LayoutBuilder(
      builder: (context, constraints) {
        final int count = _fillCount(
          constraints.maxWidth,
          cellSpan: _cardWidth + _kColumnGap,
          fallback: 4,
          min: 2,
          max: 10,
        );
        return _cellRow([
          for (int i = 0; i < count; i++)
            const _ScrollCell(
              width: _cardWidth,
              child: StrategyCardSkeleton(),
            ),
        ]);
      },
    );
  }
}

/// Dashboard preview of automated strategy baskets. Renders the same
/// [StrategyCard] as the curated row, fed by [StrategyCardData.fromAlgo].
class AlgoStrategiesSection extends ConsumerStatefulWidget {
  const AlgoStrategiesSection({super.key, this.stackedMetrics = false});

  /// When true the strategy cards render their footer metrics as a 2×2 grid
  /// (DD / WIN RATE beneath MIN. CAP / CAGR) instead of a single row.
  final bool stackedMetrics;

  @override
  ConsumerState<AlgoStrategiesSection> createState() =>
      _AlgoStrategiesSectionState();
}

class _AlgoStrategiesSectionState extends ConsumerState<AlgoStrategiesSection> {
  /// Width of each algo strategy card. The row scrolls horizontally once these
  /// fixed-width cards overflow.
  static const double _cardWidth = 320;

  /// The stacked-metrics copy uses a narrower card — its 2×2 grid needs less
  /// horizontal room than the default four-in-a-row layout.
  static const double _stackedCardWidth = 200;

  /// The leading "Algo Trading" promo banner keeps its original (narrower) width
  /// so it stays compact; only the strategy cards were widened.
  static const double _bannerWidth = 280;

  double get _cardW => widget.stackedMetrics ? _stackedCardWidth : _cardWidth;

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(rupeeCaseProvider);
    final strategies = provider.algoStrategies.toList()
      ..sort((a, b) => b.subscriberCount.compareTo(a.subscriberCount));

    if (strategies.isEmpty && !provider.algoLoading) {
      return const SizedBox.shrink();
    }

    final preview = strategies.take(_kPreviewCount).toList();

    return _StrategySection(
      title: 'Zebu Algo Strategies',
      description:
          'Deploy ready-made automated strategies, each back-tested over years '
          'of market history. Explore the baskets below, then start on Zebu '
          'Algo.',
      seeAllRoute: Routes.algoStrategies,
      showSeeAll: strategies.isNotEmpty,
      child: preview.isEmpty
          ? _buildSkeleton(context)
          : _buildScroller(context, preview),
    );
  }

  Widget _buildScroller(BuildContext context, List<AlgoStrategy> strategies) {
    return _CardScroller(
      scrollStep: _cardW + _kColumnGap,
      // The leading promo card owns the left edge until the row scrolls.
      hideLeftArrowAtStart: true,
      cells: [
        // Leading cell = the "Algo Trading" promo banner, kept at its original
        // (narrower) width and filling the full (uniform) card height set by
        // the row's stretch alignment. Tapping it opens the Zebu Algo site.
        const _ScrollCell(width: _bannerWidth, child: _AlgoTradingBanner()),
        for (int i = 0; i < strategies.length; i++)
          _ScrollCell(
            width: _cardW,
            child: StrategyCard(
              data: StrategyCardData.fromAlgo(
                strategies[i],
                accentColor: kAlgoStrategyAccentPalette[
                    i % kAlgoStrategyAccentPalette.length],
                stackedMetrics: widget.stackedMetrics,
              ),
            ),
          ),
      ],
    );
  }

  /// Loading placeholder: the static banner, then as many shimmer skeleton
  /// cards as fill the visible width — mirroring the real scroller so the
  /// layout doesn't jump when the strategies arrive.
  Widget _buildSkeleton(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enough fixed-width cards (after the leading banner) to cover the row;
        // one extra so the shimmer runs to the edge like the overflowing real
        // content.
        final int cards = _fillCount(
          constraints.maxWidth,
          cellSpan: _cardW + _kColumnGap,
          fallback: 2,
          min: 2,
          max: 8,
          reserve: 1,
        );
        return _cellRow([
          const _ScrollCell(width: _bannerWidth, child: _AlgoTradingBanner()),
          for (int i = 0; i < cards; i++)
            _ScrollCell(
              width: _cardW,
              child: const StrategyCardSkeleton(
                footer: StrategyMetricsLayout.row,
              ),
            ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────── section shell ──

/// Title + "See all" link, the intro line, and the section's content — the
/// frame both dashboard strategy rows sit in.
class _StrategySection extends StatelessWidget {
  const _StrategySection({
    required this.title,
    required this.description,
    required this.seeAllRoute,
    required this.showSeeAll,
    required this.child,
    this.trailingGap = 0,
  });

  final String title;
  final String description;
  final String seeAllRoute;

  /// The link is hidden until there is data behind it.
  final bool showSeeAll;

  final Widget child;

  /// Space kept below the section, so the next dashboard block clears it.
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: MyntWebTextStyles.head(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.bold,
              ),
            ),
            if (showSeeAll) _SeeAllLink(route: seeAllRoute),
          ],
        ),
        const SizedBox(height: 6),
        // Short intro under the title — global para sizing in the muted
        // secondary colour so it reads as a subtitle.
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(
            description,
            style: MyntWebTextStyles.titlesub(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        child,
        if (trailingGap > 0) SizedBox(height: trailingGap),
      ],
    );
  }
}

/// "See all" link opening a section's full listing page.
class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!WebNavigationHelper.isAvailable) return;
          WebNavigationHelper.navigateTo(route);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'See all',
              style: MyntWebTextStyles.para(
                context,
                darkColor: MyntColors.primaryDark,
                lightColor: MyntColors.primary,
                fontWeight: MyntFonts.bold,
              ),
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── scrolling row ──

/// One fixed-width cell of a [_CardScroller] row.
class _ScrollCell {
  const _ScrollCell({required this.width, required this.child});

  final double width;
  final Widget child;
}

/// The cells laid out in a single row, each at its own width and all stretched
/// to the tallest one. Shared by the scroller and the loading skeletons.
Widget _cellRow(List<_ScrollCell> cells) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < cells.length; i++)
          Padding(
            padding: EdgeInsets.only(
                right: i < cells.length - 1 ? _kColumnGap : 0),
            child: SizedBox(width: cells[i].width, child: cells[i].child),
          ),
      ],
    ),
  );
}

/// How many fixed-width cells cover [availableWidth], with one extra so a
/// shimmer row runs past the edge like real overflowing content. [reserve]
/// drops cells already spoken for (the algo row's leading banner).
int _fillCount(
  double availableWidth, {
  required double cellSpan,
  required int fallback,
  required int min,
  required int max,
  int reserve = 0,
}) {
  if (!availableWidth.isFinite) return fallback;
  final int fit = ((availableWidth + _kColumnGap) / cellSpan).ceil() - reserve;
  return fit.clamp(min, max);
}

/// Horizontally scrolling row of fixed-width cards with the circular scroll
/// arrows from the Tools row: both stay visible for the whole scroll (they
/// clamp at the ends) as soon as the content overflows.
class _CardScroller extends StatefulWidget {
  const _CardScroller({
    required this.cells,
    required this.scrollStep,
    this.hideLeftArrowAtStart = false,
  });

  final List<_ScrollCell> cells;

  /// Distance one arrow tap travels — one card plus its gap.
  final double scrollStep;

  /// Keeps the left arrow off the row until something has actually scrolled out
  /// of view to the left — used by the algo row, whose leading promo card the
  /// arrow would otherwise sit on top of.
  final bool hideLeftArrowAtStart;

  @override
  State<_CardScroller> createState() => _CardScrollerState();
}

class _CardScrollerState extends State<_CardScroller> {
  final ScrollController _scrollController = ScrollController();

  /// Only tracked for [_CardScroller.hideLeftArrowAtStart] rows.
  bool _atStart = true;

  @override
  void initState() {
    super.initState();
    if (widget.hideLeftArrowAtStart) {
      _scrollController.addListener(_updateAtStart);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateAtStart);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateAtStart() {
    if (!mounted) return;
    final bool atStart =
        !_scrollController.hasClients || _scrollController.offset <= 0.5;
    if (atStart != _atStart) setState(() => _atStart = atStart);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decided from the laid-out width rather than the current scroll
        // offset, so neither arrow disappears at the ends of the row.
        double contentWidth = _kColumnGap * (widget.cells.length - 1);
        for (final cell in widget.cells) {
          contentWidth += cell.width;
        }
        final bool needsScrolling = constraints.maxWidth.isFinite &&
            contentWidth > constraints.maxWidth;
        final bool showLeft =
            needsScrolling && !(widget.hideLeftArrowAtStart && _atStart);

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: _cellRow(widget.cells),
            ),
            if (showLeft) _scrollArrow(context, isLeft: true),
            if (needsScrolling) _scrollArrow(context, isLeft: false),
          ],
        );
      },
    );
  }

  /// Circular scroll button, matched to the Tools row's arrows. Used instead of
  /// a visible scrollbar.
  Widget _scrollArrow(BuildContext context, {required bool isLeft}) {
    return Positioned(
      left: isLeft ? 8 : null,
      right: isLeft ? null : 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _scrollBy(isLeft ? -1 : 1),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: resolveThemeColor(context,
                      dark: MyntColors.dashboardCarColor,
                      light: MyntColors.card),
                  border: Border.all(
                    color: resolveThemeColor(context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isLeft ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                    size: 14,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollBy(int direction) {
    if (!_scrollController.hasClients) return;
    final double target =
        (_scrollController.offset + direction * widget.scrollStep)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

// ──────────────────────────────────────────────────────────── algo banner ──

/// The leading promo card of the algo row, opening the Zebu Algo site on tap.
class _AlgoTradingBanner extends StatelessWidget {
  const _AlgoTradingBanner();

  static const Color _accent = Color(0xFF4A1F8E);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openExternalUrl('https://algo.zebuetrade.com/'),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
              colors: [
                Color(0xFF170B26),
                Color(0xFF4A1F8E),
                Color(0xFF7B3FB5),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Bottom-right glow
              Positioned(
                right: -70,
                bottom: -70,
                child: IgnorePointer(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFB685FF).withValues(alpha: 0.65),
                          const Color(0xFFB685FF).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Top-left glow
              Positioned(
                left: -50,
                top: -50,
                child: IgnorePointer(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stackedIcon(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Algo Trading',
                            style: MyntWebTextStyles.head(
                              context,
                              darkColor: Colors.white,
                              lightColor: Colors.white,
                              fontWeight: MyntFonts.bold,
                            ).copyWith(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'NEW',
                            style: MyntWebTextStyles.caption(
                              context,
                              color: const Color(0xFF170B26),
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automated • Rule-based',
                      style: MyntWebTextStyles.body(
                        context,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create & deploy automated trading strategies with Zebu Algo.',
                      style: MyntWebTextStyles.para(
                        context,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Three rotated tiles stacked behind the bolt glyph.
  Widget _stackedIcon() {
    Widget tile({required double left, required double top, double? angle,
        required Color color, Widget? child, List<BoxShadow>? shadow}) {
      final Widget box = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
        child: child,
      );
      return Positioned(
        left: left,
        top: top,
        child: angle == null ? box : Transform.rotate(angle: angle, child: box),
      );
    }

    return SizedBox(
      width: 44,
      height: 34,
      child: Stack(
        children: [
          tile(
            left: 0,
            top: 6,
            angle: -0.18,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          tile(
            left: 5,
            top: 3,
            angle: -0.09,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          tile(
            left: 10,
            top: 0,
            color: Colors.white,
            shadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            child: Center(
              child: SvgPicture.asset(
                assets.boltIcon,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  _accent,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

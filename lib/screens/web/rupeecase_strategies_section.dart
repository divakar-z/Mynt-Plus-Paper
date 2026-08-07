import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/rupeecase_model/algo_strategy_model.dart';
import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../routes/route_names.dart';
import '../../utils/custom_navigator.dart';
import 'strategy_card_web.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../res/res.dart';

class RupeeCaseStrategiesSection extends ConsumerStatefulWidget {
  const RupeeCaseStrategiesSection({super.key});

  @override
  ConsumerState<RupeeCaseStrategiesSection> createState() =>
      _RupeeCaseStrategiesSectionState();
}

class _RupeeCaseStrategiesSectionState
    extends ConsumerState<RupeeCaseStrategiesSection> {
  // One card per column; columns scroll horizontally.
  static const int _rowsPerColumn = 1;
  // Number of cards visible per view: the row sizes each card so exactly this
  // many fill the panel width, and scrolls horizontally to reach the rest.
  static const int _visibleCount = 4;
  // Floor for the card width so cards never get too cramped on a narrow panel;
  // there the row shows fewer than [_visibleCount] and scrolls.
  static const double _columnWidth = 240;
  static const double _columnGap = 16;

  /// Each tab shows a dashboard preview of this many strategies; the rest live
  /// on that tab's "See all" page.
  static const int _previewCount = 6;

  /// Approximate rendered height of a single [StrategyCard]. The card sizes to
  /// its content; this is used only to size the loading skeleton and the empty
  /// state so the section height stays stable while data loads.
  static const double _cardHeight = 360;

  // Tabs are commented out for now — only curated strategies are shown.
  // static const int _curatedTab = 0;
  // static const int _algoTab = 1;
  //
  // int _selectedTab = _curatedTab;

  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrowVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrowVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrowVisibility() {
    if (!mounted) return;
    bool left = false;
    bool right = false;
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      left = pos.pixels > 0.5;
      right = pos.pixels < pos.maxScrollExtent - 0.5;
    }
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(rupeeCaseProvider);

    // Algo strategies are commented out for now — show curated (RupeeCase)
    // strategies only.
    final bool anyData = provider.strategies.isNotEmpty;
    final bool anyLoading = provider.loading;

    // Nothing anywhere (not loaded) or loaded-but-empty → occupy no space.
    if (!anyData && !anyLoading) {
      return const SizedBox.shrink();
    }

    final sorted = provider.strategies.toList()
      ..sort((a, b) => b.cagr.compareTo(a.cagr));
    final preview = sorted.take(_previewCount).toList();
    final items = [
      for (int i = 0; i < preview.length; i++)
        StrategyCardData.fromRupeeCase(
          preview[i],
          accentColor:
              kStrategyAccentPalette[i % kStrategyAccentPalette.length],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, provider),
        const SizedBox(height: 6),
        _buildDescription(context),
        const SizedBox(height: 16),
        _buildContent(context, loading: provider.loading, items: items),
        const SizedBox(height: 32),
      ],
    );
  }

  /// Short intro shown under the "RupeeCase" title. Uses the app's global para
  /// sizing and the muted secondary text colour so it reads as a subtitle.
  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Text(
        'Explore professionally curated momentum strategies, each backed by 5 '
        'years of rolling historical performance. Browse the results below, '
        'then choose your next step.',
        style: MyntWebTextStyles.titlesub(
          context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }

  /// Section title ("RupeeCase") with the "See all" link pinned to the far
  /// right end of the row.
  Widget _buildHeader(BuildContext context, RupeeCaseProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'RupeeCase',
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        if (provider.strategies.isNotEmpty) _buildSeeAll(context),
      ],
    );
  }

  // ------------------------------- Tabs (commented out) ----------------------
  // Only curated strategies are shown for now. The Curated/Algo tab switcher
  // below is kept, commented out, for when algo strategies are re-enabled.
  /*
  /// Chip-style tabs matching the Positions page (a subtle fill on the selected
  /// chip, transparent otherwise), with the active tab's "See all" link pinned
  /// to the right.
  Widget _buildTabs(BuildContext context, RupeeCaseProvider provider) {
    final bool hasData = _selectedTab == _curatedTab
        ? provider.strategies.isNotEmpty
        : provider.algoStrategies.isNotEmpty;
    return Row(
      children: [
        _tab(context, label: 'Curated', index: _curatedTab),
        const SizedBox(width: 4),
        _tab(context, label: 'Algo', index: _algoTab),
        const Spacer(),
        if (hasData) _buildSeeAll(context),
      ],
    );
  }

  Widget _tab(BuildContext context,
      {required String label, required int index}) {
    final bool selected = _selectedTab == index;
    final Color selectedBg = resolveThemeColor(context,
        dark: Colors.white.withValues(alpha: 0.08),
        light: Colors.black.withValues(alpha: 0.05));
    final Color textColor = selected
        ? resolveThemeColor(context,
            dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)
        : resolveThemeColor(context,
            dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: MyntWebTextStyles.body(
              context,
              color: textColor,
              fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    // Lazy-load the algo tab the first time it is opened (the dashboard also
    // pre-fires this on mount; the provider guards against duplicate loads).
    if (index == _algoTab) {
      ref.read(rupeeCaseProvider).fetchAlgoStrategies();
    }
    // Reset the horizontal scroll so a new tab always starts at the left.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  // ----------------------------- Tab content ---------------------------------

  Widget _buildTabContent(BuildContext context, RupeeCaseProvider provider) {
    if (_selectedTab == _curatedTab) {
      final items = provider.strategies
          .take(_previewCount)
          .map(StrategyCardData.fromRupeeCase)
          .toList();
      return _buildContent(context, loading: provider.loading, items: items);
    }
    final items = provider.algoStrategies
        .take(_previewCount)
        .map(StrategyCardData.fromAlgo)
        .toList();
    return _buildContent(context, loading: provider.algoLoading, items: items);
  }
  */

  Widget _buildContent(
    BuildContext context, {
    required bool loading,
    required List<StrategyCardData> items,
  }) {
    if (items.isEmpty && loading) return _buildSkeleton(context);
    if (items.isEmpty) return _buildEmpty(context);
    return _buildScroller(context, items);
  }

  /// Splits the flat list into columns of [_rowsPerColumn] rows each.
  List<List<StrategyCardData>> _columns(List<StrategyCardData> items) {
    final out = <List<StrategyCardData>>[];
    for (int i = 0; i < items.length; i += _rowsPerColumn) {
      final int end = (i + _rowsPerColumn).clamp(0, items.length);
      out.add(items.sublist(i, end));
    }
    return out;
  }

  Widget _buildScroller(BuildContext context, List<StrategyCardData> items) {
    final columns = _columns(items);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final int total = columns.length;

        // Show up to [_visibleCount] cards per view. When there are more cards
        // than that (or the panel is too narrow), size each so exactly the
        // visible count fills the width and scroll horizontally to the rest.
        // With fewer cards than a full view, spread them evenly across the row.
        double colWidth;
        bool needsScrolling = false;
        if (!availableWidth.isFinite) {
          colWidth = _columnWidth;
        } else if (total <= _visibleCount) {
          final double totalGap = _columnGap * (total - 1);
          colWidth = (availableWidth - totalGap) / total;
          needsScrolling = false;
        } else {
          final double visibleGap = _columnGap * (_visibleCount - 1);
          final double fitted = (availableWidth - visibleGap) / _visibleCount;
          // Never shrink below the floor; a narrower panel simply shows fewer
          // than [_visibleCount] cards and scrolls.
          colWidth = fitted < _columnWidth ? _columnWidth : fitted;
          needsScrolling = true;
        }

        final double scrollAmount = colWidth + _columnGap;

        // Once this layout is on screen (and after every relayout, e.g. a
        // resize that changes whether the row overflows), re-evaluate which
        // arrows are needed. Cheap: it only calls setState when the answer
        // actually changes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (needsScrolling) {
            _updateArrowVisibility();
          } else if (_canScrollLeft || _canScrollRight) {
            setState(() {
              _canScrollLeft = false;
              _canScrollRight = false;
            });
          }
        });

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int c = 0; c < total; c++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: c < total - 1 ? _columnGap : 0),
                        child: SizedBox(
                          width: colWidth,
                          child: _column(context, columns[c]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (needsScrolling && _canScrollLeft)
              _scrollArrow(context, isLeft: true, scrollAmount: scrollAmount),
            if (needsScrolling && _canScrollRight)
              _scrollArrow(context, isLeft: false, scrollAmount: scrollAmount),
          ],
        );
      },
    );
  }

  /// Circular scroll button, matched to the Tools row's arrows. Used instead of
  /// a visible scrollbar.
  Widget _scrollArrow(
    BuildContext context, {
    required bool isLeft,
    required double scrollAmount,
  }) {
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
              onTap: () {
                if (!_scrollController.hasClients) return;
                final double target = (_scrollController.offset +
                        (isLeft ? -scrollAmount : scrollAmount))
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
                _scrollController.animateTo(
                  target,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
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

  Widget _column(BuildContext context, List<StrategyCardData> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: _columnGap),
          Expanded(child: StrategyCard(data: rows[r])),
        ],
      ],
    );
  }

  Widget _buildSeeAll(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!WebNavigationHelper.isAvailable) return;
          WebNavigationHelper.navigateTo(Routes.curatedStrategies);
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

  Widget _buildEmpty(BuildContext context) {
    final Color muted = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    return SizedBox(
      height: _cardHeight,
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
    // [_visibleCount] evenly-sized shimmer cards that fill the row width, so
    // nothing is clipped and there's no horizontal overflow while the real cards
    // load — matching the visible layout so nothing jumps when data arrives.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _visibleCount; i++) ...[
            if (i > 0) const SizedBox(width: _columnGap),
            const Expanded(child: StrategyCardSkeleton()),
          ],
        ],
      ),
    );
  }
}

/// Dashboard preview of automated strategy baskets. Uses the same scroll-arrow
/// behaviour as the curated RupeeCase section.
class AlgoStrategiesSection extends ConsumerStatefulWidget {
  const AlgoStrategiesSection({super.key, this.stackedMetrics = false});

  /// When true the strategy cards render their footer metrics as a 2×2 grid
  /// (DD / WIN RATE beneath MIN. CAP / CAGR) instead of a single row.
  final bool stackedMetrics;

  @override
  ConsumerState<AlgoStrategiesSection> createState() =>
      _AlgoStrategiesSectionState();
}

class _AlgoStrategiesSectionState
    extends ConsumerState<AlgoStrategiesSection> {
  static const int _previewCount = 10;
  static const double _columnGap = 16;

  /// Width of each algo strategy card. The row scrolls horizontally once these
  /// fixed-width cards overflow.
  static const double _cardWidth = 320;

  /// The leading "Algo Trading" promo banner keeps its original (narrower) width
  /// so it stays compact; only the strategy cards were widened.
  static const double _bannerWidth = 280;

  /// The stacked-metrics copy uses a narrower card — its 2×2 grid needs less
  /// horizontal room than the default four-in-a-row layout.
  static const double _stackedCardWidth = 200;

  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrowVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrowVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrowVisibility() {
    if (!mounted) return;
    bool left = false;
    bool right = false;
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      left = pos.pixels > 0.5;
      right = pos.pixels < pos.maxScrollExtent - 0.5;
    }
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(rupeeCaseProvider);
    final strategies = provider.algoStrategies.toList()
      ..sort((a, b) => b.subscriberCount.compareTo(a.subscriberCount));

    if (strategies.isEmpty && !provider.algoLoading) {
      return const SizedBox.shrink();
    }

    final preview = strategies.take(_previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, hasData: strategies.isNotEmpty),
        const SizedBox(height: 6),
        _buildDescription(context),
        const SizedBox(height: 16),
        if (preview.isEmpty)
          _buildSkeleton(context)
        else
          _buildScroller(context, preview),
      ],
    );
  }

  /// Section title ("Zebu Algo Strategies") with the "See all" link pinned to
  /// the far right — matching the RupeeCase section header.
  Widget _buildHeader(BuildContext context, {required bool hasData}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Zebu Algo Strategies',
          style: MyntWebTextStyles.head(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
            fontWeight: MyntFonts.bold,
          ),
        ),
        if (hasData) _buildSeeAll(context),
      ],
    );
  }

  /// Short intro under the title, styled like the RupeeCase subtitle.
  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Text(
        'Deploy ready-made automated strategies, each back-tested over years of '
        'market history. Explore the baskets below, then start on Zebu Algo.',
        style: MyntWebTextStyles.titlesub(
          context,
          darkColor: MyntColors.textSecondaryDark,
          lightColor: MyntColors.textSecondary,
        ),
      ),
    );
  }

  /// "See all" link opening the full Zebu Algo strategies page.
  Widget _buildSeeAll(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!WebNavigationHelper.isAvailable) return;
          WebNavigationHelper.navigateTo(Routes.algoStrategies);
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

  // ----------------------------- scroller with arrows -------------------------

  /// Loading placeholder: the static banner, then as many shimmer skeleton
  /// cards as fill the visible width — mirroring the real scroller so the
  /// layout doesn't jump when the strategies arrive.
  Widget _buildSkeleton(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        // Enough fixed-width cards (after the leading banner) to cover the row;
        // one extra so the shimmer runs to the edge like the overflowing real
        // content. Falls back to 2 when the width is unbounded.
        final double cardW =
            widget.stackedMetrics ? _stackedCardWidth : _cardWidth;
        final double cellSpan = cardW + _columnGap;
        int cards = 2;
        if (availableWidth.isFinite) {
          final int fit = ((availableWidth + _columnGap) / cellSpan).ceil();
          cards = (fit - 1).clamp(2, 8);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _bannerWidth,
                child: _buildAlgoTradingBannerCard(context),
              ),
              for (int i = 0; i < cards; i++) ...[
                const SizedBox(width: _columnGap),
                SizedBox(
                    width: cardW, child: const AlgoStrategyCardSkeleton()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildScroller(BuildContext context, List<AlgoStrategy> strategies) {
    final int total = strategies.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        // The leading banner is [_bannerWidth] wide; each strategy card is
        // [cardW] wide (narrower for the stacked-metrics copy). The row scrolls
        // horizontally once these fixed-width cells overflow.
        final double cardW =
            widget.stackedMetrics ? _stackedCardWidth : _cardWidth;
        final double rowWidth =
            _bannerWidth + (total * cardW) + (total * _columnGap);
        final bool needsScrolling =
            availableWidth.isFinite && rowWidth > availableWidth + 0.5;

        final double scrollAmount = cardW + _columnGap;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (needsScrolling) {
            _updateArrowVisibility();
          } else if (_canScrollLeft || _canScrollRight) {
            setState(() {
              _canScrollLeft = false;
              _canScrollRight = false;
            });
          }
        });

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: _columnGap),
                      // Leading cell = the "Algo Trading" promo banner, kept at
                      // its original (narrower) width and filling the full
                      // (uniform) card height set by the Row's stretch
                      // alignment. Tapping it opens the Zebu Algo site.
                      child: SizedBox(
                        width: _bannerWidth,
                        child: _buildAlgoTradingBannerCard(context),
                      ),
                    ),
                    for (int i = 0; i < total; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i < total - 1 ? _columnGap : 0),
                        child: SizedBox(
                          width: cardW,
                          child: AlgoStrategyCard(
                            strategy: strategies[i],
                            accentColor: kAlgoStrategyAccentPalette[
                                i % kAlgoStrategyAccentPalette.length],
                            stackedMetrics: widget.stackedMetrics,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (needsScrolling && _canScrollLeft)
              _scrollArrow(context,
                  isLeft: true, scrollAmount: scrollAmount),
            if (needsScrolling && _canScrollRight)
              _scrollArrow(context,
                  isLeft: false, scrollAmount: scrollAmount),
          ],
        );
      },
    );
  }

  Widget _buildAlgoTradingBannerCard(BuildContext context) {
    const Color accent = Color(0xFF4A1F8E);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final Uri algoUri = Uri.parse('https://algo.zebuetrade.com/');
          if (await canLaunchUrl(algoUri)) {
            await launchUrl(
              algoUri,
              mode: LaunchMode.externalApplication,
            );
          }
        },
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
                color: accent.withValues(alpha: 0.28),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stacked rotated icon
                    SizedBox(
                      width: 44,
                      height: 34,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 6,
                            child: Transform.rotate(
                              angle: -0.18,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.22),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 5,
                            top: 3,
                            child: Transform.rotate(
                              angle: -0.09,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.45),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            top: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(
                                        alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  assets.boltIcon,
                                  width: 16,
                                  height: 16,
                                  colorFilter: const ColorFilter.mode(
                                    accent,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  /// Circular scroll button — same style as the RupeeCase section arrows.
  Widget _scrollArrow(
    BuildContext context, {
    required bool isLeft,
    required double scrollAmount,
  }) {
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
              onTap: () {
                if (!_scrollController.hasClients) return;
                final double target = (_scrollController.offset +
                        (isLeft ? -scrollAmount : scrollAmount))
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
                _scrollController.animateTo(
                  target,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
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
                ),
                child: Center(
                  child: Icon(
                    isLeft
                        ? Icons.arrow_back_ios
                        : Icons.arrow_forward_ios,
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
}



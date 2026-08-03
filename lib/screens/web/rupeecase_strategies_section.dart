import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/rupeecase_provider.dart';
import '../../res/mynt_web_color_styles.dart';
import '../../res/mynt_web_text_styles.dart';
import '../../routes/route_names.dart';
import '../../utils/custom_navigator.dart';
import 'strategy_card_web.dart';

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
  static const double _columnWidth = 440;
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
        final double totalGap = _columnGap * (total - 1);
        final double totalMinWidth = (_columnWidth * total) + totalGap;

        // Same rule as the Tools row: fill the width evenly when every column
        // fits, otherwise pin to the min width and enable arrow scrolling.
        double colWidth;
        bool needsScrolling = false;
        if (availableWidth.isFinite && availableWidth >= totalMinWidth) {
          colWidth = (availableWidth - totalGap) / total;
        } else {
          colWidth = _columnWidth;
          needsScrolling = availableWidth.isFinite;
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
    final Color accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
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
            // Icon(Icons.chevron_right_rounded, size: 18, color: accent),
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
    final Color cardColor = resolveThemeColor(context,
        dark: MyntColors.dashboardCarColor, light: const Color(0xFFF8F9FB));

    Widget placeholder() => Container(
          width: _columnWidth,
          height: _cardHeight,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(right: _columnGap),
            child: placeholder(),
          ),
      ],
    );
  }
}

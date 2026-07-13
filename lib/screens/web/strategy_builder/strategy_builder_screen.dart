import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/models/marketwatch_model/opt_chain_model.dart';
import 'package:mynt_plus/provider/strategy_builder_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:mynt_plus/sharedWidget/hover_actions_web.dart';
import 'package:mynt_plus/screens/web/strategy_builder/entry_price_input.dart';
import 'package:mynt_plus/screens/web/strategy_builder/strategy_builder_widgets.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';


/// Lightweight tooltip state to avoid full widget rebuilds on hover
class _PayoffTooltipState {
  final double? selectedPrice;
  final bool showTooltip;
  final Offset position;

  const _PayoffTooltipState({
    this.selectedPrice,
    this.showTooltip = false,
    this.position = const Offset(10, 10),
  });
}

/// Strategy Builder Screen - Full screen strategy builder with payoff analysis
/// Renders a metric label, optionally followed by a tappable info (i) icon.
/// Used to attach the Margin Info dialog to the MARGIN label only.
Widget _labelWithInfo(
    BuildContext context, Widget label, VoidCallback? onInfoTap) {
  if (onInfoTap == null) return label;
  return Row(
    children: [
      Flexible(child: label),
      const SizedBox(width: 3),
      InkWell(
        onTap: onInfoTap,
        borderRadius: BorderRadius.circular(10),
        child: Icon(Icons.info_outline, size: 16, color:  resolveThemeColor(
                                                context,
                                                dark:
                                                    MyntColors.textPrimaryDark,
                                                light: MyntColors.textPrimary,
                                              ),),
      ),
    ],
  );
}

/// Margin Info dialog — shows the SPAN-based margin breakdown for the current
/// basket: each leg's own margin, their total, the combined margin, and the
/// benefit (total - combined). Opened from the info icon next to the MARGIN
/// label. (UI only)
void showMarginInfoDialog(BuildContext context, bool isDark) {
  final provider = ProviderScope.containerOf(context, listen: false)
      .read(strategyBuilderProvider);
  // Fire the SpanCalc calculation; the dialog watches the provider for results.
  provider.calculateMarginBenefit();

  final titleColor = isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack;
  final bodyColor =
      isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary;
  final profitColor = isDark ? MyntColors.profitDark : MyntColors.profit;

  String money(double d) => d.toIndianRupee();

  Widget valueRow(String label, String value,
          {Color? valueColor, bool strong = false, bool indent = false}) =>
      Padding(
        padding: EdgeInsets.fromLTRB( 0, 5, 0, 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                style: MyntWebTextStyles.para(context,
                    color: strong ? titleColor : bodyColor,
                    fontWeight: strong ? MyntFonts.semiBold : MyntFonts.medium),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: MyntWebTextStyles.body(context,
                  color: valueColor ?? titleColor,
                  fontWeight: MyntFonts.semiBold),
            ),
          ],
        ),
      );

  final Widget content = Consumer(
    builder: (context, ref, _) {
      final p = ref.watch(strategyBuilderProvider);

      if (p.isCalcMarginBenefit) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      }

      if (p.marginBenefitError != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            p.marginBenefitError!,
            style: MyntWebTextStyles.para(context, color: bodyColor),
          ),
        );
      }

      final r = p.marginBenefitResult;
      if (r == null) return const SizedBox.shrink();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          for (final leg in r.legs)
            valueRow(leg.name, money(leg.margin), indent: true),
          const Divider(height: 10),
          valueRow('Total', money(r.sumIndividual), strong: true),
          const Divider(height: 10),
          valueRow('As a single strategy', money(r.combined), strong: false),
          // const SizedBox(height: 10),
          valueRow('Margin benefit', money(r.benefit),
              strong: false, valueColor: profitColor),
        ],
      );
    },
  );

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: Container(
            width: 400,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.dialogDark, light: MyntColors.dialog),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: shadcn.Theme.of(context).colorScheme.border,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Margin Info',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      MyntCloseButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class StrategyBuilderScreenWeb extends ConsumerStatefulWidget {
  const StrategyBuilderScreenWeb({super.key});

  @override
  ConsumerState<StrategyBuilderScreenWeb> createState() => _StrategyBuilderScreenWebState();
}

class _StrategyBuilderScreenWebState extends ConsumerState<StrategyBuilderScreenWeb>
    with SingleTickerProviderStateMixin {
  late TabController _strategyTabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _lotMultiplierController = TextEditingController(text: '1');
  final TextEditingController _targetPriceController = TextEditingController();
  double _lastEmittedTargetPrice = 0;
  String _lastSelectedSymbol = '';
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();

  // Payoff chart tooltip state — uses ValueNotifier to avoid full widget rebuild on hover
  final ValueNotifier<_PayoffTooltipState> _tooltipNotifier = ValueNotifier(const _PayoffTooltipState());
  bool _isDragging = false;
  int _tooltipUpdateCounter = 0;
  // Keep _selectedPrice accessible for chart marker dot rendering
  double? _selectedPrice;
  bool _markerUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _strategyTabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(strategyBuilderProvider);
      // Skip initialization in analyze mode (data already loaded from positions)
      if (!provider.isAnalyzeMode) {
        provider.initialize(context);
      }
      // Initialize search controller with selected symbol
      _searchController.text = provider.selectedSymbol;
      _lastSelectedSymbol = provider.selectedSymbol;
    });

    _strategyTabController.addListener(() {
      final tabs = ['Bullish', 'Bearish', 'Neutral', 'CustomBuilder'];
      ref.read(strategyBuilderProvider).setStrategyTypeTab(tabs[_strategyTabController.index]);
    });

    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        ref.read(strategyBuilderProvider).searchStocks('');
      }
    });
  }

  @override
  void dispose() {
    _strategyTabController.dispose();
    _searchController.dispose();
    _lotMultiplierController.dispose();
    _targetPriceController.dispose();
    _tooltipNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(strategyBuilderProvider);
    final theme = ref.watch(themeProvider);
    final isDark = theme.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;

    // Sync search controller with selected symbol when it changes
    if (provider.selectedSymbol != _lastSelectedSymbol && provider.searchResults.isEmpty) {
      _lastSelectedSymbol = provider.selectedSymbol;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.text = provider.selectedSymbol;
        }
      });
    }

    // Auto-show option chain dialog when flag is set (dialog will show loader inside)
    if (provider.shouldShowOptionChain) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.shouldShowOptionChain) {
          provider.clearShouldShowOptionChain();
          _showOptionChainDialog(context, provider, isDark);
        }
      });
    }

    // Check if small screen (tablet/mobile)
    final isSmallScreen = screenWidth < 900;

    return Scaffold(
      backgroundColor: isDark ? MyntColors.backgroundColorDark : MyntColors.backgroundColor,
      appBar: _buildAppBar(context, provider, isDark),
      body: Stack(
        children: [
          isSmallScreen
              ? _buildSmallScreenLayout(context, provider, isDark, screenWidth)
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth < 1366 ? 20 : 40,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Panel - Basket & Strategies
                      Expanded(
                        flex: 1,
                        child: _buildLeftPanel(context, provider, isDark),
                      ),
                      const SizedBox(width: 16),
                      // Right Panel - Metrics & Chart
                      Expanded(
                        flex: 1,
                        child: _buildRightPanel(context, provider, isDark),
                      ),
                    ],
                  ),
                ),
          // Search dropdown: barrier + overlay
          if (provider.searchDropdownVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => provider.dismissSearchDropdown(),
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          _buildSearchDropdownOverlay(context, provider, isDark),
          // Loading overlay (only show when not showing option chain dialog)
          if (provider.isLoading && !provider.shouldShowOptionChain)
            Positioned.fill(
              child: Container(
                color: (isDark ? MyntColors.backgroundColorDark : MyntColors.backgroundColor).withOpacity(0.7),
                child: const Center(child: MyntLoader(size: MyntLoaderSize.medium)),
              ),
            ),
        ],
      ),
    );
  }

  /// Build layout for small screens (single column scrollable)
  Widget _buildSmallScreenLayout(BuildContext context, StrategyBuilderProvider provider, bool isDark, double screenWidth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basket Card with search and table
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.searchBgDark : MyntColors.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? MyntColors.dividerDark : MyntColors.divider,
              ),
            ),
            child: Column(
              children: [
                // Search bar (hidden in analyze mode) or analyze header
                if (provider.isAnalyzeMode)
                  _buildAnalyzeHeader(context, provider, isDark)
                else
                  _buildSearchSection(context, provider, isDark),
                const Divider(height: 1),
                // Basket table (limited height)
                SizedBox(
                  height: provider.basket.isEmpty ? 100 : (provider.basket.length * 50.0 + 50).clamp(100, 250),
                  child: Stack(
                    children: [
                      _buildBasketTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.basket.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lot multiplier and action buttons (hidden in analyze mode)
                if (provider.basket.isNotEmpty && !provider.isAnalyzeMode)
                  _buildBottomActions(context, provider, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Metrics section (compact for small screens)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: _buildMetricsSectionSmall(context, provider, isDark),
          ),
          const SizedBox(height: 12),
          // Payoff Chart section
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: Column(
              children: [
                // Tabs
                _buildPayoffTabs(context, provider, isDark),
                const Divider(height: 1),
                // Chart or Greeks table (fixed height for small screen)
                SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      provider.payoffTab == 0
                          ? _buildPayoffChart(context, provider, isDark)
                          : _buildGreeksTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.payoffData.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Strategies Card (hidden in analyze mode)
          if (!provider.isAnalyzeMode) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? MyntColors.searchBgDark : MyntColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? MyntColors.dividerDark : MyntColors.divider,
                ),
              ),
              child: Column(
                children: [
                  // Strategy tabs
                  TabBar(
                    controller: _strategyTabController,
                    labelColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    unselectedLabelColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                    indicatorColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    labelStyle: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.medium,
                    ),
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Bullish'),
                      Tab(text: 'Bearish'),
                      Tab(text: 'Neutral'),
                      Tab(text: 'Custom Builder'),
                    ],
                  ),
                  const Divider(height: 1),
                  // Strategy grid
                  if (provider.strategyTypeTab == 'CustomBuilder')
                    _buildStrategyGrid(context, provider, isDark)
                  else
                    SizedBox(
                      height: 200,
                      child: _buildStrategyGrid(context, provider, isDark),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Chart controls
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: _buildChartControls(context, provider, isDark),
          ),
          const SizedBox(height: 80), // Bottom padding for safe area
        ],
      ),
    );
  }

  /// Build compact metrics section for small screens
  Widget _buildMetricsSectionSmall(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // First row: MAX PROFIT, MAX LOSS
          Row(
            children: [
              _buildMetricItemSmall(context, 'MAX PROFIT', provider.metrics.maxProfit, MyntColors.profit, isDark),
              const SizedBox(width: 12),
              _buildMetricItemSmall(context, 'MAX LOSS', provider.metrics.maxLoss, isDark ? MyntColors.lossDark : MyntColors.loss, isDark),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: NET PREMIUM, MARGIN
          Row(
            children: [
              _buildMetricItemSmall(
                context,
                'NET PREMIUM',
                provider.netPremium.abs().toIndianFormat(),
                provider.netPremium > 0
                    ? (isDark ? MyntColors.profitDark : MyntColors.profit)
                    : provider.netPremium < 0
                        ? (isDark ? MyntColors.errorDark : MyntColors.loss)
                        : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                isDark,
              ),
              const SizedBox(width: 12),
              _buildMetricItemSmall(context, 'MARGIN', provider.totalMargin, null, isDark),
              // MARGIN BENEFIT hidden
              // const SizedBox(width: 12),
              // _buildMetricItemSmall(
              //   context,
              //   'MARGIN BENEFIT',
              //   provider.marginBenefit,
              //   isDark ? MyntColors.profitDark : MyntColors.profit,
              //   isDark,
              // ),
            ],
          ),
          const SizedBox(height: 8),
          // Third row: POP, REWARD/RISK
          Row(
            children: [
              _buildMetricItemSmall(context, 'POP', '${provider.metrics.popPercent.toStringAsFixed(0)}%', null, isDark),
              const SizedBox(width: 12),
              _buildMetricItemSmall(context, 'REWARD/RISK', provider.metrics.riskRewardRatio, null, isDark),
            ],
          ),
          const SizedBox(height: 8),
          // Fourth row: BREAKEVEN (full width)
          _buildMetricItemSmall(
            context,
            'BREAKEVEN',
            '--',
            null,
            isDark,
            fullWidth: true,
            valueWidget: provider.metrics.breakevens.isNotEmpty
                ? _buildBreakevenRichText(provider, MyntWebTextStyles.bodySmall(
                    context,
                    color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                    fontWeight: MyntFonts.semiBold,
                  ))
                : null,
          ),
          const SizedBox(height: 8),
          // Fifth row: Greeks
          Row(
            children: [
              _buildMetricItemSmall(context, '\u0394 DELTA', provider.greeksTotal('delta').toStringAsFixed(4), null, isDark),
              const SizedBox(width: 12),
              _buildMetricItemSmall(context, '\u0398 THETA', provider.greeksTotal('theta').toStringAsFixed(4), null, isDark),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricItemSmall(context, '\u0393 GAMMA', provider.greeksTotal('gamma').toStringAsFixed(4), null, isDark),
              const SizedBox(width: 12),
              _buildMetricItemSmall(context, '\u03BD VEGA', provider.greeksTotal('vega').toStringAsFixed(4), null, isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// Build compact metric item for small screens
  Widget _buildMetricItemSmall(BuildContext context, String label, String value, Color? valueColor, bool isDark, {bool fullWidth = false, Widget? valueWidget}) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithInfo(
            context,
            Text(
              label,
              style: MyntWebTextStyles.caption(
                context,
                color: Colors.grey,
                fontWeight: MyntFonts.medium,
              ),
            ),
            (label == 'MARGIN' &&
                    ref.read(strategyBuilderProvider).basketMarginModel != null)
                ? () => showMarginInfoDialog(context, isDark)
                : null,
          ),
          const SizedBox(height: 2),
          valueWidget ?? Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: valueColor ?? (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ],
      ),
    );

    return fullWidth ? content : Expanded(child: content);
  }

  Widget _buildBreakevenRichText(StrategyBuilderProvider provider, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final breakevens = provider.metrics.breakevens;
    for (int i = 0; i < breakevens.length; i++) {
      final b = breakevens[i];
      final pct = provider.spotPrice > 0 ? ((b - provider.spotPrice) / provider.spotPrice) * 100 : 0.0;
      if (i > 0) spans.add(TextSpan(text: '  |  ', style: baseStyle));
      spans.add(TextSpan(text: b.toIndianFormat(), style: baseStyle));
      spans.add(TextSpan(
        text: ' (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
        style: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) - 3, color: Colors.grey),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? MyntColors.searchBgDark : MyntColors.backgroundColor,
      elevation: 1,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              'Strategy Builder',
              overflow: TextOverflow.ellipsis,
              style: MyntWebTextStyles.title(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textBlack,
                fontWeight: MyntFonts.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Symbol selector
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? MyntColors.dividerDark : MyntColors.listItemBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      provider.selectedSymbol,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textBlack,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '₹${provider.spotPrice.toIndianFormat()}',
                    style: MyntWebTextStyles.body(
                      context,
                      color: MyntColors.profit,
                      fontWeight: MyntFonts.semiBold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Expiry selector
        if (provider.expiryDates.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? MyntColors.dividerDark : MyntColors.listItemBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedExpiry.isEmpty ? null : provider.selectedExpiry,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? MyntColors.iconDark : MyntColors.textSecondary,
                ),
                dropdownColor: isDark ? MyntColors.dividerDark : MyntColors.backgroundColor,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textBlack,
                ),
                items: provider.expiryDates
                    .map((expiry) => DropdownMenuItem(
                          value: expiry,
                          child: Text(expiry),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    // Handle expiry change
                  }
                },
              ),
            ),
          ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildLeftPanel(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Column(
      children: [
        // Basket Card
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.searchBgDark : MyntColors.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? MyntColors.dividerDark : MyntColors.divider,
              ),
            ),
            child: Column(
              children: [
                // Search bar (hidden in analyze mode) or analyze header
                if (provider.isAnalyzeMode)
                  _buildAnalyzeHeader(context, provider, isDark)
                else
                  _buildSearchSection(context, provider, isDark),
                const Divider(height: 1),
                // Basket table
                Expanded(
                  child: Stack(
                    children: [
                      _buildBasketTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.basket.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lot multiplier and action buttons (hidden in analyze mode)
                if (provider.basket.isNotEmpty && !provider.isAnalyzeMode)
                  _buildBottomActions(context, provider, isDark),
              ],
            ),
          ),
        ),
        // Strategies Card (hidden in analyze mode)
        if (!provider.isAnalyzeMode) ...[
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? MyntColors.searchBgDark : MyntColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? MyntColors.dividerDark : MyntColors.divider,
                ),
              ),
              child: Column(
                children: [
                  // Strategy tabs
                  TabBar(
                    controller: _strategyTabController,
                    labelColor: MyntColors.primary,
                    unselectedLabelColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                    indicatorColor: MyntColors.primary,
                    labelStyle: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.medium,
                    ),
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Bullish'),
                      Tab(text: 'Bearish'),
                      Tab(text: 'Neutral'),
                      Tab(text: 'Custom Builder'),
                    ],
                  ),
                  const Divider(height: 1),
                  // Strategy grid
                  Expanded(
                    child: _buildStrategyGrid(context, provider, isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeHeader(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategyAnalyzeHeader(context: context, provider: provider, isDark: isDark);
  }

  Widget _buildSearchSection(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategySearchSection(
      context: context,
      searchController: _searchController,
      provider: provider,
      isDark: isDark,
      placeholder: 'Search symbol (e.g., NIFTY, BANKNIFTY)',
      chainButtonLabel: 'Add',
      buttonHeight: 36,
      showClearButton: true,
      onChainPressed: provider.optionChain.isNotEmpty
          ? () => _showOptionChainDialog(context, provider, isDark)
          : null,
      onRefreshPressed: () => provider.refreshEntryPrices(context),
      onClearBasket: () => provider.clearBasket(),
      onSearchChanged: (value) => provider.searchStocks(value),
      onClearSearch: () {
        _searchController.clear();
        provider.searchStocks('');
      },
      searchLayerLink: _searchLayerLink,
      searchFieldKey: _searchFieldKey,
    );
  }

  Widget _buildSearchDropdownOverlay(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategySearchDropdown(
      context: context,
      provider: provider,
      isDark: isDark,
      searchController: _searchController,
      onStockSelected: (result) => provider.selectStock(result, context),
      onLastSelectedSymbolChanged: (name) => _lastSelectedSymbol = name,
      searchLayerLink: _searchLayerLink,
      searchFieldKey: _searchFieldKey,
      onDismiss: () => provider.dismissSearchDropdown(),
    );
  }

  void _showOptionChainDialog(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final watchedProvider = ref.watch(strategyBuilderProvider);
          return Dialog(
            backgroundColor: isDark ? MyntColors.searchBgDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: MediaQuery.of(context).size.width < 460
                  ? MediaQuery.of(context).size.width * 0.95
                  : 420,
              height: 620,
              child: Column(
                children: [
                  // Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Symbol Name
                        Flexible(
                          child: Text(
                            watchedProvider.selectedSymbol,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: MyntWebTextStyles.body(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textBlack,
                            fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Spot Price
                        if (watchedProvider.spotPrice > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MyntColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              watchedProvider.spotPrice.toIndianFormat(),
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                color: MyntColors.primary,
                                fontWeight: MyntFonts.semiBold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),

                        // Expiry Dropdown with days to expiry
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: watchedProvider.selectedExpiry.isEmpty || !watchedProvider.expiryDates.contains(watchedProvider.selectedExpiry) ? null : watchedProvider.selectedExpiry,
                              hint: Text(watchedProvider.selectedExpiry.isNotEmpty ? watchedProvider.selectedExpiry : 'Expiry'),
                              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textBlack,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: isDark ? Colors.grey : Colors.black54,
                              ),
                              items: watchedProvider.expiryDates.map((expiry) {
                                final daysText = watchedProvider.selectedExpiry == expiry
                                    ? ' ${watchedProvider.daysToExpiry}(D)'
                                    : '';
                                return DropdownMenuItem(
                                  value: expiry,
                                  child: Text('$expiry$daysText'),
                                );
                              }).toList(),
                              onChanged: watchedProvider.isLoading ? null : (value) {
                                if (value != null) {
                                  watchedProvider.setSelectedExpiry(value, context);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Strike Count Dropdown
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: watchedProvider.selectedStrikeCount,
                              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textBlack,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: isDark ? Colors.grey : Colors.black54,
                              ),
                              items: [10, 15, 20, 25].map((count) =>
                                DropdownMenuItem(
                                  value: count,
                                  child: Text('$count Strike'),
                                )
                              ).toList(),
                              onChanged: watchedProvider.isLoading ? null : (value) {
                                if (value != null) {
                                  watchedProvider.setStrikeCount(value, context);
                                }
                              },
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Close Button
                        InkWell(
                          onTap: () => Navigator.pop(dialogContext),
                          child: Icon(
                            Icons.close,
                            color: isDark ? Colors.grey : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),

                  // Column Headers - Call and Put
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Call section header
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '<',
                                style: TextStyle(
                                  color: MyntColors.profit,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '>',
                                style: TextStyle(
                                  color: MyntColors.profit,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Call',
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: MyntColors.profit,
                                  fontWeight: MyntFonts.semiBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer for strike column
                        const SizedBox(width: 80),
                        // Put section header
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '<',
                                style: TextStyle(
                                  color: MyntColors.loss,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '>',
                                style: TextStyle(
                                  color: MyntColors.loss,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Put',
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: MyntColors.loss,
                                  fontWeight: MyntFonts.semiBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Headers
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Call OI(ch)
                        Expanded(
                          child: Text(
                            'OI(ch)',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context, color: Colors.grey),
                          ),
                        ),
                        // Call LTP
                        Expanded(
                          child: Text(
                            'LTP',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context, color: Colors.grey),
                          ),
                        ),
                        // STRIKES
                        SizedBox(
                          width: 80,
                          child: Text(
                            'STRIKES',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context, color: Colors.grey, fontWeight: MyntFonts.bold),
                          ),
                        ),
                        // Put LTP
                        Expanded(
                          child: Text(
                            'LTP',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context, color: Colors.grey),
                          ),
                        ),
                        // Put OI(ch)
                        Expanded(
                          child: Text(
                            'OI(ch)',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.caption(context, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Option chain table or loader
                  Expanded(
                    child: watchedProvider.isLoading
                        ? const Center(child: MyntLoader(size: MyntLoaderSize.medium))
                        : _buildOptionChainTable(context, watchedProvider, isDark),
                  ),

                  // Footer with OI totals and PCR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _calculateTotalOI(watchedProvider, 'CE'),
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textBlack,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                        Text(
                          'PCR: ${_calculatePCR(watchedProvider)}',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: Colors.grey,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                        Text(
                          _calculateTotalOI(watchedProvider, 'PE'),
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textBlack,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _calculateTotalOI(StrategyBuilderProvider provider, String optt) {
    double total = 0;
    for (var option in provider.optionChain) {
      if (option.optt == optt) {
        total += double.tryParse(option.oi ?? '0') ?? 0;
      }
    }
    // Convert to readable format (in lakhs)
    if (total >= 100000) {
      return (total / 100000).toIndianFormat();
    }
    return total.toIndianFormat();
  }

  String _calculatePCR(StrategyBuilderProvider provider) {
    double ceOI = 0;
    double peOI = 0;
    for (var option in provider.optionChain) {
      if (option.optt == 'CE') {
        ceOI += double.tryParse(option.oi ?? '0') ?? 0;
      } else if (option.optt == 'PE') {
        peOI += double.tryParse(option.oi ?? '0') ?? 0;
      }
    }
    if (ceOI == 0) return '0.00';
    return (peOI / ceOI).toStringAsFixed(2);
  }

  Widget _buildOptionChainTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.optionChain.isEmpty) {
      return const Center(child: Text('No option chain data available'));
    }

    // Group by strike price
    final Map<String, Map<String, dynamic>> strikeData = {};
    for (var option in provider.optionChain) {
      final strike = option.strprc ?? '';
      if (strike.isEmpty) continue;

      strikeData.putIfAbsent(strike, () => {'CE': null, 'PE': null});
      strikeData[strike]![option.optt ?? ''] = option;
    }

    final sortedStrikes = strikeData.keys.toList()
      ..sort((a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));

    // Find ATM index (closest to spot price)
    String? atmStrike;
    int atmIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < sortedStrikes.length; i++) {
      final diff = ((double.tryParse(sortedStrikes[i]) ?? 0) - provider.spotPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmStrike = sortedStrikes[i];
        atmIndex = i;
      }
    }

    // Limit strikes above and below spot based on selected strike count
    final int strikeRange = provider.selectedStrikeCount;
    final int startIndex = (atmIndex - strikeRange).clamp(0, sortedStrikes.length);
    final int endIndex = (atmIndex + strikeRange).clamp(0, sortedStrikes.length);
    final limitedStrikes = sortedStrikes.sublist(startIndex, endIndex);

    // Build the list with spot price row inserted
    final List<Widget> rows = [];
    bool spotInserted = false;

    for (int i = 0; i < limitedStrikes.length; i++) {
      final strike = limitedStrikes[i];
      final strikePrice = double.tryParse(strike) ?? 0;
      final ceOption = strikeData[strike]!['CE'];
      final peOption = strikeData[strike]!['PE'];

      // Determine if ITM
      final isCEITM = strikePrice < provider.spotPrice;
      final isPEITM = strikePrice > provider.spotPrice;

      // Insert spot price row before first strike >= spot
      if (!spotInserted && strikePrice >= provider.spotPrice) {
        rows.add(_buildSpotPriceRow(context, provider, isDark));
        spotInserted = true;
      }

      rows.add(_buildOptionRow(
        context,
        provider,
        isDark,
        strike,
        ceOption,
        peOption,
        isCEITM,
        isPEITM,
        strike == atmStrike,
      ));
    }

    // If spot price is higher than all strikes, insert at end
    if (!spotInserted) {
      rows.add(_buildSpotPriceRow(context, provider, isDark));
    }

    return ListView(
      children: rows,
    );
  }

  Widget _buildSpotPriceRow(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final pct = provider.spotPriceChangePercent;
    final isPositive = pct >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF333333) : const Color(0xFF424242),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${provider.spotPrice.toIndianFormat()} (${isPositive ? '' : ''}${pct.toStringAsFixed(2)}%)',
            style: MyntWebTextStyles.bodySmall(
              context,
              color: Colors.white,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(
    BuildContext context,
    StrategyBuilderProvider provider,
    bool isDark,
    String strike,
    dynamic ceOption,
    dynamic peOption,
    bool isCEITM,
    bool isPEITM,
    bool isATM,
  ) {
    // Parse OI and OI change
    final ceOI = double.tryParse(ceOption?.oi ?? '0') ?? 0;
    final ceOIChange = double.tryParse(ceOption?.poi ?? '0') ?? 0;
    final peOI = double.tryParse(peOption?.oi ?? '0') ?? 0;
    final peOIChange = double.tryParse(peOption?.poi ?? '0') ?? 0;

    // Check if CE/PE at this strike is in the basket
    final ceToken = ceOption?.token ?? '';
    final peToken = peOption?.token ?? '';
    final ceInBasket = ceToken.isNotEmpty
        ? provider.basket.where((b) => b.token == ceToken).firstOrNull
        : null;
    final peInBasket = peToken.isNotEmpty
        ? provider.basket.where((b) => b.token == peToken).firstOrNull
        : null;

    // Basket highlight colors
    Color? ceBasketBg;
    Color? ceBasketBorder;
    if (ceInBasket != null) {
      final isBuy = ceInBasket.buySell == 'BUY';
      ceBasketBg = isBuy
          ? (isDark ? const Color(0xFF0D2818) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFF2D1215) : const Color(0xFFFCE4EC));
      ceBasketBorder = isBuy ? MyntColors.profit : MyntColors.loss;
    }

    Color? peBasketBg;
    Color? peBasketBorder;
    if (peInBasket != null) {
      final isBuy = peInBasket.buySell == 'BUY';
      peBasketBg = isBuy
          ? (isDark ? const Color(0xFF0D2818) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFF2D1215) : const Color(0xFFFCE4EC));
      peBasketBorder = isBuy ? MyntColors.profit : MyntColors.loss;
    }

    // Format OI display
    String formatOI(double oi, double change) {
      final oiStr = oi > 0 ? oi.toIndianFormat() : '--';
      final changeStr = change != 0 ? '(${change >= 0 ? '' : ''}${change.toIndianFormat()})' : '';
      return '$oiStr$changeStr';
    }

    return InkWell(
      onTap: () {
        // Show action menu for selecting Buy/Sell CE/PE
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Call OI(ch) - with ITM background
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: ceBasketBg ?? (isCEITM ? (isDark ? const Color(0xFF3D1F1F) : const Color(0xFFFFEBEE)) : null),
                ),
                child: InkWell(
                  onTap: ceOption != null ? () {
                    if (ceInBasket != null) {
                      final idx = provider.basket.indexOf(ceInBasket);
                      if (idx != -1) provider.removeFromBasket(idx, context);
                    } else {
                      _showBuySellMenu(context, provider, ceOption, isDark);
                    }
                  } : null,
                  child: Text(
                    formatOI(ceOI, ceOIChange),
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.caption(
                      context,
                      color: ceOIChange >= 0 ? MyntColors.profit : MyntColors.loss,
                    ),
                  ),
                ),
              ),
            ),
            // Call LTP - with ITM background
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: ceBasketBg ?? (isCEITM ? (isDark ? const Color(0xFF3D1F1F) : const Color(0xFFFFEBEE)) : null),
                  border: ceBasketBorder != null
                      ? Border(right: BorderSide(color: ceBasketBorder, width: 3))
                      : null,
                ),
                child: InkWell(
                  onTap: ceOption != null ? () {
                    if (ceInBasket != null) {
                      final idx = provider.basket.indexOf(ceInBasket);
                      if (idx != -1) provider.removeFromBasket(idx, context);
                    } else {
                      _showBuySellMenu(context, provider, ceOption, isDark);
                    }
                  } : null,
                  child: Text(
                    ceOption?.lp ?? '--',
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: MyntColors.profit,
                      fontWeight: MyntFonts.medium,
                    ),
                  ),
                ),
              ),
            ),
            // Strike Price
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                strike,
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textBlack,
                  fontWeight: isATM ? MyntFonts.bold : MyntFonts.medium,
                ),
              ),
            ),
            // Put LTP - with ITM background
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: peBasketBg ?? (isPEITM ? (isDark ? const Color(0xFF3D1F1F) : const Color(0xFFFFEBEE)) : null),
                  border: peBasketBorder != null
                      ? Border(left: BorderSide(color: peBasketBorder, width: 3))
                      : null,
                ),
                child: InkWell(
                  onTap: peOption != null ? () {
                    if (peInBasket != null) {
                      final idx = provider.basket.indexOf(peInBasket);
                      if (idx != -1) provider.removeFromBasket(idx, context);
                    } else {
                      _showBuySellMenu(context, provider, peOption, isDark);
                    }
                  } : null,
                  child: Text(
                    peOption?.lp ?? '--',
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: MyntColors.loss,
                      fontWeight: MyntFonts.medium,
                    ),
                  ),
                ),
              ),
            ),
            // Put OI(ch) - with ITM background
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: peBasketBg ?? (isPEITM ? (isDark ? const Color(0xFF3D1F1F) : const Color(0xFFFFEBEE)) : null),
                ),
                child: InkWell(
                  onTap: peOption != null ? () {
                    if (peInBasket != null) {
                      final idx = provider.basket.indexOf(peInBasket);
                      if (idx != -1) provider.removeFromBasket(idx, context);
                    } else {
                      _showBuySellMenu(context, provider, peOption, isDark);
                    }
                  } : null,
                  child: Text(
                    formatOI(peOI, peOIChange),
                    textAlign: TextAlign.center,
                    style: MyntWebTextStyles.caption(
                      context,
                      color: peOIChange >= 0 ? MyntColors.profit : MyntColors.loss,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuySellMenu(BuildContext context, StrategyBuilderProvider provider, dynamic option, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? MyntColors.searchBgDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.tsym ?? 'Select Action',
              style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textBlack,
                fontWeight: MyntFonts.semiBold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Buy Button
                ElevatedButton(
                  onPressed: () {
                    provider.addToBasket(option, 'BUY', context);
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyntColors.profit,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('BUY', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                // Sell Button
                ElevatedButton(
                  onPressed: () {
                    provider.addToBasket(option, 'SELL', context);
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyntColors.loss,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('SELL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.basket.isEmpty) {
      // Show skeleton shimmer rows when loading in analyze mode
      if (provider.isLoading && provider.isAnalyzeMode) {
        return _buildBasketTableSkeleton(isDark);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "There's nothing here yet.",
              style: MyntWebTextStyles.body(
                context,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add some options to see them here.',
              style: MyntWebTextStyles.bodySmall(
                context,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // Show create strategy dialog
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Create your Strategy',
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textBlack,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Add both horizontal and vertical scrolling for the basket table
    // Horizontal scrollbar is fixed at the bottom of the container
    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    final dataTable = DataTable(
      columnSpacing: 10,
      horizontalMargin: 8,
      headingRowHeight: 40,
      headingRowColor: WidgetStateProperty.all(
        isDark ? MyntColors.dividerDark : MyntColors.divider,
      ),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(
          label: Checkbox(
            value: provider.isAllSelected,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            side: isDark ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
            onChanged: (value) => provider.toggleAllCheckboxes(value ?? false, context),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        DataColumn(
          label: Text(
            'B/S',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Expiry',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Strike',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'CE/PE',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Lots',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Entry Price',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'LTP',
            style: MyntWebTextStyles.caption(
              context,
              darkColor: Colors.grey,
              lightColor: Colors.grey[600],
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        const DataColumn(label: SizedBox(width: 40)),
      ],
      rows: provider.basket.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _buildBasketRow(context, provider, item, index, isDark);
      }).toList(),
    );

    // Horizontal scrollbar (outer) appears at bottom, vertical scrollbar (inner) appears on right
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8),
            radius: const Radius.circular(4),
            thumbColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.6)),
            trackColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.2)),
            trackVisibility: WidgetStateProperty.all(true),
          ),
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    scrollDirection: Axis.vertical,
                    child: dataTable,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Skeleton shimmer loader for basket table during analyze mode loading
  Widget _buildBasketTableSkeleton(bool isDark) {
    Widget shimmerCell(double width) => MyntShimmerLoader(width: width, height: 14, borderRadius: 4);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Skeleton header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? MyntColors.dividerDark : MyntColors.divider,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                shimmerCell(20),
                const SizedBox(width: 16),
                shimmerCell(28),
                const SizedBox(width: 16),
                shimmerCell(52),
                const SizedBox(width: 16),
                shimmerCell(48),
                const SizedBox(width: 16),
                shimmerCell(36),
                const SizedBox(width: 16),
                shimmerCell(30),
                const SizedBox(width: 16),
                Expanded(child: shimmerCell(60)),
              ],
            ),
          ),
          // Skeleton data rows
          ...List.generate(3, (index) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
                ),
              ),
            ),
            child: Row(
              children: [
                shimmerCell(20),
                const SizedBox(width: 16),
                shimmerCell(28),
                const SizedBox(width: 16),
                shimmerCell(52),
                const SizedBox(width: 16),
                shimmerCell(48),
                const SizedBox(width: 16),
                shimmerCell(36),
                const SizedBox(width: 16),
                shimmerCell(30),
                const SizedBox(width: 16),
                Expanded(child: shimmerCell(60)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  DataRow _buildBasketRow(
    BuildContext context,
    StrategyBuilderProvider provider,
    StrategyBasketItem item,
    int index,
    bool isDark,
  ) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: item.checkbox,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            side: isDark ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
            onChanged: (_) => provider.toggleCheckbox(index, context),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        // Buy/Sell toggle
        DataCell(
          InkWell(
            onTap: () => provider.toggleBuySell(index, context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.buySell == 'BUY'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withOpacity(0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.buySell == 'BUY' ? 'B' : 'S',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: item.buySell == 'BUY' ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Expiry
        DataCell(
          PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 30),
            splashRadius: isDark ? 0 : null,
            color: isDark ? MyntColors.cardDark : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatExpiry(item.expdate),
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ).copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark ? Colors.grey : Colors.grey[600],
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => provider.expiryDates
                .map((exp) => PopupMenuItem(
                      value: exp,
                      child: Text(
                        _formatExpiry(exp),
                        style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                      ),
                    ))
                .toList(),
            onSelected: (value) => provider.updateExpiry(index, value, context),
          ),
        ),
        // Strike
        DataCell(
          PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 30),
            constraints: const BoxConstraints(maxHeight: 300),
            splashRadius: isDark ? 0 : null,
            color: isDark ? MyntColors.cardDark : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.strprc,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ).copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark ? Colors.grey : Colors.grey[600],
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => provider.getStrikesForExpiry(item.expdate, currentStrike: item.strprc)
                .map((strike) => PopupMenuItem(
                      value: strike,
                      child: Text(
                        strike,
                        style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                      ),
                    ))
                .toList(),
            onSelected: (value) => provider.updateStrike(index, value, context),
          ),
        ),
        // CE/PE toggle
        DataCell(
          InkWell(
            onTap: () => provider.toggleCePe(index, context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.optt == 'CE'
                    ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary).withOpacity(0.15)
                    : resolveThemeColor(context, dark: MyntColors.loss, light: MyntColors.loss).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.optt,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: item.optt == 'CE' ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary) : resolveThemeColor(context, dark: MyntColors.loss, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Lots
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => provider.updateLots(index, item.ordlot - 1, context),
                child: const Icon(Icons.remove, size: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${item.ordlot * provider.lotMultiplier}',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => provider.updateLots(index, item.ordlot + 1, context),
                child: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        // Entry Price
        DataCell(
          SizedBox(
            width: 80,
            child: MyntTextField(
              controller: TextEditingController(text: item.entryPrice.toStringAsFixed(2)),
              placeholder: '0.00',
              height: 30,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              borderRadius: 4,
              onChanged: (value) {
                final price = double.tryParse(value);
                if (price != null) {
                  provider.updateEntryPrice(index, price, context);
                }
              },
            ),
          ),
        ),
        // LTP
        DataCell(
          Text(
            item.ltp.toIndianFormat(),
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
            ).copyWith(fontSize: 12),
          ),
        ),
        // Delete button
        DataCell(
          IconButton(
            onPressed: () => provider.removeFromBasket(index, context),
            icon: const Icon(Icons.delete_outline, size: 20, color: MyntColors.loss),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Lot Multiplier
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lot Multiplier',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textBlack,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (provider.lotMultiplier > 1) {
                    provider.setLotMultiplier(provider.lotMultiplier - 1, context);
                    _lotMultiplierController.text = provider.lotMultiplier.toString();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.remove, size: 16),
                ),
              ),
              SizedBox(
                width: 50,
                child: MyntTextField(
                  controller: _lotMultiplierController,
                  placeholder: '1',
                  height: 30,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  borderRadius: 4,
                  onChanged: (value) {
                    final multiplier = int.tryParse(value);
                    if (multiplier != null && multiplier > 0) {
                      provider.setLotMultiplier(multiplier, context);
                    }
                  },
                ),
              ),
              InkWell(
                onTap: () {
                  provider.setLotMultiplier(provider.lotMultiplier + 1, context);
                  _lotMultiplierController.text = provider.lotMultiplier.toString();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.add, size: 16),
                ),
              ),
            ],
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Place Order button
              ElevatedButton(
                onPressed: provider.isOrderLoading ? null : () => provider.placeOrder(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyntColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(100, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: provider.isOrderLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Place order',
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          color: Colors.white,
                          fontWeight: MyntFonts.medium,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyGrid(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final strategies = provider.filteredStrategies;
    final isCustomTab = provider.strategyTypeTab == 'CustomBuilder';

    if (strategies.isEmpty && !isCustomTab) {
      return Center(
        child: Text(
          'No strategies found.\nCreate a strategy to get started.',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leg builder (only for Custom Builder tab)
          if (isCustomTab) ...[
            _buildLegBuilder(context, provider, isDark),
            _buildLegBuilderBottomActions(context, provider, isDark),
          ],
          // Strategy cards
          if (strategies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: strategies.map((strategy) {
                  final isActive = provider.activePredefinedStrategy == strategy.title;
                  final showDelete = strategy.type == 'CustomBuilder';
                  return InkWell(
                    onTap: () => provider.setActivePredefinedStrategy(strategy, context),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? MyntColors.primary
                                : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? (isDark ? MyntColors.secondary : MyntColors.primary)
                                  : (isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Strategy SVG image
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: SvgPicture.asset(
                                  strategy.image,
                                  width: 32,
                                  height: 32,
                                  placeholderBuilder: (context) => Icon(
                                    Icons.show_chart,
                                    color: isActive ? Colors.white : MyntColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                strategy.title,
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: isActive
                                      ? Colors.white
                                      : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                              // Extra space for delete icon
                              if (showDelete)
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                        // Delete button at top-right corner
                        if (showDelete)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _showDeleteCustomStrategyDialog(context, provider, strategy.title, isDark),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : (isDark ? Colors.grey : Colors.grey[600]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ,
        ],
      ),
    );
  }

  /// Leg builder section — shown above strategy tabs when on Custom Builder tab
  Widget _buildLegBuilder(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final draftLegs = provider.draftLegs;

    if (draftLegs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              "No legs defined yet.",
              style: MyntWebTextStyles.body(context, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Add legs to build your custom strategy.',
              style: MyntWebTextStyles.bodySmall(context, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => provider.addDraftLeg(),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Add Leg',
                style: MyntWebTextStyles.body(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    final dataTable = DataTable(
      columnSpacing: 10,
      horizontalMargin: 8,
      headingRowHeight: 40,
      headingRowColor: WidgetStateProperty.all(
        isDark ? MyntColors.dividerDark : MyntColors.divider,
      ),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(
          label: Checkbox(
            value: provider.isAllDraftLegsSelected,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            onChanged: (value) => provider.toggleAllDraftLegCheckboxes(value ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        DataColumn(
          label: Text('B/S',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('CE/PE',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Lots',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Exp Offset',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Strike Type',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Offset/Premium',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        const DataColumn(label: SizedBox()),
      ],
      rows: draftLegs.asMap().entries.map((entry) {
        final index = entry.key;
        final draft = entry.value;
        return _buildDraftLegDataRow(context, provider, index, draft, isDark);
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8),
            radius: const Radius.circular(4),
            thumbColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.6)),
            trackColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.2)),
            trackVisibility: WidgetStateProperty.all(true),
          ),
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    scrollDirection: Axis.vertical,
                    child: dataTable,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDraftLegDataRow(BuildContext context, StrategyBuilderProvider provider,
      int index, CustomStrategyLegDraft draft, bool isDark) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: draft.checkbox,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            onChanged: (value) {
              draft.checkbox = value ?? false;
              provider.updateDraftLeg(index, draft);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        // B/S toggle
        DataCell(
          InkWell(
            onTap: () {
              draft.action = draft.action == 'BUY' ? 'SELL' : 'BUY';
              provider.updateDraftLeg(index, draft);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: draft.action == 'BUY'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                draft.action == 'BUY' ? 'B' : 'S',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: draft.action == 'BUY'
                      ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                      : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // CE/PE toggle
        DataCell(
          InkWell(
            onTap: () {
              draft.optionType = draft.optionType == 'CE' ? 'PE' : 'CE';
              provider.updateDraftLeg(index, draft);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: draft.optionType == 'CE'
                    ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary).withValues(alpha: 0.15)
                    : resolveThemeColor(context, dark: MyntColors.loss, light: MyntColors.loss).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                draft.optionType,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: draft.optionType == 'CE'
                      ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)
                      : resolveThemeColor(context, dark: MyntColors.loss, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Lots (+/- stepper)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: draft.ordlot > 1 ? () {
                  draft.ordlot--;
                  provider.updateDraftLeg(index, draft);
                } : null,
                child: const Icon(Icons.remove, size: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${draft.ordlot}',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  draft.ordlot++;
                  provider.updateDraftLeg(index, draft);
                },
                child: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        // Expiry Offset (+/- stepper)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: draft.expiryOffset > 0 ? () {
                  draft.expiryOffset--;
                  provider.updateDraftLeg(index, draft);
                } : null,
                child: const Icon(Icons.remove, size: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${draft.expiryOffset}',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  draft.expiryOffset++;
                  provider.updateDraftLeg(index, draft);
                },
                child: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        // Strike Type (PopupMenuButton dropdown)
        DataCell(
          PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 30),
            splashRadius: isDark ? 0 : null,
            color: isDark ? MyntColors.cardDark : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    draft.strikeType == 'PREMIUM' ? 'P' : draft.strikeType,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ).copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark ? Colors.grey : Colors.grey[600],
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => ['ATM', 'ITM', 'OTM', 'PREMIUM']
                .map((type) => PopupMenuItem(
                      value: type,
                      child: Text(
                        type == 'PREMIUM' ? 'P (Premium)' : type,
                        style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                      ),
                    ))
                .toList(),
            onSelected: (value) {
              draft.strikeType = value;
              if (value == 'PREMIUM') draft.strikeOffset = 0;
              provider.updateDraftLeg(index, draft);
            },
          ),
        ),
        // Offset / Premium value
        DataCell(
          draft.strikeType == 'PREMIUM'
              ? SizedBox(
                  width: 80,
                  child: EntryPriceTableInput(
                    value: draft.premiumValue,
                    onChanged: (price) {
                      draft.premiumValue = price;
                      provider.updateDraftLeg(index, draft);
                    },
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: draft.strikeOffset > 0 ? () {
                        draft.strikeOffset--;
                        provider.updateDraftLeg(index, draft);
                      } : null,
                      child: const Icon(Icons.remove, size: 16),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${draft.strikeOffset}',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textBlack,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        draft.strikeOffset++;
                        provider.updateDraftLeg(index, draft);
                      },
                      child: const Icon(Icons.add, size: 16),
                    ),
                  ],
                ),
        ),
        // Delete
        DataCell(
          IconButton(
            onPressed: () => provider.removeDraftLeg(index),
            icon: const Icon(Icons.delete_outline, size: 20, color: MyntColors.loss),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  /// Bottom actions for the custom strategy leg builder
  Widget _buildLegBuilderBottomActions(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add Leg row (similar to Lot Multiplier row)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => provider.addDraftLeg(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Add Leg',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(70, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
          // Clear, Save, Apply row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => provider.clearDraftLegs(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _showSaveCustomStrategyDialog(context, provider, isDark),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: provider.isLoading ? null : () => provider.applyCustomStrategy(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                    disabledBackgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary).withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: const Size(100, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Apply',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: Colors.white,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Save custom strategy dialog
  void _showSaveCustomStrategyDialog(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final nameController = TextEditingController(text: provider.editingCustomBuilderName ?? '');
    final focusNode = FocusNode();

    // Request focus after dialog animation completes
    Future.delayed(const Duration(milliseconds: 250), () {
      focusNode.requestFocus();
      if (provider.editingCustomBuilderName != null && nameController.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 50), () {
          nameController.selection = TextSelection.collapsed(
            offset: nameController.text.length,
          );
        });
      }
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isUpdateMode = provider.editingCustomBuilderName != null &&
                nameController.text == provider.editingCustomBuilderName;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: shadcn.Card(
                  borderRadius: BorderRadius.circular(8),
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: 400,
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: shadcn.Theme.of(context).colorScheme.border,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUpdateMode ? 'Update Custom Builder' : 'Save Custom Builder',
                                style: MyntWebTextStyles.title(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                ),
                              ),
                              MyntCloseButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: MyntFormTextField(
                                        controller: nameController,
                                        focusNode: focusNode,
                                        placeholder: 'Enter strategy name',
                                        enabled: !isUpdateMode,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    if (isUpdateMode) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          nameController.clear();
                                          focusNode.requestFocus();
                                          setState(() {});
                                        },
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 24),
                                MyntPrimaryButton(
                                  size: MyntButtonSize.large,
                                  label: isUpdateMode ? 'Update' : 'Save',
                                  isFullWidth: true,
                                  onPressed: nameController.text.trim().isEmpty
                                      ? null
                                      : () {
                                          provider.saveCustomStrategy(nameController.text.trim(), context);
                                          Navigator.pop(dialogContext);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Delete custom strategy dialog
  void _showDeleteCustomStrategyDialog(BuildContext context, StrategyBuilderProvider provider, String strategyName, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: shadcn.Card(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              child: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 250),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: shadcn.Theme.of(context).colorScheme.border,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delete Strategy',
                            style: MyntWebTextStyles.title(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          MyntCloseButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Are you sure you want to delete "$strategyName"?',
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            MyntButton(
                              type: MyntButtonType.primary,
                              size: MyntButtonSize.large,
                              label: 'Delete',
                              isFullWidth: true,
                              backgroundColor: resolveThemeColor(
                                context,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary,
                              ),
                              onPressed: () {
                                provider.deleteCustomStrategy(strategyName, context);
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? MyntColors.overlayBgDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          // Metrics section
          _buildMetricsSection(context, provider, isDark),
          const Divider(height: 1),
          // Tabs
          _buildPayoffTabs(context, provider, isDark),
          const Divider(height: 1),
          // Chart or Greeks table
          Expanded(
            child: Stack(
              children: [
                provider.payoffTab == 0
                    ? _buildPayoffChart(context, provider, isDark)
                    : _buildGreeksTable(context, provider, isDark),
                if (provider.isPayoffLoading && provider.payoffData.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
          ),
          // Greeks row
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildMetricItem(context, '\u0394 DELTA', provider.greeksTotal('delta').toStringAsFixed(4), null, isDark),
                _buildMetricItem(context, '\u0398 THETA', provider.greeksTotal('theta').toStringAsFixed(4), null, isDark),
                _buildMetricItem(context, '\u0393 GAMMA', provider.greeksTotal('gamma').toStringAsFixed(4), null, isDark),
                _buildMetricItem(context, '\u03BD VEGA', provider.greeksTotal('vega').toStringAsFixed(4), null, isDark),
              ],
            ),
          ),
          // Chart controls
          _buildChartControls(context, provider, isDark),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildMetricItem(context, 'MAX PROFIT', provider.metrics.maxProfit, MyntColors.profit, isDark),
                _buildMetricItem(context, 'MAX LOSS', provider.metrics.maxLoss, isDark ? MyntColors.errorDark : MyntColors.loss, isDark),
                _buildMetricItem(
                  context,
                  'NET PREMIUM',
                  // Show absolute value - color indicates if it's credit (green) or debit (red)
                  provider.netPremium.abs().toIndianFormat(),
                  provider.netPremium > 0
                      ? (isDark ? MyntColors.profitDark : MyntColors.profit)
                      : provider.netPremium < 0
                          ? (isDark ? MyntColors.errorDark : MyntColors.loss)
                          : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                  isDark,
                ),
                _buildMetricItem(context, 'MARGIN', provider.totalMargin, null, isDark),
                // MARGIN BENEFIT hidden
                // _buildMetricItem(context, 'MARGIN BENEFIT', provider.marginBenefit, isDark ? MyntColors.profitDark : MyntColors.profit, isDark),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetricItem(context, 'POP', '${provider.metrics.popPercent.toStringAsFixed(0)}%', null, isDark),
                _buildMetricItem(context, 'REWARD/RISK', provider.metrics.riskRewardRatio, null, isDark),
                _buildMetricItem(
                  context,
                  'BREAKEVEN',
                  '--',
                  null,
                  isDark,
                  valueWidget: provider.metrics.breakevens.isNotEmpty
                      ? _buildBreakevenRichText(provider, MyntWebTextStyles.bodySmall(
                          context,
                          color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(fontSize: 14))
                      : null,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, Color? valueColor, bool isDark, {Widget? valueWidget}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithInfo(
            context,
            Text(
              label,
              style: MyntWebTextStyles.caption(
                context,
                color: Colors.grey,
                fontWeight: MyntFonts.medium,
              ).copyWith(fontSize: 11),
            ),
            (label == 'MARGIN' &&
                    ref.read(strategyBuilderProvider).basketMarginModel != null)
                ? () => showMarginInfoDialog(context, isDark)
                : null,
          ),
          const SizedBox(height: 4),
          valueWidget ?? Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: valueColor ?? (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
              fontWeight: MyntFonts.medium,
            ).copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoffTabs(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final hasData = provider.payoffData.isNotEmpty;
    final targetDate = DateTime.now().add(Duration(days: provider.targetDaysToExpiry));
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final labelStyle = MyntWebTextStyles.caption(
      context,
      darkColor: Colors.grey,
      lightColor: Colors.grey[700],
      fontWeight: MyntFonts.medium,
    ).copyWith(fontSize: 11);
    final resetStyle = MyntWebTextStyles.caption(
      context,
      color: MyntColors.primary,
      fontWeight: MyntFonts.bold,
    ).copyWith(fontSize: 11);
    final valueStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textBlack,
      fontWeight: MyntFonts.semiBold,
    ).copyWith(fontSize: 13);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabButton(context, 'Payoff Graph', provider.payoffTab == 0, isDark, () {
            provider.setPayoffTab(0);
          }),
          const SizedBox(width: 16),
          _buildTabButton(context, 'Greeks', provider.payoffTab == 1, isDark, () {
            provider.setPayoffTab(1);
          }),
          const Spacer(),
          // Target Date controls
          Text('Target Date: ${provider.daysToExpiry - provider.targetDaysToExpiry}D', style: labelStyle),
          const SizedBox(width: 8),
          InkWell(
            onTap: hasData ? () => provider.setTargetDaysToExpiry(0) : null,
            child: Text('Reset', style: resetStyle),
          ),
          const SizedBox(width: 10),
          Container(
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (!hasData || provider.targetDaysToExpiry <= 0) return;
                    provider.setTargetDaysToExpiry(provider.targetDaysToExpiry - 1);
                  },
                  child: Container(
                    width: 28, height: 28, alignment: Alignment.center,
                    child: Icon(Icons.chevron_left, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                VerticalDivider(width: 1, color: borderColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "${_getWeekday(targetDate.weekday)}, ${targetDate.day} ${_getMonth(targetDate.month)}",
                    style: valueStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                VerticalDivider(width: 1, color: borderColor),
                InkWell(
                  onTap: () {
                    if (!hasData || provider.targetDaysToExpiry >= provider.daysToExpiry) return;
                    provider.setTargetDaysToExpiry(provider.targetDaysToExpiry + 1);
                  },
                  child: Container(
                    width: 28, height: 28, alignment: Alignment.center,
                    child: Icon(Icons.chevron_right, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, bool isActive, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? MyntColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: isActive ? MyntColors.primary : Colors.grey,
            fontWeight: MyntFonts.medium,
          ),
        ),
      ),
    );
  }

  Widget _buildPayoffChart(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.payoffData.isEmpty) {
      return Center(
        child: Text(
          'Add options to see payoff chart',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    final currentPrice = provider.isTargetSpotActive ? provider.targetSpotPrice : provider.spotPrice;

    // Convert payoff data to lists
    final stockPrices = provider.payoffData.map((p) => p.price).toList();
    final payoffsExpiry = provider.payoffData.map((p) => p.profit).toList();
    final payoffsTarget = provider.targetPayoffData.map((p) => p.profit).toList();

    if (stockPrices.isEmpty || payoffsExpiry.isEmpty) {
      return Center(
        child: Text(
          'No payoff data available',
          style: MyntWebTextStyles.body(context, color: Colors.grey),
        ),
      );
    }

    // Calculate Y-axis range with nice round intervals
    double minPayoff = payoffsExpiry.reduce((a, b) => a < b ? a : b);
    double maxPayoff = payoffsExpiry.reduce((a, b) => a > b ? a : b);

    if (payoffsTarget.isNotEmpty) {
      final targetMin = payoffsTarget.reduce((a, b) => a < b ? a : b);
      final targetMax = payoffsTarget.reduce((a, b) => a > b ? a : b);
      minPayoff = minPayoff < targetMin ? minPayoff : targetMin;
      maxPayoff = maxPayoff > targetMax ? maxPayoff : targetMax;
    }

    // Add padding
    double yRange = maxPayoff - minPayoff;
    if (yRange <= 0) yRange = 10000;
    minPayoff = minPayoff - (yRange * 0.15);
    maxPayoff = maxPayoff + (yRange * 0.15);

    // Round to nice intervals (multiples of 10000 for large values, 1000 for smaller)
    double roundingFactor = 10000;
    if ((maxPayoff - minPayoff).abs() < 50000) {
      roundingFactor = 5000;
    }
    if ((maxPayoff - minPayoff).abs() < 10000) {
      roundingFactor = 1000;
    }

    // Round min down and max up to nice values
    minPayoff = (minPayoff / roundingFactor).floor() * roundingFactor;
    maxPayoff = (maxPayoff / roundingFactor).ceil() * roundingFactor;

    // Ensure zero is visible with proper negative space
    if (minPayoff > 0) {
      minPayoff = -roundingFactor;
    } else if (maxPayoff < 0) {
      maxPayoff = roundingFactor;
    }

    // Ensure minimum visible range
    if ((maxPayoff - minPayoff) < roundingFactor * 4) {
      maxPayoff = minPayoff + roundingFactor * 4;
    }

    // Calculate X-axis range
    double minPrice = stockPrices.reduce((a, b) => a < b ? a : b);
    double maxPrice = stockPrices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Center around midpoint of payoff data (stable, not affected by live price ticks)
    final centerPrice = (minPrice + maxPrice) / 2;
    
    // If SD lines are enabled, expand range to include all SD lines
    double zoomedRange = priceRange * 0.6;
    if (provider.showSDLines && provider.sdPrices.isNotEmpty) {
      final sdMin = provider.sdPrices['-2σ'] ?? minPrice;
      final sdMax = provider.sdPrices['+2σ'] ?? maxPrice;
      final sdRange = sdMax - sdMin;
      // Ensure SD range fits with 10% padding
      if (sdRange * 1.15 > zoomedRange) {
        zoomedRange = sdRange * 1.15;
      }
    }
    
    minPrice = centerPrice - (zoomedRange / 2);
    maxPrice = centerPrice + (zoomedRange / 2);

    // Ensure we don't go beyond actual data bounds
    final actualMinPrice = stockPrices.reduce((a, b) => a < b ? a : b);
    final actualMaxPrice = stockPrices.reduce((a, b) => a > b ? a : b);

    if (minPrice < actualMinPrice) {
      final adjustment = actualMinPrice - minPrice;
      minPrice = actualMinPrice;
      maxPrice = maxPrice + adjustment;
    }
    if (maxPrice > actualMaxPrice) {
      final adjustment = maxPrice - actualMaxPrice;
      maxPrice = actualMaxPrice;
      minPrice = minPrice - adjustment;
      if (minPrice < actualMinPrice) {
        minPrice = actualMinPrice;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartHeight = constraints.maxHeight;

        return Stack(
          children: [
            MouseRegion(
              onExit: (event) {
                _hidePayoffTooltipAfterDelay();
              },
              child: Listener(
                onPointerDown: (event) {
                  setState(() {
                    _isDragging = true;
                  });
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerMove: (event) {
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerHover: (event) {
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerUp: (event) {
                  setState(() {
                    _isDragging = false;
                  });
                  _hidePayoffTooltipAfterDelay();
                },
                onPointerCancel: (event) {
                  _isDragging = false;
                  _selectedPrice = null;
                  _tooltipNotifier.value = const _PayoffTooltipState();
                },
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                enableAxisAnimation: false,
                primaryXAxis: NumericAxis(
                  minimum: minPrice,
                  maximum: maxPrice,
                  rangePadding: ChartRangePadding.none,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: MajorGridLines(
                    width: 1,
                    color: Colors.grey.withOpacity(0.15),
                  ),
                  desiredIntervals: 5,
                  axisLabelFormatter: (AxisLabelRenderDetails args) {
                    return ChartAxisLabel(
                      args.value.toStringAsFixed(0),
                      TextStyle(
                        fontFamily: MyntFonts.fontFamily,
                        fontSize: MyntFonts.caption,
                        color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                      ),
                    );
                  },
                  plotBands: <PlotBand>[
                    // Current price line (vertical blue line)
                    PlotBand(
                      start: currentPrice,
                      end: currentPrice,
                      borderColor: const Color(0xFF2962FF),
                      borderWidth: 1.5,
                    ),
                    // Breakeven lines (vertical grey dashed lines)
                    ...provider.metrics.breakevens.map(
                      (be) => PlotBand(
                        start: be,
                        end: be,
                        color: Colors.transparent,
                        borderColor: Colors.grey.withOpacity(0.5),
                        borderWidth: 1.5,
                        dashArray: const <double>[5, 5],
                      ),
                    ),
                    // SD lines (standard deviation lines)
                    if (provider.showSDLines && provider.sdPrices.isNotEmpty) ...[
                      // -2σ line
                      PlotBand(
                        start: provider.sdPrices['-2σ']!,
                        end: provider.sdPrices['-2σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '-2σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // -1σ line
                      PlotBand(
                        start: provider.sdPrices['-1σ']!,
                        end: provider.sdPrices['-1σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '-1σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // +1σ line
                      PlotBand(
                        start: provider.sdPrices['+1σ']!,
                        end: provider.sdPrices['+1σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '+1σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // +2σ line
                      PlotBand(
                        start: provider.sdPrices['+2σ']!,
                        end: provider.sdPrices['+2σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '+2σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                    ],
                  ],
                ),
                primaryYAxis: NumericAxis(
                  minimum: minPayoff,
                  maximum: maxPayoff,
                  rangePadding: ChartRangePadding.none,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: MajorGridLines(
                    width: 1,
                    color: Colors.grey.withOpacity(0.15),
                  ),
                  desiredIntervals: 6,
                  axisLabelFormatter: (AxisLabelRenderDetails args) {
                    final value = args.value;
                    String label;
                    if (value.abs() >= 100000) {
                      // Show as lakhs (1L = 100000)
                      label = '₹${(value / 100000).toStringAsFixed(0)}L';
                    } else if (value.abs() >= 1000) {
                      // Show as thousands with K suffix
                      final thousands = (value / 1000).round();
                      label = '₹${thousands}K';
                    } else {
                      label = '₹${value.toStringAsFixed(0)}';
                    }
                    return ChartAxisLabel(
                      label,
                      TextStyle(
                        fontFamily: MyntFonts.fontFamily,
                        fontSize: MyntFonts.caption,
                        color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                      ),
                    );
                  },
                  plotBands: <PlotBand>[
                    // Zero line (horizontal line)
                    PlotBand(
                      start: 0,
                      end: 0,
                      borderColor: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                      borderWidth: 1,
                    ),
                  ],
                ),
                trackballBehavior: TrackballBehavior(
                  enable: true,
                  activationMode: ActivationMode.longPress,
                  tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                  shouldAlwaysShow: _isDragging,
                  hideDelay: 0,
                  lineType: TrackballLineType.vertical,
                  lineColor: Colors.grey.withOpacity(0.5),
                  lineWidth: 1,
                  markerSettings: const TrackballMarkerSettings(
                    markerVisibility: TrackballVisibilityMode.visible,
                    height: 8,
                    width: 8,
                  ),
                  tooltipSettings: const InteractiveTooltip(
                    enable: false,
                  ),
                ),
                series: <CartesianSeries<dynamic, dynamic>>[
                  // Loss shaded area (below zero) - light red fill
                  AreaSeries<_PayoffData, double>(
                    dataSource: _generateAreaDataFromZero(stockPrices, payoffsExpiry, false),
                    xValueMapper: (_PayoffData data, _) => data.price,
                    yValueMapper: (_PayoffData data, _) => data.payoff,
                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                    borderWidth: 0,
                    animationDuration: 0,
                    name: 'Loss',
                    enableTooltip: false,
                  ),
                  // Profit shaded area (above zero) - light green fill
                  AreaSeries<_PayoffData, double>(
                    dataSource: _generateAreaDataFromZero(stockPrices, payoffsExpiry, true),
                    xValueMapper: (_PayoffData data, _) => data.price,
                    yValueMapper: (_PayoffData data, _) => data.payoff,
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderWidth: 0,
                    animationDuration: 0,
                    name: 'Profit',
                    enableTooltip: false,
                  ),
                  // Target/Today line (BLUE solid) - matches reference image
                  if (payoffsTarget.isNotEmpty)
                    LineSeries<_PayoffData, double>(
                      dataSource: _generateLineData(stockPrices, payoffsTarget),
                      xValueMapper: (_PayoffData data, _) => data.price,
                      yValueMapper: (_PayoffData data, _) => data.payoff,
                      color: const Color(0xFF2962FF), // Blue solid line
                      width: 2.5,
                      animationDuration: 0,
                      name: 'Target',
                      enableTooltip: false,
                    ),
                  // Expiry line (Segmented Red/Green) - matches reference image
                  ..._generateSegmentedLineSeries(
                    stockPrices: stockPrices,
                    payoffs: payoffsExpiry,
                    colorPositive: MyntColors.profit,
                    colorNegative: MyntColors.loss,
                    width: 2.5,
                    dashArray: null,
                    name: 'Expiry',
                  ),
                  // Marker dot on Target line at tooltip position
                  if (_selectedPrice != null && payoffsTarget.isNotEmpty)
                    ScatterSeries<_PayoffData, double>(
                      dataSource: [
                        _PayoffData(
                          price: _selectedPrice!,
                          payoff: _getPayoffAtPrice(stockPrices, payoffsTarget, _selectedPrice!),
                        ),
                      ],
                      xValueMapper: (_PayoffData data, _) => data.price,
                      yValueMapper: (_PayoffData data, _) => data.payoff,
                      pointColorMapper: (_PayoffData data, _) => const Color(0xFF2962FF),
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        height: 10,
                        width: 10,
                        shape: DataMarkerType.circle,
                        borderWidth: 2,
                        borderColor: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                      ),
                      animationDuration: 0,
                      name: 'Target Marker',
                      enableTooltip: false,
                    ),
                ],
              ),
            ), // Close Listener
            ), // Close MouseRegion
            // Custom tooltip — uses ValueListenableBuilder to avoid rebuilding the chart
            ValueListenableBuilder<_PayoffTooltipState>(
              valueListenable: _tooltipNotifier,
              builder: (context, tooltipState, _) {
                if (!tooltipState.showTooltip || tooltipState.selectedPrice == null) {
                  return const SizedBox.shrink();
                }
                return _buildPayoffCustomTooltip(provider, isDark, stockPrices, payoffsExpiry, payoffsTarget, tooltipState);
              },
            ),
          ],
        );
      },
    );
  }

  void _updatePayoffTooltipFromPosition(double xPosition, double yPosition, double chartWidth, double chartHeight, double minPrice, double maxPrice) {
    ++_tooltipUpdateCounter;

    // Account for chart padding
    final plotAreaWidth = chartWidth * 0.85;
    final plotAreaStart = chartWidth * 0.075;
    final relativeX = ((xPosition - plotAreaStart) / plotAreaWidth).clamp(0.0, 1.0);

    final calculatedPrice = minPrice + (relativeX * (maxPrice - minPrice));

    // Calculate tooltip position
    const tooltipOffset = 20.0;
    const tooltipWidth = 200.0;
    const tooltipHeight = 150.0;
    const edgePadding = 8.0;

    final maxX = chartWidth - tooltipWidth - edgePadding;
    final maxY = chartHeight - tooltipHeight - edgePadding;
    final minX = edgePadding;
    final minY = edgePadding;

    double tooltipX;
    final rightPosition = xPosition + tooltipOffset;
    final leftPosition = xPosition - tooltipWidth - tooltipOffset;

    if (rightPosition + tooltipWidth <= maxX) {
      tooltipX = rightPosition;
    } else if (leftPosition >= minX) {
      tooltipX = leftPosition;
    } else {
      final rightSpace = maxX - xPosition;
      final leftSpace = xPosition - minX;
      tooltipX = rightSpace > leftSpace ? maxX : minX;
    }

    tooltipX = tooltipX.clamp(minX, maxX);
    double tooltipY = yPosition - tooltipHeight / 2;
    tooltipY = tooltipY.clamp(minY, maxY);

    _selectedPrice = calculatedPrice;
    _tooltipNotifier.value = _PayoffTooltipState(
      selectedPrice: calculatedPrice,
      showTooltip: true,
      position: Offset(tooltipX, tooltipY),
    );
    // Schedule a single setState per frame for chart marker dot update
    if (!_markerUpdateScheduled) {
      _markerUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
        _markerUpdateScheduled = false;
      });
    }
  }

  void _hidePayoffTooltipAfterDelay() {
    if (!_isDragging) {
      final counterWhenScheduled = _tooltipUpdateCounter;
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted && !_isDragging && counterWhenScheduled == _tooltipUpdateCounter) {
          _selectedPrice = null;
          _tooltipNotifier.value = const _PayoffTooltipState();
        }
      });
    }
  }

  Widget _buildPayoffCustomTooltip(StrategyBuilderProvider provider, bool isDark, List<double> stockPrices, List<double> payoffsExpiry, List<double> payoffsTarget, _PayoffTooltipState tooltipState) {
    final selectedPrice = tooltipState.selectedPrice!;
    final initialPrice = provider.spotPrice;

    // Get payoff values at selected price
    final expiryPayoff = _getPayoffAtPrice(stockPrices, payoffsExpiry, selectedPrice);
    final targetPayoff = payoffsTarget.isNotEmpty
        ? _getPayoffAtPrice(stockPrices, payoffsTarget, selectedPrice)
        : 0.0;

    // Calculate price difference percentage from spot
    final priceDiffPercent = initialPrice > 0 ? ((selectedPrice - initialPrice) / initialPrice) * 100 : 0.0;

    // Calculate payoff percentages
    final expiryPayoffPercent = initialPrice > 0 ? (expiryPayoff / initialPrice) * 100 : 0.0;
    final targetPayoffPercent = initialPrice > 0 ? (targetPayoff / initialPrice) * 100 : 0.0;

    return Positioned(
      left: tooltipState.position.dx,
      top: tooltipState.position.dy,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Underlying Price with percentage difference from spot
            _buildTooltipRowWithPercent(context, 'Underlying Price:', selectedPrice.toIndianFormat(), priceDiffPercent, MyntColors.textBlack),
            const SizedBox(height: 6),
            // Expiry P&L with percentage
            _buildTooltipRowWithPercent(context, 'Expiry P&L:', '\u20B9${expiryPayoff.toIndianFormat()}', expiryPayoffPercent, expiryPayoff >= 0 ? MyntColors.profit : MyntColors.loss),
            // Target P&L (if available)
            if (payoffsTarget.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildTooltipRowWithPercent(context, 'Target P&L:', '\u20B9${targetPayoff.toIndianFormat()}', targetPayoffPercent, targetPayoff >= 0 ? MyntColors.profit : MyntColors.loss),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildTooltipRowWithPercent(BuildContext context, String label, String value, double percent, Color valueColor) {
    final baseStyle = MyntWebTextStyles.bodySmall(
      context,
      color: valueColor,
      fontWeight: MyntFonts.medium,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: MyntWebTextStyles.bodySmall(
            context,
            color: MyntColors.textBlack,
            fontWeight: MyntFonts.medium,
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: baseStyle),
              TextSpan(
                text: ' (${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)',
                style: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) - 3, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_PayoffData> _generateLineData(List<double> prices, List<double> payoffs) {
    final length = prices.length < payoffs.length ? prices.length : payoffs.length;
    return List.generate(
      length,
      (i) => _PayoffData(price: prices[i], payoff: payoffs[i]),
    );
  }

  double _getPayoffAtPrice(List<double> prices, List<double> payoffs, double targetPrice) {
    if (prices.isEmpty || payoffs.isEmpty) return 0.0;

    int closestIndex = 0;
    double minDiff = (prices[0] - targetPrice).abs();

    for (int i = 1; i < prices.length; i++) {
      final diff = (prices[i] - targetPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    if (minDiff < 0.01 || closestIndex == 0 || closestIndex == prices.length - 1) {
      return payoffs[closestIndex];
    }

    final prevIndex = targetPrice < prices[closestIndex] ? closestIndex - 1 : closestIndex;
    final nextIndex = targetPrice < prices[closestIndex] ? closestIndex : closestIndex + 1;

    if (prevIndex < 0 || nextIndex >= prices.length) {
      return payoffs[closestIndex];
    }

    final prevPrice = prices[prevIndex];
    final nextPrice = prices[nextIndex];
    final prevPayoff = payoffs[prevIndex];
    final nextPayoff = payoffs[nextIndex];

    if ((nextPrice - prevPrice).abs() < 0.01) {
      return prevPayoff;
    }

    final t = (targetPrice - prevPrice) / (nextPrice - prevPrice);
    return prevPayoff + (nextPayoff - prevPayoff) * t;
  }

  List<CartesianSeries<_PayoffData, double>> _generateSegmentedLineSeries({
    required List<double> stockPrices,
    required List<double> payoffs,
    required Color colorPositive,
    required Color colorNegative,
    required double width,
    required List<double>? dashArray,
    required String name,
    bool enableTooltip = true,
  }) {
    final length = stockPrices.length < payoffs.length ? stockPrices.length : payoffs.length;

    List<_PayoffData> positiveData = [];
    List<_PayoffData> negativeData = [];

    for (int i = 0; i < length; i++) {
      final price = stockPrices[i];
      final payoff = payoffs[i];

      if (i > 0) {
        final prevPayoff = payoffs[i - 1];
        final prevPrice = stockPrices[i - 1];

        if ((prevPayoff >= 0 && payoff < 0) || (prevPayoff < 0 && payoff >= 0)) {
          final t = prevPayoff / (prevPayoff - payoff);
          final zeroCrossPrice = prevPrice + (price - prevPrice) * t;

          if (prevPayoff >= 0) {
            positiveData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
            negativeData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
          } else {
            negativeData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
            positiveData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
          }
        }
      }

      if (payoff >= 0) {
        positiveData.add(_PayoffData(price: price, payoff: payoff));
      } else {
        negativeData.add(_PayoffData(price: price, payoff: payoff));
      }
    }

    List<CartesianSeries<_PayoffData, double>> series = [];

    if (positiveData.isNotEmpty) {
      series.add(LineSeries<_PayoffData, double>(
        dataSource: positiveData,
        xValueMapper: (_PayoffData data, _) => data.price,
        yValueMapper: (_PayoffData data, _) => data.payoff,
        color: colorPositive,
        width: width,
        dashArray: dashArray,
        animationDuration: 0,
        name: '$name (Positive)',
        enableTooltip: enableTooltip,
      ));
    }

    if (negativeData.isNotEmpty) {
      series.add(LineSeries<_PayoffData, double>(
        dataSource: negativeData,
        xValueMapper: (_PayoffData data, _) => data.price,
        yValueMapper: (_PayoffData data, _) => data.payoff,
        color: colorNegative,
        width: width,
        dashArray: dashArray,
        animationDuration: 0,
        name: '$name (Negative)',
        enableTooltip: enableTooltip,
      ));
    }

    return series;
  }

  List<_PayoffData> _generateAreaDataFromZero(List<double> prices, List<double> payoffs, bool isPositive) {
    final length = prices.length < payoffs.length ? prices.length : payoffs.length;
    final List<_PayoffData> result = [];

    for (int i = 0; i < length; i++) {
      final price = prices[i];
      final payoff = payoffs[i];

      if (isPositive) {
        result.add(_PayoffData(
          price: price,
          payoff: payoff > 0 ? payoff : 0.0,
        ));
      } else {
        result.add(_PayoffData(
          price: price,
          payoff: payoff < 0 ? payoff : 0.0,
        ));
      }
    }

    return result;
  }

  Widget _buildGreeksTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.basket.isEmpty) {
      return Center(
        child: Text(
          'Add options to see Greeks',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
      return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          headingRowColor: WidgetStateProperty.all(
            isDark ? MyntColors.dividerDark : MyntColors.divider,
          ),
          dividerThickness: 0,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(
              label: Text(
                'Instrument',
                style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'IV',
              style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Delta',
              style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Theta',
              style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Gamma',
              style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Vega',
              style: MyntWebTextStyles.caption(
                context,
                darkColor: Colors.grey,
                lightColor: Colors.grey[600],
                fontWeight: MyntFonts.medium,
              ),
            ),
            numeric: true,
          ),
        ],
        rows: [
          ...provider.basket.where((item) => item.checkbox).map((item) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.buySell == 'BUY'
                              ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withOpacity(0.15)
                              : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.buySell == 'BUY' ? 'B' : 'S',
                          style: MyntWebTextStyles.caption(
                            context,
                            color: item.buySell == 'BUY' ? resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary) : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                            fontWeight: MyntFonts.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${item.ordlot} x ${item.tsym}',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textBlack,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(
                  item.iv?.toStringAsFixed(2) ?? '--',
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  item.delta?.toStringAsFixed(4) ?? '--',
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  item.theta?.toStringAsFixed(4) ?? '--',
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  item.gamma?.toStringAsFixed(4) ?? '--',
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  item.vega?.toStringAsFixed(4) ?? '--',
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
              ],
            );
          }),
          // Total row
          DataRow(
            cells: [
              DataCell(
                Text(
                  'Total',
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.bold,
                  ),
                ),
              ),
              const DataCell(Text('--')),
              DataCell(Text(
                provider.greeksTotal('delta').toStringAsFixed(4),
                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
              )),
              DataCell(Text(
                provider.greeksTotal('theta').toStringAsFixed(4),
                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
              )),
              DataCell(Text(
                provider.greeksTotal('gamma').toStringAsFixed(4),
                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
              )),
              DataCell(Text(
                provider.greeksTotal('vega').toStringAsFixed(4),
                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
              )),
            ],
          ),
        ],
      ),
      ),
      ),
    );
      },
    );
  }

  Widget _buildChartControls(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final hasData = provider.payoffData.isNotEmpty;

    // Sync target price controller with provider (only if value changed externally)
    final currentTargetPrice = provider.targetSpotPrice > 0 ? provider.targetSpotPrice : provider.spotPrice;
    if ((_lastEmittedTargetPrice - currentTargetPrice).abs() > 0.001) {
      _targetPriceController.text = currentTargetPrice.toStringAsFixed(2);
      _lastEmittedTargetPrice = currentTargetPrice;
    }

    final percentChange = _getPercentChange(provider.targetSpotPrice, provider.spotPrice);
    final percentPrefix = percentChange.startsWith('-') ? '' : '+';

    final labelStyle = MyntWebTextStyles.caption(
      context,
      darkColor: Colors.grey,
      lightColor: Colors.grey[700],
      fontWeight: MyntFonts.medium,
    ).copyWith(fontSize: 11);

    final resetStyle = MyntWebTextStyles.caption(
      context,
      color: MyntColors.primary,
      fontWeight: MyntFonts.bold,
    ).copyWith(fontSize: 11);

    final valueStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textBlack,
      fontWeight: MyntFonts.semiBold,
    ).copyWith(fontSize: 13);

    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('${provider.selectedSymbol.split(' ')[0]} Target', style: labelStyle),
              const SizedBox(width: 8),
              InkWell(
                onTap: hasData ? () => provider.resetTargetSpotPrice() : null,
                child: Text('Reset', style: resetStyle),
              ),
              const SizedBox(width: 8),
              Text('$percentPrefix$percentChange%', style: labelStyle),
              const Spacer(),
              Container(
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (!hasData) return;
                        provider.setTargetSpotPrice(provider.targetSpotPrice - (provider.spotPrice * 0.005));
                      },
                      child: Container(
                        width: 28, height: 28, alignment: Alignment.center,
                        child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                    VerticalDivider(width: 1, color: borderColor),
                    SizedBox(
                      width: 90,
                      height: 28,
                      child: TextField(
                        controller: _targetPriceController,
                        style: valueStyle,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final price = double.tryParse(val);
                          if (price != null && hasData) {
                            _lastEmittedTargetPrice = price;
                            provider.setTargetSpotPrice(price);
                          }
                        },
                      ),
                    ),
                    VerticalDivider(width: 1, color: borderColor),
                    InkWell(
                      onTap: () {
                        if (!hasData) return;
                        provider.setTargetSpotPrice(provider.targetSpotPrice + (provider.spotPrice * 0.005));
                      },
                      child: Container(
                        width: 28, height: 28, alignment: Alignment.center,
                        child: Icon(Icons.add, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
              inactiveTrackColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              thumbColor: Colors.white,
              overlayColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.08),
              thumbShape: _TradingSliderThumbShape(
                enabledThumbRadius: 7,
                borderColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: (provider.targetSpotPrice > 0
                  ? provider.targetSpotPrice
                  : provider.spotPrice).clamp(provider.spotPrice * 0.8, provider.spotPrice * 1.2),
              min: provider.spotPrice * 0.8,
              max: provider.spotPrice * 1.2,
              onChanged: hasData ? (value) => provider.setTargetSpotPrice(value) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatExpiry(String expiry) {
    if (expiry.length > 7) {
      return expiry.substring(0, 7);
    }
    return expiry;
  }

  String _getPercentChange(double current, double original) {
    if (original == 0) return '0.0';
    final change = ((current - original) / original) * 100;
    return change.toStringAsFixed(1);
  }
}

/// Payoff data point for chart
class _PayoffData {
  final double price;
  final double payoff;

  _PayoffData({required this.price, required this.payoff});
}

/// Trading-app style slider thumb with shadow, fill, and accent border ring
class _TradingSliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final Color borderColor;
  final double borderWidth;

  const _TradingSliderThumbShape({
    this.enabledThumbRadius = 7,
    this.borderColor = Colors.blue,
    this.borderWidth = 2.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius + 2);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Shadow
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center.translate(0, 1), radius: enabledThumbRadius + 1));
    canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.25), 3.0, true);

    // White outer ring/background
    canvas.drawCircle(
      center,
      enabledThumbRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Inner solid blue core
    canvas.drawCircle(
      center,
      enabledThumbRadius - 2.0, // Create a 2px white ring effect
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill,
    );
  }
}

/// Strategy Builder Panel - Embeddable panel version for use within CustomizableSplitHomeScreen
/// This version has no Scaffold/AppBar and fits directly into the panel layout
class StrategyBuilderPanelWeb extends ConsumerStatefulWidget {
  const StrategyBuilderPanelWeb({super.key});

  @override
  ConsumerState<StrategyBuilderPanelWeb> createState() => _StrategyBuilderPanelWebState();
}

class _StrategyBuilderPanelWebState extends ConsumerState<StrategyBuilderPanelWeb>
    with SingleTickerProviderStateMixin {
  late TabController _strategyTabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _lotMultiplierController = TextEditingController(text: '1');
  final TextEditingController _targetPriceController = TextEditingController();
  double _lastEmittedTargetPrice = 0;
  String _lastSelectedSymbol = '';
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();

  // Payoff chart tooltip state — uses ValueNotifier to avoid full widget rebuild on hover
  final ValueNotifier<_PayoffTooltipState> _tooltipNotifier = ValueNotifier(const _PayoffTooltipState());
  bool _isDragging = false;
  int _tooltipUpdateCounter = 0;
  // Keep _selectedPrice accessible for chart marker dot rendering
  double? _selectedPrice;
  bool _markerUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _strategyTabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(strategyBuilderProvider);
      // Skip initialization in analyze mode (data already loaded from positions)
      if (!provider.isAnalyzeMode) {
        provider.initialize(context);
      }
      // Initialize search controller with selected symbol
      _searchController.text = provider.selectedSymbol;
      _lastSelectedSymbol = provider.selectedSymbol;
    });

    _strategyTabController.addListener(() {
      final tabs = ['Bullish', 'Bearish', 'Neutral', 'CustomBuilder'];
      ref.read(strategyBuilderProvider).setStrategyTypeTab(tabs[_strategyTabController.index]);
    });

    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        ref.read(strategyBuilderProvider).searchStocks('');
      }
    });
  }

  @override
  void dispose() {
    _strategyTabController.dispose();
    _searchController.dispose();
    _lotMultiplierController.dispose();
    _targetPriceController.dispose();
    _tooltipNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(strategyBuilderProvider);
    final theme = ref.watch(themeProvider);
    final isDark = theme.isDarkMode;

    // Sync search controller with selected symbol when it changes
    if (provider.selectedSymbol != _lastSelectedSymbol && provider.searchResults.isEmpty) {
      _lastSelectedSymbol = provider.selectedSymbol;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.text = provider.selectedSymbol;
        }
      });
    }

    // Auto-show option chain dialog when flag is set (dialog will show loader inside)
    if (provider.shouldShowOptionChain) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.shouldShowOptionChain) {
          provider.clearShouldShowOptionChain();
          _showOptionChainDialog(context, provider, isDark);
        }
      });
    }

    // Don't return loader here - show it as overlay instead to preserve text field state

    // Use screen width to determine layout - more reliable than panel constraints
    final screenWidth = MediaQuery.of(context).size.width;
    // Switch to single column when screen width is less than 1200px (typical tablet/small desktop)
    // This accounts for watchlist panel taking ~350px on the left
    final isNarrow = screenWidth < 1300;

    final Widget content;
    if (isNarrow) {
      content = _buildNarrowPanelLayout(context, provider, isDark);
    } else {
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel - Basket & Strategies
            Expanded(
              flex: 1,
              child: _buildLeftPanel(context, provider, isDark),
            ),
            const SizedBox(width: 16),
            // Right Panel - Metrics & Chart
            Expanded(
              flex: 1,
              child: _buildRightPanel(context, provider, isDark),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (provider.searchDropdownVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => provider.dismissSearchDropdown(),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        _buildSearchDropdownOverlay(context, provider, isDark),
      ],
    );
  }

  /// Build layout for narrow panels (single column scrollable)
  Widget _buildNarrowPanelLayout(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basket Card with search and table
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: Column(
              children: [
                // Search bar (hidden in analyze mode) or analyze header
                if (provider.isAnalyzeMode)
                  _buildAnalyzeHeader(context, provider, isDark)
                else
                  _buildSearchSection(context, provider, isDark),
                const Divider(height: 1),
                // Show leg builder when Custom Builder tab is selected, otherwise show basket table
                // Basket table (limited height)
                SizedBox(
                  height: provider.basket.isEmpty ? 100 : (provider.basket.length * 50.0 + 50).clamp(100, 200),
                  child: Stack(
                    children: [
                      _buildBasketTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.basket.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lot multiplier and action buttons (hidden in analyze mode)
                if (provider.basket.isNotEmpty && !provider.isAnalyzeMode)
                  _buildBottomActions(context, provider, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Metrics section (compact for narrow panels)
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: _buildMetricsSectionNarrow(context, provider, isDark),
          ),
          const SizedBox(height: 12),
          // Payoff Chart section
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: Column(
              children: [
                // Tabs
                _buildPayoffTabs(context, provider, isDark),
                const Divider(height: 1),
                // Chart or Greeks table (fixed height)
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      provider.payoffTab == 0
                          ? _buildPayoffChart(context, provider, isDark)
                          : _buildGreeksTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.payoffData.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Strategies Card (hidden in analyze mode)
          if (!provider.isAnalyzeMode) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? MyntColors.overlayBgDark : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Column(
                children: [
                  // Strategy tabs
                  TabBar(
                    controller: _strategyTabController,
                    labelColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    unselectedLabelColor: isDark ? Colors.grey : Colors.grey[600],
                    indicatorColor:resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    labelStyle: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.medium,
                    ),
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Bullish'),
                      Tab(text: 'Bearish'),
                      Tab(text: 'Neutral'),
                      Tab(text: 'Custom Builder'),
                    ],
                  ),
                  const Divider(height: 1),
                  // Strategy grid
                  if (provider.strategyTypeTab == 'CustomBuilder')
                    _buildStrategyGrid(context, provider, isDark)
                  else
                    SizedBox(
                      height: 180,
                      child: _buildStrategyGrid(context, provider, isDark),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Chart controls
          Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            child: (provider.isLoading && provider.isAnalyzeMode)
                ? _buildChartControlsSkeleton(isDark)
                : _buildChartControls(context, provider, isDark),
          ),
          const SizedBox(height: 60), // Bottom padding
        ],
      ),
    );
  }

  /// Build compact metrics section for narrow panels
  Widget _buildMetricsSectionNarrow(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.isLoading && provider.isAnalyzeMode) {
      return _buildMetricsSkeleton(isDark);
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Row 1: MAX PROFIT, MAX LOSS, NET PREMIUM, MARGIN
          Row(
            children: [
              _buildMetricItemNarrow(context, 'MAX PROFIT', provider.metrics.maxProfit, MyntColors.profit, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, 'MAX LOSS', provider.metrics.maxLoss, isDark ? MyntColors.errorDark : MyntColors.loss, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(
                context,
                'NET PREMIUM',
                provider.netPremium.abs().toIndianFormat(),
                provider.netPremium > 0
                    ? (isDark ? MyntColors.profitDark : MyntColors.profit)
                    : provider.netPremium < 0
                        ? (isDark ? MyntColors.errorDark : MyntColors.loss)
                        : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                isDark,
              ),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, 'MARGIN', provider.totalMargin, null, isDark),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: POP, REWARD/RISK, BREAKEVEN (MARGIN BENEFIT hidden)
          Row(
            children: [
              // MARGIN BENEFIT hidden
              // _buildMetricItemNarrow(context, 'MARGIN BENEFIT', provider.marginBenefit, isDark ? MyntColors.profitDark : MyntColors.profit, isDark),
              // const SizedBox(width: 8),
              _buildMetricItemNarrow(context, 'POP', '${provider.metrics.popPercent.toStringAsFixed(0)}%', null, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, 'REWARD/RISK', provider.metrics.riskRewardRatio, null, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(
                context,
                'BREAKEVEN',
                '--',
                null,
                isDark,
                valueWidget: provider.metrics.breakevens.isNotEmpty
                    ? _buildBreakevenRichText(provider, MyntWebTextStyles.bodySmall(
                        context,
                        color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                        fontWeight: MyntFonts.semiBold,
                      ).copyWith(fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Row 3: Greeks
          Row(
            children: [
              _buildMetricItemNarrow(context, '\u0394 DELTA', provider.greeksTotal('delta').toStringAsFixed(4), null, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, '\u0398 THETA', provider.greeksTotal('theta').toStringAsFixed(4), null, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, '\u0393 GAMMA', provider.greeksTotal('gamma').toStringAsFixed(4), null, isDark),
              const SizedBox(width: 8),
              _buildMetricItemNarrow(context, '\u03BD VEGA', provider.greeksTotal('vega').toStringAsFixed(4), null, isDark),
            ],
          ),
        ],
      ),
    );
  }

  /// Build compact metric item for narrow panels
  Widget _buildMetricItemNarrow(BuildContext context, String label, String value, Color? valueColor, bool isDark, {bool isExpanded = true, Widget? valueWidget}) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? MyntColors.overlayBgDark : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithInfo(
            context,
            Text(
              label,
              style: MyntWebTextStyles.caption(
                context,
                color: Colors.grey,
                fontWeight: MyntFonts.medium,
              ).copyWith(fontSize: 11),
            ),
            (label == 'MARGIN' &&
                    ref.read(strategyBuilderProvider).basketMarginModel != null)
                ? () => showMarginInfoDialog(context, isDark)
                : null,
          ),
          const SizedBox(height: 2),
          valueWidget ?? Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: valueColor ?? (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
              fontWeight: MyntFonts.semiBold,
            ).copyWith(fontSize: 14), 
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return isExpanded ? Expanded(child: content) : content;
  }

  Widget _buildLeftPanel(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Column(
      children: [
        // Basket Card
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? MyntColors.dashboardCarColor : MyntColors.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? MyntColors.dividerDark : MyntColors.divider,
              ),
            ),
            child: Column(
              children: [
                // Search bar (hidden in analyze mode) or analyze header
                if (provider.isAnalyzeMode)
                  _buildAnalyzeHeader(context, provider, isDark)
                else
                  _buildSearchSection(context, provider, isDark),
                const Divider(height: 1),
                // Basket table
                Expanded(
                  child: Stack(
                    children: [
                      _buildBasketTable(context, provider, isDark),
                      if (provider.isPayoffLoading && provider.basket.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lot multiplier and action buttons (hidden in analyze mode)
                if (provider.basket.isNotEmpty && !provider.isAnalyzeMode)
                  _buildBottomActions(context, provider, isDark),
              ],
            ),
          ),
        ),
        // Strategies Card (hidden in analyze mode)
        if (!provider.isAnalyzeMode) ...[
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? MyntColors.dashboardCarColor : MyntColors.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? MyntColors.dividerDark : MyntColors.divider,
                ),
              ),
              child: Column(
                children: [
                  // Strategy tabs
                  TabBar(
                    controller: _strategyTabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    unselectedLabelColor: isDark ? Colors.grey : Colors.grey[600],
                    indicatorColor:resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                    labelStyle: MyntWebTextStyles.bodySmall(
                      context,
                      fontWeight: MyntFonts.medium,
                    ),
                    tabs: const [
                      Tab(text: 'Bullish'),
                      Tab(text: 'Bearish'),
                      Tab(text: 'Neutral'),
                      Tab(text: 'Custom Builder'),
                    ],
                  ),
                  const Divider(height: 1),
                  // Strategy grid
                  Expanded(
                    child: _buildStrategyGrid(context, provider, isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeHeader(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategyAnalyzeHeader(context: context, provider: provider, isDark: isDark);
  }

  Widget _buildSearchSection(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategySearchSection(
      context: context,
      searchController: _searchController,
      provider: provider,
      isDark: isDark,
      placeholder: 'Search & add',
      chainButtonLabel: 'Chain',
      buttonHeight: 45,
      showClearButton: false,
      onChainPressed: provider.optionChain.isNotEmpty
          ? () => _showOptionChainDialog(context, provider, isDark)
          : null,
      onRefreshPressed: () => provider.refreshEntryPrices(context),
      onClearBasket: () => provider.clearBasket(),
      onSearchChanged: (value) => provider.searchStocks(value),
      onClearSearch: () {
        _searchController.clear();
        provider.searchStocks('');
      },
      searchLayerLink: _searchLayerLink,
      searchFieldKey: _searchFieldKey,
    );
  }

  Widget _buildSearchDropdownOverlay(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return buildStrategySearchDropdown(
      context: context,
      provider: provider,
      isDark: isDark,
      searchController: _searchController,
      onStockSelected: (result) => provider.selectStock(result, context),
      onLastSelectedSymbolChanged: (name) => _lastSelectedSymbol = name,
      searchLayerLink: _searchLayerLink,
      searchFieldKey: _searchFieldKey,
      onDismiss: () => provider.dismissSearchDropdown(),
    );
  }

  void _showOptionChainDialog(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    // Show as a side panel using general dialog for custom animation - OPENS FROM LEFT
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Option Chain',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Consumer(
          builder: (context, ref, child) {
            final watchedProvider = ref.watch(strategyBuilderProvider);
            return Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: isDark ? MyntColors.overlayBgDark: Colors.white,
                elevation: 16,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                ),
                child: SizedBox(
                   width: MediaQuery.of(context).size.width < 660
                      ? MediaQuery.of(context).size.width * 0.95
                      : 620,
                  height: double.infinity,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Symbol name
                            Text(
                              watchedProvider.selectedSymbol,
                              style: MyntWebTextStyles.body(
                                context,
                                darkColor: MyntColors.textPrimaryDark,
                                lightColor: MyntColors.textBlack,
                                fontWeight: MyntFonts.semiBold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Spot Price
                            if (watchedProvider.spotPrice > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  watchedProvider.spotPrice.toIndianFormat(),
                                  style: MyntWebTextStyles.bodySmall(
                                    context,
                                    color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                                    fontWeight: MyntFonts.semiBold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            // Expiry dropdown with days
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? MyntColors.cardHoverDark : MyntColors.cardHover,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: watchedProvider.selectedExpiry.isEmpty || !watchedProvider.expiryDates.contains(watchedProvider.selectedExpiry) ? null : watchedProvider.selectedExpiry,
                                  hint: Text(watchedProvider.selectedExpiry.isNotEmpty ? watchedProvider.selectedExpiry : 'Expiry'),
                                  dropdownColor: isDark ? MyntColors.cardHoverDark : MyntColors.cardHover,
                                  isDense: true,
                                  icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.grey : Colors.black54),
                                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                                  items: watchedProvider.expiryDates.map((expiry) {
                                    final daysText = watchedProvider.selectedExpiry == expiry ? ' ${watchedProvider.daysToExpiry}(D)' : '';
                                    return DropdownMenuItem(value: expiry, child: Text('$expiry$daysText'));
                                  }).toList(),
                                  onChanged: watchedProvider.isLoading ? null : (value) {
                                    if (value != null) watchedProvider.setSelectedExpiry(value, context);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Strike count dropdown
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? MyntColors.cardHoverDark : MyntColors.cardHover,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: watchedProvider.selectedStrikeCount,
                                   dropdownColor: isDark ? MyntColors.cardHoverDark : MyntColors.cardHover,
                                  isDense: true,
                                  icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.grey : Colors.black54),
                                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                                  items: [10, 15, 20, 25].map((count) => DropdownMenuItem(value: count, child: Text('$count Strike'))).toList(),
                                  onChanged: watchedProvider.isLoading ? null : (value) {
                                    if (value != null) {
                                      watchedProvider.setStrikeCount(value, context);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Close button
                            InkWell(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Icon(Icons.close, color: isDark ? Colors.grey : Colors.grey[600], size: 20),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),

                      // Show loader or content
                      if (watchedProvider.isLoading)
                        const Expanded(child: Center(child: MyntLoader(size: MyntLoaderSize.medium)))
                      else ...[
                        // Call/Put section headers
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              // Call header
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Text('<', style: TextStyle(color: resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit), fontWeight: FontWeight.bold)),
                                    // const SizedBox(width: 4),
                                    // Text('>', style: TextStyle(color: resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit), fontWeight: FontWeight.bold)),
                                    // const SizedBox(width: 8),
                                    Text('CALLS', style: MyntWebTextStyles.bodySmall(context, color: resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit), fontWeight: MyntFonts.semiBold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 80),
                              // Put header
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Text('<', style: TextStyle(color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss), fontWeight: FontWeight.bold)),
                                    // const SizedBox(width: 4),
                                    // Text('>', style: TextStyle(color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss), fontWeight: FontWeight.bold)),
                                    // const SizedBox(width: 8),
                                    Text('PUTS', style: MyntWebTextStyles.bodySmall(context, color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss), fontWeight: MyntFonts.semiBold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table headers
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text('OI(ch)', textAlign: TextAlign.center, style: MyntWebTextStyles.caption(context, color:resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textBlack)))),
                              Expanded(child: Text('LTP', textAlign: TextAlign.center, style: MyntWebTextStyles.caption(context, color:resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textBlack)))),
                              SizedBox(width: 80, child: Text('STRIKES', textAlign: TextAlign.center, style: MyntWebTextStyles.caption(context, color:resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textBlack), fontWeight: MyntFonts.bold))),
                              Expanded(child: Text('LTP', textAlign: TextAlign.center, style: MyntWebTextStyles.caption(context, color:resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textBlack)))),
                              Expanded(child: Text('OI(ch)', textAlign: TextAlign.center, style: MyntWebTextStyles.caption(context, color:resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textBlack)))),
                            ],
                          ),
                        ),

                        // Option chain table
                        Expanded(
                          child: _buildPanelOptionChainTable(context, watchedProvider, isDark),
                        ),

                        // Footer with OI totals and PCR
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _calculateTotalOI(watchedProvider, 'CE'),
                                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium),
                              ),
                              Text(
                                'PCR: ${_calculatePCR(watchedProvider)}',
                                style: MyntWebTextStyles.bodySmall(context, color: Colors.grey, fontWeight: MyntFonts.medium),
                              ),
                              Text(
                                _calculateTotalOI(watchedProvider, 'PE'),
                                style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuad)),
          child: child,
        );
      },
    );
  }

  String _calculateTotalOI(StrategyBuilderProvider provider, String optt) {
    double total = 0;
    for (var option in provider.optionChain) {
      if (option.optt == optt) {
        total += double.tryParse(option.oi ?? '0') ?? 0;
      }
    }
    if (total >= 100000) return (total / 100000).toIndianFormat();
    return total.toIndianFormat();
  }

  String _calculatePCR(StrategyBuilderProvider provider) {
    double ceOI = 0, peOI = 0;
    for (var option in provider.optionChain) {
      if (option.optt == 'CE') {
        ceOI += double.tryParse(option.oi ?? '0') ?? 0;
      } else if (option.optt == 'PE') {
        peOI += double.tryParse(option.oi ?? '0') ?? 0;
      }
    }
    if (ceOI == 0) return '0.00';
    return (peOI / ceOI).toStringAsFixed(2);
  }

  Widget _buildHeaderCell(BuildContext context, String title, String subtitle, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: MyntWebTextStyles.caption(context, color: isDark ? Colors.white70 : Colors.black87, fontWeight: MyntFonts.medium)),
        Text(
          '($subtitle)',
          style: MyntWebTextStyles.caption(
            context,
            color: Colors.grey,
          ).copyWith(fontSize: 10),
        ),
      ],
    );
  }

  /// Panel version of Option Chain - Matches OptionChainSSWeb logic and layout
  Widget _buildPanelOptionChainTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.optionChain.isEmpty) {
      return const Center(child: Text('No option chain data available'));
    }

    // Build StrikeRowData list from optionChain
    final Map<String, Map<String, OptionValues>> strikeData = {};
    for (var option in provider.optionChain) {
      final strike = option.strprc ?? '';
      if (strike.isEmpty) continue;
      strikeData.putIfAbsent(strike, () => {});
      strikeData[strike]![option.optt ?? ''] = option;
    }

    final sortedStrikes = strikeData.keys.toList()
      ..sort((a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));

    // Find ATM index
    int atmIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < sortedStrikes.length; i++) {
      final diff = ((double.tryParse(sortedStrikes[i]) ?? 0) - provider.spotPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmIndex = i;
      }
    }

    // Limit strikes above and below spot based on selected strike count
    final int strikeRange = provider.selectedStrikeCount;
    final int startIndex = (atmIndex - strikeRange).clamp(0, sortedStrikes.length);
    final int endIndex = (atmIndex + strikeRange).clamp(0, sortedStrikes.length);
    final limitedStrikes = sortedStrikes.sublist(startIndex, endIndex);

    final List<_StrategyStrikeRowData> strikeRows = [];
    for (var strike in limitedStrikes) {
      strikeRows.add(_StrategyStrikeRowData(
        strikePrice: strike,
        isATM: strike == sortedStrikes[atmIndex],
        callOption: strikeData[strike]?['CE'],
        putOption: strikeData[strike]?['PE'],
      ));
    }

    // Find where to insert spot price row
    int spotInsertIndex = strikeRows.length;
    for (int i = 0; i < strikeRows.length; i++) {
      final strikePrice = double.tryParse(strikeRows[i].strikePrice) ?? 0;
      if (strikePrice >= provider.spotPrice) {
        spotInsertIndex = i;
        break;
      }
    }

    // Total items = strikes + 1 for spot price row
    final totalItems = strikeRows.length + 1;

    return ListView.builder(
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == spotInsertIndex) {
          return _buildSpotPriceRow(context, provider, isDark);
        }
        final strikeIndex = index > spotInsertIndex ? index - 1 : index;
        final row = strikeRows[strikeIndex];
        return _buildPanelOptionChainRow(context, provider, row, isDark);
      },
    );
  }

  Widget _buildSpotPriceRow(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final pct = provider.spotPriceChangePercent;
    final isPositive = pct >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF333333) : const Color(0xFF424242),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${provider.spotPrice.toIndianFormat()} (${isPositive ? '' : ''}${pct.toStringAsFixed(2)}%)',
            style: MyntWebTextStyles.bodySmall(
              context,
              color: Colors.white,
              fontWeight: MyntFonts.semiBold,
            ),
          ),
        ),
      ),
    );
  }

  /// Build a single option chain row matching OptionChainRowWeb visual logic
  Widget _buildPanelOptionChainRow(BuildContext context, StrategyBuilderProvider provider, _StrategyStrikeRowData row, bool isDark) {
    // final strikePrice = double.tryParse(row.strikePrice) ?? 0;
    
    // Background Colors
    // final itmColor = isDark ? const Color(0xFF2C2C23) : const Color(0xFFFFFBE6);

    // Check if CE/PE at this strike is in the basket
    final ceToken = row.callOption?.token ?? '';
    final peToken = row.putOption?.token ?? '';
    final ceInBasket = ceToken.isNotEmpty
        ? provider.basket.where((b) => b.token == ceToken).firstOrNull
        : null;
    final peInBasket = peToken.isNotEmpty
        ? provider.basket.where((b) => b.token == peToken).firstOrNull
        : null;

    // Basket highlight colors
    Color? ceBasketBg;
    Color? ceBasketBorder;
    if (ceInBasket != null) {
      final isBuy = ceInBasket.buySell == 'BUY';
      ceBasketBg = isBuy
          ? (isDark ? const Color(0xFF0D2818) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFF2D1215) : const Color(0xFFFCE4EC));
      ceBasketBorder = isBuy ? MyntColors.profit : MyntColors.loss;
    }

    Color? peBasketBg;
    Color? peBasketBorder;
    if (peInBasket != null) {
      final isBuy = peInBasket.buySell == 'BUY';
      peBasketBg = isBuy
          ? (isDark ? const Color(0xFF0D2818) : const Color(0xFFE8F5E9))
          : (isDark ? const Color(0xFF2D1215) : const Color(0xFFFCE4EC));
      peBasketBorder = isBuy ? MyntColors.profit : MyntColors.loss;
    }

    return Consumer(
      builder: (context, ref, child) {
        // Watch WebSocket data safe access
        final callSocketData = row.callOption != null
            ? ref.watch(websocketProvider.select((p) => p.socketDatas[row.callOption!.token]))
            : null;
        final putSocketData = row.putOption != null
            ? ref.watch(websocketProvider.select((p) => p.socketDatas[row.putOption!.token]))
            : null;

        return Container(
          height: 52, 
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // CALL SIDE
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: ceBasketBg,
                    border: ceBasketBorder != null
                        ? Border(right: BorderSide(color: ceBasketBorder, width: 3))
                        : null,
                  ),
                  child: _buildSideCell(context, provider, row.callOption, callSocketData, isDark, true, ceBasketBg != null),
                ),
              ),
              
              // STRIKE
              Container(
                width: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: row.isATM ? (isDark ? const Color(0xFF323F4B) : const Color(0xFFD3D9E9)) : null, // Darker highlight for ATM
                  border: Border.symmetric(vertical: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 0.5)),
                ),
                child: Text(
                  row.strikePrice,
                  style: MyntWebTextStyles.body(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: row.isATM ? MyntFonts.bold : MyntFonts.medium,
                  ),
                ),
              ),
              
              // PUT SIDE
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: peBasketBg,
                    border: peBasketBorder != null
                        ? Border(left: BorderSide(color: peBasketBorder, width: 3))
                        : null,
                  ),
                  child: _buildSideCell(context, provider, row.putOption, putSocketData, isDark, false, peBasketBg != null),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideCell(BuildContext context, StrategyBuilderProvider provider, OptionValues? option, dynamic socketData, bool isDark, bool isCall, bool isSelected) {
    if (option == null) return const SizedBox();

    final Map<String, dynamic>? sData = (socketData is Map) ? socketData as Map<String, dynamic> : null;

    // Data parsing matching OptionChainRowWeb
    final lp = sData?['lp']?.toString() ?? option.lp ?? option.close ?? "0.00";
    final perChange = sData?['pc']?.toString() ?? option.perChange ?? "0.00";
    final currentOI = double.tryParse(sData?['oi']?.toString() ?? option.oi ?? "0") ?? 0.0;
    
    // OI in Lakhs
    final oiLack = (currentOI / 100000).toIndianFormat();
    
    // OI % Change
    final poi = double.tryParse(sData?['poi']?.toString() ?? option.poi ?? "0") ?? 0.0;
    String oiPerChng = "0.00";
    if (poi > 0) {
      oiPerChng = (((currentOI - poi) / poi) * 100).toStringAsFixed(2);
    }

    final changeColor = perChange.startsWith("-") 
        ?resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss) 
        : (perChange == "0.00" ? Colors.grey : resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit));
        
    final oiChangeColor = oiPerChng.startsWith("-")
        ?resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss)
        : (oiPerChng == "0.00" ? Colors.grey : resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit));

    // Watch so the bookmark icon updates immediately.
    final isInWatchlist = ref.watch(
      marketWatchProvider.select(
        (p) => p.scrips.any(
          (s) => "${s['exch']}|${s['token']}" == "${option.exch}|${option.token}",
        ),
      ),
    );

    // Reuse the same hover action button UI as the watchlist option chain.
    return HoverActionsWrapper(
      actionsAlignment: isCall ? Alignment.centerRight : Alignment.centerLeft,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 2),
      // Blue hover background (matches the watchlist option chain), but only
      // when this leg isn't already selected — a selected Buy/Sell leg keeps
      // its green/red selection background instead.
      hoverBackgroundColor: isSelected
          ? null
          : resolveThemeColor(context,
                  dark: MyntColors.primaryDark, light: MyntColors.primary)
              .withValues(alpha: 0.10),
      actionsBuilder: (ctx) => [
        HoverActionButton.buy(
          context: ctx,
          onPressed: () => provider.addToBasket(option, 'BUY', context),
        ),
        HoverActionButton.sell(
          context: ctx,
          onPressed: () => provider.addToBasket(option, 'SELL', context),
        ),
        // Chart Button — navigates to home and opens the option's chart
        HoverActionButton.icon(
          context: ctx,
          iconAsset: assets.chartnew,
          onPressed: () => _handleChartTapSB(option),
        ),
        HoverActionButton.icon(
          context: ctx,
          iconAsset: isInWatchlist
              ? assets.bookmarkIcon
              : assets.bookmarkLineIcon,
          iconColor: isInWatchlist
              ? resolveThemeColor(
                  ctx,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary,
                )
              : null,
          onPressed: () => _handleSaveToWatchlistSB(option),
        ),
      ],
      child: Row(
        children: [
          // Order depends on Call (Left) or Put (Right) side
          // CALL: [OI] [LTP]
          // PUT:  [LTP] [OI]
          
          // First Column (OI for Call, LTP for Put)
          Expanded(
            child: isCall 
              ? _buildStackedCell(context, oiLack, '$oiPerChng%', oiChangeColor, true, isDark)
              : _buildStackedCell(context, lp, '$perChange%', changeColor, false, isDark),
          ),
          
          // Second Column (LTP for Call, OI for Put)
          Expanded(
            child: isCall 
              ? _buildStackedCell(context, lp, '$perChange%', changeColor, false, isDark)
              : _buildStackedCell(context, oiLack, '$oiPerChng%', oiChangeColor, true, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedCell(BuildContext context, String mainValue, String subValue, Color subColor, bool isOI, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          mainValue,
          style: MyntWebTextStyles.bodySmall(
            context,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textBlack,
            fontWeight: MyntFonts.medium,
          ),
        ),
        Text(
          '(${subValue})',
          style: MyntWebTextStyles.caption(
            context,
            color: subColor,
          ).copyWith(fontSize: 10),
        ),
      ],
    );
  }

  /// Open this option's chart. The strategy builder is hosted inside
  /// CustomizableSplitHomeScreen, which owns the chart panel — so we close the
  /// option-chain dialog and open the chart in that panel (on the Chart tab),
  /// the same mechanism the watchlist option chain uses. No navigation, so the
  /// strategy (basket) is untouched.
  void _handleChartTapSB(OptionValues option) {
    if (option.tsym?.contains("|||") ?? false) {
      ResponsiveSnackBar.showWarning(
          context, "Symbol not available for trading");
      return;
    }

    final marketWatch = ref.read(marketWatchProvider);
    final depthArgs = DepthInputArgs(
      exch: option.exch?.toString() ?? '',
      token: option.token?.toString() ?? '',
      tsym: option.tsym?.toString() ?? '',
      instname: '',
      symbol: option.symbol?.toString() ?? option.tsym?.toString() ?? '',
      expDate: option.expDate?.toString() ?? '',
      option: option.option?.toString() ?? '',
      isOption: true,
    );

    // Close the option-chain dialog so the chart panel is visible.
    Navigator.of(context).pop();
    marketWatch.openOnChartTab = true;
    marketWatch.scripdepthsize(false);
    marketWatch.calldepthApis(context, depthArgs, "");
  }

  /// Add / remove this option to the current watchlist — mirrors the
  /// watchlist option-chain "Add to Watchlist" action.
  Future<void> _handleSaveToWatchlistSB(OptionValues option) async {
    final scripData = ref.read(marketWatchProvider);

    if (scripData.isPreDefWLs == "Yes") {
      ResponsiveSnackBar.showWarning(
          context, "This is a pre-defined watchlist that cannot be edited!");
      return;
    }

    final scripToken = "${option.exch}|${option.token}";
    final isCurrentlyInWatchlist = scripData.scrips
        .any((scrip) => "${scrip['exch']}|${scrip['token']}" == scripToken);

    if (isCurrentlyInWatchlist) {
      final success = await scripData.addDelMarketScrip(
          scripData.wlName, scripToken, context, false, true, false, false);
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Removed from your watchlist "${scripData.wlName}"');
      }
    } else {
      ref.read(websocketProvider).establishConnection(
            channelInput: scripToken,
            task: "d",
            context: context,
          );
      final success = await scripData.addDelMarketScrip(
          scripData.wlName, scripToken, context, true, true, false, false);
      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Added to your watchlist "${scripData.wlName}"');
      }
    }
  }

  Widget _buildBasketTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.basket.isEmpty) {
      // Show skeleton shimmer rows when loading in analyze mode
      if (provider.isLoading && provider.isAnalyzeMode) {
        return _buildBasketTableSkeleton(isDark);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "There's nothing here yet.",
              style: MyntWebTextStyles.body(
                context,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add some options to see them here.' ,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: provider.optionChain.isNotEmpty
                  ? () => _showOptionChainDialog(context, provider, isDark)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Create your Strategy',
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textBlack,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Add both horizontal and vertical scrolling for the basket table
    // Horizontal scrollbar is fixed at the bottom of the container
    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    final dataTable = DataTable(
      columnSpacing: 10,
      horizontalMargin: 8,
      headingRowHeight: 40,
      headingRowColor: WidgetStateProperty.all(
        isDark ? MyntColors.overlayBgDark : MyntColors.listItemBg,
      ),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(
          label: Checkbox(
            value: provider.isAllSelected,
            onChanged: (value) => provider.toggleAllCheckboxes(value ?? false, context),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            // side: isDark ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
          ),
        ),
        DataColumn(
          label: Text(
            'B/S',
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.regular,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Expiry',
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Strike',
           style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'CE/PE',
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Lots',
              textAlign: TextAlign.center,
             style: MyntWebTextStyles.bodySmall(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textBlack,
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'Entry Price',
           style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        DataColumn(
          label: Text(
            'LTP',
           style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
              fontWeight: MyntFonts.medium,
            ),
          ),
        ),
        const DataColumn(label: SizedBox()), // Delete action column
      ],
      rows: provider.basket.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _buildBasketRow(context, provider, item, index, isDark);
      }).toList(),
    );

    // Horizontal scrollbar (outer) appears at bottom, vertical scrollbar (inner) appears on right
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8),
            radius: const Radius.circular(4),
            thumbColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.6)),
            trackColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.2)),
            trackVisibility: WidgetStateProperty.all(true),
          ),
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    scrollDirection: Axis.vertical,
                    child: dataTable,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Skeleton shimmer for metrics section (MAX PROFIT, MAX LOSS, etc.)
  Widget _buildMetricsSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Row 1: 4 metric skeletons
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyntShimmerLoader(width: 70, height: 10, borderRadius: 4),
                    const SizedBox(height: 6),
                    MyntShimmerLoader(width: 50, height: 16, borderRadius: 4),
                  ],
                ),
              ),
            )),
          ),
          const SizedBox(height: 12),
          // Row 2: 3 metric skeletons + empty
          Row(
            children: [
              ...List.generate(3, (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyntShimmerLoader(width: 70, height: 10, borderRadius: 4),
                      const SizedBox(height: 6),
                      MyntShimmerLoader(width: 50, height: 16, borderRadius: 4),
                    ],
                  ),
                ),
              )),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  /// Skeleton shimmer for payoff chart area
  Widget _buildPayoffChartSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Y-axis labels + chart area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-axis shimmer labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (_) =>
                    const MyntShimmerLoader(width: 40, height: 10, borderRadius: 4),
                  ),
                ),
                const SizedBox(width: 8),
                // Chart area shimmer
                Expanded(
                  child: MyntShimmerLoader(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // X-axis shimmer labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (_) =>
              const MyntShimmerLoader(width: 40, height: 10, borderRadius: 4),
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton shimmer for Greeks row (DELTA, THETA, GAMMA, VEGA)
  Widget _buildGreeksRowSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(4, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyntShimmerLoader(width: 60, height: 10, borderRadius: 4),
                const SizedBox(height: 4),
                MyntShimmerLoader(width: 50, height: 14, borderRadius: 4),
              ],
            ),
          ),
        )),
      ),
    );
  }

  /// Skeleton shimmer for chart controls (target price slider + target date slider)
  Widget _buildChartControlsSkeleton(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          // Target price row
          Row(
            children: [
              const MyntShimmerLoader(width: 100, height: 12, borderRadius: 4),
              const SizedBox(width: 8),
              const MyntShimmerLoader(width: 36, height: 12, borderRadius: 4),
              const Spacer(),
              MyntShimmerLoader(width: 90, height: 28, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          // Slider shimmer
          const MyntShimmerLoader(width: double.infinity, height: 4, borderRadius: 2),
          const SizedBox(height: 14),
          // Target date row
          Row(
            children: [
              const MyntShimmerLoader(width: 140, height: 12, borderRadius: 4),
              const SizedBox(width: 8),
              const MyntShimmerLoader(width: 36, height: 12, borderRadius: 4),
              const Spacer(),
              MyntShimmerLoader(width: 130, height: 28, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          // Slider shimmer
          const MyntShimmerLoader(width: double.infinity, height: 4, borderRadius: 2),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Skeleton shimmer loader for basket table during analyze mode loading
  Widget _buildBasketTableSkeleton(bool isDark) {
    Widget shimmerCell(double width) => MyntShimmerLoader(width: width, height: 14, borderRadius: 4);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Skeleton header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? MyntColors.overlayBgDark : MyntColors.listItemBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                shimmerCell(20),
                const SizedBox(width: 16),
                shimmerCell(28),
                const SizedBox(width: 16),
                shimmerCell(52),
                const SizedBox(width: 16),
                shimmerCell(48),
                const SizedBox(width: 16),
                shimmerCell(36),
                const SizedBox(width: 16),
                shimmerCell(30),
                const SizedBox(width: 16),
                Expanded(child: shimmerCell(60)),
              ],
            ),
          ),
          // Skeleton data rows
          ...List.generate(3, (index) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
                ),
              ),
            ),
            child: Row(
              children: [
                shimmerCell(20),
                const SizedBox(width: 16),
                shimmerCell(28),
                const SizedBox(width: 16),
                shimmerCell(52),
                const SizedBox(width: 16),
                shimmerCell(48),
                const SizedBox(width: 16),
                shimmerCell(36),
                const SizedBox(width: 16),
                shimmerCell(30),
                const SizedBox(width: 16),
                Expanded(child: shimmerCell(60)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  DataRow _buildBasketRow(
    BuildContext context,
    StrategyBuilderProvider provider,
    StrategyBasketItem item,
    int index,
    bool isDark,
  ) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: item.checkbox,
            onChanged: (_) => provider.toggleCheckbox(index, context),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            side: isDark ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
          ),
        ),
        // Buy/Sell toggle
        DataCell(
          InkWell(
            onTap: () => provider.toggleBuySell(index, context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: item.buySell == 'BUY'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withOpacity(0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.buySell == 'BUY' ? 'B' : 'S',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: item.buySell == 'BUY' ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) 
                  : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Expiry Dropdown
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            decoration: BoxDecoration(
              border: Border.all(color: (isDark ? MyntColors.cardBorderDark : MyntColors.cardBorder)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.expiryDates.contains(item.expdate) ? item.expdate : null,
                hint: Text(item.expdate, style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12)),
                isDense: true,
                style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                onChanged: (val) {
                  if (val != null) provider.updateExpiry(index, val, context);
                },
                items: provider.expiryDates.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e, style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12)),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        // Strike Dropdown
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            decoration: BoxDecoration(
              border: Border.all(color: (isDark ? MyntColors.cardBorderDark : MyntColors.cardBorder)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: item.strprc,
                isDense: true,
                menuMaxHeight: 250,
                style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                onChanged: (val) {
                  if (val != null) provider.updateStrike(index, val, context);
                },
                items: provider.getStrikesForExpiry(item.expdate, currentStrike: item.strprc)
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        // CE/PE toggle
        DataCell(
          InkWell(
            onTap: () => provider.toggleCePe(index, context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.optt == 'CE'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withOpacity(0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.optt,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: item.optt == 'CE' ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Lots with - Input +
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () => provider.updateLots(index, item.ordlot - 1, context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: (isDark ? MyntColors.cardBorderDark : MyntColors.cardBorder)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.ordlot * provider.lotMultiplier}',
                  style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
               IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => provider.updateLots(index, item.ordlot + 1, context),
                 padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Entry Price
        DataCell(
          SizedBox(
            width: 90,
            child: EntryPriceTableInput(
              value: item.entryPrice,
              onChanged: (price) => provider.updateEntryPrice(index, price, context),
            ),
          ),
        ),
        // LTP
        DataCell(
          Text(
            item.ltp.toIndianFormat(),
            style: MyntWebTextStyles.bodySmall(
              context,
              darkColor: MyntColors.textPrimaryDark,
              lightColor: MyntColors.textBlack,
            ).copyWith(fontSize: 12),
          ),
        ),
        // Delete Action
        DataCell(
          IconButton(
            icon:  Icon(Icons.delete_outline, color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss), size: 20),
            onPressed: () => provider.removeFromBasket(index, context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lot Multiplier row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Lot Multiplier',
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: provider.lotMultiplier,
                      isDense: true,
                      menuMaxHeight: 300,
                      style: MyntWebTextStyles.bodySmall(
                        context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.semiBold,
                      ),
                      dropdownColor: isDark ? MyntColors.textPrimary : Colors.white,
                      items: List.generate(200, (i) => i + 1)
                          .map((val) => DropdownMenuItem<int>(
                                value: val,
                                child: Text('$val'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          provider.setLotMultiplier(val, context);
                          _lotMultiplierController.text = val.toString();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
          // Clear, Save, Place Order row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => provider.clearBasket(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: provider.isOrderLoading ? null : () => provider.placeOrder(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: const Size(100, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: provider.isOrderLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Place order',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: Colors.white,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyGrid(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final strategies = provider.filteredStrategies;
    final isCustomTab = provider.strategyTypeTab == 'CustomBuilder';
    final activeColor = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);

    if (strategies.isEmpty && !isCustomTab) {
      return Center(
        child: Text(
          'No strategies found.',
          textAlign: TextAlign.center,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leg builder (only for Custom Builder tab)
          if (isCustomTab) ...[
            _buildLegBuilder(context, provider, isDark),
            _buildLegBuilderBottomActions(context, provider, isDark),
          ],
          // Strategy cards
          if (strategies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: strategies.map((strategy) {
                  final isActive = provider.activePredefinedStrategy == strategy.title;
                  final showDelete = strategy.type == 'CustomBuilder';
                  return InkWell(
                    onTap: () => provider.setActivePredefinedStrategy(strategy, context),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? MyntColors.overlayBgDark : MyntColors.cardHover)
                                : (isDark ? MyntColors.cardDark : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? activeColor
                                  : (isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Strategy SVG image
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: SvgPicture.asset(
                                  strategy.image,
                                  width: 34,
                                  height: 34,
                                  placeholderBuilder: (context) => Icon(
                                    Icons.show_chart,
                                    color: isActive ? activeColor : resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                strategy.title,
                                style: MyntWebTextStyles.bodySmall(
                                  context,
                                  color: isActive
                                      ? activeColor
                                      : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                                  fontWeight: MyntFonts.medium,
                                ),
                              ),
                              // Extra space for delete icon
                              if (showDelete)
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                        // Delete button at top-right corner
                        if (showDelete)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _showDeleteCustomStrategyDialog(context, provider, strategy.title, isDark),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: isActive
                                      ? activeColor.withValues(alpha: 0.7)
                                      : (isDark ? Colors.grey : Colors.grey[600]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ,
        ],
      ),
    );
  }

  /// Leg builder section — shown above strategy tabs when on Custom Builder tab
  Widget _buildLegBuilder(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final draftLegs = provider.draftLegs;

    if (draftLegs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              "No legs defined yet.",
              style: MyntWebTextStyles.body(context, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Add legs to build your custom strategy.',
              style: MyntWebTextStyles.bodySmall(context, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => provider.addDraftLeg(),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Add Leg',
                style: MyntWebTextStyles.body(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    final ScrollController horizontalController = ScrollController();
    final ScrollController verticalController = ScrollController();

    final dataTable = DataTable(
      columnSpacing: 10,
      horizontalMargin: 8,
      headingRowHeight: 40,
      headingRowColor: WidgetStateProperty.all(
        isDark ? MyntColors.dividerDark : MyntColors.divider,
      ),
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      columns: [
        DataColumn(
          label: Checkbox(
            value: provider.isAllDraftLegsSelected,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            onChanged: (value) => provider.toggleAllDraftLegCheckboxes(value ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        DataColumn(
          label: Text('B/S',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('CE/PE',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Lots',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Exp Offset',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Strike Type',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        DataColumn(
          label: Text('Offset/Premium',
              style: MyntWebTextStyles.bodySmall(context,
                  darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack, fontWeight: MyntFonts.medium)),
        ),
        const DataColumn(label: SizedBox()),
      ],
      rows: draftLegs.asMap().entries.map((entry) {
        final index = entry.key;
        final draft = entry.value;
        return _buildDraftLegDataRow(context, provider, index, draft, isDark);
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(8),
            radius: const Radius.circular(4),
            thumbColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.6)),
            trackColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.2)),
            trackVisibility: WidgetStateProperty.all(true),
          ),
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    scrollDirection: Axis.vertical,
                    child: dataTable,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDraftLegDataRow(BuildContext context, StrategyBuilderProvider provider,
      int index, CustomStrategyLegDraft draft, bool isDark) {
    return DataRow(
      cells: [
        // Checkbox
        DataCell(
          Checkbox(
            value: draft.checkbox,
            activeColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
            checkColor: isDark ? Colors.white : null,
            onChanged: (value) {
              draft.checkbox = value ?? false;
              provider.updateDraftLeg(index, draft);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        // B/S toggle
        DataCell(
          InkWell(
            onTap: () {
              draft.action = draft.action == 'BUY' ? 'SELL' : 'BUY';
              provider.updateDraftLeg(index, draft);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: draft.action == 'BUY'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                draft.action == 'BUY' ? 'B' : 'S',
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: draft.action == 'BUY'
                      ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                      : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // CE/PE toggle
        DataCell(
          InkWell(
            onTap: () {
              draft.optionType = draft.optionType == 'CE' ? 'PE' : 'CE';
              provider.updateDraftLeg(index, draft);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: draft.optionType == 'CE'
                    ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.15)
                    : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                draft.optionType,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: draft.optionType == 'CE'
                      ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                      : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                  fontWeight: MyntFonts.bold,
                ).copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
        // Lots (+/- stepper)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: draft.ordlot > 1 ? () {
                  draft.ordlot--;
                  provider.updateDraftLeg(index, draft);
                } : null,
                child: const Icon(Icons.remove, size: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${draft.ordlot}',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  draft.ordlot++;
                  provider.updateDraftLeg(index, draft);
                },
                child: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        // Expiry Offset (+/- stepper)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: draft.expiryOffset > 0 ? () {
                  draft.expiryOffset--;
                  provider.updateDraftLeg(index, draft);
                } : null,
                child: const Icon(Icons.remove, size: 16),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${draft.expiryOffset}',
                  textAlign: TextAlign.center,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textBlack,
                    fontWeight: MyntFonts.medium,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  draft.expiryOffset++;
                  provider.updateDraftLeg(index, draft);
                },
                child: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        // Strike Type (PopupMenuButton dropdown)
        DataCell(
          PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 30),
            splashRadius: isDark ? 0 : null,
            color: isDark ? MyntColors.cardDark : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? MyntColors.cardDark : MyntColors.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    draft.strikeType == 'PREMIUM' ? 'P' : draft.strikeType,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ).copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark ? Colors.grey : Colors.grey[600],
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => ['ATM', 'ITM', 'OTM', 'PREMIUM']
                .map((type) => PopupMenuItem(
                      value: type,
                      child: Text(
                        type == 'PREMIUM' ? 'P (Premium)' : type,
                        style: MyntWebTextStyles.bodySmall(context).copyWith(fontSize: 12),
                      ),
                    ))
                .toList(),
            onSelected: (value) {
              draft.strikeType = value;
              if (value == 'PREMIUM') draft.strikeOffset = 0;
              provider.updateDraftLeg(index, draft);
            },
          ),
        ),
        // Offset / Premium value
        DataCell(
          draft.strikeType == 'PREMIUM'
              ? SizedBox(
                  width: 80,
                  child: EntryPriceTableInput(
                    value: draft.premiumValue,
                    onChanged: (price) {
                      draft.premiumValue = price;
                      provider.updateDraftLeg(index, draft);
                    },
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: draft.strikeOffset > 0 ? () {
                        draft.strikeOffset--;
                        provider.updateDraftLeg(index, draft);
                      } : null,
                      child: const Icon(Icons.remove, size: 16),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${draft.strikeOffset}',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textBlack,
                          fontWeight: MyntFonts.medium,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        draft.strikeOffset++;
                        provider.updateDraftLeg(index, draft);
                      },
                      child: const Icon(Icons.add, size: 16),
                    ),
                  ],
                ),
        ),
        // Delete
        DataCell(
          IconButton(
            onPressed: () => provider.removeDraftLeg(index),
            icon: Icon(Icons.delete_outline, size: 20, color: isDark ? MyntColors.lossDark : MyntColors.loss),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  /// Bottom actions for the custom strategy leg builder
  Widget _buildLegBuilderBottomActions(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add Leg row (similar to Lot Multiplier row)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => provider.addDraftLeg(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Add Leg',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(70, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
          // Clear, Save, Apply row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => provider.clearDraftLegs(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _showSaveCustomStrategyDialog(context, provider, isDark),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(60, 36),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: provider.isLoading ? null : () => provider.applyCustomStrategy(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary),
                    disabledBackgroundColor: resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary).withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize: const Size(100, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Apply',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: Colors.white,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Save custom strategy dialog
  void _showSaveCustomStrategyDialog(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final nameController = TextEditingController(text: provider.editingCustomBuilderName ?? '');
    final focusNode = FocusNode();

    // Request focus after dialog animation completes
    Future.delayed(const Duration(milliseconds: 250), () {
      focusNode.requestFocus();
      if (provider.editingCustomBuilderName != null && nameController.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 50), () {
          nameController.selection = TextSelection.collapsed(
            offset: nameController.text.length,
          );
        });
      }
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isUpdateMode = provider.editingCustomBuilderName != null &&
                nameController.text == provider.editingCustomBuilderName;
            return Center(
              child: Material(
                color: Colors.transparent,
                child: shadcn.Card(
                  borderRadius: BorderRadius.circular(8),
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: 400,
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: shadcn.Theme.of(context).colorScheme.border,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUpdateMode ? 'Update Custom Builder' : 'Save Custom Builder',
                                style: MyntWebTextStyles.title(
                                  context,
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary,
                                  ),
                                ),
                              ),
                              MyntCloseButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: MyntFormTextField(
                                        controller: nameController,
                                        focusNode: focusNode,
                                        placeholder: 'Enter strategy name',
                                        enabled: !isUpdateMode,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    if (isUpdateMode) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          nameController.clear();
                                          focusNode.requestFocus();
                                          setState(() {});
                                        },
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 24),
                                MyntPrimaryButton(
                                  size: MyntButtonSize.large,
                                  label: isUpdateMode ? 'Update' : 'Save',
                                  isFullWidth: true,
                                  onPressed: nameController.text.trim().isEmpty
                                      ? null
                                      : () {
                                          provider.saveCustomStrategy(nameController.text.trim(), context);
                                          Navigator.pop(dialogContext);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Delete custom strategy dialog
  void _showDeleteCustomStrategyDialog(BuildContext context, StrategyBuilderProvider provider, String strategyName, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: shadcn.Card(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              child: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 250),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: shadcn.Theme.of(context).colorScheme.border,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delete Strategy',
                            style: MyntWebTextStyles.title(
                              context,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                            ),
                          ),
                          MyntCloseButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Are you sure you want to delete "$strategyName"?',
                              textAlign: TextAlign.center,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: FontWeight.w500,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            MyntButton(
                              type: MyntButtonType.primary,
                              size: MyntButtonSize.large,
                              label: 'Delete',
                              isFullWidth: true,
                              backgroundColor: resolveThemeColor(
                                context,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary,
                              ),
                              onPressed: () {
                                provider.deleteCustomStrategy(strategyName, context);
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? MyntColors.dashboardCarColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          // Metrics section
          _buildMetricsSection(context, provider, isDark),
          const Divider(height: 1),
          // Tabs
          _buildPayoffTabs(context, provider, isDark),
          const Divider(height: 1),
          // Chart or Greeks table
          Expanded(
            child: Stack(
              children: [
                provider.payoffTab == 0
                    ? _buildPayoffChart(context, provider, isDark)
                    : _buildGreeksTable(context, provider, isDark),
                if (provider.isPayoffLoading && provider.payoffData.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
          ),
          // Greeks row
          const Divider(height: 1),
          if (provider.isLoading && provider.isAnalyzeMode)
            _buildGreeksRowSkeleton(isDark)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildMetricItem(context, '\u0394 DELTA', provider.greeksTotal('delta').toStringAsFixed(4), null, isDark),
                  _buildMetricItem(context, '\u0398 THETA', provider.greeksTotal('theta').toStringAsFixed(4), null, isDark),
                  _buildMetricItem(context, '\u0393 GAMMA', provider.greeksTotal('gamma').toStringAsFixed(4), null, isDark),
                  _buildMetricItem(context, '\u03BD VEGA', provider.greeksTotal('vega').toStringAsFixed(4), null, isDark),
                ],
              ),
            ),
          // Chart controls
          if (provider.isLoading && provider.isAnalyzeMode)
            _buildChartControlsSkeleton(isDark)
          else
            _buildChartControls(context, provider, isDark),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.isLoading && provider.isAnalyzeMode) {
      return _buildMetricsSkeleton(isDark);
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricItem(context, 'MAX PROFIT', provider.metrics.maxProfit, isDark ? MyntColors.profitDark : MyntColors.profit, isDark),
              _buildMetricItem(context, 'MAX LOSS', provider.metrics.maxLoss, isDark ? MyntColors.lossDark : MyntColors.loss, isDark),
              _buildMetricItem(
                context,
                'NET PREMIUM',
                // Show absolute value - color indicates if it's credit (green) or debit (red)
                provider.netPremium.abs().toIndianFormat(),
                provider.netPremium > 0
                    ? (isDark ? MyntColors.profitDark : MyntColors.profit)
                    : provider.netPremium < 0
                        ? (isDark ? MyntColors.lossDark : MyntColors.loss)
                        : (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
                isDark,
              ),
              _buildMetricItem(context, 'MARGIN', provider.totalMargin, null, isDark),
              // MARGIN BENEFIT hidden
              // _buildMetricItem(context, 'MARGIN BENEFIT', provider.marginBenefit, isDark ? MyntColors.profitDark : MyntColors.profit, isDark),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricItem(context, 'POP', '${provider.metrics.popPercent.toStringAsFixed(0)}%', null, isDark),
              _buildMetricItem(context, 'REWARD/RISK', provider.metrics.riskRewardRatio, null, isDark),
              _buildMetricItem(
                context,
                'BREAKEVEN',
                '--',
                null,
                isDark,
                valueWidget: provider.metrics.breakevens.isNotEmpty
                    ? _buildBreakevenRichText(provider, MyntWebTextStyles.bodySmall(
                        context,
                        color: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                        fontWeight: MyntFonts.medium,
                      ).copyWith(fontSize: 14))
                    : null,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, Color? valueColor, bool isDark, {Widget? valueWidget}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithInfo(
            context,
            Text(
              label,
              style: MyntWebTextStyles.caption(
                context,
                color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                fontWeight: MyntFonts.medium,
              ).copyWith(fontSize: 11),
            ),
            (label == 'MARGIN' &&
                    ref.read(strategyBuilderProvider).basketMarginModel != null)
                ? () => showMarginInfoDialog(context, isDark)
                : null,
          ),
          const SizedBox(height: 2),
          valueWidget ?? Text(
            value,
            style: MyntWebTextStyles.bodySmall(
              context,
              color: valueColor ?? (isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack),
              fontWeight: MyntFonts.medium,
            ).copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakevenRichText(StrategyBuilderProvider provider, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final breakevens = provider.metrics.breakevens;
    for (int i = 0; i < breakevens.length; i++) {
      final b = breakevens[i];
      final pct = provider.spotPrice > 0 ? ((b - provider.spotPrice) / provider.spotPrice) * 100 : 0.0;
      if (i > 0) spans.add(TextSpan(text: '  |  ', style: baseStyle));
      spans.add(TextSpan(text: b.toIndianFormat(), style: baseStyle));
      spans.add(TextSpan(
        text: ' (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
        style: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) - 3, color: Colors.grey),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildPayoffTabs(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    // final hasData = provider.payoffData.isNotEmpty;
    // final targetDate = DateTime.now().add(Duration(days: provider.targetDaysToExpiry));
    // final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    // final labelStyle = MyntWebTextStyles.caption(
    //   context,
    //   darkColor: Colors.grey,
    //   lightColor: Colors.grey[700],
    //   fontWeight: MyntFonts.medium,
    // ).copyWith(fontSize: 11);
    // final resetStyle = MyntWebTextStyles.caption(
    //   context,
    //   color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
    //   fontWeight: MyntFonts.bold,
    // ).copyWith(fontSize: 11);
    // final valueStyle = MyntWebTextStyles.bodySmall(
    //   context,
    //   darkColor: MyntColors.textPrimaryDark,
    //   lightColor: MyntColors.textBlack,
    //   fontWeight: MyntFonts.semiBold,
    // ).copyWith(fontSize: 13);

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
      child: Row(
        children: [
          _buildTabButton(context, 'Payoff Graph', provider.payoffTab == 0, isDark, () {
            provider.setPayoffTab(0);
          }),
          const SizedBox(width: 16),
          _buildTabButton(context, 'Greeks', provider.payoffTab == 1, isDark, () {
            provider.setPayoffTab(1);
          }),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, bool isActive, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: isActive ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) : Colors.grey,
            fontWeight: MyntFonts.medium,
          ),
        ),
      ),
    );
  }

  Widget _buildPayoffChart(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.isLoading && provider.isAnalyzeMode) {
      return _buildPayoffChartSkeleton(isDark);
    }
    if (provider.payoffData.isEmpty) {
      return Center(
        child: Text(
          'Add options to see payoff chart',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    final currentPrice = provider.isTargetSpotActive ? provider.targetSpotPrice : provider.spotPrice;

    // Convert payoff data to lists
    final stockPrices = provider.payoffData.map((p) => p.price).toList();
    final payoffsExpiry = provider.payoffData.map((p) => p.profit).toList();
    final payoffsTarget = provider.targetPayoffData.map((p) => p.profit).toList();

    if (stockPrices.isEmpty || payoffsExpiry.isEmpty) {
      return Center(
        child: Text(
          'No payoff data available',
          style: MyntWebTextStyles.body(context, color: Colors.grey),
        ),
      );
    }

    // Calculate Y-axis range with nice round intervals
    double minPayoff = payoffsExpiry.reduce((a, b) => a < b ? a : b);
    double maxPayoff = payoffsExpiry.reduce((a, b) => a > b ? a : b);

    if (payoffsTarget.isNotEmpty) {
      final targetMin = payoffsTarget.reduce((a, b) => a < b ? a : b);
      final targetMax = payoffsTarget.reduce((a, b) => a > b ? a : b);
      minPayoff = minPayoff < targetMin ? minPayoff : targetMin;
      maxPayoff = maxPayoff > targetMax ? maxPayoff : targetMax;
    }

    // Add padding
    double yRange = maxPayoff - minPayoff;
    if (yRange <= 0) yRange = 10000;
    minPayoff = minPayoff - (yRange * 0.15);
    maxPayoff = maxPayoff + (yRange * 0.15);

    // Round to nice intervals (multiples of 10000 for large values, 1000 for smaller)
    double roundingFactor = 10000;
    if ((maxPayoff - minPayoff).abs() < 50000) {
      roundingFactor = 5000;
    }
    if ((maxPayoff - minPayoff).abs() < 10000) {
      roundingFactor = 1000;
    }

    // Round min down and max up to nice values
    minPayoff = (minPayoff / roundingFactor).floor() * roundingFactor;
    maxPayoff = (maxPayoff / roundingFactor).ceil() * roundingFactor;

    // Ensure zero is visible with proper negative space
    if (minPayoff > 0) {
      minPayoff = -roundingFactor;
    } else if (maxPayoff < 0) {
      maxPayoff = roundingFactor;
    }

    // Ensure minimum visible range
    if ((maxPayoff - minPayoff) < roundingFactor * 4) {
      maxPayoff = minPayoff + roundingFactor * 4;
    }

    // Calculate X-axis range
    double minPrice = stockPrices.reduce((a, b) => a < b ? a : b);
    double maxPrice = stockPrices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Center around midpoint of payoff data (stable, not affected by live price ticks)
    final centerPrice = (minPrice + maxPrice) / 2;
    
    // If SD lines are enabled, expand range to include all SD lines
    double zoomedRange = priceRange * 0.6;
    if (provider.showSDLines && provider.sdPrices.isNotEmpty) {
      final sdMin = provider.sdPrices['-2σ'] ?? minPrice;
      final sdMax = provider.sdPrices['+2σ'] ?? maxPrice;
      final sdRange = sdMax - sdMin;
      // Ensure SD range fits with 10% padding
      if (sdRange * 1.15 > zoomedRange) {
        zoomedRange = sdRange * 1.15;
      }
    }
    
    minPrice = centerPrice - (zoomedRange / 2);
    maxPrice = centerPrice + (zoomedRange / 2);

    // Ensure we don't go beyond actual data bounds
    final actualMinPrice = stockPrices.reduce((a, b) => a < b ? a : b);
    final actualMaxPrice = stockPrices.reduce((a, b) => a > b ? a : b);

    if (minPrice < actualMinPrice) {
      final adjustment = actualMinPrice - minPrice;
      minPrice = actualMinPrice;
      maxPrice = maxPrice + adjustment;
    }
    if (maxPrice > actualMaxPrice) {
      final adjustment = maxPrice - actualMaxPrice;
      maxPrice = actualMaxPrice;
      minPrice = minPrice - adjustment;
      if (minPrice < actualMinPrice) {
        minPrice = actualMinPrice;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartHeight = constraints.maxHeight;

        return Stack(
          children: [
            MouseRegion(
              onExit: (event) {
                _hidePayoffTooltipAfterDelay();
              },
              child: Listener(
                onPointerDown: (event) {
                  setState(() {
                    _isDragging = true;
                  });
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerMove: (event) {
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerHover: (event) {
                  _updatePayoffTooltipFromPosition(
                    event.localPosition.dx,
                    event.localPosition.dy,
                    chartWidth,
                    chartHeight,
                    minPrice,
                    maxPrice,
                  );
                },
                onPointerUp: (event) {
                  setState(() {
                    _isDragging = false;
                  });
                  _hidePayoffTooltipAfterDelay();
                },
                onPointerCancel: (event) {
                  _isDragging = false;
                  _selectedPrice = null;
                  _tooltipNotifier.value = const _PayoffTooltipState();
                },
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                enableAxisAnimation: false,
                primaryXAxis: NumericAxis(
                  minimum: minPrice,
                  maximum: maxPrice,
                  rangePadding: ChartRangePadding.none,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: MajorGridLines(
                    width: 1,
                    color: Colors.grey.withOpacity(0.15),
                  ),
                  desiredIntervals: 5,
                  axisLabelFormatter: (AxisLabelRenderDetails args) {
                    return ChartAxisLabel(
                      args.value.toStringAsFixed(0),
                      TextStyle(
                        fontFamily: MyntFonts.fontFamily,
                        fontSize: MyntFonts.caption,
                        color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                      ),
                    );
                  },
                  plotBands: <PlotBand>[
                    // Current price line (vertical blue line)
                    PlotBand(
                      start: currentPrice,
                      end: currentPrice,
                      borderColor: const Color(0xFF2962FF),
                      borderWidth: 1.5,
                    ),
                    // Breakeven lines (vertical grey dashed lines)
                    ...provider.metrics.breakevens.map(
                      (be) => PlotBand(
                        start: be,
                        end: be,
                        color: Colors.transparent,
                        borderColor: Colors.grey.withOpacity(0.5),
                        borderWidth: 1.5,
                        dashArray: const <double>[5, 5],
                      ),
                    ),
                    // SD lines (standard deviation lines)
                    if (provider.showSDLines && provider.sdPrices.isNotEmpty) ...[
                      // -2σ line
                      PlotBand(
                        start: provider.sdPrices['-2σ']!,
                        end: provider.sdPrices['-2σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '-2σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // -1σ line
                      PlotBand(
                        start: provider.sdPrices['-1σ']!,
                        end: provider.sdPrices['-1σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '-1σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // +1σ line
                      PlotBand(
                        start: provider.sdPrices['+1σ']!,
                        end: provider.sdPrices['+1σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '+1σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                      // +2σ line
                      PlotBand(
                        start: provider.sdPrices['+2σ']!,
                        end: provider.sdPrices['+2σ']!,
                        color: Colors.transparent,
                        borderColor: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                        borderWidth: 1.5,
                        dashArray: const <double>[6, 4],
                        text: '+2σ',
                        textStyle: TextStyle(
                          fontFamily: MyntFonts.fontFamily,
                          color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                          fontSize: MyntFonts.caption,
                          fontWeight: MyntFonts.medium,
                        ),
                        verticalTextAlignment: TextAnchor.start,
                        horizontalTextAlignment: TextAnchor.middle,
                        verticalTextPadding: '2%',
                      ),
                    ],
                  ],
                ),
                primaryYAxis: NumericAxis(
                  minimum: minPayoff,
                  maximum: maxPayoff,
                  rangePadding: ChartRangePadding.none,
                  axisLine: const AxisLine(width: 0),
                  majorGridLines: MajorGridLines(
                    width: 1,
                    color: isDark ? MyntColors.dividerDark : MyntColors.divider,
                  ),
                  title: AxisTitle(
                    text: 'Profit/Loss',
                    textStyle: TextStyle(
                      fontFamily: MyntFonts.fontFamily,
                      fontSize: MyntFonts.caption,
                      fontWeight: MyntFonts.medium,
                      color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                    ),
                  ),
                  desiredIntervals: 6,
                  axisLabelFormatter: (AxisLabelRenderDetails args) {
                    final value = args.value;
                    String sign = value >= 0 ? '+' : '';
                    String label = '${sign}₹${value.toInt()}';
                    return ChartAxisLabel(
                      label,
                      TextStyle(
                        fontFamily: MyntFonts.fontFamily,
                        fontSize: MyntFonts.caption,
                        color: isDark ? MyntColors.textSecondaryDark : MyntColors.textSecondary,
                      ),
                    );
                  },
                  plotBands: <PlotBand>[
                    // Zero line (horizontal line)
                    PlotBand(
                      start: 0,
                      end: 0,
                      borderColor: isDark ? MyntColors.textPrimaryDark : Colors.black,
                      borderWidth: 1,
                    ),
                  ],
                ),
                trackballBehavior: TrackballBehavior(
                  enable: true,
                  activationMode: ActivationMode.longPress,
                  tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
                  shouldAlwaysShow: _isDragging,
                  hideDelay: 0,
                  lineType: TrackballLineType.vertical,
                  lineColor: Colors.grey.withOpacity(0.5),
                  lineWidth: 1,
                  markerSettings: const TrackballMarkerSettings(
                    markerVisibility: TrackballVisibilityMode.visible,
                    height: 8,
                    width: 8,
                  ),
                  tooltipSettings: const InteractiveTooltip(
                    enable: false,
                  ),
                ),
                series: <CartesianSeries<dynamic, dynamic>>[
                  // Loss shaded area (below zero) - light red fill
                  AreaSeries<_PayoffData, double>(
                    dataSource: _generateAreaDataFromZero(stockPrices, payoffsExpiry, false),
                    xValueMapper: (_PayoffData data, _) => data.price,
                    yValueMapper: (_PayoffData data, _) => data.payoff,
                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                    borderWidth: 0,
                    animationDuration: 0,
                    name: 'Loss',
                    enableTooltip: false,
                  ),
                  // Profit shaded area (above zero) - light green fill
                  AreaSeries<_PayoffData, double>(
                    dataSource: _generateAreaDataFromZero(stockPrices, payoffsExpiry, true),
                    xValueMapper: (_PayoffData data, _) => data.price,
                    yValueMapper: (_PayoffData data, _) => data.payoff,
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderWidth: 0,
                    animationDuration: 0,
                    name: 'Profit',
                    enableTooltip: false,
                  ),
                  // Target/Today line (BLUE solid) - matches reference image
                  if (payoffsTarget.isNotEmpty)
                    LineSeries<_PayoffData, double>(
                      dataSource: _generateLineData(stockPrices, payoffsTarget),
                      xValueMapper: (_PayoffData data, _) => data.price,
                      yValueMapper: (_PayoffData data, _) => data.payoff,
                      color: const Color(0xFF2962FF), // Blue solid line
                      width: 2.5,
                      animationDuration: 0,
                      name: 'Target',
                      enableTooltip: false,
                    ),
                  // Expiry line (Segmented Red/Green) - matches reference image
                  ..._generateSegmentedLineSeries(
                    stockPrices: stockPrices,
                    payoffs: payoffsExpiry,
                    colorPositive: MyntColors.profit,
                    colorNegative: MyntColors.loss,
                    width: 2.5,
                    dashArray: null,
                    name: 'Expiry',
                  ),
                  // Marker dot on Target line at tooltip position
                  if (_selectedPrice != null && payoffsTarget.isNotEmpty)
                    ScatterSeries<_PayoffData, double>(
                      dataSource: [
                        _PayoffData(
                          price: _selectedPrice!,
                          payoff: _getPayoffAtPrice(stockPrices, payoffsTarget, _selectedPrice!),
                        ),
                      ],
                      xValueMapper: (_PayoffData data, _) => data.price,
                      yValueMapper: (_PayoffData data, _) => data.payoff,
                      pointColorMapper: (_PayoffData data, _) => const Color(0xFF2962FF),
                      markerSettings: MarkerSettings(
                        isVisible: true,
                        height: 10,
                        width: 10,
                        shape: DataMarkerType.circle,
                        borderWidth: 2,
                        borderColor: isDark ? MyntColors.textPrimaryDark : MyntColors.textBlack,
                      ),
                      animationDuration: 0,
                      name: 'Target Marker',
                      enableTooltip: false,
                    ),
                ],
              ),
            ), // Close Listener
            ), // Close MouseRegion
            // Custom tooltip — uses ValueListenableBuilder to avoid rebuilding the chart
            ValueListenableBuilder<_PayoffTooltipState>(
              valueListenable: _tooltipNotifier,
              builder: (context, tooltipState, _) {
                if (!tooltipState.showTooltip || tooltipState.selectedPrice == null) {
                  return const SizedBox.shrink();
                }
                return _buildPayoffCustomTooltip(provider, isDark, stockPrices, payoffsExpiry, payoffsTarget, tooltipState);
              },
            ),
          ],
        );
      },
    );
  }

  void _updatePayoffTooltipFromPosition(double xPosition, double yPosition, double chartWidth, double chartHeight, double minPrice, double maxPrice) {
    ++_tooltipUpdateCounter;

    // Account for chart padding
    final plotAreaWidth = chartWidth * 0.85;
    final plotAreaStart = chartWidth * 0.075;
    final relativeX = ((xPosition - plotAreaStart) / plotAreaWidth).clamp(0.0, 1.0);

    final calculatedPrice = minPrice + (relativeX * (maxPrice - minPrice));

    // Calculate tooltip position
    const tooltipOffset = 20.0;
    const tooltipWidth = 200.0;
    const tooltipHeight = 150.0;
    const edgePadding = 8.0;

    final maxX = chartWidth - tooltipWidth - edgePadding;
    final maxY = chartHeight - tooltipHeight - edgePadding;
    final minX = edgePadding;
    final minY = edgePadding;

    double tooltipX;
    final rightPosition = xPosition + tooltipOffset;
    final leftPosition = xPosition - tooltipWidth - tooltipOffset;

    if (rightPosition + tooltipWidth <= maxX) {
      tooltipX = rightPosition;
    } else if (leftPosition >= minX) {
      tooltipX = leftPosition;
    } else {
      final rightSpace = maxX - xPosition;
      final leftSpace = xPosition - minX;
      tooltipX = rightSpace > leftSpace ? maxX : minX;
    }

    tooltipX = tooltipX.clamp(minX, maxX);
    double tooltipY = yPosition - tooltipHeight / 2;
    tooltipY = tooltipY.clamp(minY, maxY);

    _selectedPrice = calculatedPrice;
    _tooltipNotifier.value = _PayoffTooltipState(
      selectedPrice: calculatedPrice,
      showTooltip: true,
      position: Offset(tooltipX, tooltipY),
    );
    // Schedule a single setState per frame for chart marker dot update
    if (!_markerUpdateScheduled) {
      _markerUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
        _markerUpdateScheduled = false;
      });
    }
  }

  void _hidePayoffTooltipAfterDelay() {
    if (!_isDragging) {
      final counterWhenScheduled = _tooltipUpdateCounter;
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted && !_isDragging && counterWhenScheduled == _tooltipUpdateCounter) {
          _selectedPrice = null;
          _tooltipNotifier.value = const _PayoffTooltipState();
        }
      });
    }
  }

  Widget _buildPayoffCustomTooltip(StrategyBuilderProvider provider, bool isDark, List<double> stockPrices, List<double> payoffsExpiry, List<double> payoffsTarget, _PayoffTooltipState tooltipState) {
    final selectedPrice = tooltipState.selectedPrice!;
    final initialPrice = provider.spotPrice;

    // Get payoff values at selected price
    final expiryPayoff = _getPayoffAtPrice(stockPrices, payoffsExpiry, selectedPrice);
    final targetPayoff = payoffsTarget.isNotEmpty
        ? _getPayoffAtPrice(stockPrices, payoffsTarget, selectedPrice)
        : 0.0;

    // Calculate price difference percentage from spot
    final priceDiffPercent = initialPrice > 0 ? ((selectedPrice - initialPrice) / initialPrice) * 100 : 0.0;

    // Calculate payoff percentages
    final expiryPayoffPercent = initialPrice > 0 ? (expiryPayoff / initialPrice) * 100 : 0.0;
    final targetPayoffPercent = initialPrice > 0 ? (targetPayoff / initialPrice) * 100 : 0.0;

    return Positioned(
      left: tooltipState.position.dx,
      top: tooltipState.position.dy,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Underlying Price with percentage difference from spot
            _buildTooltipRowWithPercent(context, 'Underlying Price:', selectedPrice.toIndianFormat(), priceDiffPercent, MyntColors.textBlack),
            const SizedBox(height: 6),
            // Expiry P&L with percentage
            _buildTooltipRowWithPercent(context, 'Expiry P&L:', '\u20B9${expiryPayoff.toIndianFormat()}', expiryPayoffPercent, expiryPayoff >= 0 ? MyntColors.profit : MyntColors.loss),
            // Target P&L (if available)
            if (payoffsTarget.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildTooltipRowWithPercent(context, 'Target P&L:', '\u20B9${targetPayoff.toIndianFormat()}', targetPayoffPercent, targetPayoff >= 0 ? MyntColors.profit : MyntColors.loss),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildTooltipRowWithPercent(BuildContext context, String label, String value, double percent, Color valueColor) {
    final baseStyle = MyntWebTextStyles.bodySmall(
      context,
      color: valueColor,
      fontWeight: MyntFonts.medium,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: MyntWebTextStyles.bodySmall(
            context,
            color: MyntColors.textBlack,
            fontWeight: MyntFonts.medium,
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value, style: baseStyle),
              TextSpan(
                text: ' (${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)',
                style: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) - 3, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_PayoffData> _generateLineData(List<double> prices, List<double> payoffs) {
    final length = prices.length < payoffs.length ? prices.length : payoffs.length;
    return List.generate(
      length,
      (i) => _PayoffData(price: prices[i], payoff: payoffs[i]),
    );
  }

  double _getPayoffAtPrice(List<double> prices, List<double> payoffs, double targetPrice) {
    if (prices.isEmpty || payoffs.isEmpty) return 0.0;

    int closestIndex = 0;
    double minDiff = (prices[0] - targetPrice).abs();

    for (int i = 1; i < prices.length; i++) {
      final diff = (prices[i] - targetPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    if (minDiff < 0.01 || closestIndex == 0 || closestIndex == prices.length - 1) {
      return payoffs[closestIndex];
    }

    final prevIndex = targetPrice < prices[closestIndex] ? closestIndex - 1 : closestIndex;
    final nextIndex = targetPrice < prices[closestIndex] ? closestIndex : closestIndex + 1;

    if (prevIndex < 0 || nextIndex >= prices.length) {
      return payoffs[closestIndex];
    }

    final prevPrice = prices[prevIndex];
    final nextPrice = prices[nextIndex];
    final prevPayoff = payoffs[prevIndex];
    final nextPayoff = payoffs[nextIndex];

    if ((nextPrice - prevPrice).abs() < 0.01) {
      return prevPayoff;
    }

    final t = (targetPrice - prevPrice) / (nextPrice - prevPrice);
    return prevPayoff + (nextPayoff - prevPayoff) * t;
  }

  List<CartesianSeries<_PayoffData, double>> _generateSegmentedLineSeries({
    required List<double> stockPrices,
    required List<double> payoffs,
    required Color colorPositive,
    required Color colorNegative,
    required double width,
    required List<double>? dashArray,
    required String name,
    bool enableTooltip = true,
  }) {
    final length = stockPrices.length < payoffs.length ? stockPrices.length : payoffs.length;

    List<_PayoffData> positiveData = [];
    List<_PayoffData> negativeData = [];

    for (int i = 0; i < length; i++) {
      final price = stockPrices[i];
      final payoff = payoffs[i];

      if (i > 0) {
        final prevPayoff = payoffs[i - 1];
        final prevPrice = stockPrices[i - 1];

        if ((prevPayoff >= 0 && payoff < 0) || (prevPayoff < 0 && payoff >= 0)) {
          final t = prevPayoff / (prevPayoff - payoff);
          final zeroCrossPrice = prevPrice + (price - prevPrice) * t;

          if (prevPayoff >= 0) {
            positiveData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
            negativeData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
          } else {
            negativeData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
            positiveData.add(_PayoffData(price: zeroCrossPrice, payoff: 0.0));
          }
        }
      }

      if (payoff >= 0) {
        positiveData.add(_PayoffData(price: price, payoff: payoff));
      } else {
        negativeData.add(_PayoffData(price: price, payoff: payoff));
      }
    }

    List<CartesianSeries<_PayoffData, double>> series = [];

    if (positiveData.isNotEmpty) {
      series.add(LineSeries<_PayoffData, double>(
        dataSource: positiveData,
        xValueMapper: (_PayoffData data, _) => data.price,
        yValueMapper: (_PayoffData data, _) => data.payoff,
        color: colorPositive,
        width: width,
        dashArray: dashArray,
        animationDuration: 0,
        name: '$name (Positive)',
        enableTooltip: enableTooltip,
      ));
    }

    if (negativeData.isNotEmpty) {
      series.add(LineSeries<_PayoffData, double>(
        dataSource: negativeData,
        xValueMapper: (_PayoffData data, _) => data.price,
        yValueMapper: (_PayoffData data, _) => data.payoff,
        color: colorNegative,
        width: width,
        dashArray: dashArray,
        animationDuration: 0,
        name: '$name (Negative)',
        enableTooltip: enableTooltip,
      ));
    }

    return series;
  }

  List<_PayoffData> _generateAreaDataFromZero(List<double> prices, List<double> payoffs, bool isPositive) {
    final length = prices.length < payoffs.length ? prices.length : payoffs.length;
    final List<_PayoffData> result = [];

    for (int i = 0; i < length; i++) {
      final price = prices[i];
      final payoff = payoffs[i];

      if (isPositive) {
        result.add(_PayoffData(
          price: price,
          payoff: payoff > 0 ? payoff : 0.0,
        ));
      } else {
        result.add(_PayoffData(
          price: price,
          payoff: payoff < 0 ? payoff : 0.0,
        ));
      }
    }

    return result;
  }

  Widget _buildGreeksTable(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    if (provider.basket.isEmpty) {
      return Center(
        child: Text(
          'Add options to see Greeks',
          style: MyntWebTextStyles.body(
            context,
            color: Colors.grey,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
      return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
          child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DataTable(
            columnSpacing: 16,
          headingRowHeight: 40,
          headingRowColor: WidgetStateProperty.all(
            isDark ? MyntColors.overlayBgDark : MyntColors.listItemBg,
          ),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          horizontalMargin: 12,
          dividerThickness: 0,
          columns: [
            DataColumn(
              label: Text('Instrument', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
            ),
            DataColumn(
              label: Text('IV', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Delta', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Theta', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Gamma', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
              numeric: true,
            ),
            DataColumn(
              label: Text('Vega', style: MyntWebTextStyles.bodySmall(context, fontWeight: MyntFonts.bold)),
              numeric: true,
            ),
          ],
          rows: [
            ...provider.basket.where((item) => item.checkbox).map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.buySell == 'BUY' ? 'B' : 'S',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            color: item.buySell == 'BUY' ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary) : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
                            fontWeight: MyntFonts.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.ordlot} x ${item.tsym}',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textBlack,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    item.iv?.toStringAsFixed(2) ?? '--',
                    style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                  )),
                  DataCell(Text(
                    item.delta?.toStringAsFixed(4) ?? '--',
                    style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                  )),
                  DataCell(Text(
                    item.theta?.toStringAsFixed(4) ?? '--',
                    style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                  )),
                  DataCell(Text(
                    item.gamma?.toStringAsFixed(4) ?? '--',
                    style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                  )),
                  DataCell(Text(
                    item.vega?.toStringAsFixed(4) ?? '--',
                    style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                  )),
                ],
              );
            }),
            // Total row
            DataRow(
              cells: [
                DataCell(
                  Text(
                    'Total',
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textBlack,
                      fontWeight: MyntFonts.bold,
                    ),
                  ),
                ),
                const DataCell(Text('')),
                DataCell(Text(
                  provider.greeksTotal('delta').toStringAsFixed(4),
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  provider.greeksTotal('theta').toStringAsFixed(4),
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  provider.greeksTotal('gamma').toStringAsFixed(4),
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
                DataCell(Text(
                  provider.greeksTotal('vega').toStringAsFixed(4),
                  style: MyntWebTextStyles.bodySmall(context, darkColor: MyntColors.textPrimaryDark, lightColor: MyntColors.textBlack),
                )),
              ],
            ),
          ],
        ),
      ),
      ),
      ),
    );
      },
    );
  }

  Widget _buildChartControls(BuildContext context, StrategyBuilderProvider provider, bool isDark) {
    final hasData = provider.payoffData.isNotEmpty;

    // Sync target price controller with provider (only if value changed externally)
    final currentTargetPrice = provider.targetSpotPrice > 0 ? provider.targetSpotPrice : provider.spotPrice;
    if ((_lastEmittedTargetPrice - currentTargetPrice).abs() > 0.001) {
      _targetPriceController.text = currentTargetPrice.toStringAsFixed(2);
      _lastEmittedTargetPrice = currentTargetPrice;
    }

    final percentChange = _getPercentChange(provider.targetSpotPrice, provider.spotPrice);
    final percentPrefix = percentChange.startsWith('-') ? '' : '+';

    final labelStyle = MyntWebTextStyles.caption(
      context,
      darkColor: Colors.grey,
      lightColor: Colors.grey[700],
      fontWeight: MyntFonts.medium,
    ).copyWith(fontSize: 11);

    final resetStyle = MyntWebTextStyles.caption(
      context,
      color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
      fontWeight: MyntFonts.bold,
    ).copyWith(fontSize: 11);

    final valueStyle = MyntWebTextStyles.bodySmall(
      context,
      darkColor: MyntColors.textPrimaryDark,
      lightColor: MyntColors.textBlack,
      fontWeight: MyntFonts.semiBold,
    ).copyWith(fontSize: 13);

    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('${provider.selectedSymbol.split(' ')[0]} Target', style: labelStyle),
              const SizedBox(width: 8),
              InkWell(
                onTap: hasData ? () => provider.resetTargetSpotPrice() : null,
                child: Text('Reset', style: resetStyle),
              ),
              const SizedBox(width: 8),
              Text('$percentPrefix$percentChange%', style: labelStyle),
              const Spacer(),
              Container(
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (!hasData) return;
                        provider.setTargetSpotPrice(provider.targetSpotPrice - (provider.spotPrice * 0.005));
                      },
                      child: Container(
                        width: 28, height: 28, alignment: Alignment.center,
                        child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                    VerticalDivider(width: 1, color: borderColor),
                    SizedBox(
                      width: 90,
                      height: 28,
                      child: TextField(
                        controller: _targetPriceController,
                        style: valueStyle,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          final price = double.tryParse(val);
                          if (price != null && hasData) {
                            _lastEmittedTargetPrice = price;
                            provider.setTargetSpotPrice(price);
                          }
                        },
                      ),
                    ),
                    VerticalDivider(width: 1, color: borderColor),
                    InkWell(
                      onTap: () {
                        if (!hasData) return;
                        provider.setTargetSpotPrice(provider.targetSpotPrice + (provider.spotPrice * 0.005));
                      },
                      child: Container(
                        width: 28, height: 28, alignment: Alignment.center,
                        child: Icon(Icons.add, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
              inactiveTrackColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              thumbColor: Colors.white,
              overlayColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.08),
              thumbShape: _TradingSliderThumbShape(
                enabledThumbRadius: 7,
                borderColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: (provider.targetSpotPrice > 0
                  ? provider.targetSpotPrice
                  : provider.spotPrice).clamp(provider.spotPrice * 0.8, provider.spotPrice * 1.2),
              min: provider.spotPrice * 0.8,
              max: provider.spotPrice * 1.2,
              onChanged: hasData ? (value) => provider.setTargetSpotPrice(value) : null,
            ),
          ),
          // Target Date controls
          _buildTargetDateRow(context, provider, isDark, hasData, labelStyle, resetStyle, valueStyle, borderColor),
        ],
      ),
    );
  }

  Widget _buildTargetDateRow(BuildContext context, StrategyBuilderProvider provider, bool isDark, bool hasData, TextStyle labelStyle, TextStyle resetStyle, TextStyle valueStyle, Color borderColor) {
    final targetDate = DateTime.now().add(Duration(days: provider.targetDaysToExpiry));

    return Column(
      children: [
        Row(
          children: [
            Text('Target Date: ${provider.daysToExpiry - provider.targetDaysToExpiry}D - Expiry', style: labelStyle),
            const SizedBox(width: 8),
            InkWell(
              onTap: hasData ? () => provider.setTargetDaysToExpiry(0) : null,
              child: Text('Reset', style: resetStyle),
            ),
            const Spacer(),
            Container(
              height: 28,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (!hasData || provider.targetDaysToExpiry <= 0) return;
                      provider.setTargetDaysToExpiry(provider.targetDaysToExpiry - 1);
                    },
                    child: Container(
                      width: 28, height: 28, alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  VerticalDivider(width: 1, color: borderColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "${_getWeekday(targetDate.weekday)}, ${targetDate.day} ${_getMonth(targetDate.month)}",
                      style: valueStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  VerticalDivider(width: 1, color: borderColor),
                  InkWell(
                    onTap: () {
                      if (!hasData || provider.targetDaysToExpiry >= provider.daysToExpiry) return;
                      provider.setTargetDaysToExpiry(provider.targetDaysToExpiry + 1);
                    },
                    child: Container(
                      width: 28, height: 28, alignment: Alignment.center,
                      child: Icon(Icons.chevron_right, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
            inactiveTrackColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
            thumbColor: resolveThemeColor(context, dark: MyntColors.textWhite, light: MyntColors.textWhite),
            overlayColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary).withValues(alpha: 0.08),
            thumbShape: _TradingSliderThumbShape(
              enabledThumbRadius: 7,
              borderColor: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: provider.targetDaysToExpiry.toDouble(),
            min: 0,
            max: provider.daysToExpiry.toDouble(),
            divisions: provider.daysToExpiry > 0 ? provider.daysToExpiry : 1,
            onChanged: hasData ? (value) => provider.setTargetDaysToExpiry(value.round()) : null,
          ),
        ),
      ],
    );
  }

  String _getWeekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }



  String _getPercentChange(double current, double original) {
    if (original == 0) return '0.0';
    final change = ((current - original) / original) * 100;
    return change.toStringAsFixed(1);
  }
}

/// Data class representing a single strike price row for strategy builder option chain
class _StrategyStrikeRowData {
  final String strikePrice;
  final bool isATM;
  final OptionValues? callOption;
  final OptionValues? putOption;

  const _StrategyStrikeRowData({
    required this.strikePrice,
    required this.isATM,
    this.callOption,
    this.putOption,
  });
}

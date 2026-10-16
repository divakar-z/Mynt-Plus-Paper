import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/models/explore_model/basketcollection_model.dart';
import 'package:mynt_plus/provider/dashboard_provider.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/sharedWidget/common_search_fields_web.dart';
import 'package:mynt_plus/sharedWidget/common_text_fields_web.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'benchmark_backtest_web.dart';

class CollectionBasketBuilder extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const CollectionBasketBuilder({
    super.key,
    this.onBack,
  });

  @override
  ConsumerState<CollectionBasketBuilder> createState() =>
      _CollectionBasketBuilderState();
}

class _CollectionBasketBuilderState
    extends ConsumerState<CollectionBasketBuilder> {
  // Track which categories are expanded
  final Map<String, bool> _expandedCategories = {};
  final Map<String, FocusNode> _weightFocusNodes = {};
  late ScrollController _tableScrollController;
  late ScrollController _orderScrollController;
  bool _isBacktestLoading = false;
  bool _isInvestLoading = false;
  bool _investInitialized = false;
  String? _backtestError;
  final GlobalKey _weightSchemeKey = GlobalKey();
  OverlayEntry? _weightSchemeOverlay;

  @override
  void initState() {
    super.initState();
    _tableScrollController = ScrollController();
    _orderScrollController = ScrollController();
    // If already in editing mode on open, initialize invest state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initInvestStateIfNeeded();
    });
  }

  void _initInvestStateIfNeeded() {
    if (!mounted) return;
    final strategy = ref.read(dashboardProvider);
    if (strategy.isEditingMode && strategy.selectedFunds.isNotEmpty && !_investInitialized) {
      _investInitialized = true;
      strategy.resetBasketInvest();
      strategy.basketInvestAmountController.text = '100000';
      strategy.calculateBasketAllocations(100000);
      // enrichFundsByIsins already called by loadStrategy — no need to call again
    }
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _orderScrollController.dispose();
    _removeWeightSchemeOverlay();
    for (final node in _weightFocusNodes.values) {
      node.dispose();
    }
    _weightFocusNodes.clear();
    super.dispose();
  }

  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
  }

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(dashboardProvider);

    // Lazy-init invest state once strategy is saved (isEditingMode flips true after autoSaveFundChange)
    if (strategy.isEditingMode && strategy.selectedFunds.isNotEmpty && !_investInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initInvestStateIfNeeded());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
          backgroundColor: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final hasBacktest = strategy.analysisData != null || _isBacktestLoading;
              // Both panels split equally — wrap if each half is too narrow for content
              final halfWidth = (constraints.maxWidth - 1) / 2; // -1 for divider
              // Split-mode table min widths: Fund Name ~120, Weight ~100, Amount ~90, Units ~80, Lock ~40, Delete ~40 + padding
              final showInvestCols = strategy.selectedFunds.isNotEmpty;
              final minTableWidth = showInvestCols ? 510.0 : 320.0; // sum of actual min column widths + padding
              final canFitSideBySide = !hasBacktest || halfWidth >= minTableWidth;

              if (!hasBacktest || canFitSideBySide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildLeftPanel(strategy),
                    ),
                    if (hasBacktest) ...[
                      Container(
                        width: 1,
                        color: resolveThemeColor(context,
                            dark: MyntColors.dividerDark,
                            light: MyntColors.divider),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildRightPanel(strategy),
                      ),
                    ],
                  ],
                );
              } else {
                // Stack vertically when not enough width
                return Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildLeftPanel(strategy),
                    ),
                    Container(
                      height: 1,
                      color: resolveThemeColor(context,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildRightPanel(strategy),
                    ),
                  ],
                );
              }
            },
          ),
      ),
    );
  }

  // ─── LEFT PANEL ───────────────────────────────────────────────────────

  Widget _buildLeftPanel(DashboardProvider strategy) {
    return Column(
      children: [
        // Header with search + action buttons
        _buildLeftHeader(strategy),
        // Content area — always shows funds table
        Expanded(
          child: strategy.selectedFunds.isEmpty
              ? Center(
                  child: NoDataFoundWeb(
                    title: 'No Funds',
                    subtitle: 'Search and add funds to build your strategy',
                    primaryEnabled: false,
                    secondaryEnabled: false,
                  ),
                )
              : _buildSelectedFundsTable(strategy),
        ),
        // Invest footer — show whenever funds are present (works for both create and edit)
        if (strategy.selectedFunds.isNotEmpty)
          _buildInvestFooter(strategy),
      ],
    );
  }

  Widget _buildLeftHeader(DashboardProvider strategy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark,
                light: MyntColors.divider),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final isSplit = availableWidth < 800;

          // Row 1: Back arrow + Strategy name + (if not split: search + actions)
          final row1 = Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _handleBackNavigation(),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strategy.isEditingMode
                      ? strategy.strategyNameController.text
                      : strategy.pendingStrategyName.isNotEmpty
                          ? strategy.pendingStrategyName
                          : "New Strategy",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary),
                ),
              ),
              if (!isSplit) ...[
                const SizedBox(width: 12),
                if (availableWidth >= 900)
                  SizedBox(
                    width: availableWidth >= 1100 ? 350 : 250,
                    child: GestureDetector(
                      onTap: () => _showFundSearchDialog(),
                      child: AbsorbPointer(
                        child: MyntSearchTextField.withSmartClear(
                          controller: TextEditingController(),
                          placeholder: 'Search funds',
                          leadingIcon: assets.searchIcon,
                          enabled: false,
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showFundSearchDialog(),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.search,
                          size: 20,
                          color: resolveThemeColor(context,
                              dark: MyntColors.textPrimaryDark,
                              light: MyntColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ..._buildActionButtons(strategy),
              ],
            ],
          );

          if (!isSplit) return row1;

          // Row 2 (split only): Search + actions
          final row2 = Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFundSearchDialog(),
                  child: AbsorbPointer(
                    child: MyntSearchTextField.withSmartClear(
                      controller: TextEditingController(),
                      placeholder: 'Search funds...',
                      leadingIcon: assets.searchIcon,
                      enabled: false,
                    ),
                  ),
                ),
              ),
              ..._buildActionButtons(strategy),
            ],
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row1,
              const SizedBox(height: 8),
              row2,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildActionButtons(DashboardProvider strategy) {
    return [
      // Weighting Scheme dropdown
      if (strategy.selectedFunds.isNotEmpty) ...[
        const SizedBox(width: 8),
        _buildWeightSchemeDropdown(),
      ],
      // Analyse button
      if (strategy.selectedFunds.isNotEmpty) ...[
        const SizedBox(width: 8),
        SizedBox(
            height: 40,
            child: MyntOutlinedButton(
              label: "Backtest",
                 onPressed: () {
              if (strategy.isStrategyValid) {
                strategy.stratergySavebackbutton(false);
                _handleAnalyseAction(context, popDialog: false);
              } else {
                error(context,
                    strategy.getStrategyValidationError() ??
                        'Please fix validation errors before proceeding');
              }
            },
              textColor: resolveThemeColor(context,
                  dark: MyntColors.textWhite, light: MyntColors.primary),
            ),
          ),
       
      ],
    ];
  }

  void _showFundSearchDialog() {
    final strategy = ref.read(dashboardProvider);
    strategy.searchController.clear();
    strategy.Basketsearch("");

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fund Search',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: _FundSearchDialogContent(
                onDone: () {
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        final s = ref.read(dashboardProvider);
        s.autoSaveFundChange(context);
        if (s.selectedFunds.isNotEmpty) {
          final amount = double.tryParse(s.basketInvestAmountController.text) ?? 100000;
          s.calculateBasketAllocations(amount > 0 ? amount : 100000);
          s.enrichFundsByIsins();
        }
      }
    });
  }

  // ─── SELECTED FUNDS TABLE (Single table with expandable groups) ─────────

  Widget _buildSelectedFundsTable(DashboardProvider strategy) {
    final grouped = strategy.groupedSelectedFunds;
    final dark = isDarkMode(context);
    final allFunds = strategy.selectedFunds;
    final isSplit = strategy.analysisData != null || _isBacktestLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 32; // 16px padding each side

        // ── Column width calculation (like holdings table) ──
        // Full: Fund Name, AUM, 1yr CAGR, NAV, Weight %, [Amount, Units,] Lock, Delete
        // Split: Fund Name, Weight %, [Amount, Units,] Lock, Delete
        final showInvestCols = strategy.selectedFunds.isNotEmpty;
        final headers = isSplit
            ? (showInvestCols
                ? ['Fund Name', 'Wt %', 'Amount', 'Units', '', '']
                : ['Fund Name', 'Wt %', '', ''])
            : (showInvestCols
                ? ['Fund Name', 'AUM', '1yr CAGR', 'NAV', 'Weight %', 'Amount', 'Units', '', '']
                : ['Fund Name', 'AUM', '1yr CAGR', 'NAV', 'Weight %', '', '']);
        final colCount = headers.length;
        const textStyle = TextStyle(fontSize: 14);
        const padding = 24.0;
        const sortIconWidth = 0.0; // No sorting in this table

        final minWidths = <int, double>{};

        for (int col = 0; col < colCount; col++) {
          double maxWidth = 0.0;

          // Measure header width
          final headerWidth = _measureTextWidth(headers[col], textStyle);
          maxWidth = headerWidth + sortIconWidth;

          // Measure widest data value
          for (final fund in allFunds) {
            String cellText = '';
            if (isSplit) {
              switch (col) {
                case 0: cellText = fund.name; break;
                case 1: cellText = '100'; break; // Weight %
                case 2: cellText = showInvestCols ? '₹1,00,000' : ''; break;
                case 3: cellText = showInvestCols ? '1234.5678' : ''; break;
                case 4: cellText = ''; break; // lock icon
                case 5: cellText = ''; break; // delete icon
              }
            } else {
              switch (col) {
                case 0: cellText = fund.name; break;
                case 1: cellText = fund.aum > 0 ? fund.aum.toStringAsFixed(2) : '-'; break;
                case 2: cellText = fund.oneYearCAGR > 0 ? '${fund.oneYearCAGR.toStringAsFixed(2)}%' : '-'; break;
                case 3: cellText = fund.nav > 0 ? '₹${fund.nav.toStringAsFixed(2)}' : '-'; break;
                case 4: cellText = '100'; break; // max possible weight text
                case 5: cellText = showInvestCols ? '₹1,00,000' : ''; break;
                case 6: cellText = showInvestCols ? '1234.5678' : ''; break;
                case 7: cellText = ''; break; // lock icon
                case 8: cellText = ''; break; // delete icon
              }
            }
            final cellWidth = _measureTextWidth(cellText, textStyle);
            if (cellWidth > maxWidth) maxWidth = cellWidth;
          }

          // Absolute minimums for special columns
          if (isSplit) {
            final lockCol = showInvestCols ? 4 : 2;
            final deleteCol = showInvestCols ? 5 : 3;
            if (col == lockCol || col == deleteCol) maxWidth = maxWidth < 40 ? 40 : maxWidth;
            if (col == 1) maxWidth = maxWidth < 100 ? 100 : maxWidth; // Weight stepper (- N +)
            if (showInvestCols && col == 2) maxWidth = maxWidth < 90 ? 90 : maxWidth; // Amount
            if (showInvestCols && col == 3) maxWidth = maxWidth < 95 ? 95 : maxWidth; // Units
          } else {
            final lockCol = showInvestCols ? 7 : 5;
            final deleteCol = showInvestCols ? 8 : 6;
            if (col == lockCol || col == deleteCol) maxWidth = maxWidth < 40 ? 40 : maxWidth;
            if (col == 1) maxWidth = maxWidth < 90 ? 90 : maxWidth; // AUM
            if (col == 2) maxWidth = maxWidth < 80 ? 80 : maxWidth; // 1yr CAGR
            if (col == 3) maxWidth = maxWidth < 80 ? 80 : maxWidth; // NAV
            if (col == 4) maxWidth = maxWidth < 100 ? 100 : maxWidth; // Weight stepper
            if (showInvestCols && col == 5) maxWidth = maxWidth < 90 ? 90 : maxWidth; // Amount
          }

          minWidths[col] = maxWidth + padding;
        }

        // Start with minimum widths
        final columnWidthValues = <int, double>{};
        for (int i = 0; i < colCount; i++) {
          columnWidthValues[i] = minWidths[i] ?? 80.0;
        }

        final totalMinWidth = columnWidthValues.values.fold<double>(0, (s, w) => s + w);

        if (totalMinWidth < availableWidth) {
          // Extra space - distribute proportionally
          final extraSpace = availableWidth - totalMinWidth;
          final growthFactors = isSplit
              ? (showInvestCols
                  ? <int, double>{0: 2.0, 1: 0.5, 2: 0.3, 3: 0.3, 4: 0.1, 5: 0.1}
                  : <int, double>{0: 2.0, 1: 0.5, 2: 0.1, 3: 0.1})
              : (showInvestCols
                  ? <int, double>{0: 2.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 0.5, 5: 0.5, 6: 0.5, 7: 0.1, 8: 0.1}
                  : <int, double>{0: 2.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 0.5, 5: 0.1, 6: 0.1});
          final totalGrowth = growthFactors.values.fold<double>(0, (s, v) => s + v);
          for (int i = 0; i < colCount; i++) {
            columnWidthValues[i] = columnWidthValues[i]! +
                (extraSpace * growthFactors[i]!) / totalGrowth;
          }
        } else if (totalMinWidth > availableWidth) {
          // Not enough space - shrink proportionally
          final excessWidth = totalMinWidth - availableWidth;
          final absoluteMinWidths = isSplit
              ? (showInvestCols
                  ? <int, double>{0: 120.0, 1: 100.0, 2: 90.0, 3: 95.0, 4: 40.0, 5: 40.0}
                  : <int, double>{0: 120.0, 1: 100.0, 2: 40.0, 3: 40.0})
              : (showInvestCols
                  ? <int, double>{0: 140.0, 1: 90.0, 2: 80.0, 3: 80.0, 4: 100.0, 5: 90.0, 6: 70.0, 7: 40.0, 8: 40.0}
                  : <int, double>{0: 140.0, 1: 90.0, 2: 80.0, 3: 80.0, 4: 100.0, 5: 40.0, 6: 40.0});
          final shrinkableAmounts = <int, double>{};
          double totalShrinkable = 0.0;
          for (int i = 0; i < colCount; i++) {
            final shrinkable = columnWidthValues[i]! - (absoluteMinWidths[i] ?? 40);
            shrinkableAmounts[i] = shrinkable > 0 ? shrinkable : 0;
            totalShrinkable += shrinkableAmounts[i]!;
          }
          if (totalShrinkable > 0) {
            final shrinkFactor = excessWidth < totalShrinkable
                ? excessWidth / totalShrinkable : 1.0;
            for (int i = 0; i < colCount; i++) {
              if (shrinkableAmounts[i]! > 0) {
                columnWidthValues[i] = columnWidthValues[i]! -
                    (shrinkableAmounts[i]! * shrinkFactor);
              }
            }
          }
        }

        final columnWidths = <int, shadcn.TableSize>{
          for (int i = 0; i < colCount; i++)
            i: shadcn.FixedTableSize(columnWidthValues[i]!),
        };

        // ── Build body rows (category headers + fund data) ──
        final List<shadcn.TableRow> bodyRows = [];

        for (final entry in grouped.entries) {
          final category = entry.key;
          final funds = entry.value;
          final categoryColor = _getTypeColor(category);
          final isExpanded = _expandedCategories[category] ?? true;
          final totalPercent =
              funds.fold<double>(0, (sum, f) => sum + f.percentage);

          final categoryBg = categoryColor.withOpacity(0.09);
          onTapCategory() {
            setState(() {
              _expandedCategories[category] = !isExpanded;
            });
          }

          // Category group header row — content spans all columns except the last (chevron)
          final categoryHeaderContent = Row(
            children: [
              Container(
                width: 4,
                height: 24,
                color: categoryColor,
                margin: const EdgeInsets.only(right: 10),
              ),
              Text(
                category.toUpperCase(),
                style: MyntWebTextStyles.tableHeader(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: MyntFonts.semiBold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${funds.length}',
                  style: MyntWebTextStyles.para(context,
                      fontWeight: MyntFonts.semiBold,
                      color: categoryColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${totalPercent.toStringAsFixed(0)}%)',
                style: MyntWebTextStyles.tableHeader(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary,
                    fontWeight: MyntFonts.medium),
              ),
              const Spacer(),
            ],
          );

          bodyRows.add(shadcn.TableRow(
            cells: [
              // First cell with OverflowBox so content extends over empty cells
              shadcn.TableCell(
                child: GestureDetector(
                  onTap: onTapCategory,
                  child: Container(
                    color: categoryBg,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    child: OverflowBox(
                      maxWidth: availableWidth - 40, // full width minus chevron col
                      alignment: Alignment.centerLeft,
                      child: categoryHeaderContent,
                    ),
                  ),
                ),
              ),
              // Empty cells for remaining columns (except first and last)
              for (int i = 0; i < colCount - 2; i++)
                shadcn.TableCell(
                  child: GestureDetector(
                    onTap: onTapCategory,
                    child: Container(color: categoryBg),
                  ),
                ),
              shadcn.TableCell(
                child: GestureDetector(
                  onTap: onTapCategory,
                  child: Container(
                    color: categoryBg,
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ));

          if (isExpanded) {
            for (final fund in funds) {
              bodyRows.add(shadcn.TableRow(
                cells: [
                  _buildDataCell(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: resolveThemeColor(context,
                              dark: MyntColors.backgroundColorDark,
                              light: MyntColors.backgroundColor),
                          child: ClipOval(
                            child: Image.network(
                              'https://v3.mynt.in/mfapi/static/images/mf/${fund.aMCCode ?? ""}.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.account_balance,
                                size: 14,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Tooltip(
                                message: fund.name,
                                preferBelow: true,
                                child: Text(
                                  fund.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MyntWebTextStyles.tableCell(context,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary,
                                      fontWeight: MyntFonts.medium),
                                ),
                              ),
                              if (showInvestCols) Builder(builder: (_) {
                                final allocation = strategy.basketAllocations
                                    .where((a) => a.fund.isin == fund.isin)
                                    .firstOrNull;
                                if (allocation != null && !allocation.isValid) {
                                  return Text(
                                    'Min ₹${fund.minimumPurchaseAmount.toStringAsFixed(0)}',
                                    style: MyntWebTextStyles.tableCell(context,
                                        color: Colors.red,
                                        darkColor: Colors.red,
                                        lightColor: Colors.red,
                                        fontWeight: MyntFonts.medium).copyWith(fontSize: 10),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                    alignRight: false,
                  ),
                  if (!isSplit)
                  _buildDataCell(
                    child: Text(
                      fund.aum > 0 ? fund.aum.toStringAsFixed(2) : '-',
                      style: MyntWebTextStyles.tableCell(context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.medium),
                    ),
                    alignRight: true,
                  ),
                  if (!isSplit)
                  _buildDataCell(
                    child: Text(
                      fund.oneYearCAGR > 0
                          ? '${fund.oneYearCAGR.toStringAsFixed(2)}%'
                          : '-',
                      style: MyntWebTextStyles.tableCell(context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.medium),
                    ),
                    alignRight: true,
                  ),
                  if (!isSplit)
                  _buildDataCell(
                    child: Text(
                      fund.nav > 0 ? '₹${fund.nav.toStringAsFixed(2)}' : '-',
                      style: MyntWebTextStyles.tableCell(context,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary,
                          fontWeight: MyntFonts.medium),
                    ),
                    alignRight: true,
                  ),
                  shadcn.TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      alignment: Alignment.centerRight,
                      child: _buildWeightField(context, fund, strategy, dark),
                    ),
                  ),
                  if (showInvestCols)
                    _buildDataCell(
                      child: Builder(builder: (context) {
                        final allocation = strategy.basketAllocations
                            .where((a) => a.fund.isin == fund.isin)
                            .firstOrNull;
                        final amount = allocation?.allocatedAmount ?? 0;
                        final isValid = allocation?.isValid ?? true;
                        return Text(
                          amount > 0 ? '₹${_formatAmount(amount)}' : '-',
                          style: MyntWebTextStyles.tableCell(context,
                              darkColor: !isValid ? Colors.red : MyntColors.textPrimaryDark,
                              lightColor: !isValid ? Colors.red : MyntColors.textPrimary,
                              fontWeight: MyntFonts.semiBold),
                        );
                      }),
                      alignRight: true,
                    ),
                  if (showInvestCols)
                    _buildDataCell(
                      child: Builder(builder: (context) {
                        final allocation = strategy.basketAllocations
                            .where((a) => a.fund.isin == fund.isin)
                            .firstOrNull;
                        final units = allocation?.estimatedUnits ?? 0;
                        return Text(
                          units > 0 ? units.toStringAsFixed(4) : '-',
                          style: MyntWebTextStyles.tableCell(context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                              fontWeight: MyntFonts.medium),
                        );
                      }),
                      alignRight: true,
                    ),
                  shadcn.TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      alignment: Alignment.center,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => strategy.toggleFundLock(fund, context),
                        child: Icon(
                          fund.isLocked ? Icons.lock : Icons.lock_open,
                          color: strategy.selectedFunds.length == 1
                              ? resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary)
                                  .withOpacity(0.3)
                              : fund.isLocked
                                  ? resolveThemeColor(context,
                                      dark: MyntColors.primaryDark,
                                      light: MyntColors.primary)
                                  : resolveThemeColor(context,
                                      dark: MyntColors.textSecondaryDark,
                                      light: MyntColors.textSecondary),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  shadcn.TableCell(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      alignment: Alignment.center,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () {
                          strategy.removeFundFromStrategy(fund);
                          showResponsiveWarning(context,
                              '${fund.name} deleted');
                        },
                        child: Icon(
                          Icons.delete_outline,
                          color: resolveThemeColor(context,
                              dark: MyntColors.lossDark,
                              light: MyntColors.loss),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ));
            }
          }
        }

        // ── Fixed Header + Scrollable Body (like holdings table) ──
        return Padding(
          padding: const EdgeInsets.all(16),
          child: shadcn.OutlinedContainer(
            clipBehavior: Clip.antiAlias,
            child: Column(
            children: [
              // Fixed Header
              shadcn.Table(
                columnWidths: columnWidths,
                defaultRowHeight: const shadcn.FixedTableSize(44),
                rows: [
                  shadcn.TableHeader(
                    cells: [
                      _buildHeaderCell('Fund Name', false),
                      if (!isSplit) _buildHeaderCell('AUM', true),
                      if (!isSplit) _buildHeaderCell('1yr CAGR', true),
                      if (!isSplit) _buildHeaderCell('NAV', true),
                      _buildHeaderCell('Weight %', true),
                      if (showInvestCols) _buildHeaderCell('Amount', true),
                      if (showInvestCols) _buildHeaderCell('Units', true),
                      _buildHeaderCell('', true),
                      _buildHeaderCell('', true),
                    ],
                  ),
                ],
              ),
              // Scrollable Body
              Expanded(
                child: RawScrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  trackColor: resolveThemeColor(context,
                      dark: Colors.grey.withOpacity(0.1),
                      light: Colors.grey.withOpacity(0.1)),
                  thumbColor: resolveThemeColor(context,
                      dark: Colors.grey.withOpacity(0.3),
                      light: Colors.grey.withOpacity(0.3)),
                  thickness: 6,
                  radius: const Radius.circular(3),
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: shadcn.Table(
                      columnWidths: columnWidths,
                      defaultRowHeight: shadcn.FixedTableSize(showInvestCols ? 60 : 50),
                      rows: bodyRows,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  shadcn.TableCell _buildHeaderCell(String label, bool alignRight) {
    return shadcn.TableCell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          style: MyntWebTextStyles.tableHeader(context,
              fontWeight: MyntFonts.semiBold,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary),
        ),
      ),
    );
  }

  shadcn.TableCell _buildDataCell({
    required Widget child,
    required bool alignRight,
  }) {
    return shadcn.TableCell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'equity':
        return const Color(0xFF6366F1); // Indigo
      case 'hybrid':
        return Colors.orange;
      case 'debt':
        return Colors.blue;
      case 'fixed income':
        return const Color(0xFF0EA5E9); // Sky blue
      case 'liquid':
        return const Color(0xFF06B6D4); // Cyan
      case 'solution oriented':
        return const Color(0xFF8B5CF6); // Violet
      case 'index':
        return const Color(0xFF10B981); // Emerald
      case 'fof':
      case 'fund of funds':
        return const Color(0xFFF59E0B); // Amber
      case 'elss':
        return const Color(0xFFEF4444); // Red
      default:
        // Pick from a palette based on string hash so any new type gets a distinct color
        const palette = [
          Color(0xFF14B8A6), // Teal
          Color(0xFFF97316), // Orange
          Color(0xFFEC4899), // Pink
          Color(0xFF84CC16), // Lime
          Color(0xFF6366F1), // Indigo
          Color(0xFFA855F7), // Purple
        ];
        return palette[type.hashCode.abs() % palette.length];
    }
  }

  Widget _buildWeightSchemeDropdown() {
    return GestureDetector(
      key: _weightSchemeKey,
      onTap: () => _showWeightSchemeOverlay(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              dark: MyntColors.transparent,
              light: const Color(0xffF1F3F8)),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: resolveThemeColor(context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.primary),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ref.watch(dashboardProvider).weightingScheme,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.medium,
                  darkColor: MyntColors.textWhite,
                  lightColor: MyntColors.textBlack),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              color: resolveThemeColor(context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightSchemeOverlay() {
    _removeWeightSchemeOverlay();

    final renderBox =
        _weightSchemeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final isDark = isDarkMode(context);
    final bgColor = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF444444)
        : const Color(0xFFE0E0E0);
    final primary = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    const options = ['Equi-Weighted', 'AUM Weighted', 'Custom Weighted'];

    _weightSchemeOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeWeightSchemeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(6),
              color: bgColor,
              child: Container(
                width: size.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: options.map((option) {
                      final isSelected = option == ref.read(dashboardProvider).weightingScheme;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _removeWeightSchemeOverlay();
                            ref.read(dashboardProvider).updateWeightingScheme(option);
                            final s = ref.read(dashboardProvider);
                            if (option == 'Equi-Weighted') {
                              _applyEquiWeighted(s);
                            } else if (option == 'AUM Weighted') {
                              _applyMarketCapWeighted(s);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  option,
                                  style: MyntWebTextStyles.body(context,
                                      fontWeight: isSelected
                                          ? MyntFonts.semiBold
                                          : MyntFonts.medium,
                                      color:
                                          isSelected ? primary : textColor),
                                ),
                                if (isSelected)
                                  Icon(Icons.check,
                                      size: 16, color: primary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_weightSchemeOverlay!);
  }

  void _removeWeightSchemeOverlay() {
    _weightSchemeOverlay?.remove();
    _weightSchemeOverlay = null;
  }

  void _applyEquiWeighted(DashboardProvider strategy) {
    final funds = strategy.selectedFunds;
    if (funds.isEmpty) return;
    final equalPct = (100.0 / funds.length);
    for (int i = 0; i < funds.length; i++) {
      funds[i].isLocked = false;
      if (i == funds.length - 1) {
        // Last fund gets remainder to ensure total = 100
        final used = funds.take(i).fold(0.0, (s, f) => s + f.percentage);
        funds[i].percentage = (100.0 - used).roundToDouble();
      } else {
        funds[i].percentage = equalPct.roundToDouble();
      }
    }
    strategy.updateAllControllers();
  }

  void _applyMarketCapWeighted(DashboardProvider strategy) {
    final funds = strategy.selectedFunds;
    if (funds.isEmpty) return;
    final totalAum = funds.fold(0.0, (sum, f) => sum + f.aum);
    if (totalAum <= 0) {
      // Fallback to equi-weighted if no AUM data
      _applyEquiWeighted(strategy);
      ref.read(dashboardProvider).updateWeightingScheme('Equi-Weighted');
      return;
    }

    // Step 1: raw proportional weights, clamp min to 1% so no fund shows 0
    for (int i = 0; i < funds.length; i++) {
      funds[i].isLocked = false;
      final raw = (funds[i].aum / totalAum) * 100;
      funds[i].percentage = raw < 1.0 ? 1.0 : raw;
    }

    // Step 2: renormalize — clamping may have pushed total above 100
    final clampedTotal = funds.fold(0.0, (s, f) => s + f.percentage);
    for (int i = 0; i < funds.length; i++) {
      funds[i].percentage = (funds[i].percentage / clampedTotal) * 100;
    }

    // Step 3: round to integers (matching equi-weighted behaviour)
    for (int i = 0; i < funds.length; i++) {
      funds[i].percentage = funds[i].percentage.roundToDouble();
    }

    // Step 4: fix integer rounding diff on the largest fund
    final total = funds.fold(0.0, (s, f) => s + f.percentage);
    final diff = (100.0 - total).roundToDouble();
    if (diff != 0) {
      final largest = funds.reduce((a, b) => a.percentage >= b.percentage ? a : b);
      largest.percentage = (largest.percentage + diff).clamp(1.0, 100.0);
    }

    strategy.updateAllControllers();
  }

  Widget _buildWeightField(BuildContext context, FundListModel fund,
      DashboardProvider strategy, bool dark) {
    final controller = strategy.percentageControllers[fund.name] ??
        TextEditingController();

    void updateWeight(int delta) {
      if (!strategy.canChangeWeightOf(fund)) {
        error(context, 'Unlock at least one other fund to change this weight');
        return;
      }
      final current = int.tryParse(controller.text) ?? 0;
      final newVal = (current + delta).clamp(1, 100);
      final newText = '$newVal';
      // Atomic update — sets text and selection in one operation so there is
      // no intermediate frame where the browser selection is visible.
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      strategy.updateFundPercentage(fund, newVal.toDouble());
      strategy.validatepercentage(context);
      if (ref.read(dashboardProvider).weightingScheme != 'Custom Weighted') {
        ref.read(dashboardProvider).updateWeightingScheme('Custom Weighted');
      }
    }

    // Get or create a persistent focus node for this fund
    final focusNode = _weightFocusNodes.putIfAbsent(
      fund.name,
      () => FocusNode(),
    );
    // Attach arrow key handler (safe to reassign each build)
    focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          updateWeight(1);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          updateWeight(-1);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    final iconColor = dark ? MyntColors.primaryDark : MyntColors.primary;
    final borderColor = dark ? MyntColors.textSecondaryDark : MyntColors.primary;
    final bgColor = dark
        ? const Color(0xffB5C0CF).withValues(alpha: 0.15)
        : const Color(0xffF1F3F8);
    final textStyle = MyntWebTextStyles.body(context,
        fontWeight: MyntFonts.medium,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary);

    // Custom container: − and + are siblings to the TextField, not inside it.
    // This prevents tapping the buttons from focusing the TextField.
    return Container(
      height: 34,
      width: 110,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          // Minus button — opaque hit area, isolated from TextField
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => updateWeight(-1),
            child: SizedBox(
              width: 28,
              height: 34,
              child: Center(child: Icon(Icons.remove, size: 16, color: iconColor)),
            ),
          ),
          // Number input — only the middle area focuses the field
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.startsWith('0')) return oldValue;
                  return newValue;
                }),
              ],
              style: textStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (value) {
                final intValue = int.tryParse(value);
                if (intValue != null && intValue > 0 && intValue <= 100) {
                  if (!strategy.canChangeWeightOf(fund)) {
                    // Revert the field so the visible value matches the model.
                    final currentText = fund.percentage.round().toString();
                    controller.value = TextEditingValue(
                      text: currentText,
                      selection: TextSelection.collapsed(offset: currentText.length),
                    );
                    error(context, 'Unlock at least one other fund to change this weight');
                    return;
                  }
                  strategy.updateFundPercentage(fund, intValue.toDouble());
                } else if (value.isEmpty) {
                  // User is mid-edit (clearing to retype) — don't update the model
                } else {
                  // intValue == 0 or invalid — ignore, keep current percentage
                }
                strategy.validatepercentage(context);
                if (ref.read(dashboardProvider).weightingScheme != 'Custom Weighted') {
                  ref.read(dashboardProvider).updateWeightingScheme('Custom Weighted');
                }
              },
            ),
          ),
          // Plus button — opaque hit area, isolated from TextField
          GestureDetector( 
            behavior: HitTestBehavior.opaque,
            onTap: () => updateWeight(1),
            child: SizedBox(
              width: 28,
              height: 34,
              child: Center(child: Icon(Icons.add, size: 16, color: iconColor)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderProgressDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Order Progress',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Consumer(
                builder: (ctx, ref, _) {
                  final strategy = ref.watch(dashboardProvider);
                  final screenWidth = MediaQuery.of(ctx).size.width;
                  final dialogWidth = (screenWidth * 0.4).clamp(420.0, 560.0);

                  return shadcn.Card(
                    borderRadius: BorderRadius.circular(8),
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: dialogWidth,
                      height: MediaQuery.of(ctx).size.height * 0.65,
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: shadcn.Theme.of(ctx).colorScheme.border,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order Summary',
                                  style: MyntWebTextStyles.title(ctx,
                                      fontWeight: MyntFonts.semiBold,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                ),
                                if (!strategy.isBasketOrdering)
                                  MyntCloseButton(
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                              ],
                            ),
                          ),
                          // Order list — reuse inline builder
                          Expanded(child: _buildOrderProgress(strategy)),
                          // Footer: total + view order book (after complete)
                          if (strategy.basketOrderCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: shadcn.Theme.of(ctx).colorScheme.border,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Total Invested: ₹${_formatAmount(strategy.basketOrderResults.where((r) => r.isSuccess).fold(0.0, (sum, r) => sum + r.amount))}',
                                    style: MyntWebTextStyles.body(ctx,
                                        fontWeight: MyntFonts.medium,
                                        darkColor: MyntColors.textSecondaryDark,
                                        lightColor: MyntColors.textSecondary),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    height: 40,
                                    child: MyntPrimaryButton(
                                      label: 'View Order Book',
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Future.delayed(
                                          const Duration(milliseconds: 300),
                                          strategy.resetBasketInvest,
                                        );
                                        ref.read(mfProvider).mfExTabchange(2);
                                        ref.read(mfProvider).setMfPortfolioInitialTab(1);
                                        if (WebNavigationHelper.isAvailable) {
                                          WebNavigationHelper.navigateTo('mutualFund');
                                        }
                                      },
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
            ),
          ),
        );
      },
    );
  }

  // ─── INVEST FOOTER ────────────────────────────────────────────────────

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)} L';
    }
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match match) => '${match[1]},',
    );
  }

  Widget _buildInvestFooter(DashboardProvider strategy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label + amount field on the left
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Investment Amount',
                    style: MyntWebTextStyles.para(context,
                        fontWeight: MyntFonts.medium,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                  if (strategy.isFetchingNav) ...[
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(MyntColors.primary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fetching NAV...',
                      style: MyntWebTextStyles.caption(context,
                          fontWeight: MyntFonts.regular,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                height: 40,
                child: MyntFormTextField(
                  controller: strategy.basketInvestAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  placeholder: 'Enter amount',
                  height: 40,
                  leadingWidget: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      assets.ruppeIcon,
                      colorFilter: ColorFilter.mode(
                        resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    final amount = double.tryParse(value);
                    if (amount != null && amount > 0) {
                      strategy.calculateBasketAllocations(amount);
                    } else {
                      strategy.calculateBasketAllocations(0);
                    }
                  },
                ),
              ),
            ],
          ),
          const Spacer(),
          // Place Order button on the right
          SizedBox(
            height: 40,
            width: 200,
            child: ElevatedButton(
              onPressed: _isInvestLoading ? null : () async {
                if (!strategy.isStrategyValid) {
                  error(context,
                      strategy.getStrategyValidationError() ??
                          'Please fix validation errors before proceeding');
                  return;
                }
                if (strategy.basketAllocations.isEmpty) {
                  error(context, 'Please enter an investment amount');
                  return;
                }
                if (strategy.basketInvestError != null) {
                  error(context, strategy.basketInvestError!);
                  return;
                }
                if (!strategy.isBasketReadyToOrder) {
                  error(context, 'Please fix allocation errors before placing order');
                  return;
                }
                if (strategy.hasStrategyChanged) {
                  setState(() => _isInvestLoading = true);
                  try {
                    await ref.read(dashboardProvider).updateStrategy(context);
                  } finally {
                    if (mounted) setState(() => _isInvestLoading = false);
                  }
                }
                if (mounted) {
                  strategy.placeBasketLumpsumOrders();
                  _showOrderProgressDialog();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.secondary, light: MyntColors.primary),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                elevation: 0,
              ),
              child: _isInvestLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Place Order',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ORDER PROGRESS ───────────────────────────────────────────────────

  Widget _buildOrderProgress(DashboardProvider strategy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Order List',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary),
              ),
              if (strategy.isBasketOrdering) ...[
                const SizedBox(width: 8),
                Text(
                  '(Placing order ${strategy.currentOrderIndex + 1} of ${strategy.basketAllocations.length})',
                  style: MyntWebTextStyles.para(context,
                      fontWeight: MyntFonts.medium,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _orderScrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(0),
              thumbColor: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary)
                  .withValues(alpha: 0.5),
              child: ListView.separated(
                controller: _orderScrollController,
                padding: EdgeInsets.zero,
                itemCount: strategy.basketAllocations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 0,
                  thickness: 1,
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark, light: MyntColors.divider),
                ),
                itemBuilder: (_, index) {
                  final allocation = strategy.basketAllocations[index];
                  final hasResult = index < strategy.basketOrderResults.length;
                  final result = hasResult ? strategy.basketOrderResults[index] : null;

                  Widget? statusBadge;
                  if (!hasResult) {
                    if (index == strategy.currentOrderIndex && strategy.isBasketOrdering) {
                      statusBadge = const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(MyntColors.primary),
                        ),
                      );
                    }
                  } else {
                    final statusColor = result!.isSuccess ? Colors.green : Colors.red;
                    final statusText = result.isSuccess ? 'CONFIRMED' : 'FAILED';
                    statusBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: MyntWebTextStyles.para(context,
                            fontWeight: MyntFonts.medium, color: statusColor),
                      ),
                    );
                  }

                  final tooltipMessage = result?.message ?? '';
                  final orderItem = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  allocation.fund.name,
                                  style: MyntWebTextStyles.body(context,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (statusBadge != null) ...[
                                const SizedBox(width: 8),
                                statusBadge,
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '₹${_formatAmount(allocation.allocatedAmount)}',
                            style: MyntWebTextStyles.para(context,
                                fontWeight: MyntFonts.medium,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );

                  return tooltipMessage.isNotEmpty
                      ? Tooltip(
                          message: tooltipMessage,
                          waitDuration: const Duration(milliseconds: 300),
                          child: orderItem,
                        )
                      : orderItem;
                },
              ),
            ),
          ),
        ),
        // Email instruction info box
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: Colors.blue.withValues(alpha: 0.08),
                  light: Colors.blue.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: resolveThemeColor(context,
                    dark: Colors.blue.withValues(alpha: 0.2),
                    light: Colors.blue.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16,
                    color: resolveThemeColor(context,
                        dark: Colors.blue.shade300, light: Colors.blue.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please check your registered email for payment instructions from BSE to complete your investment.',
                    style: MyntWebTextStyles.para(context,
                        fontWeight: MyntFonts.medium,
                        color: resolveThemeColor(context,
                            dark: Colors.blue.shade300,
                            light: Colors.blue.shade700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── RIGHT PANEL ──────────────────────────────────────────────────────

  String _formatInvestAmount(double number) {
    if (number >= 10000000) return '${(number / 10000000).toStringAsFixed(1)}Cr';
    if (number >= 100000) return '${(number / 100000).toStringAsFixed(1)}L';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toStringAsFixed(0);
  }

  Widget _buildRightPanel(DashboardProvider strategy) {
    if (_isBacktestLoading) {
      return Center(child: MyntLoader.branded());
    }

    if (_backtestError != null || strategy.analysisData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _backtestError != null ? Icons.error_outline : Icons.analytics_outlined,
                size: 48,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                _backtestError != null ? 'Backtest Failed' : 'No Results',
                style: MyntWebTextStyles.body(context,
                    fontWeight: MyntFonts.semiBold,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _backtestError ?? 'No backtest results available for this strategy.',
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.para(context,
                    fontWeight: MyntFonts.medium,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _performBacktest(context),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('Retry', style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolveThemeColor(context,
                        dark: MyntColors.secondary, light: MyntColors.primary),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                'Backtest Results',
                style: MyntWebTextStyles.bodyMedium(context, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),

                 RichText(
                text: TextSpan(
                  style: MyntWebTextStyles.para(context,
                      darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary),
                  children: [
                    const TextSpan(text: '( Invest. amt : '),
                    TextSpan(
                      text: '₹${_formatInvestAmount(double.tryParse(strategy.backtestAmount ?? strategy.investmentController.text) ?? 0)}',
                      style: MyntWebTextStyles.para(context,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary),
                    ),
                    const TextSpan(text: '   Duration : '),
                    TextSpan(
                      text: strategy.backtestDuration ?? strategy.selectedDuration,
                      style: MyntWebTextStyles.para(context,
                          fontWeight: MyntFonts.semiBold,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary),
                    ),
                    const TextSpan(text: ' )'),
                  ],
                ),
              ),
              const Spacer(),
              if (ref.watch(dashboardProvider).isEditingMode) ...[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: 'Investment settings',
                    padding: EdgeInsets.zero,
                    onPressed: () => _showInvestmentDetailsDialog(context, settingsMode: true),
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  ref.read(dashboardProvider).clearData();
                  setState(() => _isBacktestLoading = false);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: resolveThemeColor(context,
              dark: MyntColors.dividerDark, light: MyntColors.divider),
        ),
        // Backtest content
        const Expanded(
          child: BenchMarkBacktestScreenWeb(
            onBack: null,
            onCustomize: null,
          ),
        ),
      ],
    );
  }

  // ─── DIALOGS & NAVIGATION (same logic as old screen) ───────────────────

  void _handleBackNavigation() {
    final strategy = ref.read(dashboardProvider);
    if (strategy.isEditingMode && strategy.hasStrategyChanged) {
      _showUnsavedChangesDialog();
    } else {
      _navigateBack();
    }
  }

  void _navigateBack() {
    widget.onBack?.call();
  }

  Future<void> _showUnsavedChangesDialog() async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: shadcn.Card(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: shadcn.Theme.of(ctx).colorScheme.border,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Unsaved Changes',
                            style: MyntWebTextStyles.title(
                              ctx,
                              color: resolveThemeColor(ctx,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                              fontWeight: MyntFonts.medium,
                            ),
                          ),
                          MyntCloseButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'You have unsaved changes. Do you want to save them before leaving?',
                            textAlign: TextAlign.center,
                            style: MyntWebTextStyles.body(
                              ctx,
                              color: resolveThemeColor(ctx,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: MyntOutlinedButton(
                                    label: 'Discard',
                                    isFullWidth: true,
                                    textColor: resolveThemeColor(ctx,
                                        dark: MyntColors.textWhite,
                                        light: MyntColors.primary),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _navigateBack();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: MyntPrimaryButton(
                                    label: 'Save',
                                    isFullWidth: true,
                                    onPressed: () async {
                                      final strategy =
                                          ref.read(dashboardProvider);
                                      if (strategy.selectedFunds.isEmpty) {
                                        Navigator.of(ctx).pop();
                                        error(context, 'Please add at least one fund before saving');
                                        return;
                                      }
                                      strategy.stratergySavebackbutton(true);
                                      if (strategy.isEditingMode) {
                                        // Close dialog and navigate back first, then save in background
                                        Navigator.of(ctx).pop();
                                        _navigateBack();
                                        try {
                                          await strategy
                                              .updateStrategy(context);
                                        } catch (e) {}
                                      } else {
                                        Navigator.of(ctx).pop();
                                        _showSaveStrategyDialog(
                                            navigateBackAfterSave: true);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  void _handleAnalyseAction(BuildContext dialogContext, {bool popDialog = true}) async {
    try {
      final strategy = ref.read(dashboardProvider);
      if (popDialog) Navigator.of(dialogContext).pop();
      if (!strategy.isEditingMode || strategy.hasStrategyChanged) {
        if (strategy.isEditingMode) {
          await strategy.updateStrategy(context);
          if (!mounted) return;
        } else {
          _showSaveStrategyDialog(triggerBacktest: true);
          return;
        }
      }
      if (!mounted) return;
      await _performBacktest(context);
    } catch (e) {
      if (mounted) {
        error(context, 'Failed to analyse strategy. Please try again.');
      }
    }
  }

  Future<void> _performBacktest(BuildContext context) async {
    final strategy = ref.read(dashboardProvider);
    setState(() {
      _isBacktestLoading = true;
      _backtestError = null;
    });
    try {
      await strategy.backtestAnalysis(
          uuid: strategy.editingStrategy?.data?.firstOrNull?.uuid ?? '');
      if (mounted) {
        setState(() {
          _isBacktestLoading = false;
          if (strategy.analysisData == null) {
            _backtestError = 'No backtest results available for this strategy.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBacktestLoading = false;
          _backtestError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showInvestmentDetailsDialog(BuildContext context, {bool settingsMode = false}) {
    // Snapshot originals so we can restore if user closes without clicking Set
    final strategy = ref.read(dashboardProvider);
    final originalAmount = settingsMode ? strategy.investmentController.text : null;
    final originalDuration = settingsMode ? strategy.selectedDuration : null;
    bool confirmed = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Investment Details',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Consumer(
                builder: (ctx, ref, child) {
                  final strategy = ref.watch(dashboardProvider);
                  final screenWidth = MediaQuery.of(ctx).size.width;
                  final dialogWidth =
                      screenWidth * 0.25 < 320 ? 320.0 : screenWidth * 0.25;

                  return shadcn.Card(
                    borderRadius: BorderRadius.circular(8),
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      width: dialogWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: shadcn.Theme.of(ctx).colorScheme.border,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  settingsMode ? 'Investment Settings' : 'Investment Details',
                                  style: MyntWebTextStyles.title(ctx,
                                      fontWeight: MyntFonts.medium,
                                      color: resolveThemeColor(ctx,
                                          dark: MyntColors.textPrimaryDark,
                                          light: MyntColors.textPrimary)),
                                ),
                                MyntCloseButton(
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Type',
                                  style: MyntWebTextStyles.body(ctx,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: ['One-time']
                                      .map((type) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: _buildInvestmentTypeChip(
                                                type,
                                                strategy.selectedInvestmentType == type,
                                                ctx),
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Initial amount',
                                  style: MyntWebTextStyles.body(ctx,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                ),
                                const SizedBox(height: 10),
                                MyntFormTextField(
                                  controller: strategy.investmentController,
                                  placeholder: '\u20B9  Enter amount',
                                  height: 40,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) {
                                    strategy.validateInvestmentAmount(value);
                                  },
                                ),
                                if (strategy.investmentError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    strategy.investmentError!,
                                    style: MyntWebTextStyles.caption(ctx,
                                        fontWeight: MyntFonts.medium,
                                        color: resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.error)),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  'Over a duration of',
                                  style: MyntWebTextStyles.body(ctx,
                                      fontWeight: MyntFonts.medium,
                                      darkColor: MyntColors.textPrimaryDark,
                                      lightColor: MyntColors.textPrimary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: ['1Y', '3Y', '5Y']
                                      .map((duration) => _buildDurationChip(
                                          duration,
                                          strategy.selectedDuration == duration,
                                          ctx))
                                      .toList(),
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: MyntPrimaryButton(
                                    label: strategy.backtestButtonText,
                                    isFullWidth: true,
                                    onPressed: () {
                                      if (strategy.isStrategyValid) {
                                        confirmed = true;
                                        _handleAnalyseAction(ctx);
                                      } else {
                                        error(ctx,
                                            strategy.getStrategyValidationError() ??
                                                'Please fix validation errors before proceeding');
                                      }
                                    },
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
            ),
          ),
        );
      },
    ).then((_) {
      // If settings mode and user closed without clicking Set, restore originals
      if (settingsMode && !confirmed && mounted) {
        final s = ref.read(dashboardProvider);
        s.investmentController.text = originalAmount!;
        s.updateDuration(originalDuration!);
      }
    });
  }

  Widget _buildInvestmentTypeChip(
      String text, bool isSelected, BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () {
          ref.read(dashboardProvider).updateInvestmentType(text);
        },
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: isSelected
                ? resolveThemeColor(context,
                    dark: colors.searchBgDark,
                    light: const Color(0xffF1F3F8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: Text(
              text,
              style: MyntWebTextStyles.body(context,
                  fontWeight: MyntFonts.semiBold,
                  color: isSelected
                      ? resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary)
                      : resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(
      String text, bool isSelected, BuildContext context) {
    final dark = isDarkMode(context);
    return TextButton(
      onPressed: () {
        ref.read(dashboardProvider).updateDuration(text);
        FocusScope.of(context).unfocus();
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        backgroundColor: !dark
            ? isSelected
                ? const Color(0xffF1F3F8)
                : Colors.transparent
            : isSelected
                ? colors.darkGrey
                : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: isSelected
              ? BorderSide(color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        style: MyntWebTextStyles.body(context,
            fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.regular,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary),
      ),
    );
  }

  void _showSaveStrategyDialog(
      {bool triggerBacktest = false,
      bool navigateBackAfterSave = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Save Strategy',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: _SaveStrategyDialogContent(
                isBackNavigation: navigateBackAfterSave,
                onSaved: () {
                  Navigator.of(ctx).pop();
                  if (navigateBackAfterSave) {
                    _navigateBack();
                  } else if (triggerBacktest) {
                    _performBacktest(context);
                  } else {
                    // New strategy just saved — initialize invest state
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _investInitialized = false;
                      _initInvestStateIfNeeded();
                    });
                  }
                },
                onBacktest: () {
                  Navigator.of(ctx).pop();
                  _performBacktest(context);
                },
              ),
            ),
          ),
        );
      },
    );
  }

}

// ─── SAVE STRATEGY DIALOG ──────────────────────────────────────────────────

class _SaveStrategyDialogContent extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback? onBacktest;
  final bool isBackNavigation;

  const _SaveStrategyDialogContent({
    required this.onSaved,
    this.onBacktest,
    this.isBackNavigation = false,
  });

  @override
  ConsumerState<_SaveStrategyDialogContent> createState() =>
      _SaveStrategyDialogContentState();
}

class _SaveStrategyDialogContentState
    extends ConsumerState<_SaveStrategyDialogContent> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider).clearStrategyNameError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(dashboardProvider);
    final dark = isDarkMode(context);
    const dialogWidth = 380.0;

    return Container(
      width: dialogWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strategy.isEditingMode ? 'Update Strategy' : 'Save Strategy',
                  style: MyntWebTextStyles.title(context,
                      fontWeight: MyntFonts.semiBold,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: dark
                            ? MyntColors.textSecondaryDark
                            : MyntColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategy Name',
                  style: MyntWebTextStyles.body(context,
                      fontWeight: MyntFonts.medium,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary),
                ),
                const SizedBox(height: 8),
                MyntFormTextField(
                  controller: strategy.strategyNameController,
                  placeholder: 'Enter strategy Name',
                  height: 40,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9 ]')),
                    TextInputFormatter.withFunction(
                        (oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue;
                      final capitalized =
                          newValue.text[0].toUpperCase() +
                              newValue.text.substring(1);
                      return newValue.copyWith(text: capitalized);
                    }),
                  ],
                  onChanged: (value) {
                    if (strategy.strategyNameError != null) {
                      strategy.clearStrategyNameError();
                    }
                  },
                ),
                if (strategy.strategyNameError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    strategy.strategyNameError!,
                    style: MyntWebTextStyles.caption(context,
                        fontWeight: MyntFonts.regular,
                        color: MyntColors.loss),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = strategy.strategyNameController.text.trim();
                      if (name.isEmpty) {
                        strategy.setStrategyNameError('Strategy name is required');
                        return;
                      }
                      if (name.length < 3) {
                        strategy.setStrategyNameError('Strategy name must be at least 3 characters');
                        return;
                      }
                      if (_isSaving) return;
                      setState(() => _isSaving = true);
                      try {
                        strategy.stratergySavebackbutton(true);
                        if (strategy.isEditingMode) {
                          await strategy.updateStrategy(context);
                          if (!mounted) return;
                          widget.onSaved();
                        } else {
                          await strategy.saveStrategy(name, context);
                          if (!mounted) return;
                          widget.onSaved();
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSaving = false);
                          error(context,
                              'Failed to save strategy. Please try again.');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyntColors.primary,
                      disabledBackgroundColor:
                          MyntColors.textSecondary.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                      strategy.isEditingMode ? 'Update' : 'Save',
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.semiBold,
                          color: MyntColors.textWhite),
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
}

// ─── FUND SEARCH DIALOG ──────────────────────────────────────────────────────

class _FundSearchDialogContent extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const _FundSearchDialogContent({required this.onDone});

  @override
  ConsumerState<_FundSearchDialogContent> createState() =>
      _FundSearchDialogContentState();
}

class _FundSearchDialogContentState
    extends ConsumerState<_FundSearchDialogContent> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<FundListModel> _getFilteredFunds(DashboardProvider strategy) {
    List<FundListModel> funds = (strategy.basketSearchItems ?? [])
        .map((item) => FundListModel(
              name: item.name ?? "Unknown Scheme",
              schemeName: item.schemeName ?? "Unknown Scheme",
              type: item.type ?? '',
              oneYearCAGR: double.tryParse(item.oneYearData ?? "0") ?? 0.0,
              fiveYearCAGR: double.tryParse(item.fIVEYEARDATA ?? "0") ?? 0.0,
              threeYearCAGR: double.tryParse(item.tHREEYEARDATA ?? "0") ?? 0.0,
              aum: double.tryParse(item.aUM ?? "0") ?? 0.0,
              sharpe: 0.0,
              aMCCode: item.aMCCode,
              isin: item.iSIN,
              schemeCode: item.schemeCode,
              minimumPurchaseAmount:
                  double.tryParse(item.minimumPurchaseAmount ?? "100") ?? 100.0,
              nav: double.tryParse(item.nETASSETVALUE ?? "0") ?? 0.0,
            ))
        .toList();

    return funds;
  }

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(dashboardProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.35 < 450 ? 450.0 : screenWidth * 0.35;
    final funds = _getFilteredFunds(strategy);

    return shadcn.Card(
      borderRadius: BorderRadius.circular(8),
      padding: EdgeInsets.zero,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search bar + close button
            Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 8, top: 16, bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: MyntSearchTextField.withSmartClear(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: 'Search funds...',
                      leadingIcon: assets.searchIcon,
                      autofocus: true,
                      onChanged: (value) {
                        strategy.Basketsearch(value);
                      },
                      onClear: () {
                        strategy.clearBasketSearchResults();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (strategy.selectedFunds.isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () {
                          strategy.searchController.clear();
                          strategy.Basketsearch("");
                          widget.onDone();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(
                            'Done',
                            style: MyntWebTextStyles.body(context,
                                fontWeight: MyntFonts.semiBold,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.primaryDark,
                                    light: MyntColors.primary)),
                          ),
                        ),
                      ),
                    )
                  else
                    MyntCloseButton(
                      onPressed: () {
                        strategy.searchController.clear();
                        strategy.Basketsearch("");
                        widget.onDone();
                      },
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: shadcn.Theme.of(context).colorScheme.border,
            ),
            // Results
            Expanded(
              child: funds.isEmpty
                  ? Center(
                      child: NoDataFoundWeb(
                        title: _searchController.text.isNotEmpty
                            ? 'No Results Found'
                            : 'Start Searching',
                        subtitle: _searchController.text.isNotEmpty
                            ? 'No funds match your search "${_searchController.text}".'
                            : 'Type to search for mutual funds.',
                        primaryEnabled: false,
                        secondaryEnabled: false,
                      ),
                    )
                  : ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: shadcn.Theme.of(context).colorScheme.border,
                      ),
                      itemCount: funds.length,
                      itemBuilder: (context, index) {
                        final fund = funds[index];
                        final isSelected = strategy.selectedFunds
                            .any((f) => f.name == fund.name);
                        return _buildSearchResultItem(
                            fund, isSelected, strategy);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchResultItem(
      FundListModel fund, bool isSelected, DashboardProvider strategy) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: resolveThemeColor(context,
            dark: MyntColors.primaryDark,
            light: MyntColors.primary).withValues(alpha: 0.08),
        onTap: () {
          if (isSelected) {
            strategy.removeFundFromStrategy(fund);
            showResponsiveWarning(
                context, '${fund.name} removed');
          } else {
            strategy.addFundToStrategy(fund);
            showResponsiveSuccess(
                context, '${fund.name} added');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: resolveThemeColor(context,
                    dark: MyntColors.backgroundColorDark,
                    light: MyntColors.backgroundColor),
                child: ClipOval(
                  child: Image.network(
                    "https://v3.mynt.in/mfapi/static/images/mf/${fund.aMCCode ?? ""}.png",
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.account_balance,
                        size: 18,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fund.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.body(context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textPrimaryDark,
                          lightColor: MyntColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fund.type,
                      style: MyntWebTextStyles.para(context,
                          fontWeight: MyntFonts.medium,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (isSelected) {
                      strategy.removeFundFromStrategy(fund);
                      showResponsiveWarning(
                          context, '${fund.name} removed');
                    } else {
                      strategy.addFundToStrategy(fund);
                      showResponsiveSuccess(
                          context, '${fund.name} added');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: SvgPicture.asset(
                      isSelected
                          ? assets.bookmarkIcon
                          : assets.bookmarkedIcon,
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? resolveThemeColor(context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary)
                            : resolveThemeColor(context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary),
                        BlendMode.srcIn,
                      ),
                      height: 18,
                      width: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

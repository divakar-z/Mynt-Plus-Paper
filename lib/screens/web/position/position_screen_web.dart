import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/screens/web/position/position_download_helper.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/screens/web/position/exit_all_positions_dialog_web.dart';
import 'package:mynt_plus/screens/web/position/position_detail_screen_web.dart';
import 'package:mynt_plus/screens/web/position/convert_position_dialogue_web.dart';
import 'package:mynt_plus/screens/web/position/position_table.dart';
import 'package:mynt_plus/screens/web/position/group/position_group_screen_web.dart';
import 'package:mynt_plus/screens/web/position/group/create_group_web.dart';

import '../../../../models/portfolio_model/position_book_model.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../res/responsive_extensions.dart';
import '../../../../sharedWidget/no_data_found.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../../models/marketwatch_model/get_quotes.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../utils/responsive_snackbar.dart';
import '../../../../utils/rupee_convert_format.dart';
import '../../../../utils/pip_service.dart';
import '../../../../provider/strategy_builder_provider.dart';
import '../strategy_builder/strategy_builder_screen.dart';

class PositionScreenWeb extends ConsumerStatefulWidget {
  final List<PositionBookModel> listofPosition;
  const PositionScreenWeb({super.key, required this.listofPosition});

  @override
  ConsumerState<PositionScreenWeb> createState() => _PositionScreenWebState();
}

class _PositionScreenWebState extends ConsumerState<PositionScreenWeb> {
  int _selectedTabIndex = 0;
  bool _showGroupsView = false; // Toggle between positions and groups view
  bool _analyzing = false; // Strategy builder shown in place of the positions (Analyze)
  // ✅ Use ValueNotifier for search query to avoid rebuilding entire widget
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  // TextEditingController to control the TextField value
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _selectedFilter =
      ValueNotifier<String>('All'); // Filter options: All, MIS, NRML, CNC
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Active sort for the positions table, held here rather than inside it.
  //
  // Refresh replaces the table with a loader, so anything the table owned was
  // destroyed and rebuilt — which is why the sort used to clear while the
  // search box and filter chip, both owned by this screen, survived. Kept
  // separate from the two fields above, which belong to the retired
  // DataTable2 path.
  int? _positionsSortColumnIndex;
  bool _positionsSortAscending = true;
  // ✅ Use ValueNotifier instead of setState to avoid rebuilding entire widget
  final ValueNotifier<String?> _hoveredRowToken = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  // WebSocket subscription for live updates (like mobile)
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    // Sync controller with ValueNotifier
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery.value) {
        _searchQuery.value = _searchController.text;
      }
    });
    // TC_389 — exit selections are held against the FULL open position list,
    // never the filtered one, and exitPosition() squares off everything still
    // ticked. So a row that was ticked and is now hidden by the product filter
    // or the search box would still be exited, with the button and the confirm
    // dialog both showing the stale count. Clear the selection whenever the
    // visible list changes. Listening on the notifiers rather than on the
    // widgets catches every path that can change them, including any added
    // later.
    _searchQuery.addListener(_clearExitSelectionOnListChange);
    _selectedFilter.addListener(_clearExitSelectionOnListChange);
    // Set up WebSocket subscription for live position updates (like mobile)
    _setupSocketSubscription();
  }

  /// Drops any pending exit selection when the visible position list changes.
  /// Kept cheap: does nothing unless something is actually selected, so it
  /// will not fire a provider notify on every keystroke.
  void _clearExitSelectionOnListChange() {
    if (!mounted) return;
    final positionBook = ref.read(portfolioProvider);
    if (!positionBook.hasExitSelection &&
        positionBook.exitPositionQty == 0 &&
        !positionBook.isExitAllPosition) {
      return;
    }
    positionBook.resetExitPositionSelection();
  }

  void _setupSocketSubscription() {
    Future.microtask(() {
      final websocket = ref.read(websocketProvider);
      final positionBook = ref.read(portfolioProvider);

      _socketSubscription = websocket.socketDataStream.listen((socketDatas) {
        bool needsUpdate = false;

        for (var position in widget.listofPosition) {
          if (socketDatas.containsKey(position.token)) {
            final socketData = socketDatas[position.token];

            // Strict guard — defense in depth, independent of central sanitiser.
            // Rejects null, "null", "", "0", "0.0", "0.00" so broker zero
            // defaults can never write into position.lp and produce phantom
            // P&L. Same pattern applied to pc.
            final lp = socketData['lp']?.toString();
            if (lp != null && lp != "null" && lp != "" &&
                lp != "0" && lp != "0.0" && lp != "0.00" &&
                lp != position.lp) {
              position.lp = lp;
              needsUpdate = true;
            }

            final pc = socketData['pc']?.toString();
            if (pc != null && pc != "null" && pc != "" &&
                pc != "0" && pc != "0.0" && pc != "0.00" &&
                pc != position.perChange) {
              position.perChange = pc;
              needsUpdate = true;
            }
          }
        }

        // Recalculate totals when price data changes (like mobile)
        if (needsUpdate) {
          positionBook.positionCal(positionBook.isDay);
        }
      });
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel(); // Cancel WebSocket subscription
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hoveredRowToken.dispose();
    _hoveredColumnIndex.dispose();
    _searchQuery.removeListener(_clearExitSelectionOnListChange);
    _selectedFilter.removeListener(_clearExitSelectionOnListChange);
    _searchQuery.dispose(); // ✅ Dispose search query ValueNotifier
    _searchController.dispose(); // Dispose TextEditingController
    _selectedFilter.dispose();

    super.dispose();
  }

  // Manual refresh method for button click. Only surface an error toaster
  // when the fetch actually fails (API error or exception). Successful
  // refreshes are silent — the table updating is the feedback.
  Future<void> _handleManualRefresh() async {
    final positionBook = ref.read(portfolioProvider);
    await positionBook.fetchPositionBook(context, positionBook.isDay,
        isRefresh: true);
    if (!mounted) return;
    if (!positionBook.lastRefreshSucceeded) {
      ResponsiveSnackBar.showError(
          context, 'Refresh failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch posloader to rebuild when loading state changes
    final positionBook = ref.watch(portfolioProvider);
    final theme = ref.read(themeProvider);

    // Product filters are built from the positions actually held. If the
    // selected product is no longer present (last CO/BO position squared off,
    // fresh position book), fall back to All so the table never stays empty
    // behind a filter that is no longer in the menu.
    ref.listen(portfolioProvider, (previous, next) {
      final selected = _selectedFilter.value;
      if (selected == 'All') return;
      if (!_availableProductFilters(next).contains(selected)) {
        _selectedFilter.value = 'All';
      }
    });

    // Analyze: the strategy builder fills this page; its back arrow returns here.
    if (_analyzing) {
      return StrategyBuilderPanelWeb(onBack: () => setState(() => _analyzing = false));
    }

    // Show full screen loader only on initial load (when no positions exist yet)
    if (positionBook.posloader ) {
      return Center(child: MyntLoader.simple());
    }

    // DrawerOverlay is now at app level in main.dart
    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: resolveThemeColor(
          context,
          dark: resolveThemeColor(context,
              dark: MyntColors.backgroundColorDark,
              light: MyntColors.backgroundColor),
          light: Colors.white,
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.all(context.responsive(
              mobile: 8.0,
              tablet: 12.0,
              desktop: 16.0,
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards Section (includes Trade Positions)
                _buildSummaryCards(theme, positionBook),
                SizedBox(height: context.responsive(
                  mobile: 12.0,
                  tablet: 16.0,
                  desktop: 20.0,
                )),

                // Main Content Area - use Expanded to fill remaining space
                Expanded(
                  child: _buildMainContent(theme, positionBook),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
      ThemesProvider theme, PortfolioProvider positionBook) {
    // Use Consumer to watch specific portfolio values for live updates
    // This ensures stats update when positionCal() recalculates totals from WebSocket data
    return Consumer(
      builder: (context, ref, _) {
        // Watch the portfolio provider to get live updates for totals
        final portfolio = ref.watch(portfolioProvider);
        final totPnL = portfolio.totPnL;
        final totMtM = portfolio.totMtM;

        final cards = [
          _buildStatCard(
            label: 'Total P&L',
            value: totPnL.toIndianFormat(),
            valueColor: _getValueColor(totPnL, theme),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Total MTM',
            value: totMtM.toIndianFormat(),
            valueColor: _getValueColor(totMtM, theme),
            theme: theme,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            } else {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String? percentage,
    required Color valueColor,
    required ThemesProvider theme,
  }) {
    // Privacy Mode: hide the amount (and its sign/colour); the (%) shell
    // stays so the layout doesn't shift.
    final privacy = ref.watch(privacyProvider);
    if (privacy.isPrivate) {
      value = value.contains('₹') ? '₹$kPrivacyMask' : kPrivacyMask;
      percentage = percentage == null ? null : kPrivacyMask;
      valueColor = resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    }
    final horizontalPadding = context.responsive<double>(
      mobile: 8.0,
      tablet: 10.0,
      desktop: 12.0,
    );
    final verticalPadding = context.responsive<double>(
      mobile: 6.0,
      tablet: 7.0,
      desktop: 8.0,
    );

    return shadcn.Theme(
        data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
        child: shadcn.Card(
          padding: EdgeInsets.all(10),
          child: Row(
              children: [
               
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                          fontWeight: MyntFonts.medium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Use Wrap to move percentage to next line when space is limited
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            value,
                            style: MyntWebTextStyles.head(
                              context,
                              color: valueColor,
                              fontWeight: MyntFonts.medium,
                            ),
                          ),
                          if (percentage != null)
                            Text(
                              '($percentage%)',
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                color: valueColor,
                                fontWeight: MyntFonts.medium,
                              ).copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
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
        );
  }

  Color _getStatValueColor(String value, ThemesProvider theme) {
    // Extract numeric value from string (remove any text like percentages)
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    final numValue = double.tryParse(cleanValue) ?? 0.0;
    final colorScheme = shadcn.Theme.of(context).colorScheme;
    if (numValue > 0) {
      return colorScheme.chart2;
    } else if (numValue < 0) {
      return colorScheme.destructive;
    } else {
      return colorScheme.mutedForeground;
    }
  }

  Widget _buildMainContent(
      ThemesProvider theme, PortfolioProvider positionBook) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabsAndActionBar(theme, positionBook),
        const SizedBox(height: 16),
        Expanded(
          child: positionBook.posloader || positionBook.isRefreshing
              ? Center(child: MyntLoader.simple())
              : _showGroupsView
                  ? const PositionGroupScreen()
                  : _buildPositionsTable(theme, positionBook),
        ),
      ],
    );
  }

  Widget _buildTabsAndActionBar(
      ThemesProvider theme, PortfolioProvider positionBook) {
    final openPositionsCount = _getOpenPositionsCount(positionBook);

    final horizontalPadding = context.responsive<double>(
      mobile: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 0, horizontal: horizontalPadding),
      child: Row(
        children: [
          // Custom chip-style tabs matching the design
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Positions tab
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (mounted && _selectedTabIndex != 0) {
                      setState(() {
                        _selectedTabIndex = 0;
                      });
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                      color: _selectedTabIndex == 0
                          ? (theme.isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05))
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
                      border: null, // ✅ no border
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Positions',
                  style: MyntWebTextStyles.body(
                    context,
                            fontWeight: _selectedTabIndex == 0
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                  ).copyWith(
                            color: _selectedTabIndex == 0
                                ? shadcn.Theme.of(context)
                                    .colorScheme
                                    .foreground
                                : shadcn.Theme.of(context)
                                    .colorScheme
                                    .mutedForeground,
                  ),
                ),
                if (openPositionsCount > 0) ...[
                  const SizedBox(width: 4),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text(
                      '$openPositionsCount',
                      style: MyntWebTextStyles.bodySmall(
                        context,
                                fontWeight: _selectedTabIndex == 0
                                    ? MyntFonts.semiBold
                                    : MyntFonts.medium,
                      ).copyWith(
                        fontSize: context.responsive<double>(
                          mobile: 10,
                          tablet: 11,
                          desktop: 12,
                        ),
                                color: _selectedTabIndex == 0
                                    ? shadcn.Theme.of(context)
                                        .colorScheme
                                        .foreground
                                    : shadcn.Theme.of(context)
                                        .colorScheme
                                        .mutedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
                  ),
                ),
              ),
            ],
          ),
          // Spacer to push action items to the right
          const Spacer(),
          // Only show search, filter, exit all, refresh when Positions view is shown
          if (!_showGroupsView) ...[
            // PiP toggle icon (only if browser supports Document PiP API)
            if (PipService.isSupported) ...[
              _buildPipToggleIcon(theme, positionBook),
              SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
            ],
            // Search Bar - Use shadcn.TextField to match Holdings exactly
            SizedBox(
              width: context.responsiveValue<double>(
                mobile: 140,
                smallTablet: 180,
                tablet: 220,
                desktop: 300,
                largeDesktop: 350,
                widescreen: 400,
              ),
              child: MyntSearchTextField.withSmartClear(
                controller: _searchController,
                placeholder: context.isMobile ? 'Search' : 'Search positions',
                leadingIcon: assets.searchIcon,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9& \-]')),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.text.startsWith(' ')) return oldValue;
                    return newValue;
                  }),
                ],
                onClear: () => _searchController.clear(),
              ),
            ),

            // Filter dropdown button
            SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
            _buildFilterButton(theme),
            SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
            // Exit All Button - only show if there are open positions
            // Use Consumer to watch exitPositionQty which changes when selections change
            Consumer(
              builder: (context, ref, _) {
                // Watch exitPositionQty - this primitive value changes when selections change
                // (watching openPosition list doesn't work because list reference stays same)
                final selectedCount =
                    ref.watch(portfolioProvider.select((p) => p.exitPositionQty));
                final openPositions =
                    ref.read(portfolioProvider).openPosition ?? [];
                final nonZeroPositions =
                    openPositions.where((p) => p.qty != "0").toList();

                // Hide button if no open positions
                if (nonZeroPositions.isEmpty) {
                  return const SizedBox.shrink();
                }

                final buttonHeight = context.responsive<double>(
                  mobile: 30,
                  tablet: 32,
                  desktop: 35,
                );
                final buttonPadding = context.responsive<double>(
                  mobile: 12,
                  tablet: 16,
                  desktop: 20,
                );

                return SizedBox(
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => _exitAllPositions(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: resolveThemeColor(
                        context,
                        dark: MyntColors.secondary,
                        light: MyntColors.primary,
                      ),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: buttonPadding, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      selectedCount == 0
                          ? (context.isMobile ? 'Exit' : 'Exit All')
                          : 'Exit ($selectedCount)',
                      style: context.isMobile
                          ? MyntWebTextStyles.para(
                              context,
                              color: Colors.white,
                              fontWeight: MyntFonts.semiBold,
                            )
                          : MyntWebTextStyles.body(
                              context,
                              color: Colors.white,
                              fontWeight: MyntFonts.semiBold,
                            ),
                    ),
                  ),
                );
              },
            ),

            // Analyze Button - only show when F&O options are selected
            Consumer(
              builder: (context, ref, _) {
                final selectedFnO = ref.watch(portfolioProvider.select((p) => p.selectedFnOPositions));
                if (selectedFnO.isEmpty) return const SizedBox.shrink();
                // A strategy has one underlying (one spot axis); same key as loadFromPositions.
                final mixed = selectedFnO.map((p) => p.symbol ?? p.dname ?? p.tsym).toSet().length > 1;

                final buttonHeight = context.responsive<double>(
                  mobile: 30,
                  tablet: 32,
                  desktop: 35,
                );
                final buttonPadding = context.responsive<double>(
                  mobile: 12,
                  tablet: 16,
                  desktop: 20,
                );

                return Padding(
                  padding: EdgeInsets.only(left: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
                  child: Tooltip(
                    message: mixed ? 'Select positions of one symbol to analyze' : '',
                    child: SizedBox(
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: mixed ? null : () => _openAnalyze(selectedFnO),
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: Text(
                        'Analyze (${selectedFnO.length})',
                        style: context.isMobile
                            ? MyntWebTextStyles.para(
                                context,
                                color: Colors.white,
                                fontWeight: MyntFonts.semiBold,
                              )
                            : MyntWebTextStyles.body(
                                context,
                                color: Colors.white,
                                fontWeight: MyntFonts.semiBold,
                              ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resolveThemeColor(
                          context,
                          dark: MyntColors.secondary,
                          light: MyntColors.primary,
                        ),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: resolveThemeColor(
                          context,
                          dark: MyntColors.secondary,
                          light: MyntColors.primary,
                        ).withValues(alpha: .4),
                        disabledForegroundColor: Colors.white70,
                        padding: EdgeInsets.symmetric(horizontal: buttonPadding, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  ),
                );
              },
            ),

            SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
              _buildDownloadButton(theme, positionBook),
            SizedBox(width: context.responsive<double>(mobile: 4, tablet: 6, desktop: 8)),
            // Refresh Button - triggers manual refresh
            _buildIconButton(
              icon: Icons.refresh,
              onPressed: () {
                _handleManualRefresh();
              },
              theme: theme,
              tooltip: 'Refresh',
            ),
            SizedBox(width: context.responsive<double>(mobile: 4, tablet: 6, desktop: 8)),
            // Groups toggle icon - show posgrp icon to navigate to groups
            _buildGroupsToggleIcon(theme),
          ],
          // Show Create Group button and close icon when Position Groups view is shown
          if (_showGroupsView) ...[
            _buildGroupFilterButton(theme, positionBook),
            SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
            MyntIconTextButton(
              label: 'New Group',
              // iconAsset: assets.addCircleIcon,
              onPressed: () {
                _showCreateGroupDialog(context, positionBook);
              },
            ),
            SizedBox(width: context.responsive<double>(mobile: 4, tablet: 6, desktop: 8)),
            // Close icon - to go back to positions
            _buildCloseGroupsIcon(theme),
          ],
        ],
      ),
    );
  }

  // Show Create Group dialog - web style
  void _showCreateGroupDialog(BuildContext context, PortfolioProvider positionBook) {
    // Prevent multiple dialog opens
    if (positionBook.isFilterNavigating) return;

    try {
      positionBook.setFilterNavigating(true);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: resolveThemeColor(
          context,
          dark: MyntColors.modalBarrierDark,
          light: MyntColors.modalBarrierLight,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const CreateGroupPos();
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ).then((_) {
        // Reset navigation lock after dialog is closed
        positionBook.setFilterNavigating(false);
      });
    } catch (e) {
      positionBook.setFilterNavigating(false);
    }
  }

  // Icon button helper matching Holdings
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemesProvider theme,
    String? tooltip,
  }) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 22,
      tablet: 25,
      desktop: 28,
    );

    final button = Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: resolveThemeColor(
                context,
                dark: MyntColors.iconDark,
                light: MyntColors.icon,
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  /// PiP toggle icon — reflects active state via pipVisibilityNotifier.
  /// Clicking it toggles the Document PiP window with current P&L data.
  Widget _buildPipToggleIcon(
      ThemesProvider theme, PortfolioProvider positionBook) {
    return ValueListenableBuilder<bool>(
      valueListenable: pipVisibilityNotifier,
      builder: (context, isPipActive, _) {
        return _buildIconButton(
          icon: isPipActive
              ? Icons.picture_in_picture_alt
              : Icons.picture_in_picture_alt_outlined,
          onPressed: () async {
            final positions = PipService.buildPositionItems(
              groupedBySymbol: positionBook.groupedBySymbol,
              groupPositionSym: positionBook.groupPositionSym,
            );
            await PipService.togglePip(
              pnl: positionBook.totPnL,
              mtm: positionBook.totMtM,
              positions: positions,
              isDarkMode: theme.isDarkMode,
            );
          },
          theme: theme,
          tooltip: 'Picture in Picture',
        );
      },
    );
  }

   Widget _buildDownloadButton(ThemesProvider theme, PortfolioProvider positionBook) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 22,
      tablet: 25,
      desktop: 28,
    );

    return PopupMenuButton<String>(
      tooltip: 'Download',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.isDarkMode ? MyntColors.cardDark : Colors.white,
      onSelected: (value) {
        final positions = positionBook.allPostionList.isNotEmpty
            ? positionBook.allPostionList
            : positionBook.openPosition ?? [];

        // Download is the full list, same as Holdings and Orders —
        // search, product filter and sort are not applied.
        // final filteredPositions = _getFilteredPositionsFromList(positions);
        final filteredPositions = positions.toList();

        if (filteredPositions.isEmpty) {
          warningMessage(context, 'No positions to download');
          return;
        }

        final pref = locator<Preferences>();
        final clientId = pref.clientId ?? '';
        final clientName = pref.clientName ?? '';

        if (value == 'pdf') {
          PositionDownloadHelper.downloadPdf(
            positions: filteredPositions,
            clientId: clientId,
            clientName: clientName,
          );
        } else if (value == 'excel') {
          PositionDownloadHelper.downloadExcel(
            positions: filteredPositions,
            clientId: clientId,
            clientName: clientName,
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Download PDF',
                  style: TextStyle(
                    color: theme.isDarkMode
                        ? MyntColors.textPrimaryDark
                        : MyntColors.textPrimary,
                  )),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text('Download Excel',
                  style: TextStyle(
                    color: theme.isDarkMode
                        ? MyntColors.textPrimaryDark
                        : MyntColors.textPrimary,
                  )),
            ],
          ),
        ),
      ],
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.download,
            size: iconSize,
            color: resolveThemeColor(
              context,
              dark: MyntColors.iconDark,
              light: MyntColors.icon,
            ),
          ),
        ),
      ),
    );
  }


  // Filter dropdown button matching Holdings
  Widget _buildFilterButton(ThemesProvider theme) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 16,
      tablet: 18,
      desktop: 20,
    );

    return Builder(
      builder: (buttonContext) {
        // The icon used to look identical whether or not a product filter was
        // on, so a filtered list was indistinguishable from a short one. Tint
        // the icon and fill the button while a filter is active, and name the
        // filter in the tooltip — same idea as the group filter button below.
        return ValueListenableBuilder<String>(
          valueListenable: _selectedFilter,
          builder: (context, currentFilter, child) {
            final isFiltered = currentFilter != 'All';
            final activeColor = resolveThemeColor(
              context,
              dark: MyntColors.secondary,
              light: MyntColors.primary,
            );
            return Tooltip(
              message: isFiltered ? 'Filter: $currentFilter' : 'Filter',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showFilterPopup(buttonContext, theme),
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      // Clip.none so the dot can sit just outside the icon's
                      // top-right corner. It stays well inside the button box,
                      // so nothing is cut off.
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SvgPicture.asset(
                            assets.searchFilter,
                            width: iconSize,
                            colorFilter: ColorFilter.mode(
                              isFiltered
                                  ? activeColor
                                  : resolveThemeColor(
                                      context,
                                      dark: MyntColors.iconDark,
                                      light: MyntColors.icon,
                                    ),
                              BlendMode.srcIn,
                            ),
                          ),
                          if (isFiltered)
                            Positioned(
                              top: -5,
                              right: -3,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: activeColor,
                                  shape: BoxShape.circle,
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
          },
        );
      },
    );
  }

  // Filter dropdown for position groups: underlying vs underlying + expiry
  Widget _buildGroupFilterButton(
      ThemesProvider theme, PortfolioProvider positionBook) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 16,
      tablet: 18,
      desktop: 20,
    );

    return Builder(
      builder: (buttonContext) {
        return Tooltip(
          message: positionBook.positionGroupFilter == 'underlying_expiry'
              ? 'Group: Underlying + Expiry'
              : 'Group: Underlying',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showGroupFilterPopup(buttonContext, theme),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    assets.searchFilter,
                    width: iconSize,
                    colorFilter: ColorFilter.mode(
                      resolveThemeColor(
                        context,
                        dark: MyntColors.iconDark,
                        light: MyntColors.icon,
                      ),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGroupFilterPopup(BuildContext context, ThemesProvider theme) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGroupFilterMenuItem('Underlying', 'underlying', theme),
                  _buildGroupFilterMenuItem(
                      'Underlying + Expiry', 'underlying_expiry', theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupFilterMenuItem(
      String label, String value, ThemesProvider theme) {
    return Consumer(
      builder: (context, ref, _) {
        final currentFilter = ref
            .watch(portfolioProvider.select((p) => p.positionGroupFilter));
        final isSelected = currentFilter == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref.read(portfolioProvider).setPositionGroupFilter(value);
              shadcn.closeOverlay(context);
            },
            splashColor: resolveThemeColor(
              context,
              dark: MyntColors.rippleDark,
              light: MyntColors.rippleLight,
            ),
            highlightColor: resolveThemeColor(
              context,
              dark: MyntColors.highlightDark,
              light: MyntColors.highlightLight,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withOpacity(0.12),
                        light: const Color(0xFFE8F0FE),
                      )
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight:
                            isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              )
                            : resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Position Groups toggle icon - shows posgrp icon to navigate to groups
  Widget _buildGroupsToggleIcon(ThemesProvider theme) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 18,
      tablet: 20,
      desktop: 22,
    );

    return Tooltip(
      message: 'Show Position Groups',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            setState(() {
              _showGroupsView = true;
            });
          },
          borderRadius: BorderRadius.circular(6),
          splashColor: isDarkMode(context)
              ? MyntColors.rippleDark
              : MyntColors.rippleLight,
          highlightColor: isDarkMode(context)
              ? MyntColors.highlightDark
              : MyntColors.highlightLight,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              assets.posgrp,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                resolveThemeColor(
                  context,
                  dark: MyntColors.textSecondaryDark,
                  light: MyntColors.textSecondary,
                ),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Close groups icon - shows X icon to go back to positions
  Widget _buildCloseGroupsIcon(ThemesProvider theme) {
    final buttonSize = context.responsive<double>(
      mobile: 32,
      tablet: 36,
      desktop: 40,
    );
    final iconSize = context.responsive<double>(
      mobile: 18,
      tablet: 20,
      desktop: 22,
    );

    return Tooltip(
      message: 'Back to Positions',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            setState(() {
              _showGroupsView = false;
            });
          },
          borderRadius: BorderRadius.circular(6),
          splashColor: isDarkMode(context)
              ? MyntColors.rippleDark
              : MyntColors.rippleLight,
          highlightColor: isDarkMode(context)
              ? MyntColors.highlightDark
              : MyntColors.highlightLight,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            alignment: Alignment.center,
            child: Icon(
              Icons.close,
              size: iconSize,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Product filters actually present in the current position book, in a fixed
  // display order. CO and BO were missing from the old hardcoded menu, so a
  // cover/bracket position could be seen but not filtered. Built from the data
  // so the menu never shows a product the client does not hold.
  static const List<String> _productFilterOrder = [
    'MIS',
    'NRML',
    'CNC',
    'CO',
    'BO',
  ];

  List<String> _availableProductFilters(PortfolioProvider positionBook) {
    // Same source the table renders from (see position_table.dart).
    final positions = positionBook.allPostionList.isNotEmpty
        ? positionBook.allPostionList
        : positionBook.openPosition ?? [];

    final present = <String>{};
    for (final position in positions) {
      final product = position.sPrdtAli?.toString().trim() ?? '';
      if (product.isNotEmpty) present.add(product);
    }

    return [
      'All',
      ..._productFilterOrder.where(present.contains),
    ];
  }

  void _showFilterPopup(BuildContext context, ThemesProvider theme) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 160,
              // Consumer so the menu picks up a newly added product while it
              // is still open (new position placed, or one squared off).
              child: Consumer(
                builder: (context, ref, child) {
                  final positionBook = ref.watch(portfolioProvider);
                  final options = _availableProductFilters(positionBook);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: options
                        .map((option) => _buildFilterMenuItem(option, theme))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Filter menu item helper matching Holdings
  Widget _buildFilterMenuItem(String value, ThemesProvider theme) {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedFilter,
      builder: (context, currentFilter, child) {
        final isSelected = currentFilter == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _selectedFilter.value = value;
              shadcn.closeOverlay(context);
            },
            splashColor: resolveThemeColor(
              context,
              dark: MyntColors.rippleDark,
              light: MyntColors.rippleLight,
            ),
            highlightColor: resolveThemeColor(
              context,
              dark: MyntColors.highlightDark,
              light: MyntColors.highlightLight,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withOpacity(0.12),
                        light:
                            const Color(0xFFE8F0FE), // Light blue like in image
                      )
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight:
                            isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              )
                            : resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs(ThemesProvider theme, PortfolioProvider positionBook) {
    final openPositionsCount = _getOpenPositionsCount(positionBook);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(ThemesProvider theme, PortfolioProvider positionBook) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // Search Bar
          SizedBox(
            width: 400,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.searchBgDark,
                  light: MyntColors.searchBg,
                ),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.outlinedBorderDark,
                    light: MyntColors.outlinedBorder,
                  ),
                  width: 1,
                ),
              ),
              child: TextField(
                onChanged: (value) => _searchQuery.value =
                    value, // ✅ Use ValueNotifier instead of setState
                style: MyntWebTextStyles.bodySmall(
                  context,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary,
                  ),
                  fontWeight: MyntFonts.bold,
                ),
                decoration: InputDecoration(
                  hintText: '',
                  hintStyle: MyntWebTextStyles.bodySmall(
                    context,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                    fontWeight: MyntFonts.bold,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(
                      assets.searchIcon,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.iconDark,
                        light: MyntColors.icon,
                      ),
                      fit: BoxFit.scaleDown,
                      width: 18,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          // Exit All Button - only show if there are open positions
          // Use Consumer to watch exitPositionQty which changes when selections change
          Consumer(
            builder: (context, ref, _) {
              // Watch exitPositionQty - this primitive value changes when selections change
              // (watching openPosition list doesn't work because list reference stays same)
              final selectedCount =
                  ref.watch(portfolioProvider.select((p) => p.exitPositionQty));
              final openPositions =
                  ref.read(portfolioProvider).openPosition ?? [];
              final nonZeroPositions =
                  openPositions.where((p) => p.qty != "0").toList();

              // Hide button if no open positions
              if (nonZeroPositions.isEmpty) {
                return const SizedBox.shrink();
              }

              return MyntTextButton(
                onPressed: () => _exitAllPositions(),
                label: selectedCount == 0
                    ? 'Exit All'
                    : (selectedCount == 1
                        ? 'Exit (1)'
                        : 'Exit ($selectedCount)'),
              );
            },
          ),
          const SizedBox(width: 16),
          // Refresh Button - triggers manual refresh
          MyntIconButton(
            icon: Icons.refresh,
            onPressed: () {
              _handleManualRefresh();
            },
            size: MyntButtonSize.medium,
          ),
        ],
      ),
    );
  }

  // Responsive breakpoints
  static const double _mobileBreakpoint = 768;
  static const double _tabletBreakpoint = 1024;
  static const double _desktopBreakpoint = 1440;

  // Helper method to get responsive column configuration
  Map<String, dynamic> _getResponsivePositionColumns(double screenWidth) {
    if (screenWidth < _mobileBreakpoint) {
      // Mobile: Show only essential columns
      return {
        'headers': ['Select', 'Instrument', 'Qty', 'LTP', 'P&L'],
        'columnMinWidth': {
          'Select': 60,
          'Instrument': 250,
          'Qty': 90,
          'LTP': 100,
          'P&L': 110,
        },
      };
    } else if (screenWidth < _tabletBreakpoint) {
      // Tablet: Show most columns
      return {
        'headers': [
          'Select',
          'Instrument',
          'Product',
          'Qty',
          'LTP',
          'P&L',
          'MTM'
        ],
        'columnMinWidth': {
          'Select': 60,
          'Instrument': 250,
          'Product': 130,
          'Qty': 80,
          'LTP': 100,
          'P&L': 110,
          'MTM': 110,
        },
      };
    } else if (screenWidth < _desktopBreakpoint) {
      // Small Desktop: Show more columns
      return {
        'headers': [
          'Select',
          'Instrument',
          'Product',
          'Qty',
          'Act Avg Price',
          'LTP',
          'P&L',
          'MTM',
          'Avg Price'
        ],
        'columnMinWidth': {
          'Select': 60,
          'Instrument': 250,
          'Product': 130,
          'Qty': 80,
          'Act Avg Price': 140,
          'LTP': 100,
          'P&L': 110,
          'MTM': 110,
          'Avg Price': 110,
        },
      };
    } else {
      // Large Desktop: Full columns with optimal widths
      return {
        'headers': [
          'Select',
          'Instrument',
          'Product',
          'Qty',
          'Act Avg Price',
          'LTP',
          'P&L',
          'MTM',
          'Avg Price',
          'Buy Qty',
          'Sell Qty',
          'Buy Avg',
          'Sell Avg'
        ],
        'columnMinWidth': {
          'Select': 60,
          'Instrument': 300,
          'Product': 130,
          'Qty': 80,
          'Act Avg Price': 140,
          'LTP': 100,
          'P&L': 110,
          'MTM': 110,
          'Avg Price': 130,
          'Buy Qty': 95,
          'Sell Qty': 95,
          'Buy Avg': 111,
          'Sell Avg': 105,
        },
      };
    }
  }

  Widget _buildPositionsTable(
      ThemesProvider theme, PortfolioProvider positionBook) {
    // Use ValueListenableBuilder to only rebuild table when search query or filter changes
    return ValueListenableBuilder<String>(
      valueListenable: _searchQuery,
      builder: (context, searchQuery, child) {
        return ValueListenableBuilder<String>(
          valueListenable: _selectedFilter,
          builder: (context, filterType, child) {
            return PositionTable(
              searchQuery: searchQuery,
              filterType: filterType,
              initialSortColumnIndex: _positionsSortColumnIndex,
              initialSortAscending: _positionsSortAscending,
              onSortChanged: (columnIndex, ascending) {
                _positionsSortColumnIndex = columnIndex;
                _positionsSortAscending = ascending;
              },
            );
          },
        );
      },
    );
  }

  // ✅ Helper method that works with a list instead of provider
  List<PositionBookModel> _getFilteredPositionsFromList(
      List<PositionBookModel> positions) {
    List<PositionBookModel> filtered = positions.toList();

    // Apply search filter - use ValueNotifier value
    final searchQuery = _searchQuery.value.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((position) {
        // Match the displayed contract name (master/dname/tsym) and its
        // parsed parts so expiry ("JUL", "24 JUL 26") and strike/option
        // ("270 CE") searches work, not just the underlying symbol.
        // Keep in sync with the table filter in position_table.dart.
        final searchable = [
          position.masterName,
          position.dname,
          position.tsym,
          position.symbol,
          position.expDate,
          position.option,
          position.exch,
        ];
        return searchable.any(
            (field) => (field ?? '').toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Apply product filter
     if (_selectedFilter.value != 'All') {
      filtered = filtered.where((position) {
        return position.sPrdtAli == _selectedFilter.value;
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 1: // Instrument
            comparison = '${a.symbol ?? ''} ${a.exch ?? ''}'
                .compareTo('${b.symbol ?? ''} ${b.exch ?? ''}');
            break;
          case 2: // Product
            comparison = (a.sPrdtAli ?? '').compareTo(b.sPrdtAli ?? '');
            break;
          case 3: // Qty
            comparison = (int.tryParse(a.qty ?? '0') ?? 0)
                .compareTo(int.tryParse(b.qty ?? '0') ?? 0);
            break;
          case 4: // Act Avg Price
            comparison = (double.tryParse(a.avgPrc ?? '0') ?? 0)
                .compareTo(double.tryParse(b.avgPrc ?? '0') ?? 0);
            break;
          case 5: // LTP
            comparison = (double.tryParse(a.lp ?? '0') ?? 0)
                .compareTo(double.tryParse(b.lp ?? '0') ?? 0);
            break;
          case 6: // P&L
            comparison = (double.tryParse(a.profitNloss ?? '0') ?? 0)
                .compareTo(double.tryParse(b.profitNloss ?? '0') ?? 0);
            break;
          case 7: // MTM
            comparison = (double.tryParse(a.mTm ?? '0') ?? 0)
                .compareTo(double.tryParse(b.mTm ?? '0') ?? 0);
            break;
          case 8: // Avg Price
            comparison = (double.tryParse(a.avgPrc ?? '0') ?? 0)
                .compareTo(double.tryParse(b.avgPrc ?? '0') ?? 0);
            break;
          case 9: // Buy Qty
            comparison = (int.tryParse(a.daybuyqty ?? '0') ?? 0)
                .compareTo(int.tryParse(b.daybuyqty ?? '0') ?? 0);
            break;
          case 10: // Sell Qty
            comparison = (int.tryParse(a.daysellqty ?? '0') ?? 0)
                .compareTo(int.tryParse(b.daysellqty ?? '0') ?? 0);
            break;
          case 11: // Buy Avg
            comparison = (double.tryParse(a.daybuyavgprc ?? '0') ?? 0)
                .compareTo(double.tryParse(b.daybuyavgprc ?? '0') ?? 0);
            break;
          case 12: // Sell Avg
            comparison = (double.tryParse(a.daysellavgprc ?? '0') ?? 0)
                .compareTo(double.tryParse(b.daysellavgprc ?? '0') ?? 0);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return filtered;
  }

  // OLD DataTable2 CODE - REMOVED - Using PositionTable widget now
  /*
  Widget _buildTableContent(
      ThemesProvider theme, PortfolioProvider positionBook, List<PositionBookModel> filteredPositions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height: screen height minus all UI elements
        final screenHeight = MediaQuery.of(context).size.height;
        const padding = 32.0; // Top and bottom padding (16 * 2)
        const headerHeight = 120.0; // Summary cards height
        const tabsAndSearchHeight = 100.0; // Tabs and search bar
        const spacing = 24.0 + 16.0; // Spacing between sections
        const bottomMargin = 20.0; // Bottom margin
        final tableHeight =
            screenHeight - padding - headerHeight - tabsAndSearchHeight - spacing - bottomMargin;

        // Ensure we don't exceed 75% of screen height
        final maxHeight = screenHeight * 0.75;
        final calculatedHeight = tableHeight > maxHeight
            ? maxHeight
            : (tableHeight > 400 ? tableHeight : 400.0);

        // Get screen width for responsive design
        final screenWidth = MediaQuery.of(context).size.width;
        
        // Get responsive column configuration
        final responsiveConfig = _getResponsivePositionColumns(screenWidth);
        final headers = List<String>.from(responsiveConfig['headers'] as List);
        final columnMinWidth = Map<String, double>.from(responsiveConfig['columnMinWidth'] as Map);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Container(
            height: calculatedHeight.toDouble(),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.isDarkMode
                    ? WebDarkColors.divider
                    : WebColors.divider,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
              color: theme.isDarkMode
                  ? WebDarkColors.background
                  : Colors.white,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  // Make both scrollbars always visible
                  thumbVisibility: WidgetStateProperty.all(true),
                  trackVisibility: WidgetStateProperty.all(true),
                  
                  // Consistent thickness for both horizontal and vertical
                  thickness: WidgetStateProperty.all(6.0),
                  crossAxisMargin: 0.0, // Remove margin to align scrollbars properly
                  mainAxisMargin: 0.0,
                  
                  // Consistent radius
                  radius: const Radius.circular(3),
                  
                  // Consistent colors for both scrollbars
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    return theme.isDarkMode 
                        ? WebDarkColors.textSecondary.withOpacity(0.3)
                        : WebColors.textSecondary.withOpacity(0.3);
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    return theme.isDarkMode 
                        ? WebDarkColors.divider.withOpacity(0.1)
                        : WebColors.divider.withOpacity(0.1);
                  }),
                  
                  // Ensure consistent behavior for both directions
                  trackBorderColor: WidgetStateProperty.all(Colors.transparent),
                  minThumbLength: 48.0, // Minimum thumb length for both scrollbars
                ),
              ),
              child: RepaintBoundary(
                child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 1800, // Increased to accommodate wider columns
                  sortColumnIndex: null, // Disable DataTable2's built-in sorting
                  sortAscending: _sortAscending,
                  fixedLeftColumns: 2, // Fix the first two columns (Select and Instrument)
                  fixedColumnsColor: theme.isDarkMode 
                      ? WebDarkColors.backgroundSecondary.withOpacity(0.8)
                      : WebColors.backgroundSecondary.withOpacity(0.8),
                  showBottomBorder: true,
                  horizontalScrollController: _horizontalScrollController,
                  scrollController: _verticalScrollController,
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(
                    theme.isDarkMode
                        ? WebDarkColors.primary
                        : WebColors.primary.withOpacity(0.05),
                  ),
                  headingTextStyle: WebTextStyles.tableHeader(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? WebDarkColors.textPrimary
                        : WebColors.textPrimary,
                  ),
                  dataTextStyle: WebTextStyles.custom(
                    fontSize: 13,
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? WebDarkColors.textPrimary
                        : WebColors.textPrimary,
                    fontWeight: WebFonts.medium,
                  ),
                  border: TableBorder(
                    top: BorderSide(
                      color: theme.isDarkMode
                          ? WebDarkColors.divider
                          : WebColors.divider,
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: theme.isDarkMode
                          ? WebDarkColors.divider
                          : WebColors.divider,
                      width: 1,
                    ),
                    horizontalInside: BorderSide(
                      color: theme.isDarkMode
                          ? WebDarkColors.divider
                          : WebColors.divider,
                      width: 1,
                    ),
                    // Remove vertical lines by not setting left, right, and verticalInside
                  ),
                  columns: _buildDataTable2Columns(headers, columnMinWidth, theme, positionBook, filteredPositions),
                  rows: _buildDataTable2Rows(filteredPositions, headers, theme, positionBook),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isNumericColumn(String header) {
    return header != 'Select' && header != 'Instrument'; // All columns except Select and Instrument contain numeric data
  }

  int _getColumnIndexForHeader(String header) {
    switch (header) {
      case 'Select': return 0;
      case 'Instrument': return 1;
      case 'Product': return 2;
      case 'Qty': return 3;
      case 'Act Avg Price': return 4;
      case 'LTP': return 5;
      case 'P&L': return 6;
      case 'MTM': return 7;
      case 'Avg Price': return 8;
      case 'Buy Qty': return 9;
      case 'Sell Qty': return 10;
      case 'Buy Avg': return 11;
      case 'Sell Avg': return 12;
      default: return -1;
    }
  }

  // OLD DataTable2 CODE - REMOVED
  /*
  List<DataColumn2> _buildDataTable2Columns(
    List<String> headers,
    Map<String, double> columnMinWidth,
    ThemesProvider theme,
    PortfolioProvider positionBook,
    List<PositionBookModel> filteredPositions,
  ) {
    return headers.map((header) {
      final columnIndex = _getColumnIndexForHeader(header);
      final isNumeric = _isNumericColumn(header);
      
      // Special handling for fixed columns (Select and Instrument)
      final isSelect = header == 'Select';
      final isInstrument = header == 'Instrument';
      final isActAvgPrice = header == 'Act Avg Price';
      
      // Get the min width for this column, or use default
      final minWidth = columnMinWidth[header];
      
      return DataColumn2(
        label: isSelect ? _buildPositionHeaderWidget(
          header,
          columnIndex,
          theme,
          positionBook,
          filteredPositions,
        ) : SizedBox.expand(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _hoveredColumnIndex.value = columnIndex,
            onExit: (_) => _hoveredColumnIndex.value = null,
            child: Tooltip(
              message: 'Sort by $header',
              child: GestureDetector(
                onTap: () => _onSortTable(columnIndex),
                behavior: HitTestBehavior.opaque,
                child: ValueListenableBuilder<int?>(
                  valueListenable: _hoveredColumnIndex,
                  builder: (context, hoveredIndex, child) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: hoveredIndex == columnIndex
                            ? (theme.isDarkMode
                                ? WebDarkColors.primary.withOpacity(0.1)
                                : WebColors.primary.withOpacity(0.05))
                            : Colors.transparent,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isActAvgPrice ? 6.0 : 8.0, 
                        vertical: 12.0
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: isNumeric ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  header,
                                  style: WebTextStyles.tableHeader(
                                    isDarkTheme: theme.isDarkMode,
                                    color: theme.isDarkMode
                                        ? WebDarkColors.textPrimary
                                        : WebColors.textPrimary,
                                  ),
                                  textAlign: isNumeric ? TextAlign.right : TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 16, // Fixed width for the icon
                                  child: _buildSortIcon(columnIndex, theme),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        size: isInstrument ? ColumnSize.L : ColumnSize.S,
        fixedWidth: isSelect ? 60.0 : (isInstrument ? 300.0 : (isActAvgPrice && minWidth != null ? minWidth : null)),
        onSort: null, // Disable DataTable2's default sort
      );
    }).toList();
  }
  */

  // List<DataRow2> _buildDataTable2Rows(
    List<PositionBookModel> positions,
    List<String> headers,
    ThemesProvider theme,
    PortfolioProvider positionBook,
  ) {
    return positions.map((position) {
      final isClosed = _isPositionClosed(position);
      final uniqueId =
          '${position.token ?? ''}_${position.exch ?? ''}_${position.prd ?? ''}_${position.tsym ?? ''}';

      // ✅ CRITICAL FIX: Wrap row in ValueListenableBuilder to prevent all rows from rebuilding on hover
      // Only the hovered row rebuilds, not the entire table
      return DataRow2(
        key: ValueKey(uniqueId), // Add key for better widget identity
        color: WidgetStateProperty.resolveWith((states) {
          // ✅ Use states.contains(WidgetState.hovered) for built-in hover detection
          // Remove direct _hoveredRowToken.value access to prevent rebuilds
          if (states.contains(WidgetState.hovered)) {
            return theme.isDarkMode
                ? WebDarkColors.primary.withOpacity(0.06)
                : WebColors.primary.withOpacity(0.10);
          }
          return Colors.transparent;
        }),
        cells: headers.map((header) {
          return _buildDataTable2Cell(
            header,
            position,
            theme,
            isClosed,
            uniqueId,
            positionBook,
          );
        }).toList(),
        onTap: () => _showPositionDetail(position),
      );
    }).toList();
  }

  DataCell _buildDataTable2Cell(
    String column,
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    String uniqueId,
    PortfolioProvider positionBook,
  ) {
    Widget cellContent;
    final isNumeric = _isNumericColumn(column);
    final alignment = isNumeric ? Alignment.centerRight : Alignment.centerLeft;
    
    switch (column) {
      case 'Select':
        cellContent = _buildPositionCheckboxCell(position, theme, isClosed, positionBook);
        break;
      case 'Instrument':
        cellContent = _buildInstrumentCellContent(
          position,
          theme,
          isClosed,
          positionBook,
          uniqueId,
        );
        break;
      case 'Product':
        cellContent = _buildPositionTextCell(
          position.sPrdtAli ?? 'N/A',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      case 'Qty':
        final formattedQty = _formatPositionQty(position);
        cellContent = _buildPositionTextCell(
          formattedQty,
          theme,
          alignment,
          color: isClosed ? Colors.grey : _getQtyColor(formattedQty, theme),
        );
        break;
      case 'Act Avg Price':
        cellContent = _buildPositionTextCell(
          position.avgPrc ?? '0.00',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      // Dynamic columns - use isolated widgets that manage their own state
      // Each widget only rebuilds itself, not the table
      case 'LTP':
        if (position.token == null || position.token!.isEmpty) {
          cellContent = _buildPositionTextCell(
            position.lp ?? '0.00',
            theme,
            alignment,
            color: _getPositionTextColor(position, theme),
          );
        } else {
          cellContent = _LTPCell(
            token: position.token!,
            initialLtp: position.lp ?? '0.00',
          );
        }
        break;
      case 'P&L':
        if (position.token == null || position.token!.isEmpty) {
          cellContent = _buildPositionTextCell(
            position.profitNloss ?? '0.00',
            theme,
            alignment,
            color: isClosed
                ? Colors.grey
                : _getValueColor(position.profitNloss ?? '0.00', theme),
          );
        } else {
          final qty = int.tryParse(position.qty ?? '0') ?? 0;
          final avgPrice = double.tryParse(position.avgPrc ?? '0') ?? 0.0;
          cellContent = _PnLCell(
            token: position.token!,
            qty: qty,
            avgPrice: avgPrice,
            initialValue: position.profitNloss ?? '0.00',
            theme: theme,
            isClosed: isClosed,
          );
        }
        break;
      case 'MTM':
        if (position.token == null || position.token!.isEmpty) {
          cellContent = _buildPositionTextCell(
            position.mTm ?? '0.00',
            theme,
            alignment,
            color: isClosed
                ? Colors.grey
                : _getValueColor(position.mTm ?? '0.00', theme),
          );
        } else {
          final qty = int.tryParse(position.qty ?? '0') ?? 0;
          final avgPrice = double.tryParse(position.avgPrc ?? '0') ?? 0.0;
          cellContent = _MTMCell(
            token: position.token!,
            qty: qty,
            avgPrice: avgPrice,
            initialValue: position.mTm ?? '0.00',
            theme: theme,
            isClosed: isClosed,
          );
        }
        break;
      case 'Avg Price':
        cellContent = _buildPositionTextCell(
          position.avgPrc ?? '0.00',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      case 'Buy Qty':
        cellContent = _buildPositionTextCell(
          position.daybuyqty ?? '0',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      case 'Sell Qty':
        cellContent = _buildPositionTextCell(
          position.daysellqty ?? '0',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      case 'Buy Avg':
        cellContent = _buildPositionTextCell(
          position.daybuyavgprc ?? '0.00',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      case 'Sell Avg':
        cellContent = _buildPositionTextCell(
          position.daysellavgprc ?? '0.00',
          theme,
          alignment,
          color: _getPositionTextColor(position, theme),
        );
        break;
      default:
        cellContent = const SizedBox.shrink();
    }

    // Wrap with MouseRegion to detect hover anywhere on the cell
    return DataCell(
      MouseRegion(
        onEnter: (_) => _hoveredRowToken.value = uniqueId,
        onExit: (_) => _hoveredRowToken.value = null,
        child: SizedBox.expand(
          child: Container(
            alignment: alignment,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: cellContent,
          ),
        ),
      ),
    );
  }
  */
  // END OLD DataTable2 CODE

  Widget _buildInstrumentCellContent(
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    PortfolioProvider positionBook,
    String uniqueId,
  ) {
    final displayText = position.masterName ??
        '${position.symbol ?? ''} ${position.exch ?? ''} ${position.expDate ?? ''} ${position.option ?? ''}';

    // ✅ Use ValueListenableBuilder to avoid rebuilding entire table on hover
    return ValueListenableBuilder<String?>(
      valueListenable: _hoveredRowToken,
      builder: (context, hoveredToken, child) {
        final rowIsHovered = hoveredToken == uniqueId;

        return Row(
          children: [
            // ✅ Instrument name - always visible, takes available space
            Expanded(
              child: Tooltip(
                message: displayText,
                child: Text(
                  displayText,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: _getPositionTextColor(position, theme),
                    fontWeight: MyntFonts.medium,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // ✅ Action buttons - appear on hover, stay within bounds
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: rowIsHovered ? null : 0,
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !rowIsHovered,
                child: AnimatedOpacity(
                  opacity: rowIsHovered ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      if (!isClosed &&
                          position.qty != "0" &&
                          position.sPrdtAli != "BO" &&
                          position.sPrdtAli != "CO" &&
                          !positionBook.isDay) ...[
                        _buildHoverButton(
                          label: 'Add',
                          color: Colors.white,
                          backgroundColor: resolveThemeColor(
                            context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary,
                          ),
                          onPressed: () async {
                            await _handleAddPosition(context, position);
                          },
                          theme: theme,
                        ),
                        const SizedBox(width: 6),
                        _buildHoverButton(
                          label: 'Exit',
                          color: Colors.white,
                          backgroundColor: resolveThemeColor(
                            context,
                            dark: MyntColors.tertiary,
                            light: MyntColors.tertiary,
                          ),
                          onPressed: () async {
                            await _handleExitPosition(context, position);
                          },
                          theme: theme,
                        ),
                        const SizedBox(width: 6),
                      ],
                      _buildHoverButton(
                        icon: Icons.bar_chart,
                        color: Colors.black,
                        backgroundColor: Colors.white,
                        borderRadius: 5.0,
                        onPressed: () async {
                          await _handleChartTap(context, position);
                        },
                        theme: theme,
                      ),
                      if (!isClosed && position.qty != "0") ...[
                        const SizedBox(width: 6),
                        _buildHoverButton(
                          icon: Icons.swap_horiz,
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          borderRadius: 5.0,
                          iconWeight: 700,
                          onPressed: () {
                            _handleConvertPosition(context, position);
                          },
                          theme: theme,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionHeaderWidget(
    String label,
    int columnIndex,
    ThemesProvider theme,
    PortfolioProvider positionBook,
    List<PositionBookModel> filteredPositions,
  ) {
    // Special case for Select column (checkbox)
    if (label == 'Select') {
      // ✅ Watch provider state instead of using setState
      return Consumer(
        builder: (context, ref, child) {
          final isExitAllPosition =
              ref.watch(portfolioProvider.select((p) => p.isExitAllPosition));
          return InkWell(
            onTap: filteredPositions.isNotEmpty
                ? () {
                    positionBook.selectExitAllPosition(!isExitAllPosition);
                  }
                : null,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6.0),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    checkboxTheme: CheckboxThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Checkbox(
                    value: isExitAllPosition,
                    onChanged: filteredPositions.isNotEmpty
                        ? (bool? value) {
                            positionBook.selectExitAllPosition(value ?? false);
                          }
                        : null,
                    activeColor: resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark,
                      light: MyntColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Sortable header for other columns
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MyntWebTextStyles.head(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Sort icon - show unfold_more when not sorted, reserve space when sorted
        if (columnIndex > 0) _buildSortIcon(columnIndex, theme),
      ],
    );
  }

  Widget _buildSortIcon(int columnIndex, ThemesProvider theme) {
    IconData icon;
    Color color;

    if (_sortColumnIndex == columnIndex) {
      // Column is currently sorted
      icon = _sortAscending ? Icons.arrow_upward : Icons.arrow_downward;
      color = resolveThemeColor(
        context,
        dark: MyntColors.primaryDark,
        light: MyntColors.primary,
      );
    } else {
      // Column is not sorted
      icon = Icons.unfold_more;
      color = resolveThemeColor(
        context,
        dark: MyntColors.iconDark,
        light: MyntColors.icon,
      ).withOpacity(0.6);
    }

    return Icon(
      icon,
      size: 16,
      color: color,
    );
  }

  Widget _buildPositionCheckboxCell(
    PositionBookModel position,
    ThemesProvider theme,
    bool isClosed,
    PortfolioProvider positionBook,
  ) {
    // ✅ Use Consumer to watch only the specific position's selection state
    return Consumer(
      builder: (context, ref, child) {
        // Find the position index and watch its selection state
        final openPositions =
            ref.watch(portfolioProvider.select((p) => p.openPosition ?? []));
        final positionIndex =
            openPositions.indexWhere((p) => p.token == position.token);
        final isSelected = positionIndex >= 0
            ? (openPositions[positionIndex].isExitSelection ?? false)
            : (position.isExitSelection ?? false);

        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6.0),
            child: Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary,
                    ).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: Checkbox(
                value: isSelected,
                onChanged: isClosed
                    ? null
                    : (bool? value) {
                        if (positionIndex >= 0) {
                          positionBook.selectExitPosition(positionIndex);
                        }
                      },
                activeColor: resolveThemeColor(
                  context,
                  dark: MyntColors.primaryDark,
                  light: MyntColors.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionTextCell(
    String text,
    ThemesProvider theme,
    Alignment alignment, {
    Color? color,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6.0),
        child: Text(
          text,
          style: MyntWebTextStyles.bodySmall(
            context,
            color: color ??
                resolveThemeColor(
                  context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary,
                ),
            fontWeight: MyntFonts.medium,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  // Helper methods
  String _calculateTradeValue(PortfolioProvider positionBook) {
    double totalValue = 0.0;
    for (var position in widget.listofPosition) {
      // Trade value = today's buy amount + today's sell amount
      final dayBuyAmt = double.tryParse(position.daybuyamt ?? '0') ?? 0;
      final daySellAmt = double.tryParse(position.daysellamt ?? '0') ?? 0;
      totalValue += dayBuyAmt + daySellAmt;
    }
    return totalValue.toStringAsFixed(2);
  }

  String _calculateOpenPositionValue(PortfolioProvider positionBook) {
    double totalPnL = 0.0;
    for (var position in widget.listofPosition) {
      final qty = double.tryParse(position.qty ?? '0') ?? 0;
      // Only sum P&L of open positions (qty != 0)
      if (qty != 0) {
        final pnl = double.tryParse(position.profitNloss ?? '0') ?? 0;
        totalPnL += pnl;
      }
    }
    return totalPnL.toStringAsFixed(2);
  }

  String _calculateOpenPosition(PortfolioProvider positionBook) {
    int openCount = 0;
    for (var position in widget.listofPosition) {
      final qty = int.tryParse(position.qty ?? '0') ?? 0;
      if (qty != 0) openCount++;
    }
    return openCount.toString();
  }

  int _getOpenPositionsCount(PortfolioProvider positionBook) {
    // Count all positions (including closed) for display in tab
    return widget.listofPosition.length;
  }

  int _getPositivePositionsCount(PortfolioProvider positionBook) {
    int count = 0;
    for (var position in widget.listofPosition) {
      final pnl = double.tryParse(position.profitNloss ?? '0') ?? 0;
      if (pnl > 0) count++;
    }
    return count;
  }

  int _getNegativePositionsCount(PortfolioProvider positionBook) {
    int count = 0;
    for (var position in widget.listofPosition) {
      final pnl = double.tryParse(position.profitNloss ?? '0') ?? 0;
      if (pnl < 0) count++;
    }
    return count;
  }

  int _getClosedPositionsCount(PortfolioProvider positionBook) {
    int count = 0;
    for (var position in widget.listofPosition) {
      final qty = int.tryParse(position.qty ?? '0') ?? 0;
      if (qty == 0) count++;
    }
    return count;
  }

  // ✅ REMOVED: Old _getFilteredPositions method - replaced with _getFilteredPositionsFromList
  // This ensures we use the watched position list from provider for real-time updates

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      ); // Green
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      ); // Red
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      ); // Grey
    }
  }

  Color _getQtyColor(String qty, ThemesProvider theme) {
    final numQty = int.tryParse(qty) ?? 0;
    if (numQty > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numQty < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  String _formatQty(String qty) {
    final numQty = int.tryParse(qty) ?? 0;
    return numQty > 0 ? '+$qty' : qty;
  }

  // Format position quantity - for MCX, divide by lot size
  String _formatPositionQty(PositionBookModel position) {
    // Use netqty as the source (raw quantity from API)
    final rawQty = int.tryParse(position.netqty?.toString() ?? '0') ?? 0;
    final lotSize = position.exch == 'MCX'
        ? (int.tryParse(position.ls?.toString() ?? '1') ?? 1)
        : 1;
    final qty = rawQty ~/ lotSize;
    return qty > 0 ? '+$qty' : '$qty';
  }

  bool _isPositionClosed(PositionBookModel position) {
    final qty = int.tryParse(position.qty ?? '0') ?? 0;
    return qty == 0;
  }

  Color _getPositionTextColor(
      PositionBookModel position, ThemesProvider theme) {
    if (_isPositionClosed(position)) {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      ).withOpacity(0.6);
    }
    return resolveThemeColor(
      context,
      dark: MyntColors.textPrimaryDark,
      light: MyntColors.textPrimary,
    );
  }

  void _exitAllPositions() {
    final positionBook = ref.read(portfolioProvider);
    final openPositions = positionBook.openPosition ?? [];

    // Get selected positions from portfolio provider
    final selectedPositions = openPositions
        .where((p) => p.isExitSelection == true && p.qty != "0")
        .toList();

    if (selectedPositions.isEmpty) {
      // If no positions are selected, show all positions for exit
      final allPositions = openPositions.where((p) => p.qty != "0").toList();

      if (allPositions.isEmpty) {
        // No positions to exit
        return;
      }

      showDialog(
        context: context,
        barrierColor: resolveThemeColor(context,
            dark: MyntColors.modalBarrierDark,
            light: MyntColors.modalBarrierLight),
        builder: (context) => ExitAllPositionsDialogWeb(
          selectedPositions: allPositions,
          selectedIndices: List.generate(allPositions.length, (index) => index),
          isExitAll: true, // Exit ALL positions
        ),
      );
    } else {
      // Show only selected positions for exit
      showDialog(
        context: context,
        barrierColor: resolveThemeColor(context,
            dark: MyntColors.modalBarrierDark,
            light: MyntColors.modalBarrierLight),
        builder: (context) => ExitAllPositionsDialogWeb(
          selectedPositions: selectedPositions,
          selectedIndices:
              selectedPositions.map((p) => openPositions.indexOf(p)).toList(),
          isExitAll: false, // Exit only SELECTED positions
        ),
      );
    }
  }

  /// Shows the strategy builder inside this page in analyze mode. Its back
  /// arrow returns to the positions; the builder going away ends analyze mode.
  void _openAnalyze(List<PositionBookModel> positions) {
    // Sets analyze mode synchronously, so the builder skips its own initialize.
    ref.read(strategyBuilderProvider).loadFromPositions(positions, context);
    setState(() => _analyzing = true);
  }

  void _onSortTable(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        // If the same column is tapped, toggle the sort order
        _sortAscending = !_sortAscending;
      } else {
        // If a new column is tapped, sort it ascending by default
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  void _showPositionDetail(PositionBookModel position) {
    // Save parent context to pass to dialog
    final parentCtx = context;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: PositionDetailScreenWeb(
            positionList: position,
            parentContext: parentCtx, // Pass parent context for navigation
          ),
        );
      },
    );
  }

  Widget _buildHoverButton({
    String? label,
    IconData? icon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    double? iconWeight,
    required VoidCallback? onPressed,
    required ThemesProvider theme,
  }) {
    final isLongLabel = label != null && label.length > 1;
    final borderRadiusValue = borderRadius ?? 5.0;
    return SizedBox(
      width: isLongLabel ? null : 25,
      height: 25,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            padding:
                isLongLabel ? const EdgeInsets.symmetric(horizontal: 8) : null,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadiusValue),
              border: borderColor != null
                  ? Border.all(
                      color: borderColor,
                      width: 1.3,
                    )
                  : null,
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 16,
                      color: color,
                      weight: iconWeight ?? 400,
                    )
                  : Text(
                      label ?? "",
                      style: MyntWebTextStyles.buttonSm(
                        context,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isInWatchlist(PositionBookModel position, ThemesProvider theme) {
    try {
      final scripData = ref.read(marketWatchProvider);
      final scrips = scripData.scrips;
      final scripToken = "${position.exch ?? ''}|${position.token ?? ''}";
      return scrips
          .any((scrip) => "${scrip['exch']}|${scrip['token']}" == scripToken);
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleChartTap(
      BuildContext context, PositionBookModel position) async {
    final scripData = ref.read(marketWatchProvider);

    await scripData.fetchScripQuoteIndex(
      position.token ?? "",
      position.exch ?? "",
      context,
    );
    final quots = scripData.getQuotes;
    if (quots != null) {
      DepthInputArgs depthArgs = DepthInputArgs(
        exch: quots.exch?.toString() ?? "",
        token: quots.token?.toString() ?? "",
        tsym: quots.tsym?.toString() ?? "",
        instname: quots.instname?.toString() ?? "",
        symbol: quots.symbol?.toString() ?? "",
        expDate: quots.expDate?.toString() ?? "",
        option: quots.option?.toString() ?? "",
      );
      scripData.scripdepthsize(false);
      await scripData.calldepthApis(context, depthArgs, "");
    }
  }

  Future<void> _handlePlaceOrder(
      BuildContext context, PositionBookModel position, bool isBuy) async {
    try {
      final scripData = ref.read(marketWatchProvider);

      // Fetch scrip info first
      await scripData.fetchScripInfo(
        position.token ?? "",
        position.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final scripInfo = scripData.scripInfoModel!;
      final lotSize = scripInfo.ls?.toString() ?? "1";

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: position.exch ?? "",
        tSym: position.tsym ?? position.symbol ?? "",
        isExit: false,
        token: position.token ?? "",
        transType: isBuy,
        lotSize: lotSize,
        ltp: position.lp ?? "0.00",
        perChange: position.perChange ?? "0.00",
        orderTpye: '',
        holdQty: position.netqty ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error placing order: ${e.toString()}");
    }
  }

  Future<void> _handleExitPosition(
      BuildContext context, PositionBookModel position) async {
    try {
      final scripData = ref.read(marketWatchProvider);

      await scripData.fetchScripInfo(
        position.token ?? "",
        position.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final netQty = int.tryParse(position.netqty ?? "0") ?? 0;
      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: position.exch ?? "",
        tSym: position.tsym ?? "",
        isExit: true,
        token: position.token ?? "",
        transType: netQty < 0 ? true : false,
        prd: position.prd ?? "",
        lotSize: position.netqty ?? "",
        ltp: position.lp ?? "0.00",
        perChange: position.perChange ?? "0.00",
        orderTpye: '',
        holdQty: position.netqty ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripData.scripInfoModel!,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error exiting position: ${e.toString()}");
    }
  }

  Future<void> _handleAddPosition(
      BuildContext context, PositionBookModel position) async {
    try {
      final scripData = ref.read(marketWatchProvider);

      await scripData.fetchScripInfo(
        position.token ?? "",
        position.exch ?? "",
        context,
        true,
      );

      if (scripData.scripInfoModel == null) {
        showResponsiveWarningMessage(
            context, "Unable to fetch scrip information");
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";
      final netQty = int.tryParse(position.netqty ?? "0") ?? 0;

      OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: position.exch ?? "",
        tSym: position.tsym ?? "",
        isExit: false,
        token: position.token ?? "",
        transType: netQty < 0 ? false : true,
        prd: position.prd ?? "",
        lotSize: lotSize,
        ltp: position.lp ?? "0.00",
        perChange: position.perChange ?? "0.00",
        orderTpye: '',
        holdQty: position.netqty ?? '',
        isModify: false,
        raw: {},
      );

      ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripData.scripInfoModel!,
          "isBskt": "",
        },
      );
    } catch (e) {
      showResponsiveWarningMessage(
          context, "Error adding position: ${e.toString()}");
    }
  }

  void _handleConvertPosition(
      BuildContext context, PositionBookModel position) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConvertPositionDialogueWeb(convertPosition: position);
      },
    );
  }
}

// Isolated widget for LTP - only this rebuilds when LTP changes
class _LTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _LTPCell({required this.token, required this.initialLtp});

  @override
  ConsumerState<_LTPCell> createState() => _LTPCellState();
}

class _LTPCellState extends ConsumerState<_LTPCell> {
  late String ltp;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialLtp;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null &&
          newLtp != ltp &&
          newLtp != '0.00' &&
          newLtp != 'null') {
        setState(() => ltp = newLtp);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(ltp, textAlign: TextAlign.right);
  }
}

// Isolated widget for P&L - watches provider's calculated profitNloss
class _PnLCell extends ConsumerWidget {
  final String token;
  final int qty;
  final double avgPrice;
  final String initialValue;
  final ThemesProvider theme;
  final bool isClosed;

  const _PnLCell({
    required this.token,
    required this.qty,
    required this.avgPrice,
    required this.initialValue,
    required this.theme,
    required this.isClosed,
  });

  Color _getValueColor(BuildContext context, String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the position's profitNloss from the provider
    // positionCal() calculates this correctly: actualBookedPnl + actualUnrealizedPnl
    final positions = ref.watch(portfolioProvider.select((p) => p.allPostionList));
    final position = positions.firstWhere(
      (p) => p.token == token,
      orElse: () => positions.isNotEmpty ? positions.first : throw Exception('Position not found'),
    );

    final pnl = position.token == token ? (position.profitNloss ?? initialValue) : initialValue;

    return Text(
      pnl,
      style: MyntWebTextStyles.bodySmall(
        context,
        color: isClosed ? Colors.grey : _getValueColor(context, pnl),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

// Isolated widget for MTM - watches provider's calculated mTm
class _MTMCell extends ConsumerWidget {
  final String token;
  final int qty;
  final double avgPrice;
  final String initialValue;
  final ThemesProvider theme;
  final bool isClosed;

  const _MTMCell({
    required this.token,
    required this.qty,
    required this.avgPrice,
    required this.initialValue,
    required this.theme,
    required this.isClosed,
  });

  Color _getValueColor(BuildContext context, String value) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the position's mTm from the provider
    // positionCal() calculates this correctly: rpnl + actualUnrealizedMtm
    final positions = ref.watch(portfolioProvider.select((p) => p.allPostionList));
    final position = positions.firstWhere(
      (p) => p.token == token,
      orElse: () => positions.isNotEmpty ? positions.first : throw Exception('Position not found'),
    );

    final mtm = position.token == token ? (position.mTm ?? initialValue) : initialValue;

    return Text(
      mtm,
      style: MyntWebTextStyles.bodySmall(
        context,
        color: isClosed ? Colors.grey : _getValueColor(context, mtm),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;


import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../models/mf_model/mutual_fundmodel.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/thems.dart';

import '../../../routes/route_names.dart';
import '../../../sharedWidget/custom_back_btn.dart';
import 'mf_order_screen_web.dart';

import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/common_search_fields_web.dart';

class MFCategoryListScreenWeb extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback? onBack;
  final Function(MutualFundList)? onFundTap;
  const MFCategoryListScreenWeb({
    super.key,
    required this.title,
    this.subtitle = "Build wealth and save taxes",
    this.icon = "",
    this.onBack,
    this.onFundTap,
  });

  @override
  ConsumerState<MFCategoryListScreenWeb> createState() =>
      _MFCategoryListScreenState();
}

class _MFCategoryListScreenState extends ConsumerState<MFCategoryListScreenWeb> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  // Dedicated to the category tab strip - sharing one controller across two
  // scroll views makes position/offset lookups throw.
  final ScrollController _tabScrollController = ScrollController();
  int selectedTab = 0;
  List<String> tabTitles = [];
  bool _tabsReady = false;

  // Tab overflow arrows
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  BoxConstraints? _lastConstraints;
  // String selectedReturn = '3Y Returns'; // Removed

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Popover state management
  shadcn.PopoverController? _activePopoverController;
  int? _popoverRowIndex;
  bool _isHoveringDropdown = false;
  Timer? _popoverCloseTimer;

  @override
  void initState() {
    super.initState();

    // Listen to hover changes for popover management
    _hoveredRowIndex.addListener(_onHoverChanged);

    _tabScrollController.addListener(_updateScrollArrows);

    // Initialize tab titles based on the category data. Done synchronously so
    // the first frame already has the tabs when the category data is cached,
    // instead of flashing the empty state for one frame.
    _initializeTabs(notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTabs();
    });
  }

  void _onHoverChanged() {
    if (_activePopoverController != null) {
      final currentHover = _hoveredRowIndex.value;
      if (currentHover == _popoverRowIndex) {
        _cancelPopoverCloseTimer();
        return;
      }
      if (_isHoveringDropdown) {
        _cancelPopoverCloseTimer();
        return;
      }
      _startPopoverCloseTimer();
    }
  }

  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_isHoveringDropdown && _hoveredRowIndex.value != _popoverRowIndex) {
        _closePopover();
      }
    });
  }

  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  void _closePopover() {
    _cancelPopoverCloseTimer();
    try {
      _activePopoverController?.close();
    } catch (_) {}
    final needsRebuild = _activePopoverController != null || _popoverRowIndex != null;
    _activePopoverController = null;
    _popoverRowIndex = null;
    _isHoveringDropdown = false;
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  // [notify] is false when called from initState, where setState is illegal.
  void _initializeTabs({bool notify = true}) {
    if (_tabsReady || !mounted) return;

    final mfData = ref.read(mfProvider);
    final categoryData = mfData.mFCategoryTypesStatic;

    // Find the matching category and get its sub-tabs
    for (var category in categoryData) {
      if (category['title'] == widget.title) {
        List<dynamic> subTabs = category['sub'] ?? [];
        // Sub-tabs are filled by the category API; bail out and retry on the
        // next provider update if the response hasn't arrived yet.
        if (subTabs.isEmpty) return;
        // Remove duplicates and convert to list
        tabTitles = subTabs.map((tab) => tab.toString()).toSet().toList();
        _tabsReady = true;
        if (notify) setState(() {});
        break;
      }
    }

    if (tabTitles.isNotEmpty) {
      selectedTab = 0;

      // Scroll to center the initial tab after the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveTab(selectedTab);
      });
    }
  }

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _hoveredRowIndex.removeListener(_onHoverChanged);
    _tabScrollController.removeListener(_updateScrollArrows);
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    _tabScrollController.dispose();
    _hoveredRowIndex.dispose();

    super.dispose();
  }

  void _updateScrollArrows() {
    if (!mounted) return;
    // Additional safety check to prevent setState after dispose
    try {
      if (!_tabScrollController.hasClients) return;
      final newCanScrollLeft = _tabScrollController.offset > 0;
      final newCanScrollRight = _tabScrollController.offset <
          _tabScrollController.position.maxScrollExtent;

      // Only call setState if values actually changed
      if (_canScrollLeft != newCanScrollLeft ||
          _canScrollRight != newCanScrollRight) {
        setState(() {
          _canScrollLeft = newCanScrollLeft;
          _canScrollRight = newCanScrollRight;
        });
      }
    } catch (e) {
      // Silently handle any errors during scroll position access
      // This prevents crashes when widget is being disposed
    }
  }

  void _scrollTabs({required bool left}) {
    if (!_tabScrollController.hasClients) return;
    final contentSize = _tabScrollController.position.viewportDimension;
    final maxScroll = _tabScrollController.position.maxScrollExtent;
    final currentScroll = _tabScrollController.offset;
    final scrollAmount = contentSize * 0.8; // Scroll 80% of view width

    double target;
    if (left) {
      target = (currentScroll - scrollAmount).clamp(0.0, maxScroll);
    } else {
      target = (currentScroll + scrollAmount).clamp(0.0, maxScroll);
    }

    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToActiveTab(int index) {
    if (_tabScrollController.hasClients) {
      // Calculate cumulative width up to the current tab
      final double totalWidthUpToIndex = _calculateTotalWidthUpToIndex(index);
      final double currentTabWidth = _calculateTabWidth(tabTitles[index]);
      final double screenWidth = MediaQuery.of(context).size.width;

      // Calculate scroll position to center the active tab
      final double scrollPosition =
          totalWidthUpToIndex - (screenWidth / 2) + (currentTabWidth / 2);

      _tabScrollController.animateTo(
        scrollPosition.clamp(
            0.0, _tabScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  double _calculateTabWidth(String text) {
    // Pill chrome: 16px horizontal padding either side + 8px right margin
    const double baseWidth = 40.0;
    // Approximate character width (adjust based on your font)
    const double charWidth = 7.0;
    // Calculate width based on text length
    double textWidth = text.length * charWidth;
    // Add base width and ensure minimum width
    return (textWidth + baseWidth).clamp(60.0, 300.0);
  }

  double _calculateTotalWidthUpToIndex(int index) {
    double totalWidth = 0.0;
    for (int i = 0; i < index && i < tabTitles.length; i++) {
      totalWidth += _calculateTabWidth(tabTitles[i]);
    }
    return totalWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final mfData = ref.watch(mfProvider);

    // The category API fills the sub-tabs asynchronously, so keep retrying
    // until they arrive instead of settling on an empty screen.
    if (!_tabsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeTabs());
    }

    // Still waiting on the category response - show the loader, not "no data".
    // fetchmfallcatnew() clears every 'sub' list before refilling it, so a
    // non-null mfallcatnewlist does not mean the sub-tabs are available yet.
    final categoriesPending = !_tabsReady &&
        (mfData.categoryDataLoader || mfData.mfallcatnewlist == null);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(context, theme),
            if (tabTitles.isNotEmpty) _buildTabBar(context, theme, mfData),
            Expanded(
              child: MyntLoaderOverlay(
                // Show loader when tab data is loading or when fund detail is loading
                isLoading: categoriesPending ||
                    (tabTitles.isEmpty && (mfData.bestmfloader ?? false)) ||
                    mfData.fundDetailLoader,
                child: categoriesPending
                    ? const SizedBox.expand()
                    : tabTitles.isEmpty
                        ? const Center(
                            child: NoDataFound(
                            secondaryEnabled: false,
                          ))
                        : _buildFundList(
                            tabTitles[selectedTab],
                            mfData,
                            theme,
                            context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(
      BuildContext context, ThemesProvider theme, dynamic mfData) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Only update scroll arrows when constraints actually change
          if (_lastConstraints != constraints) {
            _lastConstraints = constraints;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateScrollArrows();
            });
          }

          // Arrows only appear once the pills no longer fit the row
          final bool isOverflowing =
              _calculateTotalWidthUpToIndex(tabTitles.length) >
                  constraints.maxWidth;

          return Row(
            children: [
              if (isOverflowing)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: _canScrollLeft ? () => _scrollTabs(left: true) : null,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: _canScrollLeft
                            ? (theme.isDarkMode ? Colors.white : Colors.black)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      tabTitles.length,
                      (tab) => MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            if (selectedTab == tab) return;
                            setState(() {
                              selectedTab = tab;
                            });
                            mfData.changetitle(tabTitles[tab]);
                            mfData.fetchcatdatanew(
                                widget.title, tabTitles[tab]);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToActiveTab(tab);
                            });
                          },
                          child:
                              _tabConstruct(context, tabTitles[tab], theme, tab),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isOverflowing)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: InkWell(
                    onTap:
                        _canScrollRight ? () => _scrollTabs(left: false) : null,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: _canScrollRight
                            ? (theme.isDarkMode ? Colors.white : Colors.black)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabConstruct(
      BuildContext context, String title, ThemesProvider theme, int tab) {
    final isActive = selectedTab == tab;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? (theme.isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: MyntWebTextStyles.body(
          context,
          fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
        ).copyWith(
          color: isActive
              ? shadcn.Theme.of(context).colorScheme.foreground
              : shadcn.Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          CustomBackBtn(onBack: widget.onBack),
          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: MyntWebTextStyles.tableCell(context,
                    darkColor: MyntColors.textPrimaryDark,
                    lightColor: MyntColors.textPrimary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: MyntWebTextStyles.para(context,
                    darkColor: MyntColors.textSecondaryDark,
                    lightColor: MyntColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 300,
            height: 40,
            child: MyntSearchTextField(
              controller: _searchController,
              placeholder: 'Search funds',
              leadingIcon: 'assets/icon/search.svg',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16), // Right padding
        ],
      ),
    );
  }

  // Standardized text style helpers
  TextStyle _getTextStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableCell(
      context,
      color: color,
      darkColor: color ?? MyntColors.textPrimaryDark,
      lightColor: color ?? MyntColors.textPrimary,
      fontWeight: MyntFonts.medium,
    );
  }

  TextStyle _getHeaderStyle(BuildContext context, {Color? color}) {
    return MyntWebTextStyles.tableHeader(
      context,
      color: color,
      darkColor: color ?? MyntColors.textSecondaryDark,
      lightColor: color ?? MyntColors.textSecondary,
      fontWeight: MyntFonts.semiBold,
    );
  }

  // Builds a cell with hover detection
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    VoidCallback? onTap, // Added onTap
    bool alignRight = false,
  }) {
    // Add extra horizontal padding for first and last columns
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 4;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 12, 12, 12);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(12, 12, 16, 12);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            // Also highlight when popover is open for this row
            final isRowHovered = hoveredIndex == rowIndex || _popoverRowIndex == rowIndex;

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: cellPadding,
                color: isRowHovered
                    ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ).withValues(alpha: 0.08)
                    : null,
                alignment: alignRight ? Alignment.topRight : null,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  // Builds a sortable header cell
  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 4;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding =
          const EdgeInsets.fromLTRB(16, 0, 8, 0); // Reduced to 0 vertical
    } else if (isLastColumn) {
      headerPadding =
          const EdgeInsets.fromLTRB(8, 0, 16, 0); // Reduced to 0 vertical
    } else {
      headerPadding = const EdgeInsets.symmetric(
          horizontal: 6, vertical: 0); // Reduced to 0 vertical
    }

    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _onSort(columnIndex),
        child: Container(
          padding: headerPadding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              if (alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Text(
                label,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && _sortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _sortColumnIndex == columnIndex)
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  // Build fund name cell with hover dropdown menu
  shadcn.TableCell _buildFundNameCellWithActions({
    required dynamic item,
    required int rowIndex,
    required String amcCode,
    required dynamic mfData,
    VoidCallback? onTap,
  }) {
    return shadcn.TableCell(
      theme: const shadcn.TableCellTheme(
        border: shadcn.WidgetStatePropertyAll(
          shadcn.Border(
            top: shadcn.BorderSide.none,
            bottom: shadcn.BorderSide.none,
            left: shadcn.BorderSide.none,
            right: shadcn.BorderSide.none,
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) {
          _hoveredRowIndex.value = rowIndex;
          if (_activePopoverController != null && _popoverRowIndex == rowIndex) {
            _cancelPopoverCloseTimer();
          }
        },
        onExit: (_) {
          _hoveredRowIndex.value = null;
          if (_activePopoverController != null && !_isHoveringDropdown) {
            _startPopoverCloseTimer();
          }
        },
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          builder: (context, hoveredIndex, _) {
            final isHovered = hoveredIndex == rowIndex || _popoverRowIndex == rowIndex;
            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                color: isHovered
                    ? resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary,
                      ).withValues(alpha: 0.08)
                    : null,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(
                        "https://v3.mynt.in/mfapi/static/images/mf/$amcCode.png",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name ?? '--',
                            style: _getTextStyle(context),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${item.type ?? 'Equity'}   ${item.subType ?? item.schemeType ?? ''}",
                            style: MyntWebTextStyles.para(
                                context,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // 3-dot dropdown button on hover
                    if (isHovered) ...[
                      const SizedBox(width: 8),
                      _buildOptionsMenuButton(
                        item: item,
                        rowIndex: rowIndex,
                        mfData: mfData,
                        onTap: onTap,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton({
    required dynamic item,
    required int rowIndex,
    required dynamic mfData,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Close any existing popover first
            _closePopover();

            // Build menu items
            List<shadcn.MenuItem> menuItems = [];
            final iconColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);
            final textColor = resolveThemeColor(context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary);

            // One-Time option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.payments_outlined,
                title: 'One-Time',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _handleOrder(item, 'One-time', mfData);
                },
              ),
            );

            // SIP option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.autorenew,
                title: 'SIP',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _handleOrder(item, 'SIP', mfData);
                },
              ),
            );

            // Divider
            menuItems.add(const shadcn.MenuDivider());

            // Details option
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Details',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  if (onTap != null) onTap();
                },
              ),
            );

            // Create a controller for this popover
            final controller = shadcn.PopoverController();
            _activePopoverController = controller;
            _popoverRowIndex = rowIndex;

            // Show the shadcn popover menu anchored to this button
            controller.show(
              context: buttonContext,
              alignment: Alignment.topRight,
              offset: const Offset(0, 4),
              builder: (ctx) {
                return MouseRegion(
                  onEnter: (_) {
                    _isHoveringDropdown = true;
                    _cancelPopoverCloseTimer();
                  },
                  onExit: (_) {
                    _isHoveringDropdown = false;
                    _startPopoverCloseTimer();
                  },
                  child: shadcn.DropdownMenu(
                    children: menuItems,
                  ),
                );
              },
            );

            // Force rebuild to show row highlight
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: MyntColors.textWhite,
                  light: MyntColors.textWhite),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: resolveThemeColor(context,
                      dark: Colors.transparent,
                      light: Colors.grey),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.more_vert,
              size: 18,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  // Helper method for building menu buttons
  shadcn.MenuButton _buildMenuButton({
    required IconData icon,
    required String title,
    required void Function(BuildContext) onPressed,
    required Color iconColor,
    required Color textColor,
  }) {
    return shadcn.MenuButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                fontWeight: MyntFonts.medium,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundList(String selectedTab, dynamic mfData,
      ThemesProvider theme, BuildContext context) {
    // Sort the list based on selected return period
    List<dynamic>? filteredList = mfData.catnewlist?.toList();

    if (_searchQuery.isNotEmpty && filteredList != null) {
      filteredList = filteredList.where((item) {
        if (item == null) return false;
        final name = (item.name ?? '').toLowerCase();
        final search = _searchQuery.toLowerCase();
        return name.contains(search);
      }).toList();
    }

    final sortedList = filteredList;

    if (sortedList != null && sortedList.isNotEmpty) {
      if (_sortColumnIndex != null) {
        sortedList.sort((a, b) {
          if (a == null || b == null) return 0;
          int compareResult = 0;
          switch (_sortColumnIndex) {
            case 0: // Name
              compareResult = (a.name ?? '').compareTo(b.name ?? '');
              break;
            case 1: // AUM
              compareResult = (double.tryParse(a.aUM ?? '0') ?? 0)
                  .compareTo(double.tryParse(b.aUM ?? '0') ?? 0);
              break;
            case 2: // 1Y
              compareResult = (double.tryParse(a.s1Year ?? '0') ?? 0)
                  .compareTo(double.tryParse(b.s1Year ?? '0') ?? 0);
              break;
            case 3: // 3Y
              compareResult = (double.tryParse(a.s3Year ?? '0') ?? 0)
                  .compareTo(double.tryParse(b.s3Year ?? '0') ?? 0);
              break;
            case 4: // Min Invest
              compareResult =
                  (double.tryParse(a.minimumPurchaseAmount ?? '0') ?? 0)
                      .compareTo(
                          double.tryParse(b.minimumPurchaseAmount ?? '0') ?? 0);
              break;
          }
          return _sortAscending ? compareResult : -compareResult;
        });
      } else {
        // Default order: highest 3Y return first
        sortedList.sort((a, b) {
          if (a == null || b == null) return 0;
          return (double.tryParse(b.s3Year ?? '0') ?? 0)
              .compareTo(double.tryParse(a.s3Year ?? '0') ?? 0);
        });
      }
    }

    if (sortedList == null || sortedList.isEmpty) {
      return const Center(
          child: NoDataFound(
        secondaryEnabled: false,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final double fundNameWidth = totalWidth * 0.40;
        final double otherColumnWidth = totalWidth * 0.15;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: shadcn.OutlinedContainer(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: false, // Hidden scrollbar
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalWidth),
                  child: Column(
                    children: [
                      // Fixed Header Table
                      shadcn.Table(
                        defaultRowHeight: const shadcn.FixedTableSize(
                            50), // Reduced header height
                        columnWidths: {
                          0: shadcn.FixedTableSize(fundNameWidth),
                          1: shadcn.FixedTableSize(otherColumnWidth), // AUM
                          2: shadcn.FixedTableSize(
                              otherColumnWidth), // 1yr CAGR
                          3: shadcn.FixedTableSize(
                              otherColumnWidth), // 3yr CAGR
                          4: shadcn.FixedTableSize(
                              otherColumnWidth), // Min. Invest
                        },
                        rows: [
                          shadcn.TableHeader(
                            cells: [
                              buildHeaderCell('Fund name', 0),
                              buildHeaderCell('AUM', 1, true),
                              buildHeaderCell('1yr CAGR', 2, true),
                              buildHeaderCell('3yr CAGR', 3, true),
                              buildHeaderCell('Min. Invest', 4, true),
                            ],
                          ),
                        ],
                      ),
                      // Scrollable Body Table
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: shadcn.Table(
                            defaultRowHeight:
                                const shadcn.FixedTableSize(70), // Data height
                            columnWidths: {
                              0: shadcn.FixedTableSize(fundNameWidth),
                              1: shadcn.FixedTableSize(otherColumnWidth), // AUM
                              2: shadcn.FixedTableSize(
                                  otherColumnWidth), // 1yr CAGR
                              3: shadcn.FixedTableSize(
                                  otherColumnWidth), // 3yr CAGR
                              4: shadcn.FixedTableSize(
                                  otherColumnWidth), // Min. Invest
                            },
                            rows: [
                              ...sortedList.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                if (item == null)
                                  return const shadcn.TableRow(cells: []);
                                final amcCode = item.aMCCode ?? "default";

                                // Define onTap function
                                void onTap() async {
                                  try {
                                    if (item.iSIN != null) {
                                      await mfData.fetchFactSheet(item.iSIN);

                                      if (mfData.factSheetDataModel?.stat !=
                                          "Not Ok") {
                                        Map<String, dynamic> jsonData =
                                            item.toJson();
                                        MutualFundList bInstance =
                                            MutualFundList.fromJson(jsonData);

                                        // Use callback for panel system, otherwise use Navigator
                                        if (widget.onFundTap != null) {
                                          widget.onFundTap!(bInstance);
                                        } else {
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .pushNamed(
                                            Routes.mfStockDetail,
                                            arguments: bInstance,
                                          );
                                        }
                                      } else {
                                        ResponsiveSnackBar.show(
                                            context: context,
                                            message: "No Single Page Data",
                                            type: SnackBarType.error);
                                        final jsondata =
                                            MutualFundList.fromJson(
                                                item.toJson());
                                        Navigator.pushNamed(
                                            context, Routes.mforderScreen,
                                            arguments: jsondata);
                                        mfData.orderchangetitle("One-time");
                                        mfData.chngOrderType("One-time");
                                      }
                                    } else {
                                      ResponsiveSnackBar.show(
                                          context: context,
                                          message: "Missing fund information",
                                          type: SnackBarType.error);
                                    }
                                  } catch (e) {
                                    // Error handling
                                  }
                                }

                                return shadcn.TableRow(
                                  cells: [
                                    // Fund name column with 3-dot dropdown menu
                                    _buildFundNameCellWithActions(
                                      item: item,
                                      rowIndex: index,
                                      amcCode: amcCode,
                                      mfData: mfData,
                                      onTap: onTap,
                                    ),
                                    // AUM column
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 1,
                                      alignRight: true,
                                      onTap: onTap,
                                      child: Text(
                                        _formatAUM(item.aUM),
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                    // 1yr CAGR column
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 2,
                                      alignRight: true,
                                      onTap: onTap,
                                      child: Text(_formatReturns(item.s1Year),
                                          style: _getTextStyle(context)),
                                    ),
                                    // 3yr CAGR column
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 3,
                                      alignRight: true,
                                      onTap: onTap,
                                      child: Text(
                                        _formatCAGR(item.s3Year),
                                        style: _getTextStyle(context,
                                            color: _getReturnColor(
                                                context, item.s3Year)),
                                      ),
                                    ),
                                    // Min. Invest column
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 4,
                                      alignRight: true,
                                      onTap: onTap,
                                      child: Text(
                                        '₹${item.minimumPurchaseAmount ?? '500.00'}',
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
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
  }

  Future<void> _handleOrder(
      dynamic item, String orderType, dynamic mfData) async {
    // Pre-fill amount based on order type (synchronous - no delay)
    if (orderType == "One-time") {
      String amt = item.minimumPurchaseAmount ?? "0";
      mfData.invAmt.text = amt.split('.').first;
    } else {
      String amt = item.minimumPurchaseAmount ?? "0";
      mfData.installmentAmt.text = amt.split('.').first;
    }

    // Convert item to MutualFundList
    Map<String, dynamic> jsonData = item.toJson();
    // Ensure fSchemeName is set from name if not present
    if (jsonData['f_scheme_name'] == null && jsonData['name'] != null) {
      jsonData['f_scheme_name'] = jsonData['name'];
    }
    MutualFundList mfItem = MutualFundList.fromJson(jsonData);

    // Set order type immediately
    mfData.chngOrderType(orderType);
    mfData.orderchangetitle(orderType);

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.30).clamp(380.0, 500.0);
    final isDark = ref.read(themeProvider).isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: isDark
            ? MyntColors.backgroundColorDark
            : MyntColors.backgroundColor,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: dialogWidth,
          child: MFOrderScreenWeb(mfData: mfItem),
        ),
      ),
    );
    // Note: SIP data and mandate details are loaded in MFOrderScreen's initState
  }

  String _formatReturns(String? returns) {
    if (returns == null || returns.isEmpty || returns == "0.0") {
      return "0.00%";
    }
    return "$returns%";
  }

  String _formatCAGR(String? returns) {
    return _formatReturns(returns);
  }

  String _formatAUM(String? aum) {
    if (aum == null || aum.isEmpty) return "--";
    try {
      double value = double.tryParse(aum) ?? 0;
      return value.toStringAsFixed(2);
    } catch (e) {
      return aum;
    }
  }

  Color _getReturnColor(BuildContext context, String? returns) {
    if (returns == null || returns.isEmpty) {
      return Colors.grey;
    }

    try {
      final value = double.parse(returns);
      if (value > 0) {
        return resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit);
      }
      if (value < 0) {
        return resolveThemeColor(context,
            dark: MyntColors.lossDark, light: MyntColors.loss);
      }
      return Colors.grey;
    } catch (e) {
      // If parsing fails, return a neutral color
      return Colors.grey;
    }
  }
}

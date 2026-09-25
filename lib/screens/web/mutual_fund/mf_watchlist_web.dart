// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
// import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../../../provider/mf_provider.dart';
import '../../../provider/thems.dart';
import '../../../routes/route_names.dart';
import '../../../sharedWidget/mynt_loader.dart';
import '../../../sharedWidget/no_data_found.dart';
import 'mf_order_screen_web.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import 'mf_search_popup_web.dart';

class MFWatchlistScreenWeb extends ConsumerStatefulWidget {
  final Function(MutualFundList mfData)? onFundTap;

  const MFWatchlistScreenWeb({super.key, this.onFundTap});

  @override
  ConsumerState<MFWatchlistScreenWeb> createState() => _MFWatchlistScreenState();
}

class _MFWatchlistScreenState extends ConsumerState<MFWatchlistScreenWeb> {
  TextEditingController searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String searchQuery = "";

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fetch watchlist data on first load
      ref.read(mfProvider).fetchMFWatchlist("", "", context, true, "");
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

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _hoveredRowIndex.removeListener(_onHoverChanged);
    searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final mfData = ref.watch(mfProvider);

    // Get watchlist data
    final watchlist = mfData.mfWatchlist?.toList() ?? [];

    // Filter list based on search query
    final filteredList = watchlist.where((item) {
      final name =
          (item.mfsearchnamename ?? item.schemeName ?? '').toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    // Sort list
    if (_sortColumnIndex != null) {
      filteredList.sort((a, b) {
        int compareResult = 0;
        switch (_sortColumnIndex) {
          case 0: // Name
            compareResult =
                (a.mfsearchnamename ?? '').compareTo(b.mfsearchnamename ?? '');
            break;
          case 1: // AUM (Assuming field name aUM matches model)
            compareResult = (double.tryParse(a.aUM ?? '0') ?? 0)
                .compareTo(double.tryParse(b.aUM ?? '0') ?? 0);
            break;
          case 2: // 1Y
            compareResult = (double.tryParse(a.oneYearData ?? '0') ?? 0)
                .compareTo(double.tryParse(b.oneYearData ?? '0') ?? 0);
            break;
          case 3: // 3Y
            compareResult = (double.tryParse(a.tHREEYEARDATA ?? '0') ?? 0)
                .compareTo(double.tryParse(b.tHREEYEARDATA ?? '0') ?? 0);
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
      filteredList.sort((a, b) => (double.tryParse(b.tHREEYEARDATA ?? '0') ?? 0)
          .compareTo(double.tryParse(a.tHREEYEARDATA ?? '0') ?? 0));
    }

    return MyntLoaderOverlay(
      // Show loader when watchlist data is loading or when fund detail is loading
      isLoading: (mfData.mfWatchlist == null && (mfData.bestmfloader ?? false)) || mfData.fundDetailLoader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(theme),
          Expanded(
            child:
                _buildTableWithHeader(filteredList, theme, mfData, searchQuery),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemesProvider theme) {
    return Container(
      width: double.infinity,
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? MyntColors.inputBgDark : MyntColors.searchBg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const MFSearchPopupWeb(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 21,
                color: theme.isDarkMode
                    ? MyntColors.textSecondaryDark
                    : MyntColors.textSecondary,
              ),
              const SizedBox(
                  width: 8), // Common search field usually has 8-12 gap
              Text(
                "Search & Add",
                style: MyntWebTextStyles.placeholder(
                  context,
                  color: theme.isDarkMode
                      ? MyntColors.textSecondaryDark
                      : MyntColors.textSecondary,
                  fontWeight: MyntFonts.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableWithHeader(List<dynamic> data, ThemesProvider theme,
      MFProvider mf, String searchQuery) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: shadcn.OutlinedContainer(
        child: LayoutBuilder(builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double fundNameWidth = totalWidth * 0.40;
          final double otherColumnWidth = totalWidth * 0.15;

          return Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: false, // matches mf_all_best_funds
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: totalWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed Header Table
                    shadcn.Table(
                      defaultRowHeight: const shadcn.FixedTableSize(50),
                      columnWidths: {
                        0: shadcn.FixedTableSize(fundNameWidth),
                        1: shadcn.FixedTableSize(otherColumnWidth), // AUM
                        2: shadcn.FixedTableSize(otherColumnWidth), // 1Y
                        3: shadcn.FixedTableSize(otherColumnWidth), // 3Y
                        4: shadcn.FixedTableSize(
                            otherColumnWidth), // Min Invest
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
                    if (data.isNotEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: shadcn.Table(
                            defaultRowHeight:
                                const shadcn.FixedTableSize(60), // Data height
                            columnWidths: {
                              0: shadcn.FixedTableSize(fundNameWidth),
                              1: shadcn.FixedTableSize(otherColumnWidth), // AUM
                              2: shadcn.FixedTableSize(otherColumnWidth), // 1Y
                              3: shadcn.FixedTableSize(otherColumnWidth), // 3Y
                              4: shadcn.FixedTableSize(
                                  otherColumnWidth), // Min Invest
                            },
                            rows: [
                              ...data.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;

                                return shadcn.TableRow(
                                  cells: [
                                    // Fund Name with 3-dot dropdown menu
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 0,
                                      onTap: () => _openFundDetails(item, mf),
                                      child: _buildFundNameCellWithActions(
                                        item: item,
                                        rowIndex: index,
                                        mf: mf,
                                        onTap: () => _openFundDetails(item, mf),
                                      ),
                                    ),
                                    // AUM
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 1,
                                      alignRight: true,
                                      onTap: () => _openFundDetails(item, mf),
                                      child: Text(
                                        _formatAUM(item.aUM),
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                    // 1yr
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 2,
                                      alignRight: true,
                                      onTap: () => _openFundDetails(item, mf),
                                      child: Text(
                                        _formatReturns(item.oneYearData),
                                        style: _getTextStyle(context),
                                      ),
                                    ),
                                    // 3yr
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 3,
                                      alignRight: true,
                                      onTap: () => _openFundDetails(item, mf),
                                      child: Text(
                                        _formatReturns(item.tHREEYEARDATA),
                                        style: _getTextStyle(context,
                                            color: _getReturnColor(
                                                context, item.tHREEYEARDATA)),
                                      ),
                                    ),
                                    // Min Invest
                                    buildCellWithHover(
                                      rowIndex: index,
                                      columnIndex: 4,
                                      alignRight: true,
                                      onTap: () => _openFundDetails(item, mf),
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
                    if (data.isEmpty)
                      Expanded(
                        child: Center(
                          child: NoDataFound(
                            title: "No Funds Found",
                            subtitle: searchQuery.isNotEmpty
                                ? "No funds match your search"
                                : "Add your favorite funds to your watchlist",
                            primaryEnabled: false,
                            secondaryEnabled: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTable(List<dynamic> data, ThemesProvider theme, MFProvider mf) {
    return LayoutBuilder(builder: (context, constraints) {
      final double totalWidth = constraints.maxWidth - 32;
      final double fundNameWidth = totalWidth * 0.40;
      final double otherColumnWidth = totalWidth * 0.15;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
              child: shadcn.Table(
                defaultRowHeight: const shadcn.FixedTableSize(50),
                columnWidths: {
                  0: shadcn.FixedTableSize(fundNameWidth),
                  1: shadcn.FixedTableSize(otherColumnWidth), // AUM
                  2: shadcn.FixedTableSize(otherColumnWidth), // 1Y
                  3: shadcn.FixedTableSize(otherColumnWidth), // 3Y
                  4: shadcn.FixedTableSize(otherColumnWidth), // Min Invest
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
                  ...data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;

                    return shadcn.TableRow(
                      cells: [
                        // Fund Name with 3-dot dropdown menu
                        buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 0,
                          onTap: () => _openFundDetails(item, mf),
                          child: _buildFundNameCellWithActions(
                            item: item,
                            rowIndex: index,
                            mf: mf,
                            onTap: () => _openFundDetails(item, mf),
                          ),
                        ),
                        // AUM
                        buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 1,
                          alignRight: true,
                          onTap: () => _openFundDetails(item, mf),
                          child: Text(
                            _formatAUM(item.aUM),
                            style: _getTextStyle(context),
                          ),
                        ),
                        // 1yr
                        buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 2,
                          alignRight: true,
                          onTap: () => _openFundDetails(item, mf),
                          child: Text(
                            _formatReturns(item.oneYearData),
                            style: _getTextStyle(context),
                          ),
                        ),
                        // 3yr
                        buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 3,
                          alignRight: true,
                          onTap: () => _openFundDetails(item, mf),
                          child: Text(
                            _formatReturns(item.tHREEYEARDATA),
                            style: _getTextStyle(context,
                                color: _getReturnColor(
                                    context, item.tHREEYEARDATA)),
                          ),
                        ),
                        // Min Invest
                        buildCellWithHover(
                          rowIndex: index,
                          columnIndex: 4,
                          alignRight: true,
                          onTap: () => _openFundDetails(item, mf),
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
        ),
      );
    });
  }

  Widget _buildFundNameCellWithActions({
    required dynamic item,
    required int rowIndex,
    required MFProvider mf,
    required VoidCallback onTap,
  }) {
    final amcCode = item.aMCCode ?? "default";

    return ValueListenableBuilder<int?>(
      valueListenable: _hoveredRowIndex,
      builder: (context, hoveredIndex, _) {
        final isHovered = hoveredIndex == rowIndex || _popoverRowIndex == rowIndex;

        return Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(
                "https://v3.mynt.in/mfapi/static/images/mf/$amcCode.png",
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.mfsearchnamename ?? item.schemeName ?? '--',
                    style: _getTextStyle(context),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.type ?? 'Equity',
                    style: MyntWebTextStyles.para(context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Action buttons on hover
            if (isHovered) ...[
              const SizedBox(width: 8),
              // Remove button (X icon)
              GestureDetector(
                onTap: () => _handleRemove(item, mf),
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
                            dark: Colors.transparent, light: Colors.grey),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    fontWeight: FontWeight.bold,
                    color: resolveThemeColor(context,
                        dark: MyntColors.lossDark, light: MyntColors.loss),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Options menu button (3-dot icon)
              _buildOptionsMenuButton(
                item: item,
                rowIndex: rowIndex,
                mf: mf,
                onTap: onTap,
              ),
            ],
          ],
        );
      },
    );
  }

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton({
    required dynamic item,
    required int rowIndex,
    required MFProvider mf,
    required VoidCallback onTap,
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
                  _handleOrder(item, 'One-time', mf);
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
                  _handleOrder(item, 'SIP', mf);
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
                  onTap();
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
                      dark: Colors.transparent, light: Colors.grey),
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

  // Handle remove from watchlist
  Future<void> _handleRemove(dynamic item, MFProvider mf) async {
    final isin = item.iSIN;
    if (isin != null) {
      await mf.fetchMFWatchlist(
        isin,
        "delete",
        context,
        true,
        "watch",
      );
    }
  }

  // ... (Helper methods copy-pasted/adapted from mf_all_best_funds.dart)
  shadcn.TableCell buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    VoidCallback? onTap,
    bool alignRight = false,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 4;

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.fromLTRB(16, 8, 4, 8);
    } else if (isLastColumn) {
      cellPadding = const EdgeInsets.fromLTRB(4, 8, 16, 8);
    } else {
      cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
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

  shadcn.TableCell buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 4;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 6, 8, 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 6, 16, 6);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 6);
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
              Text(
                label,
                style: _getHeaderStyle(context),
              ),
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

  String _formatReturns(String? returns) {
    if (returns == null || returns.isEmpty || returns == "0.0") {
      return "0.00%";
    }
    return "$returns%";
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
      return Colors.grey;
    }
  }

  Future<void> _handleOrder(
      dynamic item, String orderType, MFProvider mf) async {
    // Pre-fill amount based on order type (synchronous - no delay)
    if (orderType == "One-time") {
      String amt = item.minimumPurchaseAmount ?? "0";
      mf.invAmt.text = amt.split('.').first;
    } else {
      String amt = item.minimumPurchaseAmount ?? "0";
      mf.installmentAmt.text = amt.split('.').first;
    }

    // Convert item to MutualFundList
    Map<String, dynamic> jsonData = item.toJson();
    // Ensure fSchemeName is set from name if not present
    if (jsonData['f_scheme_name'] == null &&
        (jsonData['name'] != null || jsonData['mfsearchnamename'] != null)) {
      jsonData['f_scheme_name'] =
          jsonData['name'] ?? jsonData['mfsearchnamename'];
    }
    MutualFundList mfItem = MutualFundList.fromJson(jsonData);

    // Set order type immediately
    mf.chngOrderType(orderType);
    mf.orderchangetitle(orderType);

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

  void _openFundDetails(dynamic item, MFProvider mf) async {
    try {
      final isin = item.iSIN;
      if (isin != null) {
        await mf.fetchFactSheet(isin);
        mf.fetchmatchisan(isin);

        // Navigate to full page instead of side sheet
        if (mf.factSheetDataModel?.stat != "Not Ok") {
          Map<String, dynamic> jsonData = item.toJson();
          if (jsonData['f_scheme_name'] == null &&
              (jsonData['name'] != null ||
                  jsonData['mfsearchnamename'] != null)) {
            jsonData['f_scheme_name'] =
                jsonData['name'] ?? jsonData['mfsearchnamename'];
          }
          MutualFundList bInstance = MutualFundList.fromJson(jsonData);

          // Use callback if provided (web panel navigation), otherwise use full page navigation
          if (widget.onFundTap != null) {
            widget.onFundTap!(bInstance);
          } else {
            // Navigate to full page using root navigator
            Navigator.of(context, rootNavigator: true).pushNamed(
              Routes.mfStockDetail,
              arguments: bInstance,
            );
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }
}

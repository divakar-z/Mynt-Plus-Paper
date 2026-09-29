// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart' hide Table, TableRow, TableCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import 'package:mynt_plus/models/desk_reports_model/approved_pledge_list_model.dart';
import 'package:mynt_plus/provider/ledger_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/mynt_loader.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/sharedWidget/custom_back_btn.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/scroll_to_load_mixin.dart';

class PledgeApproveListScreen extends StatefulWidget {
  const PledgeApproveListScreen({super.key});

  @override
  State<PledgeApproveListScreen> createState() =>
      _PledgeApproveListScreenState();
}

class _PledgeApproveListScreenState extends State<PledgeApproveListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();
  int activeTab = 0;

  // Sorting state
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);

  String _selectedCategory = 'Cash';
  String? _lastSelectedCategory;

  // ── Pagination state ──
  static const int _pageSize = 15;
  int _displayedCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tableScrollController.addListener(_onScroll);
    // TC_344 — the search field's X button empties the controller without
    // firing onChanged/onClear, so the filter kept the old query. Reset it
    // (and pagination) whenever the field becomes empty, same as Positions.
    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchController.text.isEmpty && _searchQuery.isNotEmpty) {
        setState(() {
          _searchQuery = '';
          _resetPagination();
        });
      }
    });
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final maxScroll = _tableScrollController.position.maxScrollExtent;
    final currentScroll = _tableScrollController.offset;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _displayedCount += _pageSize;
        _isLoadingMore = false;
      });
    });
  }

  void _resetPagination() {
    _displayedCount = _pageSize;
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

  List<PledgeItem> _sortList(List<PledgeItem> list) {
    if (_sortColumnIndex == null) return list;
    final sortedList = List<PledgeItem>.from(list);

    sortedList.sort((a, b) {
      int comparison = 0;
      switch (_sortColumnIndex) {
        case 0: // ISIN
          comparison =
              (a.iSIN ?? '').toLowerCase().compareTo((b.iSIN ?? '').toLowerCase());
          break;
        case 1: // Symbol
          comparison =
              (a.symbol ?? '').toLowerCase().compareTo((b.symbol ?? '').toLowerCase());
          break;
        case 2: // Security Name
          comparison =
              (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
          break;
        case 3: // Haircut
          final haircutA = double.tryParse(a.haircut ?? '0') ?? 0.0;
          final haircutB = double.tryParse(b.haircut ?? '0') ?? 0.0;
          comparison = haircutA.compareTo(haircutB);
          break;
        case 4: // Collateral
          final collA = 100 - (double.tryParse(a.haircut ?? '0') ?? 0.0);
          final collB = 100 - (double.tryParse(b.haircut ?? '0') ?? 0.0);
          comparison = collA.compareTo(collB);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return sortedList;
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_onScroll);
    _searchController.dispose();
    _tableScrollController.dispose();
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  // ── Text style helpers (matching mf_all_best_funds_web.dart) ──

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

  // ── Cell builders (matching mf_all_best_funds_web.dart) ──

  shadcn.TableCell _buildHeaderCell(String label, int columnIndex,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 4;

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.fromLTRB(16, 0, 8, 0);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(8, 0, 16, 0);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 0);
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
          alignment:
              alignRight ? Alignment.centerRight : Alignment.centerLeft,
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
              Text(label, style: _getHeaderStyle(context)),
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

  shadcn.TableCell _buildDataCell({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
  }) {
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
            final isRowHovered = hoveredIndex == rowIndex;
            return Container(
              padding: cellPadding,
              color: isRowHovered
                  ? resolveThemeColor(context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary)
                      .withValues(alpha: 0.08)
                  : null,
              alignment: alignRight ? Alignment.topRight : null,
              child: child,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      final ledgerprovider = ref.watch(ledgerProvider);

      Map<String, List<PledgeItem>> currentMap = {};
      final data = ledgerprovider.approvepledge?.data;
      if (data != null) {
        if (_selectedCategory == 'Non Cash' && data.noncash != null) {
          currentMap = data.noncash!;
        } else if (_selectedCategory == 'Cash' && data.cash != null) {
          currentMap = data.cash!;
        }
      }

      const List<String> tabOrder = [
        'ETF',
        'MF',
        'Goldbond',
        'Gsec',
        'T-bill',
      ];

      final List<String> tabKeys = currentMap.keys.toList();
      tabKeys.sort((a, b) {
        final indexA = tabOrder.indexOf(a);
        final indexB = tabOrder.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

      // Reset activeTab and pagination when category changes
      if (_lastSelectedCategory != _selectedCategory) {
        activeTab = 0;
        _lastSelectedCategory = _selectedCategory;
        _resetPagination();
      }

      // Clamp activeTab to valid range
      if (tabKeys.isNotEmpty) {
        activeTab = activeTab.clamp(0, tabKeys.length - 1);
      }

      return Scaffold(
        backgroundColor:
            theme.isDarkMode ? MyntColors.backgroundColorDark : MyntColors.backgroundColor,
        body: SafeArea(
          child: MyntLoaderOverlay(
            isLoading: ledgerprovider.approvepledgeloader,
            child: Column(
              children: [
                // Header with back button
                Container(
                  color: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      CustomBackBtn(
                        onBack: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Approved Securities',
                        style: MyntWebTextStyles.title(context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.semiBold),
                      ),
                    ],
                  ),
                ),
                // ── Toolbar: Tabs + Cash dropdown + Search + Filter ──
                _buildToolbar(tabKeys, theme),

                // ── Divider ──
                Divider(
                  height: 1,
                  thickness: 0.4,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.dividerDark,
                    light: MyntColors.divider,
                  ),
                ),

                // ── Table Content ──
                Expanded(
                  child: tabKeys.isNotEmpty
                      ? _buildTable(
                          currentMap[tabKeys[activeTab]] ?? [],
                          ledgerprovider,
                          theme,
                        )
                      : const Center(
                          child: NoDataFound(
                            title: 'No Data Found',
                            subtitle:
                                'No data found for the selected filter.',
                            secondaryEnabled: false,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Combined Toolbar: Tabs + Cash dropdown + Search + Filter ──

  Widget _buildToolbar(List<String> tabKeys, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Tabs on the left
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(tabKeys.length, (index) {
                  return _buildTabItem(tabKeys[index], index, theme);
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Cash / Non Cash dropdown
          _buildCategoryDropdown(theme),
          const SizedBox(width: 12),
          // Search bar
          SizedBox(
            width: 260,
            child: MyntSearchTextField.withSmartClear(
              controller: _searchController,
              placeholder: 'Search ISIN / symbol / name',
              leadingIcon: assets.searchIcon,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _resetPagination();
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _resetPagination();
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          // Filter icon button
          // _buildFilterButton(theme),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, ThemesProvider theme) {
    final isActive = activeTab == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            activeTab = index;
            _sortColumnIndex = null;
            _sortAscending = true;
            _resetPagination();
          });
        },
        child: Container(
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
            style: MyntWebTextStyles.body(
              context,
              fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: isActive
                  ? shadcn.Theme.of(context).colorScheme.foreground
                  : shadcn.Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemesProvider theme) {
    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showCategoryPopup(buttonContext, theme),
            child: Container(width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: resolveThemeColor(context,
                      dark: MyntColors.borderMutedDark,
                      light: MyntColors.borderMuted),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCategory,
                    style: MyntWebTextStyles.body(context,
                        darkColor: MyntColors.textPrimaryDark,
                        lightColor: MyntColors.textPrimary,
                        fontWeight: MyntFonts.medium),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      size: 18,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPopup(BuildContext context, ThemesProvider theme) {
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
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 130,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterMenuItem('Cash', theme, context),
                  _buildFilterMenuItem('Non Cash', theme, context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(ThemesProvider theme) {
    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showCategoryPopup(buttonContext, theme),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assets.searchFilter,
                  width: 20,
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
        );
      },
    );
  }

  Widget _buildFilterMenuItem(String value, ThemesProvider theme, BuildContext popoverContext) {
    final isSelected = _selectedCategory == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (value != _selectedCategory) {
            setState(() {
              _selectedCategory = value;
            });
          }
          shadcn.closeOverlay(popoverContext);
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
                    dark: MyntColors.primaryDark.withValues(alpha: 0.12),
                    light: const Color(0xFFE8F0FE),
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
  }

  // ── shadcn Table ──

  Widget _buildTable(
      List<PledgeItem> items, LDProvider ledgerprovider, ThemesProvider theme) {
    // Filter
    var filteredList = items.where((item) {
      final name = (item.name ?? '').trim();
      if (name.isEmpty) return false;
      if (_searchQuery.isEmpty) return true;

      final symbol = (item.symbol ?? '').toLowerCase();
      final nameLower = name.toLowerCase();
      final isin = (item.iSIN ?? '').toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      return symbol.contains(searchLower) ||
          nameLower.contains(searchLower) ||
          isin.contains(searchLower);
    }).toList();

    // Sort
    filteredList = _sortList(filteredList);

    if (filteredList.isEmpty) {
      return const Center(
        child: NoDataFound(
          title: 'No Data Found',
          subtitle: 'No data found for the selected filter.',
          secondaryEnabled: false,
        ),
      );
    }

    // ── Progressive loading: only render up to _displayedCount rows ──
    final int totalFiltered = filteredList.length;
    final bool hasMore = _displayedCount < totalFiltered;
    final visibleList = filteredList.take(_displayedCount).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth - 32;
        final double isinWidth = totalWidth * 0.18;
        final double symbolWidth = totalWidth * 0.22;
        final double nameWidth = totalWidth * 0.30;
        final double haircutWidth = totalWidth * 0.15;
        final double collateralWidth = totalWidth * 0.15;

        final columnWidths = {
          0: shadcn.FixedTableSize(isinWidth),
          1: shadcn.FixedTableSize(symbolWidth),
          2: shadcn.FixedTableSize(nameWidth),
          3: shadcn.FixedTableSize(haircutWidth),
          4: shadcn.FixedTableSize(collateralWidth),
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: shadcn.OutlinedContainer(
            child: Column(
              children: [
                // Fixed Header
                shadcn.Table(
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  columnWidths: columnWidths,
                  rows: [
                    shadcn.TableHeader(
                      cells: [
                        _buildHeaderCell('ISIN', 0),
                        _buildHeaderCell('Symbol', 1),
                        _buildHeaderCell('Security Name', 2),
                        _buildHeaderCell('Haircut', 3, true),
                        _buildHeaderCell('Collateral', 4, true),
                      ],
                    ),
                  ],
                ),
                // Scrollable data rows
                Expanded(
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    child: Column(
                      children: [
                        shadcn.Table(
                          defaultRowHeight: const shadcn.FixedTableSize(52),
                          columnWidths: columnWidths,
                          rows: visibleList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final haircut =
                                double.tryParse(item.haircut ?? '0') ?? 0.0;
                            final collateral = 100 - haircut;

                            return shadcn.TableRow(
                              cells: [
                                _buildDataCell(
                                  rowIndex: index,
                                  columnIndex: 0,
                                  child: Text(item.iSIN ?? '--',
                                      style: _getTextStyle(context)),
                                ),
                                _buildDataCell(
                                  rowIndex: index,
                                  columnIndex: 1,
                                  child: Text(item.symbol ?? '--',
                                      style: _getTextStyle(context)),
                                ),
                                _buildDataCell(
                                  rowIndex: index,
                                  columnIndex: 2,
                                  child: Text(
                                    item.name ?? '--',
                                    style: _getTextStyle(context),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                _buildDataCell(
                                  rowIndex: index,
                                  columnIndex: 3,
                                  alignRight: true,
                                  child: Text('${item.haircut ?? '0'} %',
                                      style: _getTextStyle(context)),
                                ),
                                _buildDataCell(
                                  rowIndex: index,
                                  columnIndex: 4,
                                  alignRight: true,
                                  child: Text(
                                      '${collateral.toStringAsFixed(2)} %',
                                      style: _getTextStyle(context)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        // Loading indicator / record count footer
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else if (hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Showing ${visibleList.length} of $totalFiltered records — scroll down for more',
                              style: _getTextStyle(context).copyWith(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Showing all $totalFiltered records',
                              style: _getTextStyle(context).copyWith(
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textSecondaryDark,
                                    light: MyntColors.textSecondary),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
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

}

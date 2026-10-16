import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'
    hide DataTable, DataColumn, DataRow, DataCell;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;
import '../../../provider/stocks_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../models/explore_model/stocks_model/toplist_stocks.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/no_data_found.dart';

class TradeActionScreenWeb extends ConsumerStatefulWidget {
  final int? initialTabIndex;
  
  const TradeActionScreenWeb({super.key, this.initialTabIndex});

  @override
  ConsumerState<TradeActionScreenWeb> createState() => _TradeActionScreenWebState();
}

class _TradeActionScreenWebState extends ConsumerState<TradeActionScreenWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VoidCallback? _tabControllerListener; // Store listener reference for proper cleanup
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _tabScrollController = ScrollController();
  
  int? _sortColumnIndex;
  bool _sortAscending = true;
  // PERFORMANCE FIX: Use ValueNotifier for hover instead of setState
  final ValueNotifier<int?> _hoveredRowIndex = ValueNotifier<int?>(null);
  StreamSubscription? _socketSubscription;
  
  // Store WebSocket data for each stock
  final Map<String, Map<String, dynamic>> _socketDataMap = {};

  final List<String> _tabs = [
    'Top gainer',
    'Top losers',
    'Volume breakout',
    'Most active',
  ];

  // Column headers for the table
  final List<String> _headers = [
    'Symbol',
    'Exchange',
    'LTP',
    'Change',
    'Change %',
    'Open',
    'High',
    'Low',
    'Close',
    'Volume',
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex ?? 0;
    final safeIndex = initialIndex >= 0 && initialIndex < _tabs.length ? initialIndex : 0;
    _tabController = TabController(
      length: _tabs.length, 
      vsync: this, 
      initialIndex: safeIndex
    );
    
    // Store listener reference for proper cleanup
    _tabControllerListener = () {
      if (mounted) {
        setState(() {});
        // Note: WebSocket subscription is handled by WebSubscriptionManager
        // No need to subscribe/unsubscribe on tab change since all trade action stocks are subscribed
      }
    };
    _tabController.addListener(_tabControllerListener!);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Ensure we're on the correct tab after the controller is created
        if (widget.initialTabIndex != null && 
            widget.initialTabIndex! >= 0 && 
            widget.initialTabIndex! < _tabs.length &&
            _tabController.index != widget.initialTabIndex!) {
          _tabController.animateTo(widget.initialTabIndex!);
        }
        
        final stocksProvider = ref.read(stocksProvide);
        // Fetch all trade action data (WebSubscriptionManager will subscribe after data is fetched)
        // Only fetch if data is empty (handler function will fetch with cooldown)
        if (stocksProvider.topGainers.isEmpty && stocksProvider.topLosers.isEmpty) {
          await stocksProvider.fetchTradeAction("NSE", "NSEALL", "topG_L", "topG_L");
          await stocksProvider.fetchTradeAction("NSE", "NSEALL", "mostActive", "mostActive");
        }
        
        // Setup WebSocket listener for receiving data updates
        // Note: Subscription is handled by WebSubscriptionManager
        _setupSocketSubscription();
      }
    });
  }
  
  @override
  void didUpdateWidget(TradeActionScreenWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initialTabIndex changed, update the tab
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        widget.initialTabIndex != null &&
        widget.initialTabIndex! >= 0 &&
        widget.initialTabIndex! < _tabs.length &&
        _tabController.index != widget.initialTabIndex!) {
      _tabController.animateTo(widget.initialTabIndex!);
    }
  }
  
  void _setupSocketSubscription() {
    final websocket = ref.read(websocketProvider);
    
    // Get existing socket data
    _socketDataMap.clear();
    websocket.socketDatas.forEach((key, value) {
      if (key is String && value is Map) {
        _socketDataMap[key] = Map<String, dynamic>.from(value);
      }
    });
    
    // ✅ Use ValueNotifier instead of setState to avoid rebuilding entire widget
    // Listen for updates - data is already stored in _socketDataMap
    // Individual cells will read from this map, no need to rebuild parent
    _socketSubscription = websocket.socketDataStream.listen((socketDatas) {
      if (mounted) {
        socketDatas.forEach((key, value) {
          if (key is String && value is Map) {
            _socketDataMap[key] = Map<String, dynamic>.from(value);
          }
        });
        // ✅ REMOVED: setState(() {}) - cells read from _socketDataMap directly
        // Individual stock cards should use isolated widgets that watch specific tokens
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    // Remove listener before disposing to prevent memory leaks
    if (_tabControllerListener != null) {
      _tabController.removeListener(_tabControllerListener!);
      _tabControllerListener = null;
    }
    _tabController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _tabScrollController.dispose();
    _hoveredRowIndex.dispose();
    super.dispose();
  }

  List<TopGainers> _getCurrentStocks() {
    final stocksProvider = ref.read(stocksProvide);
    List<TopGainers> stocks;
    switch (_tabController.index) {
      case 0:
        stocks = stocksProvider.topGainers;
        break;
      case 1:
        stocks = stocksProvider.topLosers;
        break;
      case 2:
        stocks = stocksProvider.byVolume;
        break;
      case 3:
        stocks = stocksProvider.byValue;
        break;
      default:
        return [];
    }
    
    // Apply sorting if a column is selected
    if (_sortColumnIndex != null) {
      stocks = List<TopGainers>.from(stocks);
      stocks.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Symbol
            comparison = _getSymbolName(a).compareTo(_getSymbolName(b));
            break;
          case 1: // Exchange
            comparison = (a.exch ?? '').compareTo(b.exch ?? '');
            break;
          case 2: // LTP - prefer socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aLtp = double.tryParse(aSocketData?['lp']?.toString() ?? a.lp ?? '0') ?? 0.0;
            final bLtp = double.tryParse(bSocketData?['lp']?.toString() ?? b.lp ?? '0') ?? 0.0;
            comparison = aLtp.compareTo(bLtp);
            break;
          case 3: // Change - computed from lp - close
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aSocketData = _socketDataMap['${a.exch ?? ''}|$aToken'] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap['${b.exch ?? ''}|$bToken'] ?? _socketDataMap[bToken];
            final aLp2 = double.tryParse(aSocketData?['lp']?.toString() ?? a.lp ?? '0') ?? 0.0;
            final bLp2 = double.tryParse(bSocketData?['lp']?.toString() ?? b.lp ?? '0') ?? 0.0;
            final aClose = double.tryParse(aSocketData?['c']?.toString() ?? a.c ?? '0') ?? 0.0;
            final bClose = double.tryParse(bSocketData?['c']?.toString() ?? b.c ?? '0') ?? 0.0;
            final aChange = aLp2 - aClose;
            final bChange = bLp2 - bClose;
            comparison = aChange.compareTo(bChange);
            break;
          case 4: // Change % - computed from (lp - close) / close * 100
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aSocketData = _socketDataMap['${a.exch ?? ''}|$aToken'] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap['${b.exch ?? ''}|$bToken'] ?? _socketDataMap[bToken];
            final aLp3 = double.tryParse(aSocketData?['lp']?.toString() ?? a.lp ?? '0') ?? 0.0;
            final bLp3 = double.tryParse(bSocketData?['lp']?.toString() ?? b.lp ?? '0') ?? 0.0;
            final aClose2 = double.tryParse(aSocketData?['c']?.toString() ?? a.c ?? '0') ?? 0.0;
            final bClose2 = double.tryParse(bSocketData?['c']?.toString() ?? b.c ?? '0') ?? 0.0;
            final aPerChange = aClose2 != 0 ? ((aLp3 - aClose2) / aClose2) * 100 : 0.0;
            final bPerChange = bClose2 != 0 ? ((bLp3 - bClose2) / bClose2) * 100 : 0.0;
            comparison = aPerChange.compareTo(bPerChange);
            break;
          case 5: // Open - get from socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aOpen = double.tryParse(aSocketData?['o']?.toString() ?? '0') ?? 0.0;
            final bOpen = double.tryParse(bSocketData?['o']?.toString() ?? '0') ?? 0.0;
            comparison = aOpen.compareTo(bOpen);
            break;
          case 6: // High - get from socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aHigh = double.tryParse(aSocketData?['h']?.toString() ?? '0') ?? 0.0;
            final bHigh = double.tryParse(bSocketData?['h']?.toString() ?? '0') ?? 0.0;
            comparison = aHigh.compareTo(bHigh);
            break;
          case 7: // Low - get from socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aLow = double.tryParse(aSocketData?['l']?.toString() ?? '0') ?? 0.0;
            final bLow = double.tryParse(bSocketData?['l']?.toString() ?? '0') ?? 0.0;
            comparison = aLow.compareTo(bLow);
            break;
          case 8: // Close - prefer socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aClose = double.tryParse(aSocketData?['c']?.toString() ?? a.pp ?? '0') ?? 0.0;
            final bClose = double.tryParse(bSocketData?['c']?.toString() ?? b.pp ?? '0') ?? 0.0;
            comparison = aClose.compareTo(bClose);
            break;
          case 9: // Volume - prefer socket data
            final aToken = a.token ?? "";
            final bToken = b.token ?? "";
            final aUniqueId = '${a.exch ?? ''}|$aToken';
            final bUniqueId = '${b.exch ?? ''}|$bToken';
            final aSocketData = _socketDataMap[aUniqueId] ?? _socketDataMap[aToken];
            final bSocketData = _socketDataMap[bUniqueId] ?? _socketDataMap[bToken];
            final aVolume = int.tryParse(aSocketData?['v']?.toString() ?? a.v ?? '0') ?? 0;
            final bVolume = int.tryParse(bSocketData?['v']?.toString() ?? b.v ?? '0') ?? 0;
            comparison = aVolume.compareTo(bVolume);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }
    
    return stocks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    
    return Scaffold(
      backgroundColor: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tabs
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabs
                  _buildTabs(theme),
                ],
              ),
            ),
            // Table content
            Expanded(
              child: _buildTable(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(ThemesProvider theme) {
    return SizedBox(
      height: 45,
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int index = 0; index < _tabs.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildTab(
                  _tabs[index],
                  index,
                  _tabController.index == index,
                  theme,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    String title,
    int index,
    bool isSelected,
    ThemesProvider theme,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_tabController.index != index) {
            _tabController.animateTo(index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode(context)
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: isSelected
                  ? shadcn.Theme.of(context).colorScheme.foreground
                  : shadcn.Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TABLE ──────────────────────────────────────────────────────

  Widget _buildTable(ThemesProvider theme) {
    final stocks = _getCurrentStocks();

    if (stocks.isEmpty) {
      return shadcn.OutlinedContainer(
        child: NoDataFoundWeb(
          title: "No Data",
          subtitle: "No stocks available for this category.",
          primaryEnabled: false,
          secondaryEnabled: false,
        ),
      );
    }

    return shadcn.OutlinedContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate dynamic column widths based on content
          final minWidths = _calculateMinWidths(stocks, context);
          final availableWidth = constraints.maxWidth;

          // Start with minimum widths
          final columnWidths = <int, double>{};
          for (int i = 0; i < _headers.length; i++) {
            columnWidths[i] = minWidths[i] ?? 100.0;
          }

          // Calculate total minimum width needed
          final totalMinWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);

          // Distribute extra space or shrink columns
          if (totalMinWidth < availableWidth) {
            final extraSpace = availableWidth - totalMinWidth;

            // Growth priorities: Symbol gets more growth, numeric columns less
            const symbolGrowthFactor = 2.0;
            const numericGrowthFactor = 1.0;

            final growthFactors = <int, double>{};
            double totalGrowthFactor = 0.0;

            for (int i = 0; i < _headers.length; i++) {
              final header = _headers[i];
              if (header == 'Exchange') {
                growthFactors[i] = 0.0; // Exchange doesn't grow
              } else if (header == 'Symbol') {
                growthFactors[i] = symbolGrowthFactor;
                totalGrowthFactor += symbolGrowthFactor;
              } else {
                growthFactors[i] = numericGrowthFactor;
                totalGrowthFactor += numericGrowthFactor;
              }
            }

            if (totalGrowthFactor > 0) {
              for (int i = 0; i < _headers.length; i++) {
                if (growthFactors[i]! > 0) {
                  final extraForThisColumn =
                      (extraSpace * growthFactors[i]!) / totalGrowthFactor;
                  columnWidths[i] = columnWidths[i]! + extraForThisColumn;
                }
              }
            }
          } else if (totalMinWidth > availableWidth) {
            final excessWidth = totalMinWidth - availableWidth;

            // Absolute minimum widths
            final absoluteMinWidths = <int, double>{
              0: 100.0, // Symbol
              1: 60.0,  // Exchange
              2: 70.0,  // LTP
              3: 70.0,  // Change
              4: 80.0,  // Change %
              5: 65.0,  // Open
              6: 65.0,  // High
              7: 65.0,  // Low
              8: 65.0,  // Close
              9: 70.0,  // Volume
            };

            final shrinkableAmounts = <int, double>{};
            double totalShrinkable = 0.0;

            for (int i = 0; i < _headers.length; i++) {
              final currentWidth = columnWidths[i]!;
              final absoluteMin = absoluteMinWidths[i] ?? 60.0;
              final shrinkable = currentWidth - absoluteMin;
              if (shrinkable > 0) {
                shrinkableAmounts[i] = shrinkable;
                totalShrinkable += shrinkable;
              } else {
                shrinkableAmounts[i] = 0.0;
              }
            }

            if (totalShrinkable > 0) {
              final shrinkFactor = excessWidth < totalShrinkable
                  ? excessWidth / totalShrinkable
                  : 1.0;

              for (int i = 0; i < _headers.length; i++) {
                if (shrinkableAmounts[i]! > 0) {
                  final shrinkAmount = shrinkableAmounts[i]! * shrinkFactor;
                  columnWidths[i] = columnWidths[i]! - shrinkAmount;
                }
              }
            }
          }

          final totalRequiredWidth = columnWidths.values
              .fold<double>(0.0, (sum, width) => sum + width);
          final needsHorizontalScroll = totalRequiredWidth > availableWidth;

          // Build table content (split header + scrollable body)
          Widget buildTableContent() {
            return Column(
              children: [
                // Fixed Header
                shadcn.Table(
                  columnWidths: columnWidths.map((index, width) {
                    return MapEntry(index, shadcn.FixedTableSize(width));
                  }),
                  defaultRowHeight: const shadcn.FixedTableSize(50),
                  rows: [
                    shadcn.TableHeader(
                      cells: _headers.asMap().entries.map((entry) {
                        final columnIndex = entry.key;
                        final header = entry.value;
                        final isNumeric = _isNumericColumn(header);
                        return _buildHeaderCell(header, columnIndex, theme, isNumeric);
                      }).toList(),
                    ),
                  ],
                ),
                // Scrollable Body
                Expanded(
                  child: RawScrollbar(
                    controller: _verticalScrollController,
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
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: shadcn.Table(
                        key: ValueKey('table_${_sortColumnIndex}_$_sortAscending'),
                        columnWidths: columnWidths.map((index, width) {
                          return MapEntry(index, shadcn.FixedTableSize(width));
                        }),
                        defaultRowHeight: const shadcn.FixedTableSize(50),
                        rows: [
                          ...stocks.asMap().entries.map((entry) {
                            final index = entry.key;
                            final stock = entry.value;
                            return _buildDataRow(stock, index, theme);
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Wrap in horizontal scroll if needed
          if (needsHorizontalScroll) {
            return RawScrollbar(
              controller: _horizontalScrollController,
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
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalRequiredWidth,
                  child: buildTableContent(),
                ),
              ),
            );
          } else {
            return buildTableContent();
          }
        },
      ),
    );
  }

  // ─── HEADER CELL (matches positions page) ──────────────────────

  shadcn.TableCell _buildHeaderCell(
      String label, int columnIndex, ThemesProvider theme,
      [bool alignRight = false]) {
    final isFirstColumn = columnIndex == 0; // Symbol column
    final isLastColumn = columnIndex == _headers.length - 1; // Volume column

    EdgeInsets headerPadding;
    if (isFirstColumn) {
      headerPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
    } else if (isLastColumn) {
      headerPadding = const EdgeInsets.fromLTRB(4, 6, 16, 6);
    } else {
      headerPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
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
          width: double.infinity,
          height: double.infinity,
          padding: headerPadding,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: MyntColors.cardDark,
              light: MyntColors.listItemBg,
            ),
          ),
          child: Row(
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

  // ─── DATA CELL WITH HOVER (matches positions page) ─────────────

  shadcn.TableCell _buildCellWithHover({
    required Widget child,
    required int rowIndex,
    required int columnIndex,
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0; // Symbol column
    final isLastColumn = columnIndex == _headers.length - 1; // Volume column

    EdgeInsets cellPadding;
    if (isFirstColumn) {
      cellPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
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
        onEnter: (_) => _hoveredRowIndex.value = rowIndex,
        onExit: (_) => _hoveredRowIndex.value = null,
        child: ValueListenableBuilder<int?>(
          valueListenable: _hoveredRowIndex,
          child: child,
          builder: (context, hoveredIndex, cachedChild) {
            final isRowHovered = hoveredIndex == rowIndex;

            final container = Container(
              width: double.infinity,
              height: double.infinity,
              padding: cellPadding,
              alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
              color: isRowHovered
                  ? resolveThemeColor(
                      context,
                      dark: MyntColors.primaryDark.withValues(alpha: 0.08),
                      light: MyntColors.primary.withValues(alpha: 0.08),
                    )
                  : Colors.transparent,
              child: cachedChild,
            );

            if (onTap != null) {
              return GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: container,
              );
            }
            return container;
          },
        ),
      ),
    );
  }

  // ─── BUILD DATA ROW ────────────────────────────────────────────

  shadcn.TableRow _buildDataRow(TopGainers stock, int rowIndex, ThemesProvider theme) {
    final token = stock.token ?? "";
    final socketData = _socketDataMap[token];
    final ltp = socketData?['lp']?.toString() ?? stock.lp ?? '0.00';
    final open = socketData?['o']?.toString() ?? '0.00';
    final high = socketData?['h']?.toString() ?? '0.00';
    final low = socketData?['l']?.toString() ?? '0.00';
    final close = socketData?['c']?.toString() ?? stock.c ?? '0.00';
    final volume = socketData?['v']?.toString() ?? stock.v ?? '0';

    // Compute change and percentage from lp and close
    final lpVal = double.tryParse(ltp);
    final closeVal = double.tryParse(close);
    double changeVal = 0.0;
    double perChangeVal = 0.0;
    if (lpVal != null && closeVal != null) {
      changeVal = lpVal - closeVal;
      if (closeVal != 0) {
        perChangeVal = (changeVal / closeVal) * 100;
      }
    }
    final change = changeVal.toStringAsFixed(2);
    final perChange = perChangeVal.toStringAsFixed(2);

    final changeColor = _getChangeColorFromValues(change, perChange, theme);
    final rowTap = () => _handleStockTap(stock, theme);

    return shadcn.TableRow(
      cells: [
        // Column 0: Symbol (left-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 0,
          onTap: rowTap,
          child: Text(
            _getSymbolName(stock),
            style: _getTextStyle(context),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        // Column 1: Exchange (left-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 1,
          onTap: rowTap,
          child: Text(
            stock.exch ?? "",
            style: _getTextStyle(context),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        // Column 2: LTP (right-aligned, colored)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 2,
          alignRight: true,
          onTap: rowTap,
          child: Text(
            "₹$ltp",
            style: _getTextStyle(context, color: changeColor),
          ),
        ),
        // Column 3: Change (right-aligned, colored)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 3,
          alignRight: true,
          onTap: rowTap,
          child: Text(
            change.startsWith("-") ? change : change,
            style: _getTextStyle(context, color: changeColor),
          ),
        ),
        // Column 4: Change % (right-aligned, colored)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 4,
          alignRight: true,
          onTap: rowTap,
          child: Text(
            "$perChange%",
            style: _getTextStyle(context, color: changeColor),
          ),
        ),
        // Column 5: Open (right-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 5,
          alignRight: true,
          onTap: rowTap,
          child: Text(open, style: _getTextStyle(context)),
        ),
        // Column 6: High (right-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 6,
          alignRight: true,
          onTap: rowTap,
          child: Text(high, style: _getTextStyle(context)),
        ),
        // Column 7: Low (right-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 7,
          alignRight: true,
          onTap: rowTap,
          child: Text(low, style: _getTextStyle(context)),
        ),
        // Column 8: Close (right-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 8,
          alignRight: true,
          onTap: rowTap,
          child: Text(close, style: _getTextStyle(context)),
        ),
        // Column 9: Volume (right-aligned)
        _buildCellWithHover(
          rowIndex: rowIndex,
          columnIndex: 9,
          alignRight: true,
          onTap: rowTap,
          child: Text(volume, style: _getTextStyle(context)),
        ),
      ],
    );
  }

  // ─── TEXT STYLE HELPERS (match positions page) ─────────────────

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

  // ─── COLUMN WIDTH CALCULATION (match positions page) ───────────

  bool _isNumericColumn(String header) {
    return header != 'Symbol' && header != 'Exchange';
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

  Map<int, double> _calculateMinWidths(
      List<TopGainers> stocks, BuildContext context) {
    final textStyle = TextStyle(fontSize: 14, fontFamily: dyslexiaFontOr('Geist'));
    const padding = 24.0;
    const sortIconWidth = 24.0;

    final minWidths = <int, double>{};

    for (int col = 0; col < _headers.length; col++) {
      double maxWidth = 0.0;
      final header = _headers[col];

      // Measure header width + sort icon space
      final headerWidth = _measureTextWidth(header, textStyle);
      maxWidth = headerWidth + sortIconWidth;

      // Measure widest value in this column (sample first 10 rows)
      for (final stock in stocks.take(10)) {
        final token = stock.token ?? "";
        final socketData = _socketDataMap[token];
        String cellText = '';

        switch (col) {
          case 0: // Symbol
            cellText = _getSymbolName(stock);
            break;
          case 1: // Exchange
            cellText = stock.exch ?? '';
            break;
          case 2: // LTP
            cellText = '₹${socketData?['lp']?.toString() ?? stock.lp ?? '0.00'}';
            break;
          case 3: // Change (computed from lp - close)
            final lpVal = double.tryParse(socketData?['lp']?.toString() ?? stock.lp ?? '0') ?? 0.0;
            final closeVal = double.tryParse(socketData?['c']?.toString() ?? stock.c ?? '0') ?? 0.0;
            final chg = lpVal - closeVal;
            cellText = chg < 0 ? chg.toStringAsFixed(2) : '+${chg.toStringAsFixed(2)}';
            break;
          case 4: // Change % (computed from (lp - close) / close * 100)
            final lpVal2 = double.tryParse(socketData?['lp']?.toString() ?? stock.lp ?? '0') ?? 0.0;
            final closeVal2 = double.tryParse(socketData?['c']?.toString() ?? stock.c ?? '0') ?? 0.0;
            final pctChg = closeVal2 != 0 ? ((lpVal2 - closeVal2) / closeVal2) * 100 : 0.0;
            cellText = '${pctChg.toStringAsFixed(2)}%';
            break;
          case 5: // Open
            cellText = socketData?['o']?.toString() ?? '0.00';
            break;
          case 6: // High
            cellText = socketData?['h']?.toString() ?? '0.00';
            break;
          case 7: // Low
            cellText = socketData?['l']?.toString() ?? '0.00';
            break;
          case 8: // Close
            cellText = socketData?['c']?.toString() ?? stock.c ?? '0.00';
            break;
          case 9: // Volume
            cellText = socketData?['v']?.toString() ?? stock.v ?? '0';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, textStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      // Ensure minimum width for Symbol column
      if (header == 'Symbol') {
        const minSymbolWidth = 120.0;
        maxWidth = maxWidth < minSymbolWidth ? minSymbolWidth : maxWidth;
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
  }

  // ─── SORT HANDLER (matches positions page toggle pattern) ──────

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

  // ─── DATA HELPERS (unchanged logic) ────────────────────────────

  String _getSymbolName(TopGainers stock) {
    final tsym = stock.tsym ?? "";
    if (tsym.contains("-")) {
      return tsym.split("-").first.toUpperCase();
    }
    return tsym.toUpperCase();
  }

  
  Color _getChangeColorFromValues(String change, String perChange, ThemesProvider theme) {
    if (change.startsWith("-") || perChange.startsWith('-')) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else if (change == "0.00" || perChange == "0.00") {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    }
  }

  Future<void> _handleStockTap(TopGainers stock, ThemesProvider theme) async {
    try {
      final marketWatch = ref.read(marketWatchProvider);
      
      await marketWatch.fetchScripQuoteIndex(
        stock.token?.toString() ?? "",
        stock.exch?.toString() ?? "",
        context,
      );

      final quots = marketWatch.getQuotes;
      if (quots == null) {
        return;
      }

      DepthInputArgs depthArgs = DepthInputArgs(
          exch: quots.exch?.toString() ?? "",
          token: quots.token?.toString() ?? "",
          tsym: quots.tsym?.toString() ?? "",
          instname: quots.instname?.toString() ?? "",
          symbol: quots.symbol?.toString() ?? "",
          expDate: quots.expDate?.toString() ?? "",
          option: quots.option?.toString() ?? "");

      if (depthArgs.token.isNotEmpty && depthArgs.exch.isNotEmpty) {
        await marketWatch.calldepthApis(context, depthArgs, "");
      }
    } catch (e) {
    }
  }
}

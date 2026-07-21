import 'dart:async';
import 'package:mynt_plus/provider/accessibility_provider.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'package:flutter/material.dart'
    show
        RefreshIndicator,
        SizedBox,
        Align,
        Padding,
        LayoutBuilder,
        MediaQuery,
        Column,
        Expanded,
        Flexible,
        SingleChildScrollView,
        ScrollController,
        Axis,
        ValueKey,
        Row,
        MainAxisSize,
        MainAxisAlignment,
        Text,
        TextStyle,
        TextDirection,
        TextPainter,
        TextSpan,
        FontFeature,
        FontWeight,
        Color,
        EdgeInsets,
        Alignment,
        TextOverflow,
        GestureDetector,
        HitTestBehavior,
        MouseRegion,
        InkWell,
        Icons,
        VoidCallback,
        Icon,
        Container,
        BoxDecoration,
        BorderRadius,
        Border,
        BorderSide,
        Center,
        Widget,
        BuildContext,
        IconData,
        Colors,
        WidgetsBinding,
        Material,
        BoxConstraints,
        IntrinsicWidth,
        BoxShadow,
        RawScrollbar,
        Radius,
        Offset,
        TextButton,
        RoundedRectangleBorder,
        Dialog,
        Navigator,
        showDialog,
        RichText,
        TextAlign,
        ValueNotifier,
        ValueListenableBuilder,
        Stack,
        Positioned,
        Clip,
        LinearGradient,
        Builder,
        Tooltip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn hide Colors;

import '../../../res/mynt_web_color_styles.dart' as styles;
import '../../../res/mynt_web_text_styles.dart';

import '../../../models/notification_model/broker_message_model.dart';
import '../../../models/marketwatch_model/alert_model/alert_pending_model.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/notification_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../provider/thems.dart';
import '../../../sharedWidget/no_data_found.dart';
import '../../../sharedWidget/mynt_loader.dart';
import '../../../utils/responsive_snackbar.dart';
import 'pending_alert_detail_screen_web.dart';

class PendingAlertWeb extends ConsumerStatefulWidget {
  const PendingAlertWeb({super.key});

  @override
  ConsumerState<PendingAlertWeb> createState() => _PendingAlertWebState();
}

class _PendingAlertWebState extends ConsumerState<PendingAlertWeb> {
  List<BrokerMessage>? triggeredAlerts;

  // Sorting variables
  int? _alertSortColumnIndex;
  bool _alertSortAscending = true;

  // WebSocket subscription for real-time updates
  StreamSubscription? _socketSubscription;

  // Throttling properties
  DateTime _lastSocketUpdateTime = DateTime.now();
  static const Duration _minUpdateInterval = Duration(milliseconds: 50);

  // Hover state - Use ValueNotifier for performance
  final ValueNotifier<String?> _hoveredRowToken = ValueNotifier<String?>(null);

  // Processing state for actions
  bool _isProcessingCancel = false;
  // bool _isProcessingModify = false;  // Commented out - Modify button hidden
  String? _processingAlertToken;

  // Scroll controllers
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Track the popover controller to close it when row is unhovered
  shadcn.PopoverController? _activePopoverController;

  // Track which row the popover belongs to
  int? _popoverRowIndex;

  // Track if mouse is hovering over the dropdown menu
  bool _isHoveringDropdown = false;

  // Timer for delayed popover close (allows mouse to move from row to dropdown)
  Timer? _popoverCloseTimer;

  // Prevent double-click from opening sheet twice
  bool _isSheetOpening = false;

  // Track if data has been initialized
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Listen to hover changes to close popover when row is unhovered
    _hoveredRowToken.addListener(_onHoverChanged);
    // Only fetch data once when widget is first created
    if (!_hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasInitialized) {
          _hasInitialized = true;
          _refreshData();
          // Setup WebSocket subscription after data is loaded
          _setupSocketSubscription();
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelPopoverCloseTimer();
    _hoveredRowToken.removeListener(_onHoverChanged);
    _teardownSocketSubscription();
    _hoveredRowToken.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // Close popover when hover state changes
  void _onHoverChanged() {
    if (_activePopoverController != null) {
      final currentHover = _hoveredRowToken.value;

      // If still hovering the same row that has the popover, cancel any pending close
      if (currentHover == '$_popoverRowIndex') {
        _cancelPopoverCloseTimer();
        return;
      }

      // If hovering the dropdown menu, cancel any pending close
      if (_isHoveringDropdown) {
        _cancelPopoverCloseTimer();
        return;
      }

      // Start delayed close - gives time for mouse to move from row to dropdown
      _startPopoverCloseTimer();
    }
  }

  // Start a delayed close timer
  void _startPopoverCloseTimer() {
    _cancelPopoverCloseTimer();
    _popoverCloseTimer = Timer(const Duration(milliseconds: 150), () {
      // Double-check conditions before closing
      if (!_isHoveringDropdown && _hoveredRowToken.value != '$_popoverRowIndex') {
        _closePopover();
      }
    });
  }

  // Cancel the close timer
  void _cancelPopoverCloseTimer() {
    _popoverCloseTimer?.cancel();
    _popoverCloseTimer = null;
  }

  // Helper to close popover and reset state
  void _closePopover() {
    _cancelPopoverCloseTimer();
    try {
      _activePopoverController?.close();
    } catch (_) {
      // Overlay might already be closed, ignore
    }
    final needsRebuild = _activePopoverController != null || _popoverRowIndex != null;
    _activePopoverController = null;
    _popoverRowIndex = null;
    _isHoveringDropdown = false;

    // Force rebuild to remove row highlight when popover closes
    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  // Combined method to refresh all data
  Future<void> _refreshData() async {
    if (!mounted) return;

    // Fetch both types of data
    await ref.read(marketWatchProvider).fetchPendingAlert(context);
    await _fetchTriggeredAlerts();

    // Subscribe to WebSocket for real-time updates
    _subscribeToAlertTokens();
  }

  // Subscribe to alert tokens for real-time LTP updates
  void _subscribeToAlertTokens() {
    try {
      final manage = ref.read(marketWatchProvider);
      final pendingAlerts = manage.alertPendingModel ?? [];

      if (pendingAlerts.isEmpty) return;

      // Create input string for WebSocket subscription
      final tokens = pendingAlerts
          .where((alert) => alert.token != null && alert.token!.isNotEmpty)
          .map((alert) => "${alert.exch}|${alert.token}")
          .toSet()
          .join("#");

      if (tokens.isNotEmpty) {
        ref.read(websocketProvider).establishConnection(
              channelInput: tokens,
              task: "d", // Subscribe with depth for web
              context: context,
            );
      }
    } catch (e) {
    }
  }

  // Helper method to determine font size based on screen width
  double _getResponsiveFontSize(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < 1000) {
      return 11.0;
    } else if (width < 1300) {
      return 12.0;
    }
    return 14.0;
  }

  // Fetch triggered alerts from broker messages
  Future<void> _fetchTriggeredAlerts() async {
    if (!mounted) return;
    await ref.read(notificationprovider).fetchbrokermsg(context);
  }

  // WebSocket subscription methods for real-time updates
  void _setupSocketSubscription() {
    // Use microtask to ensure context is available
    Future.microtask(() {
      final socketProvider = ref.read(websocketProvider);

      _socketSubscription =
          socketProvider.socketDataStream.listen((socketDatas) {
        if (socketDatas.isEmpty) return;

        // Apply throttling to avoid rapid updates
        final now = DateTime.now();
        if (now.difference(_lastSocketUpdateTime) < _minUpdateInterval) {
          return;
        }

        _lastSocketUpdateTime = now;
        _processSocketUpdates(socketDatas);
      });
    });
  }

  void _teardownSocketSubscription() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
  }

  void _processSocketUpdates(Map socketDatas) {
    // Check if widget is still mounted before accessing providers
    if (!mounted) return;

    bool hasUpdates = false;
    final manage = ref.read(marketWatchProvider);
    final pendingAlerts = manage.alertPendingModel ?? [];

    // Helper function to check if a string is a valid numeric price
    bool isValidNumeric(String? value) {
      if (value == null || value == "null" || value == "") return false;
      if (value == "0" || value == "0.0" || value == "0.00") return false;
      return double.tryParse(value) != null;
    }

    // Process pending alerts for LTP updates
    for (var alert in pendingAlerts) {
      if (alert.token == null || alert.token!.isEmpty) continue;

      // Skip if no socket data for this token
      if (!socketDatas.containsKey(alert.token)) continue;

      final socketData = socketDatas[alert.token];
      if (socketData == null || socketData.isEmpty) continue;

      // Cache current values to detect changes
      final currentLtp = alert.ltp;

      // Update LTP (Last Traded Price) from WebSocket data
      final lp = socketData['lp']?.toString();
      if (isValidNumeric(lp)) {
        // Always update if different to ensure real-time display
        if (currentLtp != lp) {
          alert.ltp = lp;
          hasUpdates = true;
        }
      }

      // Update percentage change if available
      final pc = socketData['pc']?.toString();
      if (isValidNumeric(pc)) {
        if (alert.perChange != pc) {
          alert.perChange = pc;
          hasUpdates = true;
        }
      }
    }

    // Trigger UI update if there were changes
    if (hasUpdates && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final manage = ref.watch(marketWatchProvider);
    final notification = ref.watch(notificationprovider);
    final order = ref.watch(orderProvider);
    final theme = ref.read(themeProvider);

    // Use order provider search functionality
    final isSearching = order.orderSearchCtrl.text.isNotEmpty;
    final pendingAlerts = isSearching
        ? manage.alertPendingSearch ?? []
        : manage.alertPendingModel ?? [];

    // Using ref.listen to detect changes in the alerts data
    ref.listen<MarketWatchProvider>(
        marketWatchProvider, (previous, current) {});
    ref.listen<NotificationProvider>(
        notificationprovider, (previous, current) {});

    // Use filtered triggered alerts from provider (if searching) or filter in UI (if not searching)
    if (isSearching) {
      triggeredAlerts = notification.triggeredAlertSearch ?? [];
    } else {
      // Filter broker messages that are related to alerts (only when not searching)
      triggeredAlerts = notification.brokermsg
              ?.where((msg) =>
                  msg.dmsg != null &&
                  msg.dmsg!.contains("Ltp") &&
                  (msg.dmsg!.contains("above") || msg.dmsg!.contains("below")))
              .toList() ??
          [];
    }

    // Combine pending and triggered alerts (pending first)
    final List<dynamic> allAlerts = [
      ...pendingAlerts,
      ...(triggeredAlerts ?? [])
    ];

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _buildAlertTable(_getSortedAlerts(allAlerts), theme),
      ),
    );
  }

  List<dynamic> _getSortedAlerts(List<dynamic> alerts) {
    if (_alertSortColumnIndex == null) return alerts;
    final sorted = [...alerts];
    int c = _alertSortColumnIndex!;
    bool asc = _alertSortAscending;

    int cmp<T extends Comparable>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    num parseNum(String? v) => double.tryParse(v ?? '') ?? 0;

    sorted.sort((a, b) {
      int r = 0;
      switch (c) {
        case 0: // Instrument
          Map<String, String>? aParsed = a is BrokerMessage ? _parseBrokerMessage(a) : null;
          Map<String, String>? bParsed = b is BrokerMessage ? _parseBrokerMessage(b) : null;
          
          String aInstrument = a is BrokerMessage
              ? (DerivativeMaster.nameFor(a.exch, a.token) ??
                  aParsed?['instrument'] ??
                  'N/A')
              : (DerivativeMaster.nameFor(a.exch, a.token) ??
                  a.tsym?.replaceAll("-EQ", "") ??
                  'N/A');
          String bInstrument = b is BrokerMessage
              ? (DerivativeMaster.nameFor(b.exch, b.token) ??
                  bParsed?['instrument'] ??
                  'N/A')
              : (DerivativeMaster.nameFor(b.exch, b.token) ??
                  b.tsym?.replaceAll("-EQ", "") ??
                  'N/A');
          r = cmp<String>(aInstrument, bInstrument);
          break;
        case 1: // Exchange
          Map<String, String>? aParsed = a is BrokerMessage ? _parseBrokerMessage(a) : null;
          Map<String, String>? bParsed = b is BrokerMessage ? _parseBrokerMessage(b) : null;
          
          String aExchange = a is BrokerMessage ? (aParsed?['exchange'] ?? 'N/A') : (a.exch ?? '');
          String bExchange = b is BrokerMessage ? (bParsed?['exchange'] ?? 'N/A') : (b.exch ?? '');
          r = cmp<String>(aExchange, bExchange);
          break;
        case 2: // Alert Type
          String aType = '';
          String bType = '';
          
          if (a is BrokerMessage) {
            aType = _resolveTriggeredAlertLabel(a);
          } else {
            switch (a.aiT) {
              case 'LTP_A':
                aType = 'LTP Above';
                break;
              case 'LTP_B':
                aType = 'LTP Below';
                break;
              case 'CH_PER_A':
                aType = 'Perc.Change Above';
                break;
              case 'CH_PER_B':
                aType = 'Perc.Change Below';
                break;
              default:
                aType = 'Unknown';
            }
          }
          if (b is BrokerMessage) {
            bType = _resolveTriggeredAlertLabel(b);
          } else {
            switch (b.aiT) {
              case 'LTP_A':
                bType = 'LTP Above';
                break;
              case 'LTP_B':
                bType = 'LTP Below';
                break;
              case 'CH_PER_A':
                bType = 'Perc.Change Above';
                break;
              case 'CH_PER_B':
                bType = 'Perc.Change Below';
                break;
              default:
                bType = 'Unknown';
            }
          }
          r = cmp<String>(aType, bType);
          break;
        case 3: // Target
          if (a is BrokerMessage || b is BrokerMessage) {
            Map<String, String>? aParsed = a is BrokerMessage ? _parseBrokerMessage(a) : null;
            Map<String, String>? bParsed = b is BrokerMessage ? _parseBrokerMessage(b) : null;
            
            String aTarget = a is BrokerMessage
                ? (aParsed?['target'] ?? '0.00')
                : (a.aiT == "CH_PER_A" || a.aiT == "CH_PER_B"
                    ? "%${a.d}"
                    : "${a.d}");
            String bTarget = b is BrokerMessage
                ? (bParsed?['target'] ?? '0.00')
                : (b.aiT == "CH_PER_A" || b.aiT == "CH_PER_B"
                    ? "%${b.d}"
                    : "${b.d}");
            r = cmp<String>(aTarget, bTarget);
          } else {
            num aTarget = parseNum("${a.d ?? 0}");
            num bTarget = parseNum("${b.d ?? 0}");
            r = aTarget.compareTo(bTarget);
          }
          break;
        case 4: // LTP
          if (a is BrokerMessage || b is BrokerMessage) {
            Map<String, String>? aParsed = a is BrokerMessage ? _parseBrokerMessage(a) : null;
            Map<String, String>? bParsed = b is BrokerMessage ? _parseBrokerMessage(b) : null;
            
            String aLtp =
                a is BrokerMessage ? (aParsed?['ltp'] ?? '0.00') : "${a.ltp ?? a.close ?? 0.00}";
            String bLtp =
                b is BrokerMessage ? (bParsed?['ltp'] ?? '0.00') : "${b.ltp ?? b.close ?? 0.00}";
            r = cmp<String>(aLtp, bLtp);
          } else {
            num aLtp = parseNum("${a.ltp ?? a.close ?? 0.00}");
            num bLtp = parseNum("${b.ltp ?? b.close ?? 0.00}");
            r = aLtp.compareTo(bLtp);
          }
          break;
        case 5: // Status
          String aStatus = a is BrokerMessage ? 'TRIGGERED' : 'PENDING';
          String bStatus = b is BrokerMessage ? 'TRIGGERED' : 'PENDING';
          r = cmp<String>(aStatus, bStatus);
          break;
      }
      return asc ? r : -r;
    });
    return sorted;
  }

  void _onSortAlertTable(int columnIndex) {
    setState(() {
      if (_alertSortColumnIndex == columnIndex) {
        _alertSortAscending = !_alertSortAscending;
      } else {
        _alertSortColumnIndex = columnIndex;
        _alertSortAscending = true;
      }
    });
  }

  Widget _buildAlertTable(List<dynamic> alerts, ThemesProvider theme) {
    // Sort alerts - handle empty case for showing header always
    final sortedAlerts = alerts.isNotEmpty
        ? _getSortedAlerts(alerts)
        : <dynamic>[];

    return SizedBox.expand(
      child: shadcn.OutlinedContainer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate minimum widths dynamically based on actual content
            final minWidths = _calculateMinWidths(sortedAlerts, context);

            // Available width
            final availableWidth = constraints.maxWidth;

            // Step 1: Start with minimum widths (content-based, no wasted space)
            final columnWidths = <int, double>{};
            for (int i = 0; i < 6; i++) {
              columnWidths[i] = minWidths[i] ?? 100.0;
            }

            // Step 2: Calculate total minimum width needed
            final totalMinWidth = columnWidths.values
                .fold<double>(0.0, (sum, width) => sum + width);

            // Step 3: If there's extra space, distribute it proportionally
            if (totalMinWidth < availableWidth) {
              final extraSpace = availableWidth - totalMinWidth;

              const instrumentGrowthFactor = 2.5;
              const textGrowthFactor = 1.2;
              const numericGrowthFactor = 1.0;

              final growthFactors = <int, double>{};
              double totalGrowthFactor = 0.0;

              for (int i = 0; i < 6; i++) {
                if (i == 0) {
                  // Instrument
                  growthFactors[i] = instrumentGrowthFactor;
                  totalGrowthFactor += instrumentGrowthFactor;
                } else if (i == 1 || i == 2 || i == 5) {
                  // Exchange, Alert Type, Status
                  growthFactors[i] = textGrowthFactor;
                  totalGrowthFactor += textGrowthFactor;
                } else {
                  // Target, LTP
                  growthFactors[i] = numericGrowthFactor;
                  totalGrowthFactor += numericGrowthFactor;
                }
              }

              if (totalGrowthFactor > 0) {
                for (int i = 0; i < 6; i++) {
                  if (growthFactors[i]! > 0) {
                    final extraForThisColumn =
                        (extraSpace * growthFactors[i]!) / totalGrowthFactor;
                    columnWidths[i] = columnWidths[i]! + extraForThisColumn;
                  }
                }
              }
            }

            final totalRequiredWidth = columnWidths.values
                .fold<double>(0.0, (sum, width) => sum + width);
            final needsHorizontalScroll = totalRequiredWidth > availableWidth;

            Widget buildTableContent() {
              return Column(
                children: [
                  // Fixed Header
                  shadcn.Table(
                    columnWidths: {
                      0: shadcn.FixedTableSize(columnWidths[0]!),
                      1: shadcn.FixedTableSize(columnWidths[1]!),
                      2: shadcn.FixedTableSize(columnWidths[2]!),
                      3: shadcn.FixedTableSize(columnWidths[3]!),
                      4: shadcn.FixedTableSize(columnWidths[4]!),
                      5: shadcn.FixedTableSize(columnWidths[5]!),
                    },
                    defaultRowHeight: const shadcn.FixedTableSize(40),
                    rows: [
                      shadcn.TableHeader(
                        cells: [
                          buildHeaderCell('Instrument', 0),
                          buildHeaderCell('Exchange', 1),
                          buildHeaderCell('Alert Type', 2),
                          buildHeaderCell('Target', 3, true),
                          buildHeaderCell('LTP', 4, true),
                          buildHeaderCell('Status', 5, true),
                        ],
                      ),
                    ],
                  ),
                  // Scrollable Body - shows loader/no data/table rows
                  Expanded(
                    child: sortedAlerts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: NoDataFoundWeb(
                                title: "No Alerts",
                                subtitle: "You don't have any alerts yet.",
                                primaryEnabled: false,
                                secondaryEnabled: false,
                              ),
                            ),
                          )
                        : RawScrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      trackColor: resolveThemeColor(context,
                          dark: Colors.grey.withValues(alpha: 0.1),
                          light: Colors.grey.withValues(alpha: 0.1)),
                      thumbColor: resolveThemeColor(context,
                          dark: Colors.grey.withValues(alpha: 0.3),
                          light: Colors.grey.withValues(alpha: 0.3)),
                      thickness: 6,
                      radius: const Radius.circular(3),
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: shadcn.Table(
                          key: ValueKey(
                              'table_${_alertSortColumnIndex}_$_alertSortAscending'),
                          columnWidths: {
                            0: shadcn.FixedTableSize(columnWidths[0]!),
                            1: shadcn.FixedTableSize(columnWidths[1]!),
                            2: shadcn.FixedTableSize(columnWidths[2]!),
                            3: shadcn.FixedTableSize(columnWidths[3]!),
                            4: shadcn.FixedTableSize(columnWidths[4]!),
                            5: shadcn.FixedTableSize(columnWidths[5]!),
                          },
                          defaultRowHeight: const shadcn.FixedTableSize(40),
                          rows: sortedAlerts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final alert = entry.value;
                            final uniqueId = alert is BrokerMessage
                                ? 'triggered_${alert.norentm ?? index}'
                                : '${alert.alId ?? alert.token ?? index}';

                            return shadcn.TableRow(
                              cells: [
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 0,
                                  onTap: () => _showAlertDetail(alert),
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: _hoveredRowToken,
                                    builder: (context, hoveredToken, _) {
                                      final isRowHovered = hoveredToken == '$index' ||
                                          (_activePopoverController != null && _popoverRowIndex == index);
                                      return _buildInstrumentCell(
                                          alert, theme, isRowHovered, uniqueId,
                                          rowIndex: index);
                                    },
                                  ),
                                ),
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 1,
                                  onTap: () => _showAlertDetail(alert),
                                  child: _buildExchangeCell(alert, theme),
                                ),
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 2,
                                  onTap: () => _showAlertDetail(alert),
                                  child: _buildAlertTypeCell(alert, theme),
                                ),
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 3,
                                  alignRight: true,
                                  onTap: () => _showAlertDetail(alert),
                                  child: _buildTargetCell(alert, theme),
                                ),
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 4,
                                  alignRight: true,
                                  onTap: () => _showAlertDetail(alert),
                                  child: _buildLTPCell(alert, theme),
                                ),
                                buildCellWithHover(
                                  rowIndex: index,
                                  columnIndex: 5,
                                  alignRight: true,
                                  onTap: () => _showAlertDetail(alert),
                                  child: _buildStatusCell(alert, theme),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            if (needsHorizontalScroll) {
              return RawScrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                trackColor: resolveThemeColor(context,
                    dark: Colors.grey.withValues(alpha: 0.1),
                    light: Colors.grey.withValues(alpha: 0.1)),
                thumbColor: resolveThemeColor(context,
                    dark: Colors.grey.withValues(alpha: 0.3),
                    light: Colors.grey.withValues(alpha: 0.3)),
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
            }

            return buildTableContent();
          },
        ),
      ),
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
    bool alignRight = false,
    VoidCallback? onTap,
  }) {
    final isFirstColumn = columnIndex == 0;
    final isLastColumn = columnIndex == 5;
    final horizontalPadding = isFirstColumn || isLastColumn ? 16.0 : 8.0;

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
        onEnter: (_) => _hoveredRowToken.value = '$rowIndex',
        onExit: (_) => _hoveredRowToken.value = null,
        child: ValueListenableBuilder<String?>(
          valueListenable: _hoveredRowToken,
          builder: (context, hoveredToken, _) {
            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 4),
                alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: hoveredToken == '$rowIndex'
                      ? resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ).withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
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
    final isLastColumn = columnIndex == 5;
    final horizontalPadding = isFirstColumn || isLastColumn ? 16.0 : 6.0;

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
        onTap: () => _onSortAlertTable(columnIndex),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
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
              if (alignRight && _alertSortColumnIndex == columnIndex)
                Icon(
                  _alertSortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 16,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
              if (alignRight && _alertSortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              Text(
                label,
                style: _getHeaderStyle(context),
              ),
              if (!alignRight && _alertSortColumnIndex == columnIndex)
                const SizedBox(width: 4),
              if (!alignRight && _alertSortColumnIndex == columnIndex)
                Icon(
                  _alertSortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 16,
                  color: shadcn.Theme.of(context).colorScheme.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate minimum column widths dynamically
  Map<int, double> _calculateMinWidths(
      List<dynamic> alerts, BuildContext context) {
    // Use dynamic font size for measurement
    final fontSize = _getResponsiveFontSize(context);

    final headerStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: dyslexiaFontOr('Geist'),
      fontWeight: MyntFonts.semiBold, // w600 for headers
    );
    final cellStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: dyslexiaFontOr('Geist'),
      fontWeight: MyntFonts.medium, // w500 for data cells
    );

    const padding = 24.0;
    const sortIconWidth = 24.0;

    final headers = [
      'Instrument',
      'Exchange',
      'Alert Type',
      'Target',
      'LTP',
      'Status',
    ];
    final minWidths = <int, double>{};

    for (int col = 0; col < headers.length; col++) {
      double maxWidth = 0.0;
      final headerWidth = _measureTextWidth(headers[col], headerStyle);
      maxWidth = headerWidth + sortIconWidth;

      for (final alert in alerts.take(20)) {
        String cellText = '';
        Map<String, String>? parsed = alert is BrokerMessage ? _parseBrokerMessage(alert) : null;
        
        switch (col) {
          case 0: // Instrument
            if (alert is BrokerMessage) {
              cellText = DerivativeMaster.nameFor(alert.exch, alert.token) ??
                  (parsed?['instrument'] ?? 'N/A');
              final exchange = parsed?['exchange'] ?? '';
              if (exchange.isNotEmpty) cellText += ' $exchange';
            } else {
              final symbol = DerivativeMaster.nameFor(alert.exch, alert.token) ??
                  (alert.tsym ?? '').replaceAll("-EQ", "").trim();
              final exchange = alert.exch ?? '';
              cellText = exchange.isNotEmpty ? '$symbol $exchange' : symbol;
            }
            break;
          case 1: // Exchange
            cellText = alert is BrokerMessage ? (parsed?['exchange'] ?? 'N/A') : (alert.exch ?? 'N/A');
            break;
          case 2: // Alert Type
            if (alert is BrokerMessage) {
              // Use the resolved direction so search / CSV export keeps
              // the same wording as the rendered cell.
              cellText = _resolveTriggeredAlertLabel(alert);
            } else {
              switch (alert.aiT) {
                case 'LTP_A':
                  cellText = 'LTP Above';
                  break;
                case 'LTP_B':
                  cellText = 'LTP Below';
                  break;
                case 'CH_PER_A':
                  cellText = 'Perc.Change Above';
                  break;
                case 'CH_PER_B':
                  cellText = 'Perc.Change Below';
                  break;
                default:
                  cellText = 'Unknown';
              }
            }
            break;
          case 3: // Target
            if (alert is BrokerMessage) {
              cellText = parsed?['target'] ?? '0.00';
            } else {
              if (alert.aiT == "CH_PER_A" || alert.aiT == "CH_PER_B") {
                cellText = "%${alert.d ?? '0.00'}";
              } else {
                cellText = "${alert.d ?? '0.00'}";
              }
            }
            break;
          case 4: // LTP
            cellText = alert is BrokerMessage
                ? (parsed?['ltp'] ?? '0.00')
                : "${alert.ltp ?? alert.close ?? '0.00'}";
            break;
          case 5: // Status
            cellText = alert is BrokerMessage ? 'TRIGGERED' : 'PENDING';
            break;
        }

        final cellWidth = _measureTextWidth(cellText, cellStyle);
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }

      minWidths[col] = maxWidth + padding;
    }

    return minWidths;
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

  void _showAlertDetail(dynamic alert) {
    // Only show detail sheet for pending alerts, not triggered ones
    if (alert is! BrokerMessage) {
      // Prevent double-click from opening sheet twice
      if (_isSheetOpening) return;
      _isSheetOpening = true;

      shadcn.openSheet(
        context: context,
        builder: (sheetContext) {
          final screenWidth = MediaQuery.of(sheetContext).size.width;
          final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
          return Container(
            width: sheetWidth,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                context,
                dark: styles.MyntColors.backgroundColorDark,
                light: styles.MyntColors.backgroundColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: PendingAlertDetailScreenWeb(alert: alert),
          );
        },
        position: shadcn.OverlayPosition.end,
        barrierColor: Colors.transparent,
      ).then((_) {
        // Reset flag when sheet closes
        _isSheetOpening = false;
      });
    }
  }

  Widget _buildInstrumentCell(
    dynamic alert,
    ThemesProvider theme,
    bool isRowHovered,
    String uniqueId, {
    int? rowIndex,
  }) {
    final isPending = alert is! BrokerMessage;

    String symbol = '';
    String exchange = '';
    if (alert is BrokerMessage) {
      // Use direct fields from API response; prefer the DerivativeMaster name.
      symbol = DerivativeMaster.nameFor(alert.exch, alert.token) ??
          (alert.tsym?.replaceAll("-EQ", "") ?? '');
      exchange = alert.exch ?? '';
    } else {
      symbol = DerivativeMaster.nameFor(alert.exch, alert.token) ??
          (alert.tsym?.replaceAll("-EQ", "") ?? 'N/A');
      exchange = alert.exch ?? '';
    }

    return GestureDetector(
      onTap: () => _showAlertDetail(alert),
      behavior: HitTestBehavior.deferToChild,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Instrument name - full width, can be partially covered by buttons
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: '$symbol${exchange.isNotEmpty ? ' $exchange' : ''}',
                child: Padding(
                  padding: EdgeInsets.only(right: isRowHovered && isPending ? 70.0 : 0.0),
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                    text: TextSpan(
                      children: [
                        // Symbol (14px, 500)
                        TextSpan(
                          text: symbol,
                          style: MyntWebTextStyles.tableCell(
                            context,
                            darkColor: MyntColors.textPrimaryDark,
                            lightColor: MyntColors.textPrimary,
                            fontWeight: MyntFonts.medium,
                          ),
                        ),
                        // Exchange (10px, 500, muted color) - matching positions table style
                        if (exchange.isNotEmpty)
                          TextSpan(
                            text: ' $exchange',
                            style: MyntWebTextStyles.para(
                              context,
                              darkColor: MyntColors.textSecondaryDark,
                              lightColor: MyntColors.textSecondary,
                              fontWeight: MyntFonts.medium,
                            ).copyWith(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Cancel button + 3-dot menu button (appears on hover)
            if (isRowHovered && isPending)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cancel button (X icon)
                      _buildCancelButton(alert, uniqueId),
                      const SizedBox(width: 6),
                      // 3-dot menu button
                      _buildOptionsMenuButton(
                        alert,
                        uniqueId,
                        rowIndex: rowIndex,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build Cancel button with X icon (tertiary/loss color) - matches positions Exit button
  Widget _buildCancelButton(
    dynamic alert,
    String uniqueId,
  ) {
    final isProcessing = _processingAlertToken == uniqueId && _isProcessingCancel;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              setState(() {
                _processingAlertToken = uniqueId;
                _isProcessingCancel = true;
              });
              await _handleCancelAlert(alert);
              if (mounted) {
                setState(() {
                  _isProcessingCancel = false;
                  _processingAlertToken = null;
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: resolveThemeColor(context,
              // dark: MyntColors.loss.withValues(alpha: 0.15),
              // light: MyntColors.loss.withValues(alpha: 0.1)),
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
          Icons.close,
          size: 16,
          fontWeight: FontWeight.bold,
          color: resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss),
        ),
      ),
    );
  }

  // Helper to build menu item matching positions dropdown style
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

  // Build the 3-dot options menu button with shadcn dropdown
  Widget _buildOptionsMenuButton(
    dynamic alert,
    String uniqueId, {
    int? rowIndex,
  }) {
    final iconColor = resolveThemeColor(context,
        dark: MyntColors.iconDark, light: MyntColors.icon);
    final textColor = resolveThemeColor(context,
        dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);

    return Builder(
      builder: (buttonContext) {
        return GestureDetector(
          onTap: () {
            // Build menu items dynamically
            List<shadcn.MenuItem> menuItems = [];

            // Modify option (commented out)
            // final isProcessing =
            //     _processingAlertToken == uniqueId && _isProcessingModify;
            // menuItems.add(
            //   _buildMenuButton(
            //     icon: Icons.edit_outlined,
            //     title: 'Modify',
            //     iconColor: iconColor,
            //     textColor: textColor,
            //     onPressed: isProcessing
            //         ? (_) {}
            //         : (ctx) async {
            //             _closePopover();
            //             setState(() {
            //               _processingAlertToken = uniqueId;
            //               _isProcessingModify = true;
            //             });
            //             await _handleModifyAlert(alert);
            //             if (mounted) {
            //               setState(() {
            //                 _isProcessingModify = false;
            //                 _processingAlertToken = null;
            //               });
            //             }
            //           },
            //   ),
            // );

            // // Add divider before info
            // menuItems.add(const shadcn.MenuDivider());

            // Info option (always available for pending alerts)
            menuItems.add(
              _buildMenuButton(
                icon: Icons.info_outline,
                title: 'Info',
                iconColor: iconColor,
                textColor: textColor,
                onPressed: (ctx) {
                  _closePopover();
                  _showAlertDetail(alert);
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
                    // Start delayed close - gives time for mouse to move back to row
                    _startPopoverCloseTimer();
                  },
                  child: shadcn.DropdownMenu(
                    children: menuItems,
                  ),
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  // dark: MyntColors.primary.withValues(alpha: 0.1),
                  // light: MyntColors.primary.withValues(alpha: 0.1)),
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
              size: 16,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimary,
                  light: MyntColors.textPrimary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExchangeCell(dynamic alert, ThemesProvider theme) {
    String exchange = '';
    if (alert is BrokerMessage) {
      // Use direct field from API response
      exchange = alert.exch ?? '';
    } else {
      exchange = alert.exch ?? 'N/A';
    }

    return Text(
      exchange,
      style: MyntWebTextStyles.tableCell(
        context,
        darkColor: MyntColors.textPrimaryDark,
        lightColor: MyntColors.textPrimary,
        fontWeight: MyntFonts.medium,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

 
  String _resolveTriggeredAlertLabel(BrokerMessage alert) {
    final dmsg = (alert.dmsg ?? '').toLowerCase();
    if (dmsg.isEmpty) return 'TRIGGERED';

    final isPercent = dmsg.contains('%') ||
        dmsg.contains('percent') ||
        dmsg.contains('perc') ||
        dmsg.contains('ch_per');

    final isAbove = RegExp(r'\babove\b').hasMatch(dmsg);
    final isBelow = RegExp(r'\bbelow\b').hasMatch(dmsg);

    if (isAbove) return isPercent ? 'Perc.Change Above' : 'LTP Above';
    if (isBelow) return isPercent ? 'Perc.Change Below' : 'LTP Below';
    return 'TRIGGERED';
  }

  Widget _buildAlertTypeCell(dynamic alert, ThemesProvider theme) {
    String alertType = '';
    Color alertColor;

    if (alert is BrokerMessage) {
      // Keep the originally-configured direction on the Alert Type column
      // (only Status flips to TRIGGERED — see _buildStatusCell).
      alertType = _resolveTriggeredAlertLabel(alert);
      final isBelowDirection = alertType.endsWith('Below');
      alertColor = isBelowDirection
          ? resolveThemeColor(context,
              dark: MyntColors.lossDark, light: MyntColors.loss)
          : resolveThemeColor(context,
              dark: MyntColors.profitDark, light: MyntColors.profit);
    } else {
      switch (alert.aiT) {
        case 'LTP_A':
          alertType = 'LTP Above';
          alertColor = resolveThemeColor(
            context,
            dark: MyntColors.profitDark,
            light: MyntColors.profit,
          );
          break;
        case 'LTP_B':
          alertType = 'LTP Below';
          alertColor = resolveThemeColor(
            context,
            dark: MyntColors.lossDark,
            light: MyntColors.loss,
          );
          break;
        case 'CH_PER_A':
          alertType = 'Perc.Change Above';
          alertColor = resolveThemeColor(
            context,
            dark: MyntColors.profitDark,
            light: MyntColors.profit,
          );
          break;
        case 'CH_PER_B':
          alertType = 'Perc.Change Below';
          alertColor = resolveThemeColor(
            context,
            dark: MyntColors.lossDark,
            light: MyntColors.loss,
          );
          break;
        default:
          alertType = 'Unknown';
          alertColor = resolveThemeColor(
            context,
            dark: MyntColors.textSecondaryDark,
            light: MyntColors.textSecondary,
          );
      }
    }

    return Text(
      alertType,
      style: MyntWebTextStyles.tableCell(
        context,
        color: alertColor,
        darkColor: alertColor,
        lightColor: alertColor,
        fontWeight: MyntFonts.medium,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTargetCell(dynamic alert, ThemesProvider theme) {
    String target = '';

    if (alert is BrokerMessage) {
      final parsed = _parseBrokerMessage(alert);
      target = parsed['target'] ?? '0.00';
    } else {
      if (alert.aiT == "CH_PER_A" || alert.aiT == "CH_PER_B") {
        target = "%${alert.d ?? '0.00'}";
      } else {
        target = "${alert.d ?? '0.00'}";
      }
    }

    return Tooltip(
      message: target,
      child: Text(
        target,
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium,
        ).copyWith(
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLTPCell(dynamic alert, ThemesProvider theme) {
    String ltp = '';
    if (alert is BrokerMessage) {
      final parsed = _parseBrokerMessage(alert);
      ltp = parsed['ltp'] ?? '0.00';
    } else {
      ltp = "${alert.ltp ?? alert.close ?? '0.00'}";
    }

    return Tooltip(
      message: ltp,
      child: Text(
        ltp,
        style: MyntWebTextStyles.tableCell(
          context,
          darkColor: MyntColors.textPrimaryDark,
          lightColor: MyntColors.textPrimary,
          fontWeight: MyntFonts.medium,
        ).copyWith(
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(dynamic alert, ThemesProvider theme) {
    final status = alert is BrokerMessage ? 'TRIGGERED' : 'PENDING';

    // Use MyntColors for status (matching GTT orders)
    Color statusColor;
    if (status == 'TRIGGERED') {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (status == 'PENDING') {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.warning, light: MyntColors.warning);
    } else {
      statusColor = resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: MyntWebTextStyles.para(
          context,
          color: statusColor,
          fontWeight: MyntFonts.medium,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  Map<String, String> _parseBrokerMessage(BrokerMessage alert) {
    final dmsg = alert.dmsg ?? '';
    final result = <String, String>{
      'instrument': '',
      'exchange': '',
      'target': '',
      'ltp': '',
    };

    if (dmsg.isEmpty) return result;

    // 1. Identify Exchange
    final exchangeMatch =
        RegExp(r'\b(NSE|BSE|MCX|NCDEX|MCXSX|NFO|CDS)\b', caseSensitive: false)
            .firstMatch(dmsg);

    if (exchangeMatch != null) {
      final exchangeToken = exchangeMatch.group(0)!;
      result['exchange'] = exchangeToken.toUpperCase();
      final exchangeIndex = dmsg.indexOf(exchangeToken);

      // 2. Extract Instrument
      String potentialInstrument = "";

      // Helper to check if string contains at least one letter
      bool hasLetter(String s) => RegExp(r'[a-zA-Z]').hasMatch(s);

      // Try before exchange first
      if (exchangeIndex > 0) {
        String before = dmsg.substring(0, exchangeIndex).trim();
        // Remove common prefixes and punctuation at the end
        before = before.replaceAll(RegExp(r'^(Alert|Price Alert|Your alert for|triggered|Info)[:\s-]*', caseSensitive: false), "").trim();
        // Remove trailing punctuation like ( or - or :
        before = before.replaceAll(RegExp(r'[\(\[\-:]$'), "").trim();
        // Only use if it contains letters (not just numbers)
        if (before.isNotEmpty && hasLetter(before)) {
          potentialInstrument = before;
        }
      }

      // If still empty or just too short/garbage, try after exchange
      if (potentialInstrument.length < 2 || !hasLetter(potentialInstrument)) {
        String after = dmsg.substring(exchangeIndex + exchangeToken.length).trim();
        // Clean up leading punctuation
        after = after.replaceAll(RegExp(r'^[\)\]\-\: ]+'), "").trim();

        // Match until first keyword
        final match = RegExp(r'^(.+?)(?=\s+(?:is|at|above|below|crossed|ltp|Ltp|LTP|has)\b)', caseSensitive: false).firstMatch(after);
        if (match != null) {
          final matched = match.group(1)?.trim() ?? "";
          if (hasLetter(matched)) {
            potentialInstrument = matched;
          }
        } else {
          // Alternative: if there's no keyword, it might be "EXCHANGE SYMBOL LTP ..."
          final words = after.split(RegExp(r'\s+'));
          for (var word in words) {
            if (word.isNotEmpty && hasLetter(word)) {
              potentialInstrument = word;
              break;
            }
          }
        }
      }

      result['instrument'] = potentialInstrument;
    }

    // 3. Extract Target and LTP
    // Target price usually follows "above" or "below" or "at"
    final targetMatch = RegExp(r'(?:above|below|at|crossed)\s+([\d,]+\.?\d*)', caseSensitive: false).firstMatch(dmsg);
    if (targetMatch != null) {
      result['target'] = targetMatch.group(1)?.replaceAll(',', '') ?? '';
    }

    // LTP usually follows "LTP" or "Ltp" or "price is"
    final ltpMatch = RegExp(r'(?:LTP|Ltp|price|is)\s*[:\s]+\s*([\d,]+\.?\d*)', caseSensitive: false).firstMatch(dmsg);
    if (ltpMatch != null) {
       result['ltp'] = ltpMatch.group(1)?.replaceAll(',', '') ?? '';
    } else {
      // Sometimes LTP is the first number after a comma or "Ltp:"
      final altLtpMatch = RegExp(r'Ltp[:\s]+([\d,]+\.?\d*)', caseSensitive: false).firstMatch(dmsg);
      if (altLtpMatch != null) {
        result['ltp'] = altLtpMatch.group(1)?.replaceAll(',', '') ?? '';
      }
    }

    // Fallback for instrument if still empty
    if (result['instrument'] == "" || result['instrument'] == "N/A") {
      // Try to find the first uppercase word or combined word
      // Must contain at least one letter (not just numbers/punctuation)
      final words = dmsg.split(RegExp(r'\s+'));
      for (var word in words) {
        final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(word);
        if (word.length > 2 && hasLetter && word == word.toUpperCase() && !(result['exchange']?.contains(word) ?? false)) {
          result['instrument'] = word;
          break;
        }
      }
    }

    return result;
  }

  Future<bool?> _showCancelAlertDialog(AlertPendingModel alert) async {
    final symbol = DerivativeMaster.nameFor(alert.exch, alert.token) ??
        (alert.tsym?.replaceAll("-EQ", "") ?? 'N/A');

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: styles.MyntColors.dialogDark,
                  light: styles.MyntColors.dialog),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cancel Alert',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.textPrimaryDark,
                              light: styles.MyntColors.textPrimary),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const shadcn.CircleBorder(),
                        child: InkWell(
                          customBorder: const shadcn.CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(context,
                                  dark: styles.MyntColors.textSecondaryDark,
                                  light: styles.MyntColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Confirmation text with symbol in quotes
                      Text(
                        'Are you sure you want to cancel "$symbol"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          context,
                          color: resolveThemeColor(context,
                              dark: styles.MyntColors.textPrimaryDark,
                              light: styles.MyntColors.textPrimary),
                        ),
                      ),

                      // Red Cancel button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor:resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: MyntWebTextStyles.buttonMd(
                              context,
                              color: Colors.white,
                            ),
                          ),
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
    );
  }

  // Action handlers
  Future<void> _handleCancelAlert(AlertPendingModel alert) async {
    // Show confirmation dialog first
    final bool? confirm = await _showCancelAlertDialog(alert);
    if (confirm != true) {
      // User cancelled the dialog, reset processing state
      if (mounted) {
        setState(() {
          _isProcessingCancel = false;
          _processingAlertToken = null;
        });
      }
      return;
    }

    try {
      final String alertId = "${alert.alId}";
      await ref.read(marketWatchProvider).fetchCancelAlert(alertId, context);
      await ref.read(marketWatchProvider).fetchPendingAlert(context);

      if (mounted) {
        ResponsiveSnackBar.showSuccess(context, 'Alert Cancelled');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, 'Failed to cancel alert');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCancel = false;
          _processingAlertToken = null;
        });
      }
    }
  }

  // _handleModifyAlert commented out - Modify button hidden
  // Future<void> _handleModifyAlert(AlertPendingModel alert) async {
  //   final uniqueId = alert.alId?.toString() ?? alert.token?.toString() ?? '';
  //   if (_isProcessingModify && _processingAlertToken == uniqueId) return;
  //
  //   try {
  //     setState(() {
  //       _isProcessingModify = true;
  //       _processingAlertToken = uniqueId;
  //     });
  //
  //     // Open modify alert sheet
  //     shadcn.openSheet(
  //       context: context,
  //       builder: (sheetContext) {
  //         final screenWidth = MediaQuery.of(sheetContext).size.width;
  //         final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
  //         return Container(
  //           width: sheetWidth,
  //           decoration: BoxDecoration(
  //             color: resolveThemeColor(
  //               context,
  //               dark: styles.MyntColors.backgroundColorDark,
  //               light: styles.MyntColors.backgroundColor,
  //             ),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withValues(alpha: 0.1),
  //                 blurRadius: 5,
  //                 offset: const Offset(-2, 0),
  //               ),
  //             ],
  //           ),
  //           child: PendingAlertDetailScreenWeb(alert: alert),
  //         );
  //       },
  //       position: shadcn.OverlayPosition.end,
  //       barrierColor: Colors.transparent,
  //     );
  //   } catch (e) {
  //     if (mounted) {
  //       ResponsiveSnackBar.showError(
  //           context, 'Failed to open modify alert: ${e.toString()}');
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isProcessingModify = false;
  //         _processingAlertToken = null;
  //       });
  //     }
  //   }
  // }
}

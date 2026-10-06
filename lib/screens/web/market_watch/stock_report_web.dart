import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mynt_plus/sharedWidget/no_data_found_web.dart';
import 'package:mynt_plus/sharedWidget/functions.dart';
import 'dart:math' as math;
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../models/marketwatch_model/scrip_overview/eodchartdata_model.dart';
import '../../../models/marketwatch_model/scrip_overview/stock_data.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/res.dart';
import '../../../sharedWidget/mynt_loader.dart';
import 'over_view/financial_web.dart';
import 'over_view/chart_web.dart';
import 'over_view/peers_table_web.dart';

class PriceData {
  final DateTime date;
  final double price;
  final int volume;

  PriceData({
    required this.date,
    required this.price,
    required this.volume,
  });
}

class EventData {
  final DateTime date; 
  final String type;
  final String title;
  final String description;

  EventData({
    required this.date,
    required this.type,
    required this.title,
    required this.description,
  });
}

// Data model for Syncfusion Circular Chart
class _ShareholderChartData {
  final String category;
  final double value;
  final Color color;

  _ShareholderChartData({
    required this.category,
    required this.value,
    required this.color,
  });
}

class NewFundamentalScreen extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;
  final GetQuotes depthData;
  final bool showHeader;

  const NewFundamentalScreen({
    super.key,
    required this.wlValue,
    required this.depthData,
    this.showHeader = true,
  });

  @override
  ConsumerState<NewFundamentalScreen> createState() =>
      _NewFundamentalScreenState();
}

class _NewFundamentalScreenState extends ConsumerState<NewFundamentalScreen> {
  List<PriceData> priceData = [];
  List<EventData> eventData = [];
  bool _isLoadingNewData = true; // Initialize as true to prevent "No Data" flash

  // Chart tooltip state (like benchmark_backtest.dart)
  FlSpot? touchedSpot;
  Timer? _hideTooltipTimer;

  // Track last converted data to avoid unnecessary re-conversions
  String? _lastConvertedTimeframe;
  // Events card: selected type chip (null = first type with data).
  String? _selectedEventType;
  // Holdings pie: hovered slice (-1 = none) — name + % shown in the centre.
  int _touchedHoldingIndex = -1;
  int? _lastConvertedDataLength;

  // Event colors for each type
  static const Map<String, Color> eventColors = {
    'Announcement': Color(0xFF2196F3), // Blue
    'Bonus': Color(0xFF4CAF50), // Green
    'Dividend': Color(0xFF9C27B0), // Purple
    'Rights': Color(0xFFFF9800), // Orange
    'Split': Color(0xFFF44336), // Red
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only clear data when showing as standalone screen (with header)
      // When embedded in tabs (showHeader: false), don't clear to prevent tab flickering
      if (widget.showHeader) {
        // Clear any existing data to prevent showing old data
        ref.read(marketWatchProvider).clearChartData();
        ref.read(marketWatchProvider).clearFundamentalData();

        // Clear cache for this specific token to ensure fresh data
        if (widget.wlValue.token.isNotEmpty) {
          ref.read(marketWatchProvider).clearCacheForToken(widget.wlValue.token);
        }
      }
      
      ref.read(websocketProvider).socketDataStream.listen((socketData) {
        if (mounted && socketData.containsKey(widget.wlValue.token)) {
          final newData = socketData[widget.wlValue.token];
          if (newData != null) {
            // Only update if values actually changed
            bool valueChanged = false;
            
            final newLtp = newData['lp']?.toString();
            final newChange = newData['chng']?.toString();
            final newPerChange = newData['pc']?.toString();
            
            if (newLtp != null && newLtp != widget.depthData.lp && newLtp != '0.00') {
              widget.depthData.lp = newLtp;
              valueChanged = true;
            }
            
            if (newChange != null && newChange != widget.depthData.chng) {
              widget.depthData.chng = newChange;
              valueChanged = true;
            }
            
            if (newPerChange != null && newPerChange != widget.depthData.pc) {
              widget.depthData.pc = newPerChange;
              valueChanged = true;
            }
            
            // Only rebuild if values actually changed
            if (valueChanged) {
              setState(() {});
            }
          }
        }
      });
      
      // Fetch data in parallel for better performance
      if (widget.wlValue.exch == "NSE" || widget.wlValue.exch == "BSE") {
        final tradeSym = "${widget.wlValue.exch}:${widget.wlValue.tsym}";
        
        // Load both data sources in parallel
        Future.wait([
          ref.read(marketWatchProvider).fetchFundamentalData(
            tradeSym: tradeSym,
            token: widget.wlValue.token,
          ),
          ref.read(marketWatchProvider).fetchEODChartData(
            widget.wlValue.symbol,
            widget.wlValue.exch,
            timeframe: "5Y",
            context: context,
          ),
        ]).then((_) {
          // Fetch technical data for returns calculation after other data is loaded
          ref.read(marketWatchProvider).fetchTechData(
            exch: widget.wlValue.exch,
            tradeSym: widget.wlValue.tsym,
            lastPrc: "${widget.depthData.lp ?? widget.depthData.c ?? 0.00}",
            context: context,
          ).then((_) {
            // Calculate returns using the same logic as scrip_depth_info.dart
            ref.read(marketWatchProvider).techDataCalc("${widget.depthData.lp ?? widget.depthData.c ?? 0.00}");
          });
          if (mounted) {
            setState(() {
              _isLoadingNewData = false;
            });
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _isLoadingNewData = false;
            });
          }
        });
      } else {
        setState(() {
          _isLoadingNewData = false;
        });
      }
      
    });
  }

  @override
  void dispose() {
    _hideTooltipTimer?.cancel();
    super.dispose();
  }

  // Process WebSocket data for live updates (same as scrip_depth_info.dart)
  void _processDepthData(GetQuotes depthData, Map<String, dynamic> socketData) {
    // Price fields are nullable post-sanitisation (null when broker emits
    // "0"/"0.00" defaults for illiquid contracts). Fall back to "0.00" so
    // downstream double.parse() doesn't see "null".
    depthData.ap = "${socketData['ap']}";
    depthData.lp = socketData['lp']?.toString() ?? "0.00";
    depthData.pc = socketData['pc']?.toString() ?? "0.00";
    depthData.o = socketData['o']?.toString() ?? "0.00";
    depthData.l = socketData['l']?.toString() ?? "0.00";
    depthData.c = socketData['c']?.toString() ?? "0.00";
    depthData.chng = socketData['chng']?.toString() ?? "0.00";
    depthData.h = socketData['h']?.toString() ?? "0.00";
    depthData.poi = "${socketData['poi']}";
    depthData.v = "${socketData['v']}";
    depthData.toi = "${socketData['toi']}";
    depthData.sp1 = "${socketData['sp1']}";
    depthData.sp2 = "${socketData['sp2']}";
    depthData.sp3 = "${socketData['sp3']}";
    depthData.sp4 = "${socketData['sp4']}";
    depthData.sp5 = "${socketData['sp5']}";
    depthData.bp1 = "${socketData['bp1']}";
    depthData.bp2 = "${socketData['bp2']}";
    depthData.bp3 = "${socketData['bp3']}";
    depthData.bp4 = "${socketData['bp4']}";
    depthData.bp5 = "${socketData['bp5']}";
    depthData.sq1 = "${socketData['sq1']}";
    depthData.sq2 = "${socketData['sq2']}";
    depthData.sq3 = "${socketData['sq3']}";
    depthData.sq4 = "${socketData['sq4']}";
    depthData.sq5 = "${socketData['sq5']}";
    depthData.bq1 = "${socketData['bq1']}";
    depthData.bq2 = "${socketData['bq2']}";
    depthData.bq3 = "${socketData['bq3']}";
    depthData.bq4 = "${socketData['bq4']}";
    depthData.bq5 = "${socketData['bq5']}";
    depthData.tbq = "${socketData['tbq']}";
    depthData.tsq = "${socketData['tsq']}";
    depthData.wk52H = "${socketData['52h']}";
    depthData.wk52L = "${socketData['52l']}";
    depthData.lc = "${socketData['lc']}";
    depthData.uc = "${socketData['uc']}";
    depthData.ltq = "${socketData['ltq']}";
    depthData.ltt = "${socketData['ltt']}";
    depthData.ft = "${socketData['ft']}";
  }

  void _convertApiDataToPriceData(
      List<EodChartData> eodDataList, String selectedTimeframe) {
    if (eodDataList.isEmpty) {
      priceData = [];
      return;
    }

    // Convert all data first (5Y data fetched by default)
    final allPriceData = eodDataList.map((eodData) {
      // Use time as date and intc as close price
      final time = eodData.time;
      final close = eodData.intc;
      final volume = eodData.intv;

      // Parse date from time string
      DateTime date;
      if (time.isNotEmpty) {
        try {
          // Handle date format like "26-SEP-2025"
          final parts = time.split('-');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = _getMonthNumber(parts[1]);
            final year = int.parse(parts[2]);
            date = DateTime(year, month, day);
          } else {
            date = DateTime.parse(time);
          }
        } catch (e) {
          date = DateTime.now();
        }
      } else {
        date = DateTime.now();
      }

      return PriceData(
        date: date,
        price: close, // intc is close price
        volume: volume.toInt(),
      );
    }).toList();

    // Sort by date to ensure proper chronological order
    allPriceData.sort((a, b) => a.date.compareTo(b.date));

    // Filter based on selected timeframe - use last N data points approach for consistency
    int dataPointsToShow;

    switch (selectedTimeframe) {
      // TC_419: 3Y / 5Y from the 5Y EOD data already fetched on open.
      case "5Y":
        dataPointsToShow = allPriceData.length;
        break;
      case "3Y":
        // Approximate 750 trading days in 3 years
        dataPointsToShow = 750;
        break;
      case "1Y":
        // Approximate 250 trading days in a year
        dataPointsToShow = 250;
        break;
      case "3M":
        // Approximate 65 trading days in 3 months
        dataPointsToShow = 65;
        break;
      case "1M":
        // Approximate 22 trading days in 1 month
        dataPointsToShow = 22;
        break;
      case "1W":
        // 7 trading days in 1 week
        dataPointsToShow = 7;
        break;
      default:
        dataPointsToShow = 7;
    }

    // Show the last N data points
    if (allPriceData.length <= dataPointsToShow) {
      priceData = allPriceData;
    } else {
      priceData = allPriceData.sublist(allPriceData.length - dataPointsToShow);
    }
  }

  int _getMonthNumber(String month) {
    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12
    };
    return months[month.toUpperCase()] ?? 1;
  }

  // Convert market watch provider event data to EventData format
  void _convertMarketWatchEventData(MarketWatchProvider marketWatch) {
    if (marketWatch.fundamentalData?.stockEvents == null) return;

    List<EventData> convertedEvents = [];

    // Convert announcements
    if (marketWatch.fundamentalData!.stockEvents!.announcement != null) {
      for (var announcement
          in marketWatch.fundamentalData!.stockEvents!.announcement!) {
        if (announcement.boardMeetingDate != null) {
          try {
            final date = DateTime.parse(announcement.boardMeetingDate!);
            convertedEvents.add(EventData(
              date: date,
              type: 'Announcement',
              title: 'Board Meeting',
              description: announcement.agenda ?? 'Board meeting scheduled',
            ));
          } catch (e) {
          }
        }
      }
    }

    // Convert dividends
    if (marketWatch.fundamentalData!.stockEvents!.dividend != null) {
      for (var dividend
          in marketWatch.fundamentalData!.stockEvents!.dividend!) {
        if (dividend.dividendDate != null) {
          try {
            final date = DateTime.parse(dividend.dividendDate!);
            convertedEvents.add(EventData(
              date: date,
              type: 'Dividend',
              title: 'Dividend',
              description:
                  '${dividend.dividendPercent ?? 'N/A'}% - ${dividend.dividendpershare ?? 'N/A'} per share',
            ));
          } catch (e) {
          }
        }
      }
    }

    // Convert bonus
    if (marketWatch.fundamentalData!.stockEvents!.bonus != null) {
      for (var bonus in marketWatch.fundamentalData!.stockEvents!.bonus!) {
        if (bonus.recordDate != null) {
          try {
            final date = DateTime.parse(bonus.recordDate!);
            convertedEvents.add(EventData(
              date: date,
              type: 'Bonus',
              title: 'Bonus Issue',
              description:
                  '${bonus.ratioD ?? 'N/A'}:${bonus.ratioN ?? 'N/A'} bonus ratio',
            ));
          } catch (e) {
          }
        }
      }
    }

    // Convert rights
    if (marketWatch.fundamentalData!.stockEvents!.rights != null) {
      for (var rights in marketWatch.fundamentalData!.stockEvents!.rights!) {
        if (rights.exRightsDate != null) {
          try {
            final date = DateTime.parse(rights.exRightsDate!);
            convertedEvents.add(EventData(
              date: date,
              type: 'Rights',
              title: 'Rights Issue',
              description: 'Price: ₹${rights.offerPrice ?? 'N/A'}',
            ));
          } catch (e) {
          }
        }
      }
    }

    // Convert splits
    if (marketWatch.fundamentalData!.stockEvents!.split != null) {
      for (var split in marketWatch.fundamentalData!.stockEvents!.split!) {
        if (split.exDate != null) {
          try {
            final date = DateTime.parse(split.exDate!);
            convertedEvents.add(EventData(
              date: date,
              type: 'Split',
              title: 'Stock Split',
              description:
                  '${split.fvChangeFrom ?? 'N/A'} to ${split.fvChangeTo ?? 'N/A'}',
            ));
          } catch (e) {
          }
        }
      }
    }

    // Sort events by date
    convertedEvents.sort((a, b) => a.date.compareTo(b.date));
    eventData = convertedEvents;
  }

  // Find the index of a date in priceData
  int _findEventDateIndex(List<PriceData> priceData, DateTime eventDate) {
    for (int i = 0; i < priceData.length; i++) {
      if (priceData[i].date.isAtSameMomentAs(eventDate) ||
          (i > 0 &&
              priceData[i].date.isAfter(eventDate) &&
              priceData[i - 1].date.isBefore(eventDate))) {
        return i;
      }
    }
    return -1; // Event date not found in price data
  }

  // Build event markers for the chart as dots on the price line
  List<LineChartBarData> _buildEventMarkers(
      List<PriceData> priceData,
      List<EventData> events,
      double minPrice,
      double maxPrice,
      MarketWatchProvider marketWatch) {
    List<LineChartBarData> eventMarkers = [];

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final eventIndex = _findEventDateIndex(priceData, event.date);
      if (eventIndex == -1) {
        continue; // Skip if event date not found in price data
      }

      final eventColor = eventColors[event.type] ?? Colors.grey;
      final eventPrice = priceData[eventIndex].price;

      // Get dot size based on event type (more important events = larger dots)
      double dotSize = _getEventDotSize(event.type);

      // Check if this dot is hovered or selected for animation
      final isHovered = marketWatch.hoveredEventDots.contains(i);
      final isSelected = marketWatch.selectedEventDot == i;

      // Scale factor for animations
      double scaleFactor = 1.0;
      if (isHovered) scaleFactor = 1.2;
      if (isSelected) scaleFactor = 1.4;

      eventMarkers.add(
        LineChartBarData(
          spots: [
            FlSpot(eventIndex.toDouble(), eventPrice),
          ],
          color: eventColor,
          barWidth: 0, // No line, just dots
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: dotSize * scaleFactor,
                color: eventColor,
                strokeWidth: isHovered || isSelected ? 3 : 2,
                strokeColor: Colors.white, // White border for contrast
              );
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return eventMarkers;
  }

  // Get dot size based on event type
  double _getEventDotSize(String eventType) {
    switch (eventType) {
      case 'Split':
        return 6.0; // Largest - most significant event
      case 'Bonus':
        return 5.5; // Large - very important
      case 'Rights':
        return 5.0; // Medium-large - important
      case 'Dividend':
        return 4.5; // Medium - regular event
      case 'Announcement':
        return 4.0; // Smallest - informational
      default:
        return 4.0;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.read(themeProvider);
      final marketWatch = ref.watch(marketWatchProvider);
      
      // Convert API data to PriceData format only when data actually changes
      if (marketWatch.eodChartData.isNotEmpty) {
        // Only convert if timeframe or data length changed to avoid repeated conversions
        if (_lastConvertedTimeframe != marketWatch.selectedTimeframe ||
            _lastConvertedDataLength != marketWatch.eodChartData.length) {
          _convertApiDataToPriceData(
              marketWatch.eodChartData, marketWatch.selectedTimeframe);
          _lastConvertedTimeframe = marketWatch.selectedTimeframe;
          _lastConvertedDataLength = marketWatch.eodChartData.length;
        }
      } else {
        priceData = [];
        _lastConvertedTimeframe = null;
        _lastConvertedDataLength = null;
      }

      // Convert market watch event data when available
      if (marketWatch.fundamentalData?.stockEvents != null) {
        _convertMarketWatchEventData(marketWatch);
      }

      // Show loading indicator if still loading
      if (_isLoadingNewData) {
        if (!widget.showHeader) {
          return _buildLoadingIndicator(theme);
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            elevation: 1,
            leadingWidth: 48,
            titleSpacing: 0,
            leading: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: Colors.grey.withOpacity(0.4),
                highlightColor: Colors.grey.withOpacity(0.2),
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 18,
                    color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                  ),
                ),
              ),
            ),
            title: Text(
              "${widget.wlValue.symbol.toUpperCase()} Fundamental",
              style: MyntWebTextStyles.head(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.bold,
              ),
            ),
          ),
          body: _buildLoadingIndicator(theme),
        );
      }

      // Check if fundamental data is available, if not show error message
      if (!_isFundamentalDataAvailable(marketWatch)) {
        if (!widget.showHeader) {
          return const Center(child: NoDataFoundWeb());
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            elevation: 1,
            leadingWidth: 48,
            titleSpacing: 0,
            leading: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: Colors.grey.withOpacity(0.4),
                highlightColor: Colors.grey.withOpacity(0.2),
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_back_ios_outlined,
                    size: 18,
                    color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                  ),
                ),
              ),
            ),
            title: Text(
              "${widget.wlValue.symbol.toUpperCase()} Fundamental",
              style: MyntWebTextStyles.head(
                context,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
                fontWeight: MyntFonts.bold,
              ),
            ),
          ),
          body: const Center(
            child: NoDataFoundWeb(),
          ),
        );
      }    

      return Scaffold(
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
            child: Consumer(
              builder: (context, ref, child) {
                final marketWatch = ref.watch(marketWatchProvider);

                return Column(
                  children: [
                    // Fixed Header Section with static border
                    Container(
                      decoration: BoxDecoration(
                        color: resolveThemeColor(context,
                          dark: MyntColors.backgroundColorDark,
                          light: MyntColors.backgroundColor),
                        border: Border(
                          bottom: BorderSide(
                            color: resolveThemeColor(context,
                                dark: MyntColors.dividerDark,
                                light: MyntColors.divider),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: _buildHeaderSection(theme, marketWatch),
                    ),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Chart & Key Indicators Section - Side by Side (Responsive)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                const double kSpacing = 16.0;

                                // Card decoration (consistent style)
                                BoxDecoration cardDecoration = BoxDecoration(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.backgroundColorDark,
                                    light: MyntColors.backgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.dividerDark,
                                      light: MyntColors.divider,
                                    ),
                                    width: 1,
                                  ),
                                );

                                // If width is less than 900, stack vertically
                                if (availableWidth < 900) {
                                  return Column(
                                    children: [
                                      // Chart Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: _buildPriceHistoryChart(theme, marketWatch),
                                      ),
                                      const SizedBox(height: 16),
                                      // Key Indicators Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Key Indicators",
                                              style: MyntWebTextStyles.title(
                                                context,
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.textPrimaryDark,
                                                  light: MyntColors.textPrimary,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildRatiosTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // Side by side layout for larger screens
                                final cardWidth = (availableWidth - kSpacing) / 2;

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Chart Section (50%)
                                      SizedBox(
                                        width: cardWidth,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: cardDecoration,
                                          child: _buildPriceHistoryChart(theme, marketWatch),
                                        ),
                                      ),
                                      const SizedBox(width: kSpacing),
                                      // Key Indicators Section (50%)
                                      SizedBox(
                                        width: cardWidth,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: cardDecoration,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Key Indicators",
                                                style: MyntWebTextStyles.title(
                                                  context,
                                                  color: resolveThemeColor(
                                                    context,
                                                    dark: MyntColors.textPrimaryDark,
                                                    light: MyntColors.textPrimary,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(child: _buildRatiosTab(marketWatch, theme)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Events (same stockEvents data the chart dots use;
                            // mobile shows it as a list, web only had the dots).
                            // Removed (user): events already show on the chart.
                            // if (marketWatch.fundamentalData?.stockEvents != null) ...[
                            //   _buildEventsCard(marketWatch, theme),
                            //   const SizedBox(height: 24),
                            // ],

                            // Holdings Trend & Income Statement Section - Side by Side (Responsive)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                const double kSpacing = 16.0;

                                // Card decoration (consistent style)
                                BoxDecoration cardDecoration = BoxDecoration(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.backgroundColorDark,
                                    light: MyntColors.backgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.dividerDark,
                                      light: MyntColors.divider,
                                    ),
                                    width: 1,
                                  ),
                                );

                                // If width is less than 900, stack vertically
                                if (availableWidth < 900) {
                                  return Column(
                                    children: [
                                      // Holdings Trend Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Holdings Trend",
                                              style: MyntWebTextStyles.title(
                                                context,
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.textPrimaryDark,
                                                  light: MyntColors.textPrimary,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildHoldingsTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Income Statement Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Income Statement",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildFinancialToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildFinancialTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // Side by side layout for larger screens
                                final cardWidth = (availableWidth - kSpacing) / 2;

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                    // Holdings Trend Section (50%)
                                    SizedBox(
                                      width: cardWidth,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Holdings Trend",
                                              style: MyntWebTextStyles.title(
                                                context,
                                                color: resolveThemeColor(
                                                  context,
                                                  dark: MyntColors.textPrimaryDark,
                                                  light: MyntColors.textPrimary,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildHoldingsTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing),
                                    // Income Statement Section (50%)
                                    SizedBox(
                                      width: cardWidth,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Income Statement",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildFinancialToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildFinancialTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Balance Sheet & Cash Flow Section - Side by Side (Responsive)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                const double kSpacing = 16.0;

                                // Card decoration (consistent style)
                                BoxDecoration cardDecoration = BoxDecoration(
                                  color: resolveThemeColor(
                                    context,
                                    dark: MyntColors.backgroundColorDark,
                                    light: MyntColors.backgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: resolveThemeColor(
                                      context,
                                      dark: MyntColors.dividerDark,
                                      light: MyntColors.divider,
                                    ),
                                    width: 1,
                                  ),
                                );

                                // If width is less than 900, stack vertically
                                if (availableWidth < 900) {
                                  return Column(
                                    children: [
                                      // Balance Sheet Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Balance Sheet",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildBalanceSheetToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildBalanceSheetTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Cash Flow Section
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Cash Flow",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildCashFlowToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildCashFlowTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // Side by side layout for larger screens
                                final cardWidth = (availableWidth - kSpacing) / 2;

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                    // Balance Sheet Section (50%)
                                    SizedBox(
                                      width: cardWidth,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Balance Sheet",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildBalanceSheetToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildBalanceSheetTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: kSpacing),
                                    // Cash Flow Section (50%)
                                    SizedBox(
                                      width: cardWidth,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: cardDecoration,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Cash Flow",
                                                  style: MyntWebTextStyles.title(
                                                    context,
                                                    color: resolveThemeColor(
                                                      context,
                                                      dark: MyntColors.textPrimaryDark,
                                                      light: MyntColors.textPrimary,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                _buildCashFlowToggle(marketWatch, theme),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildCashFlowTab(marketWatch, theme),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Peers Section - Half Width
                            // Peers Section (Full Width)
                            _buildPeersTab(marketWatch, theme),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Events card — web port of mobile's Events section (stock_events.dart).
  // Columns mirror mobile's fields; rows newest first. Display only — nothing
  // is derived from the data.
  // ---------------------------------------------------------------------------

  static const List<String> _eventTypes = [
    'Announcement',
    'Dividend',
    'Bonus',
    'Rights',
    'Split',
  ];

  /// Headers + rows for one event type (first cell = the row's main date).
  ({List<String> headers, List<List<String>> rows}) _eventTable(
      StockEvents ev, String type) {
    String v(String? s) => (s == null || s.trim().isEmpty) ? '-' : s.trim();
    List<List<String>> newestFirst(List<List<String>> rows) {
      rows.sort((a, b) {
        final da = DateTime.tryParse(a.first);
        final db = DateTime.tryParse(b.first);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      return rows;
    }

    switch (type) {
      case 'Announcement':
        return (
          headers: ['Board meeting date', 'Agenda', 'Source date'],
          rows: newestFirst([
            for (final a in ev.announcement ?? <Announcement>[])
              [
                v(a.boardMeetingDate),
                // Agenda arrives with a leading separator character.
                v(a.agenda?.replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '')),
                v(a.sourceDate),
              ]
          ]),
        );
      case 'Dividend':
        return (
          headers: [
            'Ex date',
            'Record date',
            'Dividend date',
            'Dividend %',
            'Per share',
            'Details'
          ],
          rows: newestFirst([
            for (final d in ev.dividend ?? <Dividend>[])
              [
                v(d.exDate),
                v(d.recordDate),
                v(d.dividendDate),
                v(d.dividendPercent),
                v(d.dividendpershare),
                v(d.details),
              ]
          ]),
        );
      case 'Bonus':
        return (
          headers: [
            'Ex bonus date',
            'Record date',
            'Cum bonus date',
            'Ratio N',
            'Ratio D',
            'Source date'
          ],
          rows: newestFirst([
            for (final b in ev.bonus ?? <Bonus>[])
              [
                v(b.exBonusDate),
                v(b.recordDate),
                v(b.cumBonusDate),
                v(b.ratioN),
                v(b.ratioD),
                v(b.sourceDate),
              ]
          ]),
        );
      case 'Rights':
        return (
          headers: [
            'Ex rights date',
            'Record date',
            'Offer price',
            'Premium',
            'Ratio N',
            'Ratio D'
          ],
          rows: newestFirst([
            for (final r in ev.rights ?? <Rights>[])
              [
                v(r.exRightsDate),
                v(r.recordDate),
                v(r.offerPrice),
                v(r.premiumRs),
                v(r.ratioN),
                v(r.rationD),
              ]
          ]),
        );
      default: // Split
        return (
          headers: ['Ex date', 'Record date', 'Face value from', 'Face value to'],
          rows: newestFirst([
            for (final sp in ev.split ?? const [])
              [
                v(sp.exDate),
                v(sp.recordDate),
                v(sp.fvChangeFrom),
                v(sp.fvChangeTo),
              ]
          ]),
        );
    }
  }

  /// "2022-07-28" -> "28 Jul 2022"; anything else is shown as received.
  String _formatEventCell(String value) {
    final d = DateTime.tryParse(value);
    if (d == null) return value;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildEventsCard(MarketWatchProvider marketWatch, ThemesProvider theme) {
    final ev = marketWatch.fundamentalData!.stockEvents!;
    final counts = {
      for (final t in _eventTypes) t: _eventTable(ev, t).rows.length,
    };
    final available = _eventTypes.where((t) => counts[t]! > 0).toList();
    final selected = available.contains(_selectedEventType)
        ? _selectedEventType!
        : (available.isNotEmpty ? available.first : null);

    final secondary = resolveThemeColor(context,
        dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final divider = resolveThemeColor(context,
        dark: MyntColors.dividerDark, light: MyntColors.divider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Events",
                style: MyntWebTextStyles.title(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (available.isNotEmpty)
                // Same toggle look as Income Statement's Standalone/Consolidated.
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: available.map((type) {
                      final isSelected = type == selected;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedEventType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MyntColors.secondary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "$type (${counts[type]})",
                            style: MyntWebTextStyles.para(
                              context,
                              color: isSelected ? colors.colorWhite : null,
                              darkColor: isSelected
                                  ? null
                                  : MyntColors.textSecondaryDark,
                              lightColor:
                                  isSelected ? null : MyntColors.textPrimary,
                              fontWeight: isSelected
                                  ? MyntFonts.bold
                                  : MyntFonts.medium,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (selected == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "No events available",
                  style: MyntWebTextStyles.para(context,
                      darkColor: MyntColors.textSecondaryDark,
                      lightColor: MyntColors.textSecondary),
                ),
              ),
            )
          else
            Builder(builder: (context) {
              final table = _eventTable(ev, selected);
              // Announcement agenda / dividend details are long text.
              int flexFor(String h) =>
                  (h == 'Agenda' || h == 'Details') ? 3 : 1;
              Widget cell(String text, String header, {bool isHeader = false}) {
                final shown = isHeader ? text : _formatEventCell(text);
                return Expanded(
                  flex: flexFor(header),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Tooltip(
                      message: isHeader ? '' : shown,
                      child: Text(
                        shown,
                        maxLines: isHeader ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: isHeader
                            ? MyntWebTextStyles.para(context,
                                color: secondary, fontWeight: MyntFonts.medium)
                            : MyntWebTextStyles.body(
                                context,
                                color: resolveThemeColor(context,
                                    dark: MyntColors.textPrimaryDark,
                                    light: MyntColors.textPrimary),
                              ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      for (final h in table.headers) cell(h, h, isHeader: true),
                    ]),
                  ),
                  Divider(height: 1, color: divider),
                  ConstrainedBox(
                    // Long dividend histories scroll inside the card.
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: table.rows.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: divider),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int c = 0; c < table.headers.length; c++)
                              cell(table.rows[i][c], table.headers[c]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  // Allocation card wrapper for consistent styling
  Widget _buildAllocationCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resolveThemeColor(
            context,
            dark: MyntColors.dividerDark,
            light: MyntColors.divider,
          ),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MyntWebTextStyles.title(
              context,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textPrimaryDark,
                light: MyntColors.textPrimary,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  // Header Section
  Widget _buildHeaderSection(
      ThemesProvider theme, MarketWatchProvider marketWatch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Symbol (like in scrip_depth_info.dart)
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${DerivativeMaster.nameFor(widget.wlValue.exch, widget.wlValue.token) ?? "${widget.wlValue.symbol.replaceAll("-EQ", "").toUpperCase()}${widget.wlValue.expDate} ${widget.wlValue.option}"}",
                    style: MyntWebTextStyles.title(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    marketWatch.fundamentalData?.fundamental?.isNotEmpty ==
                            true
                        ? marketWatch.fundamentalData!.fundamental!.first
                                .companyName ??
                            marketWatch.scripInfoModel?.cname ??
                            widget.wlValue.symbol.toUpperCase()
                        : marketWatch.scripInfoModel?.cname ??
                            widget.wlValue.symbol.toUpperCase(),
                    style: MyntWebTextStyles.para(
                      context,
                      darkColor: MyntColors.textPrimaryDark,
                      lightColor: MyntColors.textPrimary,
                      fontWeight: MyntFonts.medium,
                    ),
                  ),
                ],
              ),
              RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${widget.depthData.lp != "null" ? widget.depthData.lp ?? widget.depthData.c ?? 0.00 : '0.00'}",
                      style: MyntWebTextStyles.body(
                        context,
                        darkColor: (widget.depthData.chng == "null" ||
                                    widget.depthData.chng == null) ||
                                widget.depthData.chng == "0.00"
                            ? MyntColors.textSecondaryDark
                            : widget.depthData.chng!.startsWith("-") ||
                                    widget.depthData.pc!.startsWith("-")
                                ? MyntColors.lossDark
                                : MyntColors.profitDark,
                        lightColor: (widget.depthData.chng == "null" ||
                                    widget.depthData.chng == null) ||
                                widget.depthData.chng == "0.00"
                            ? MyntColors.textSecondary
                            : widget.depthData.chng!.startsWith("-") ||
                                    widget.depthData.pc!.startsWith("-")
                                ? MyntColors.loss
                                : MyntColors.profit,
                                fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(height: 4),
            
                    // Price Change and Percentage
                    Text(
                      "${(double.tryParse(widget.depthData.chng ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${(double.tryParse(widget.depthData.pc ?? '0.00') ?? 0.00).toStringAsFixed(2)}%)",
                      style: MyntWebTextStyles.para(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    // const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
 Widget _buildRatiosTab(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Show data if available, otherwise show "No Data Found"
    if (marketWatch.fundamentalData?.fundamental?.isNotEmpty == true) {
      return SingleChildScrollView(
        child: _buildRatiosSection(marketWatch.fundamentalData!.fundamental![0], theme),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: Text(
                "Data not available",
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      );
    }
  }


   Widget _buildRatiosSection(dynamic funData, ThemesProvider theme) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // VALUE SECTION

          _rowOfInfoData(
           "MARKET CAP",
           "${funData?.marketCap != null ? double.parse(funData!.marketCap!).round() : 'N/A'} Cr",
           "FACE VALUE",
           "${funData?.fv ?? 'N/A'}",
           "",
           "",
           theme,
         ),
         const SizedBox(height: 14),
         _buildSectionHeader("Value", theme),
         const SizedBox(height: 12),
         _rowOfInfoData(
           "P/E",
           "${funData?.pe ?? 'N/A'}",
           "SECTOR PE",
           "${funData?.sectorPe ?? 'N/A'}",
           "EV/EBITDA",
           "${funData?.evEbitda ?? 'N/A'}",
           theme,
         ),
         const SizedBox(height: 14),
         _rowOfInfoData(
           "P/B",
           "${funData?.priceBookValue ?? 'N/A'}",          
           "P/S",
           "${funData?.salesToWorkingCapital ?? 'N/A'}",
            "DIVIDEND YIELD",
           "${funData?.dividendYieldPercent ?? 'N/A'}",
           theme,
         ),
         const SizedBox(height: 20),
         
         // GROWTH SECTION
         _buildSectionHeader("Growth", theme),
         const SizedBox(height: 12),
         _rowOfInfoData(
           "EPS",
           "${funData?.eps ?? 'N/A'}",
           "BOOK VALUE",
           "${funData?.bookValue ?? 'N/A'}",
           "",
           "",
           theme,
         ),
         const SizedBox(height: 20),
         
         // QUALITY SECTION
         _buildSectionHeader("Quality", theme),
         const SizedBox(height: 12),
         _rowOfInfoData(
           "ROCE",
           "${funData?.rocePercent ?? 'N/A'}",
           "ROE",
           "${funData?.roePercent ?? 'N/A'}",
           "D/E",
           "${funData?.debtToEquity ?? 'N/A'}",
           theme,
         ),
        //  const SizedBox(height: 14),
        //  _rowOfInfoData(
        //    "FACE VALUE",
        //    "${funData?.fv ?? 'N/A'}",
        //    "",
        //    "",
        //    "",
        //    "",
        //    theme,
        //  ),
       ],
     );
   }

  Widget _buildSectionHeader(String title, ThemesProvider theme) {
    return Row(
      children: [
        Text(
          title,
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.semiBold,
            color : resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
          ),
        ),
        if (title == "Value" || title == "Growth" || title == "Quality") ...[
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor:
                  theme.isDarkMode ? colors.splashColorDark : colors.splashColorLight,
              highlightColor:
                  theme.isDarkMode ? colors.highlightDark : colors.highlightLight,
              onTap: () {}, // required for splash
              child: TooltipTheme(
                data: TooltipThemeData(
                  textStyle: MyntWebTextStyles.caption(
                    context,
                    lightColor: Colors.white,
                    darkColor: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  preferBelow: false,
                  verticalOffset: 8,
                ),
                child: Tooltip(
                  message: _getSectionTooltip(title),
                  triggerMode: TooltipTriggerMode.tap,
                  waitDuration: const Duration(milliseconds: 80),
                  showDuration: const Duration(seconds: 5),
                  preferBelow: false,
                  verticalOffset: 8,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Info tooltip removed

  String _getSectionTooltip(String sectionTitle) {
    switch (sectionTitle) {
      case "Value":
        return "P/E - Price-to-Earnings\nP/B - Price-to-Book\nP/S - Price-to-Sales";
      
      case "Growth":
        return "EPS - Earnings Per Share";
      
      case "Quality":
        return "ROCE - Return on Capital Employed\nROE - Return on Equity\nD/E - Debt-to-Equity";
      
      default:
        return "Financial metrics";
    }
  }

  Row _rowOfInfoData(String title1, String value1, String title2, String value2,
      String title3, String value3, ThemesProvider theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title1,
                style: MyntWebTextStyles.para(
                  context,
                  color : resolveThemeColor(
                    context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatNumber(value1, title1),
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.medium,
                ),
              ),
              const SizedBox(height: 2),
              Divider(
                color: resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider),
              ),
            ],
          ),
        ),
        if (title2.isNotEmpty) ...[
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title2,
                  style: MyntWebTextStyles.para(
                    context,
                    color : resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(value2, title2),
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Divider(
                  color: theme.isDarkMode
                      ? colors.darkColorDivider
                      : colors.colorDivider,
                ),
              ],
            ),
          ),
        ],
        if (title3.isNotEmpty) ...[
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title3,
                  style: MyntWebTextStyles.para(
                    context,
                    color : resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(value3, title3),
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: MyntFonts.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Divider(
                  color: theme.isDarkMode
                      ? colors.darkColorDivider
                      : colors.colorDivider,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatNumber(String value, String title) {
    if (value == 'N/A' || value.isEmpty) return value;
    
    final numValue = double.tryParse(value);
    if (numValue == null) return value;
    
 
    
    // For other values, just format to 2 decimal places if needed
    if (numValue % 1 == 0) {
      return numValue.toInt().toString();
    } else {
      return numValue.toStringAsFixed(2);
    }
  }



  // Company Overview Section
  Widget _buildCompanyOverviewSection(ThemesProvider theme) {
    return _buildSectionCard(
      "Overview",
      Icons.business,
      [
        _buildOverviewItem(
          "Core Business",
          "Global leader in IT services, consulting, and business solutions with expertise in digital transformation, cloud services, and enterprise software development.",
          theme,
        ),
        const SizedBox(height: 16),
        _buildOverviewItem(
          "Strategic Diversification",
          "Expansion into emerging technologies including AI/ML, blockchain, IoT solutions, and industry-specific digital platforms across banking, retail, and healthcare.",
          theme,
        ),
        const SizedBox(height: 16),
        _buildOverviewItem(
          "Competitive Advantage",
          "World-class talent pool with 600,000+ employees, strong client relationships with Fortune 500 companies, and proven delivery capabilities across 46+ countries.",
          theme,
        ),
        const SizedBox(height: 16),
        _buildOverviewItem(
          "Capital Allocation",
          "Talent development, R&D investments, and strategic acquisitions while maintaining strong cash generation and consistent dividend distribution.",
          theme,
        ),
      ],
      theme,
    );
  }

  // Rewards (Investment Thesis & Recommendation) Section
  Widget _buildRewardsSection(ThemesProvider theme) {
    return _buildSectionCard(
      "Rewards",
      Icons.trending_up,
      [
        _buildRewardItem(
          "Diversified earnings base",
          "Oil & gas, telecom, retail, and renewables provide multiple growth levers.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRewardItem(
          "Strong cash generation",
          "Operating cash flow > ₹ 170 bn, enabling self-financed capex.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRewardItem(
          "Modest leverage",
          "Debt-to-equity ≈ 0.36, well-below many peers.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRewardItem(
          "Valuation premium justified?",
          "PE and EV/EBITDA are higher than peers; price must reflect high-growth segments.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRewardItem(
          "Upside catalysts",
          "5G rollout, green-hydrogen projects, retail-to-consumer expansion, and potential strategic acquisitions.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRewardItem(
          "Downside guardrails",
          "Even a 15% price decline leaves the stock above book value (PB ≈ 1.8x) with ample cash coverage.",
          theme,
        ),
      ],
      theme,
    );
  }

  // Risks Section
  Widget _buildRisksSection(ThemesProvider theme) {
    return _buildSectionCard(
      "Key Risks to Watch",
      Icons.warning_amber,
      [
        _buildRiskItem(
          "Sharp decline in global crude-oil prices compressing refining margins.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRiskItem(
          "Regulatory/tax reforms affecting the oil-and-gas and renewable-energy segments.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRiskItem(
          "Execution risk on large-scale capex (green-hydrogen, 5G) – cost overruns could erode cash flow.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRiskItem(
          "Intensifying competition in telecom and retail, potentially slowing high-margin growth.",
          theme,
        ),
        const SizedBox(height: 12),
        _buildRiskItem(
          "Macroeconomic slowdown reducing demand for petrochemicals and discretionary retail spend.",
          theme,
        ),
      ],
      theme,
    );
  }

  Widget _buildPeersTab(MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Show data if available, otherwise show "No Data Found"
    if (marketWatch.fundamentalData?.msg != "no data found" &&
        marketWatch.fundamentalData?.peersComparison != null &&
        marketWatch.fundamentalData!.peersComparison!.stock != null &&
        marketWatch.fundamentalData!.peersComparison!.peers != null &&
        (marketWatch.fundamentalData!.peersComparison!.stock!.isNotEmpty ||
         marketWatch.fundamentalData!.peersComparison!.peers!.isNotEmpty)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Peers Comparison",
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Use new table widget - no fixed height, let it expand
            const PeersTableWeb(),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Peers Comparison",
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Text(
                        "Data not available",
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          darkColor: MyntColors.textSecondaryDark,
                          lightColor: MyntColors.textSecondary,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      );
    }
  }

  Widget _buildHoldingsTab(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Show data if available, otherwise show "No Data Found"
    if (marketWatch.fundamentalData?.msg != "no data found" &&
        marketWatch.fundamentalData?.shareholdings != null &&
        marketWatch.fundamentalData!.shareholdings!.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie Chart Container
              _buildHoldingsPieChart(marketWatch, theme),
              const SizedBox(height: 16),
              // Holdings Table
              _buildHoldingsTable(marketWatch, theme),
            ],
          ),
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: Text(
                "Data not available",
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      );
    }
  }

  // Helper method to get color for each holding type
  Color _getHoldTypeColor(String holdType) {
    switch (holdType) {
      case "Promoter Holding":
        return const Color(0xFF2196F3); // Blue
      case "Foriegn Institution":
        return const Color(0xFF4CAF50); // Green
      case "Other Domestic Institution":
        return const Color(0xFFFF9800); // Orange
      case "Retail and Others":
        return const Color(0xFF9C27B0); // Purple
      case "Mutual Funds":
        return const Color(0xFFE91E63); // Pink
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  // Section Card Helper
  Widget _buildSectionCard(String title, IconData icon, List<Widget> children,
      ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: MyntWebTextStyles.head(
                context,
                fontWeight: MyntFonts.bold,
                darkColor: MyntColors.textPrimaryDark,
                lightColor: MyntColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  // Overview Item Helper
  Widget _buildOverviewItem(
      String title, String description, ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MyntWebTextStyles.bodySmall(
            context,
            fontWeight: MyntFonts.bold,
            darkColor: MyntColors.textPrimaryDark,
            lightColor: MyntColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: MyntWebTextStyles.para(
            context,
            darkColor: MyntColors.textSecondaryDark,
            lightColor: MyntColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Reward Item Helper
  Widget _buildRewardItem(
      String title, String description, ThemesProvider theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 12),
          decoration: BoxDecoration(
            color: resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  fontWeight: MyntFonts.bold,
                  darkColor: MyntColors.textPrimaryDark,
                  lightColor: MyntColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: MyntWebTextStyles.para(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Toggle helper for Income Statement
  Widget _buildFinancialToggle(MarketWatchProvider marketWatch, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: marketWatch.finType.map((filter) {
          final isSelected = marketWatch.selcteIncomeFinType == filter;
          return GestureDetector(
            onTap: () {
              marketWatch.chngIncomeFinType(filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
               color: isSelected ? MyntColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                filter,
                style: MyntWebTextStyles.para(
                  context,
                  color: isSelected ? colors.colorWhite : null,
                  darkColor: isSelected ? null : MyntColors.textSecondaryDark,
                  lightColor: isSelected ? null : MyntColors.textPrimary,
                  fontWeight: isSelected ? MyntFonts.bold : MyntFonts.medium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Toggle helper for Balance Sheet
  Widget _buildBalanceSheetToggle(MarketWatchProvider marketWatch, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: marketWatch.finType.map((filter) {
          final isSelected = marketWatch.selcteBalanceSheetFinType == filter;
          return GestureDetector(
            onTap: () {
              marketWatch.chngBalanceSheetFinType(filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? MyntColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                filter,
                style: MyntWebTextStyles.para(
                  context,
                  color: isSelected ? colors.colorWhite : null,
                  darkColor: isSelected ? null : MyntColors.textSecondaryDark,
                  lightColor: isSelected ? null : MyntColors.textPrimary,
                  fontWeight: isSelected ? MyntFonts.bold : MyntFonts.medium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Toggle helper for Cash Flow
  Widget _buildCashFlowToggle(MarketWatchProvider marketWatch, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.isDarkMode ? colors.darkGrey : const Color(0xffF1F3F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: marketWatch.finType.map((filter) {
          final isSelected = marketWatch.selcteCashFlowFinType == filter;
          return GestureDetector(
            onTap: () {
              marketWatch.chngCashFlowFinType(filter);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? MyntColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                filter,
                style: MyntWebTextStyles.para(
                  context,
                  color: isSelected ? colors.colorWhite : null,
                  darkColor: isSelected ? null : MyntColors.textSecondaryDark,
                  lightColor: isSelected ? null : MyntColors.textPrimary,
                  fontWeight: isSelected ? MyntFonts.bold : MyntFonts.medium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Income Statement Section - Complete with chart and data
  Widget _buildFinancialTab(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Check if income data is available
    final hasConsolidatedData = marketWatch.fundamentalData?.stockFinancialsConsolidated?.incomeSheet?.isNotEmpty ?? false;
    final hasStandaloneData = marketWatch.fundamentalData?.stockFinancialsStandalone?.incomeSheet?.isNotEmpty ?? false;

    if (marketWatch.fundamentalData?.msg == "no data found" || (!hasConsolidatedData && !hasStandaloneData)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: Text(
                "Data not available",
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      );
    }

    // Show complete income section with chart and table (toggle is now in header)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Income Chart
            const FIncomeChartWeb(),
            const SizedBox(height: 16),
            // Income Data Table
            IncomeSheetDataWeb(
              themes: theme,
              incomSheet: marketWatch.selcteIncomeFinType == "Consolidated"
                  ? marketWatch.fundamentalData!.stockFinancialsConsolidated!.incomeSheet!
                  : marketWatch.fundamentalData!.stockFinancialsStandalone!.incomeSheet!,
              financialYear: marketWatch.selcteFinYear,
            ),
          ],
        ),
      ),
    );
  }

  // Balance Sheet Section - Complete with chart and data
  Widget _buildBalanceSheetTab(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Check if balance sheet data is available
    final hasConsolidatedData = marketWatch.fundamentalData?.stockFinancialsConsolidated?.balanceSheet?.isNotEmpty ?? false;
    final hasStandaloneData = marketWatch.fundamentalData?.stockFinancialsStandalone?.balanceSheet?.isNotEmpty ?? false;

    if (marketWatch.fundamentalData?.msg == "no data found" || (!hasConsolidatedData && !hasStandaloneData)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: Text(
                "Data not available",
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      );
    }

    // Show complete balance sheet section with chart and table (toggle is now in header)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Sheet Chart
            const FBalSheetChartWeb(),
            const SizedBox(height: 16),
            // Balance Sheet Data Table
            BalanceSheetDataWeb(
              balanceSheet: marketWatch.selcteBalanceSheetFinType == "Consolidated"
                  ? marketWatch.fundamentalData!.stockFinancialsConsolidated!.balanceSheet!
                  : marketWatch.fundamentalData!.stockFinancialsStandalone!.balanceSheet!,
              financialYear: marketWatch.selcteFinYear,
              themes: theme,
            ),
          ],
        ),
      ),
    );
  }

  // Cash Flow Section - Complete with chart and data
  Widget _buildCashFlowTab(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Check if cash flow data is available
    final hasConsolidatedData = marketWatch.fundamentalData?.stockFinancialsConsolidated?.cashflowSheet?.isNotEmpty ?? false;
    final hasStandaloneData = marketWatch.fundamentalData?.stockFinancialsStandalone?.cashflowSheet?.isNotEmpty ?? false;

    if (marketWatch.fundamentalData?.msg == "no data found" || (!hasConsolidatedData && !hasStandaloneData)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: Text(
                "Data not available",
                textAlign: TextAlign.center,
                style: MyntWebTextStyles.bodySmall(
                  context,
                  darkColor: MyntColors.textSecondaryDark,
                  lightColor: MyntColors.textSecondary,
                ),
              ),
            )
          ],
        ),
      );
    }

    // Show complete cash flow section with chart and table (toggle is now in header)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 600),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash Flow Chart
            const FCashFlowChartWeb(),
            const SizedBox(height: 16),
            // Cash Flow Data Table
            CashFlowSheetDataWeb(
              cashFlowSheet: marketWatch.selcteCashFlowFinType == "Consolidated"
                  ? marketWatch.fundamentalData!.stockFinancialsConsolidated!.cashflowSheet!
                  : marketWatch.fundamentalData!.stockFinancialsStandalone!.cashflowSheet!,
              financialYear: marketWatch.selcteFinYear,
              themes: theme,
            ),
          ],
        ),
      ),
    );
  }

  // Check if fundamental data is available
  bool _isFundamentalDataAvailable(MarketWatchProvider marketWatch) {
    return marketWatch.fundamentalData != null &&
           marketWatch.fundamentalData?.msg != "no data found";
  }

  // Risk Item Helper
  Widget _buildRiskItem(String description, ThemesProvider theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 12),
          decoration: BoxDecoration(
            color: resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            description,
            style: MyntWebTextStyles.para(
              context,
              darkColor: MyntColors.textSecondaryDark,
              lightColor: MyntColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // Price History & Performance Chart
  Widget _buildPriceHistoryChart(
      ThemesProvider theme, MarketWatchProvider marketWatch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          "Price History",
          style: MyntWebTextStyles.title(
            context,
            color: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
          // Header with Toggle
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [            
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: marketWatch.chartDataLoading
                    ? Center(
                        child: MyntLoader.simple(),
                      )
                    : priceData.isEmpty
                        ? Center(
                            child: Text(
                              "No Data Available",
                              style: MyntWebTextStyles.para(
                                context,
                                darkColor: MyntColors.textSecondaryDark,
                                lightColor: MyntColors.textSecondary,
                              ),
                            ),
                          )
                        : _buildScrollablePriceChart(theme, marketWatch),
              ),


              const SizedBox(height: 16),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final timeframes = _chartTimeframes(marketWatch);
                    final timeframe = timeframes[index];
                    final isSelected =
                        marketWatch.selectedTimeframe == timeframe;

                    // TC_419: no 3Y/5Y return from the backend — leave blank
                    // (the helper would fall back to the 1W figure).
                    final hasReturn = timeframe != "3Y" && timeframe != "5Y";
                    final returnPercentage = hasReturn
                        ? _getTechnicalReturnPercentage(marketWatch.returnsGridview, timeframe)
                        : " "; // keeps chip height equal

                    final percentValue = double.tryParse(returnPercentage.replaceAll(RegExp(r'[+%]'), '')) ?? 0.0;
                    final isPositive = percentValue >= 0;

                    return GestureDetector(
                      onTap: () {
                        marketWatch.updateSelectedTimeframe(timeframe);
                        // Hide tooltip when timeframe changes
                        marketWatch.updateShowTooltip(false);
                        touchedSpot = null;
                        _hideTooltipTimer?.cancel();
                        FocusScope.of(context).unfocus();

                        if (marketWatch.eodChartData.isNotEmpty) {
                          _convertApiDataToPriceData(marketWatch.eodChartData, timeframe);
                          _lastConvertedTimeframe = timeframe;
                          _lastConvertedDataLength = marketWatch.eodChartData.length;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.isDarkMode
                                  ? colors.darkGrey
                                  : const Color(0xffF1F3F8)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Timeframe text
                            Text(
                              timeframe,
                              style: MyntWebTextStyles.body(
                                context,
                               color :  resolveThemeColor(
                                  context,
                                  dark: MyntColors.textPrimaryDark,
                                  light: MyntColors.textPrimary,
                                ),
                                fontWeight: isSelected ? MyntFonts.bold : MyntFonts.semiBold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Return percentage
                            Text(
                              returnPercentage,
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                color :  resolveThemeColor(
                                  context,
                                  dark: isPositive ? MyntColors.profitDark : MyntColors.lossDark,
                                  light: isPositive ? MyntColors.profit : MyntColors.loss,
                                ),
                                fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.regular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return const SizedBox(width: 8);
                  },
                  itemCount: _chartTimeframes(marketWatch).length, // 1W, 1M, 3M, 1Y (+3Y, 5Y)
                ),
              ),
            ],
          ),
          if (eventData.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEventLegend(theme),
          ],
        ],
      );
  }

  // Non-scrollable Price Chart - fits 1 year data within screen
  Widget _buildScrollablePriceChart(
      ThemesProvider theme, MarketWatchProvider marketWatch) {
    if (priceData.isEmpty) return const SizedBox();

    final minPrice = priceData.map((e) => e.price).reduce(math.min);
    final maxPrice = priceData.map((e) => e.price).reduce(math.max);

    return Container(
      height: 400,
      color: Colors.transparent,
      padding: const EdgeInsets.only(
          top: 16, bottom: 16, left: 8, right: 8),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: Duration.zero, 
            child: LineChart(
              key: ValueKey(marketWatch
                  .selectedTimeframe), 
              LineChartData(
                gridData: const FlGridData(
                  show: false, 
                  drawVerticalLine: false,
                  drawHorizontalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: (priceData.length - 1) /
                          4, 
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < priceData.length) {
                          final date = priceData[value.toInt()].date;
                          final months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ];

                          switch (marketWatch.selectedTimeframe) {
                            case "5Y":
                            case "3Y":
                            case "1Y":
                              
                              final monthName = months[date.month - 1];
                              final year = date.year.toString().substring(2);
                              return Text(
                                '$monthName $year',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                ),
                              );
                            case "3M":
                              // For 3M view, show month and day
                              final monthName = months[date.month - 1];
                              final day = date.day;
                              return Text(
                                '$monthName $day',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                ),
                              );
                            case "1M":
                              // For 1M view, show day only
                              final day = date.day;
                              return Text(
                                '$day',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                ),
                              );
                            case "1W":
                              // For 1W view, show day and month
                              final monthName = months[date.month - 1];
                              final day = date.day;
                              return Text(
                                '$day $monthName',
                                style: MyntWebTextStyles.caption(
                                  context,
                                  darkColor: MyntColors.textSecondaryDark,
                                  lightColor: MyntColors.textSecondary,
                                ),
                              );
                            default:
                              return const SizedBox();
                          }
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                clipData: const FlClipData.all(),
                minY: (minPrice - (maxPrice - minPrice) * 0.08) <= 0
                    ? 0
                    : minPrice - (maxPrice - minPrice) * 0.08,
                maxY: maxPrice + (maxPrice - minPrice) * 0.06,
                lineBarsData: [
                  // Main price line
                  LineChartBarData(
                    spots: priceData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.price);
                    }).toList(),
                    isCurved: true,
                    color: resolveThemeColor(context,
                        dark: MyntColors.secondaryDark,
                        light: MyntColors.secondary),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: false,
                    ),
                    belowBarData: BarAreaData(
                        show: false), // Remove blue area below chart
                  ),
                  // Event markers as vertical lines
                  ..._buildEventMarkers(
                      priceData, eventData, minPrice, maxPrice, marketWatch),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) => null).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: theme.isDarkMode
                              ? MyntColors.primaryDark
                              : MyntColors.primary,
                          strokeWidth: 1, // Thin vertical line
                          dashArray: [3, 3], // Dashed line for cleaner look
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3, // Smaller circle
                              color: resolveThemeColor(context,
                                  dark: MyntColors.secondaryDark,
                                  light: MyntColors.secondary),
                              strokeWidth: 2, // Thinner border
                              strokeColor: resolveThemeColor(context,
                                  dark: MyntColors.backgroundColorDark,
                                  light: MyntColors.backgroundColor),
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchCallback:
                      (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    // Handle hover events for web support
                    if (event is FlPointerHoverEvent ||
                        event is FlTapUpEvent ||
                        event is FlPanUpdateEvent ||
                        event is FlPanStartEvent ||
                        event is FlTapDownEvent ||
                        event is FlLongPressStart ||
                        event is FlLongPressEnd ||
                        event is FlLongPressMoveUpdate) {
                      if (touchResponse != null &&
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final spot = touchResponse.lineBarSpots!.first;
                        final index = spot.x.toInt();

                        if (index >= 0 && index < priceData.length) {
                          // Check if touch is near an event dot
                          final touchedDate = priceData[index].date;
                          final nearbyEvents = _getEventsNearDate(touchedDate);

                          touchedSpot = FlSpot(index.toDouble(), spot.y);
                          marketWatch.updateShowTooltip(true);
                          marketWatch.updateSelectedIndex(index);

                          // Update hovered event dots
                          final newHoveredDots = nearbyEvents
                              .map((e) => eventData.indexOf(e))
                              .toSet();
                          marketWatch.updateHoveredEventDots(newHoveredDots);

                          // Select the closest event if any
                          if (nearbyEvents.isNotEmpty) {
                            final eventDotIndex =
                                eventData.indexOf(nearbyEvents.first);
                            marketWatch.updateSelectedEventDot(eventDotIndex);
                          } else {
                            marketWatch.updateSelectedEventDot(null);
                          }

                          // Only set auto-hide timer for tap events, not for hover/continuous interactions
                          if (event is FlTapUpEvent ||
                              event is FlPanEndEvent ||
                              event is FlLongPressEnd) {
                            _hideTooltipTimer?.cancel();
                            _hideTooltipTimer =
                                Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                marketWatch.clearChartInteractionState();
                                touchedSpot = null;
                              }
                            });
                          } else {
                            // Cancel any existing timer during hover/continuous interaction
                            _hideTooltipTimer?.cancel();
                          }
                        }
                      }
                    } else if (event is FlPointerExitEvent) {
                      // Handle mouse exit for web - hide tooltip after short delay
                      _hideTooltipTimer?.cancel();
                      _hideTooltipTimer = Timer(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          marketWatch.clearChartInteractionState();
                          touchedSpot = null;
                        }
                      });
                    } else if (event is FlPanEndEvent ||
                        event is FlTapCancelEvent) {
                      // Handle touch end/cancel events
                      _hideTooltipTimer?.cancel();
                      _hideTooltipTimer = Timer(const Duration(seconds: 2), () {
                        if (mounted) {
                          marketWatch.clearChartInteractionState();
                          touchedSpot = null;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
          ), 
          if (marketWatch.showTooltip && touchedSpot != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: theme.isDarkMode
                        ? colors.darkColorDivider
                        : colors.colorDivider,
                  ),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Colors.black.withOpacity(0.1),
                  //     blurRadius: 4,
                  //     offset: const Offset(0, 2),
                  //   ),
                  // ],
                ),
                child: Builder(
                  builder: (context) {
                    final index = touchedSpot!.x.toInt();
                    if (index >= 0 && index < priceData.length) {
                      final data = priceData[index];
                      // Check both exact date and nearby events for tooltip
                      final exactEvents = _getEventsForDate(data.date);
                      final nearbyEvents = _getEventsNearDate(data.date);
                      final eventsForDate =
                          exactEvents.isNotEmpty ? exactEvents : nearbyEvents;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getFormattedDate(data.date),
                            style: MyntWebTextStyles.caption(
                              context,
                              darkColor: colors.textSecondaryDark,
                              lightColor: colors.textSecondaryLight,
                              fontWeight: MyntFonts.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${data.price.toStringAsFixed(2)}',
                            style: MyntWebTextStyles.bodySmall(
                              context,
                              darkColor: colors.textPrimaryDark,
                              lightColor: colors.textPrimaryLight,
                            ),
                          ),
                          // Show events if any exist for this date or nearby
                          if (eventsForDate.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...eventsForDate.map((event) {
                              final eventColor =
                                  eventColors[event.type] ?? Colors.grey;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: eventColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: eventColor.withOpacity(0.3),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: eventColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        event.type == 'Dividend'
                                            ? '${event.title} ${event.description.split(' - ')[0]}' // Show "Dividend X%"
                                            : event.title,
                                        style: MyntWebTextStyles.caption(
                                          context,
                                          lightColor: eventColor,
                                          darkColor: eventColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemesProvider theme) {
    return Center(
      child: MyntLoader.branded(
        size: MyntLoaderSize.xl,
      ),
    );
  }

  /// TC_419: 3Y / 5Y only when the stock has more than ~1 year of EOD history
  /// (a recent listing would just repeat the 1Y chart). Shorter-than-range
  /// history plots from the listing date, like Kite.
  List<String> _chartTimeframes(MarketWatchProvider marketWatch) {
    final hasLongHistory = marketWatch.eodChartData.length > 250;
    return [
      "1W",
      "1M",
      "3M",
      "1Y",
      if (hasLongHistory) ...["3Y", "5Y"],
    ];
  }

  String _getTechnicalReturnPercentage(List returnsGridview, String timeframe) {
    String durationKey = '';
    
    switch (timeframe) {
      case "1W":
        durationKey = "One Week";
        break;
      case "1M":
        durationKey = "One Month";
        break;
      case "3M":
        durationKey = "Three Month";
        break;
      case "1Y":
        durationKey = "52 Week";
        break;
      default:
        durationKey = "One Week";
    }

    // Find the matching return data from technical returns
    for (var item in returnsGridview) {
      if (item['duration'] == durationKey) {
        final percent = item['percent']?.toString() ?? '0.00';
        final percentValue = double.tryParse(percent) ?? 0.0;
        final isPositive = percentValue >= 0;
        return '${isPositive ? '+' : ''}$percent%';
      }
    }
    
    return '0.00%';
  }

  // Helper method to get return percentage for a specific timeframe (keeping for backend API - not used anymore)
  String _getReturnPercentageForTimeframe(List<Returns> returnsData, String timeframe) {
    String returnKey = '';
    
    switch (timeframe) {
      case "1W":
        returnKey = "1 week";
        break;
      case "1M":
        returnKey = "1 month";
        break;
      case "3M":
        returnKey = "3 month";
        break;
      case "1Y":
        returnKey = "1 year";
        break;
      default:
        returnKey = "1 week";
    }

    // Find the matching return data
    final returnItem = returnsData.firstWhere(
      (item) => item.type == returnKey,
      orElse: () => Returns(returns: "0.00", type: timeframe),
    );

    final percent = returnItem.returns ?? '0.00';
    final percentValue = double.tryParse(percent) ?? 0.0;
    final isPositive = percentValue >= 0;
    
    return '${isPositive ? '+' : ''}$percent%';
  }

 

  // Build returns grid display (keeping for future use)
  Widget _buildReturnsGrid(List<Returns> returnsData, ThemesProvider theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: returnsData.map<Widget>((returnItem) {
        final duration = returnItem.type ?? '';
        final percent = returnItem.returns ?? '0.00';
        final percentValue = double.tryParse(percent) ?? 0.0;
        final isPositive = percentValue >= 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive
                ? (theme.isDarkMode
                    ? colors.profitDark.withOpacity(0.1)
                    : colors.profitLight.withOpacity(0.1))
                : (theme.isDarkMode
                    ? colors.lossDark.withOpacity(0.1)
                    : colors.lossLight.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isPositive
                  ? (theme.isDarkMode ? colors.profitDark : colors.profitLight)
                  : (theme.isDarkMode ? colors.lossDark : colors.lossLight),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                duration,
                style: MyntWebTextStyles.caption(
                  context,
                  darkColor: colors.textSecondaryDark,
                  lightColor: colors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}$percent%',
                style: MyntWebTextStyles.caption(
                  context,
                  darkColor: isPositive ? MyntColors.profitDark : colors.lossDark,
                  lightColor: isPositive ? MyntColors.profit : colors.lossLight,
                  fontWeight: MyntFonts.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper method to format date for tooltip
  String _getFormattedDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final weekday = weekdays[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '$weekday, $day $month $year';
  }

  // Smart tooltip positioning based on available space
  double _getSmartTooltipPosition(double touchX, double chartWidth) {
    const tooltipWidth = 120.0; // Approximate tooltip width
    const padding = 8.0; // Minimum padding from edges

    // Calculate the desired position (touch point * 4.0 for chart scaling)
    final desiredPosition = touchX * 4.0;

    // Check if tooltip would go off the right edge
    if (desiredPosition + tooltipWidth + padding > chartWidth) {
      // Position to the left of the touch point
      return (desiredPosition - tooltipWidth)
          .clamp(padding, chartWidth - tooltipWidth - padding);
    } else {
      // Position to the right of the touch point (default)
      return desiredPosition.clamp(
          padding, chartWidth - tooltipWidth - padding);
    }
  }

  // Build event legend
  Widget _buildEventLegend(ThemesProvider theme) {
    // Get unique event types from eventData
    final uniqueEventTypes = eventData.map((e) => e.type).toSet().toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: uniqueEventTypes.map((eventType) {
          final color = eventColors[eventType] ?? Colors.grey;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                eventType,
                style: MyntWebTextStyles.body(
                  context,
                  fontWeight: MyntFonts.regular,
                  color : resolveThemeColor(
                    context,
                    dark: colors.textPrimaryDark,
                    light: colors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Get events for a specific date
  List<EventData> _getEventsForDate(DateTime date) {
    return eventData.where((event) {
      return event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day;
    }).toList();
  }

  // Get events near a specific date (within 3 days for better touch interaction)
  List<EventData> _getEventsNearDate(DateTime date) {
    return eventData.where((event) {
      final daysDifference = event.date.difference(date).inDays.abs();
      return daysDifference <= 3; // Consider events within 3 days as "nearby"
    }).toList();
  }

  // Build holdings pie chart
  Widget _buildHoldingsPieChart(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    // Get the latest data (Jun 25) from shareholdings
    final shareholdingsData = marketWatch.fundamentalData?.shareholdings;
    if (shareholdingsData == null || shareholdingsData.isEmpty) {
      return Center(
        child: Text(
          'No holdings data available',
          style: MyntWebTextStyles.para(
            context,
            darkColor: colors.textSecondaryDark,
            lightColor: colors.textSecondaryLight,
          ),
        ),
      );
    }

    // Find the latest data (Jun 25)
    final latestData = _getLatestHoldingsData(shareholdingsData);
    if (latestData == null) {
      return Center(
        child: Text(
          'No latest holdings data available',
          style: MyntWebTextStyles.para(
            context,
            darkColor: colors.textSecondaryDark,
            lightColor: colors.textSecondaryLight,
          ),
        ),
      );
    }

    // Prepare chart data
    final chartData = _prepareShareholdersChartData(latestData);

    final totalSum = chartData.fold(0.0, (sum, item) => sum + item.value);
    final touched = (_touchedHoldingIndex >= 0 &&
            _touchedHoldingIndex < chartData.length)
        ? chartData[_touchedHoldingIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          height: 240,
          width: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
          PieChart(
            PieChartData(
              // Hover a slice: it grows and its name + % show in the centre
              // (Zerodha-style).
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = (!event.isInterestedForInteractions ||
                          response?.touchedSection == null)
                      ? -1
                      : response!.touchedSection!.touchedSectionIndex;
                  if (index != _touchedHoldingIndex) {
                    setState(() => _touchedHoldingIndex = index);
                  }
                },
              ),
              sections: chartData.asMap().entries.map((entry) {
                final data = entry.value;
                final isTouched = entry.key == _touchedHoldingIndex;
                final percentage = (data.value / totalSum * 100);

                return PieChartSectionData(
                  value: data.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  color: data.color,
                  radius: isTouched ? 78 : 70,
                  titleStyle: MyntWebTextStyles.para(
                    context,
                    color: theme.isDarkMode
                        ? MyntColors.textPrimaryDark
                        : MyntColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ).copyWith(
                    fontSize: 13,
                  ),
                  titlePositionPercentageOffset: 1.3,
                  badgeWidget: null,
                );
              }).toList(),
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
          if (touched != null)
            IgnorePointer(
              child: SizedBox(
                width: 92,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      touched.category,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MyntWebTextStyles.para(
                        context,
                        darkColor: MyntColors.textSecondaryDark,
                        lightColor: MyntColors.textSecondary,
                        fontWeight: MyntFonts.medium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(touched.value / totalSum * 100).toStringAsFixed(1)}%',
                      style: MyntWebTextStyles.body(
                        context,
                        color: resolveThemeColor(context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary),
                        fontWeight: MyntFonts.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // Get the latest holdings data (Jun 25)
  Shareholdings? _getLatestHoldingsData(List<Shareholdings> data) {
    // Sort data to get the latest entry
    final sortedData = List<Shareholdings>.from(data);
    sortedData.sort((a, b) {
      final orderMap = {
        'Jun 24': 1,
        'Sep 24': 2,
        'Dec 24': 3,
        'Mar 25': 4,
        'Jun 25': 5,
      };
      final aOrder = orderMap[a.convDate] ?? 0;
      final bOrder = orderMap[b.convDate] ?? 0;
      return bOrder.compareTo(aOrder); // Descending order to get latest first
    });

    return sortedData.isNotEmpty ? sortedData.first : null;
  }

  // Prepare shareholders chart data from Shareholdings
  List<_ShareholderChartData> _prepareShareholdersChartData(Shareholdings data) {
    final holdingsData = [
      {
        'name': 'Foreign Institution', // was 'Institutions'
        'value': double.tryParse(data.fiiFpi ?? '0') ?? 0.0,
        'color': const Color(0xFF2563EB), // Modern Blue
      },
      {
        'name': 'Mutual Funds', // was 'Corporation'
        'value': double.tryParse(data.mutualFunds ?? '0') ?? 0.0,
        'color': const Color(0xFFDC2626), // Modern Red
      },
      {
        'name': 'Other Domestic Institution', // was 'Holding Company'
        'value': double.tryParse(data.dii ?? '0') ?? 0.0,
        'color': const Color(0xFF059669), // Modern Green
      },
      {
        'name': 'Promoter Holding', // was 'Insiders'
        'value': double.tryParse(data.promoters ?? '0') ?? 0.0,
        'color': const Color(0xFF7C3AED), // Modern Purple
      },
      {
        'name': 'Retail and Others', // was 'Others'
        'value': double.tryParse(data.retailAndOthers ?? '0') ?? 0.0,
        'color': const Color(0xFFEA580C), // Modern Orange
      },
    ];

    // Filter out zero values
    final filteredData =
        holdingsData.where((item) => item['value'] as double > 0).toList();

    return filteredData.map((item) {
      return _ShareholderChartData(
        category: item['name'] as String,
        value: item['value'] as double,
        color: item['color'] as Color,
      );
    }).toList();
  }

  // Build legend for the pie chart

  // Build holdings table
  Widget _buildHoldingsTable(
      MarketWatchProvider marketWatch, ThemesProvider theme) {
    final shareholdingsData = marketWatch.fundamentalData?.shareholdings;
    if (shareholdingsData == null || shareholdingsData.isEmpty) {
      return Center(
        child: Text(
          'No holdings data available',
          style: MyntWebTextStyles.para(
            context,
            darkColor: colors.textSecondaryDark,
            lightColor: colors.textSecondaryLight,
          ),
        ),
      );
    }

    // Sort data by date (oldest first)
    final sortedData = List<Shareholdings>.from(shareholdingsData);
    sortedData.sort((a, b) {
      final orderMap = {
        'Jun 24': 1,
        'Sep 24': 2,
        'Dec 24': 3,
        'Mar 25': 4,
        'Jun 25': 5,
      };
      final aOrder = orderMap[a.convDate] ?? 0;
      final bOrder = orderMap[b.convDate] ?? 0;
      return aOrder.compareTo(bOrder); // Ascending order to get oldest first
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoldingsTable(
          data: sortedData,
          themes: theme,
        ),
      ],
    );
  }
}

// Holdings Table Widget
class HoldingsTable extends StatelessWidget {
  final List<Shareholdings> data;
  final ThemesProvider themes;

  const HoldingsTable({
    super.key,
    required this.data,
    required this.themes,
  });

  String _formatValue(String? value) {
    if (value == null || value.isEmpty) return "0.0";
    try {
      double numValue = double.parse(value);
      return numValue.toStringAsFixed(1);
    } catch (e) {
      return value;
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "";
    return date; // Keep original format like "Jun 25"
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with years
          _buildHeaderRow(context),
          // Data rows with colored circles
          ..._buildMetricRows(context, data),
          // Legend below table
          _buildLegend(context),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      child: Row(
        children: [
          // Empty space for the metric name column
          const Expanded(
            flex: 2,
            child: SizedBox(),
          ),
          // Year headers
          ...data
              .map((item) => Expanded(
                    child: Text(
                      _formatDate(item.convDate),
                      textAlign: TextAlign.right,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.semiBold,
                        color : resolveThemeColor(
                          context,
                          dark: colors.textSecondaryDark,
                          light: colors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ))
              ,
        ],
      ),
    );
  }

  List<Widget> _buildMetricRows(BuildContext context, List<Shareholdings> sortedData) {
    final metrics = [
      {
        "name": "Promoter Holding",
        "getValue": (item) => item.promoters,
        "color": const Color(0xFF7C3AED)
      }, // Modern Purple
      {
        "name": "Foreign Institution",
        "getValue": (item) => item.fiiFpi,
        "color": const Color(0xFF2563EB)
      }, // Modern Blue
      {
        "name": "Other Domestic Institution",
        "getValue": (item) => item.dii,
        "color": const Color(0xFF059669)
      }, // Modern Green
      {
        "name": "Retail and Others",
        "getValue": (item) => item.retailAndOthers,
        "color": const Color(0xFFEA580C)
      }, // Modern Orange
      {
        "name": "Mutual Funds",
        "getValue": (item) => item.mutualFunds,
        "color": const Color(0xFFDC2626)
      }, // Modern Red
    ];

    return metrics
        .map((metric) => Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              child: Row(
                children: [
                  // Metric name
                  Expanded(
                    flex: 2,
                    child: Text(
                      metric["name"] as String,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.regular,
                        color : resolveThemeColor(
                          context,
                          dark: colors.textPrimaryDark,
                          light: colors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ),
                  // Data values
                  ...sortedData
                      .map((item) => Expanded(
                            child: Text(
                              _formatValue(
                                  (metric["getValue"] as Function)(item)),
                              textAlign: TextAlign.right,
                              style: MyntWebTextStyles.body(
                                context,
                                fontWeight: MyntFonts.regular,
                                color : resolveThemeColor(
                                  context,
                                  dark: colors.textPrimaryDark,
                                  light: colors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ))
                      ,
                ],
              ),
            ))
        .toList();
  }

  Widget _buildLegend(BuildContext context) {
    final legendItems = [
      {"name": "Promoter Holding", "color": const Color(0xFF7C3AED)}, // Modern Purple
      {
        "name": "Foreign Institution",
        "color": const Color(0xFF2563EB)
      }, // Modern Blue
      {
        "name": "Other Domestic Institution",
        "color": const Color(0xFF059669)
      }, // Modern Green
      {"name": "Retail and Others", "color": const Color(0xFFEA580C)}, // Modern Orange
      {
        "name": "Mutual Funds",
        "color": const Color(0xFFDC2626)
      }, // Modern Red
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: legendItems
            .map((item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item["color"] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item["name"] as String,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight: MyntFonts.regular,
                        color : resolveThemeColor(
                          context,
                          dark: colors.textPrimaryDark,
                          light: colors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

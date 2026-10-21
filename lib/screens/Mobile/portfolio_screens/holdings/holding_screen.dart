import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../utils/custom_navigator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/sharedWidget/no_data_found.dart';
// import 'package:remove_emoji_input_formatter/remove_emoji_input_formatter.dart';
import '../../../../provider/fund_provider.dart';
import '../../../../provider/index_list_provider.dart';
import '../../../../provider/ledger_provider.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/global_state_text.dart';
import '../../../../res/res.dart';
import '../../../../routes/route_names.dart';
import '../../../../sharedWidget/custom_text_form_field.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/functions.dart';
import '../../../../utils/no_emoji_inputformatter.dart';
import 'filter_scrip_bottom_sheet.dart';

import 'holding_detail_screen.dart';
import 'holdings_list.dart';

class HoldingScreen extends ConsumerStatefulWidget {
  const HoldingScreen({super.key});

  @override
  ConsumerState<HoldingScreen> createState() => _HoldingScreenState();
}

class _HoldingScreenState extends ConsumerState<HoldingScreen> with TickerProviderStateMixin {
  StreamSubscription? _socketSubscription;

  // Cached values to avoid recalculations
  double _totalPnlHolding = 0.0;
  double _oneDayChng = 0.0;
  double _invest = 0.0;
  double _totalCurrentVal = 0.0;
  double _oneDayChngPer = 0.0;
  String _totPnlPercHolding = "0.00";

  // Flag to track if initialization happened
  bool _isInitialized = false;

  // Map to track which tokens have been updated
  final Map<String, bool> _updatedTokens = {};

  // Last update time for throttling
  DateTime _lastSocketUpdateTime = DateTime.now();
  static const Duration _minUpdateInterval = Duration(milliseconds: 200);

  // Cached widgets to prevent rebuilds
  Widget? _cachedActionButtons;
  Widget? _cachedEmptyState;

  // Added for memoization in _buildSummarySection
  String? _cachedSummaryKey;
  Widget? _cachedSummarySection;

  // Added for action buttons memoization
  String? _cachedActionButtonsKey;

  // Static divider containers (one for dark, one for light theme)
  Widget? _cachedDarkDivider;
  Widget? _cachedLightDivider;

  // Scroll controller and animation controller for scroll-based animations
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isScrollingUp = false;

  @override
  void initState() {
    super.initState();
    _holdSearchCtrl = ref.read(portfolioProvider).holdingSearchCtrl;
    _lastHoldSearchText = _holdSearchCtrl.text;
    _holdSearchCtrl.addListener(_onHoldSearchTextChanged);
    
    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize fade animation
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    ref.read(portfolioProvider).holdingsTabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    // Delay initialization to avoid setState during build
    // Use a longer delay to ensure we batch multiple initialization steps
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // FocusScope.of(context).unfocus();
        _calculateInitialValues();
        _setupSocketSubscription();
      }
    });
  }
  
  // Scroll listener to detect scroll direction and animate
  void _onScroll() {
    final currentOffset = _scrollController.offset;
    // Scrolling up means offset is increasing (user scrolling up, content moves up)
    // Scrolling down means offset is decreasing (user scrolling down, content moves down)
    // Keep Total PNL card visible when scrolled past initial position, never hide when scrolling down
    bool shouldShowTotalPnlCard = false;
    
    if (currentOffset > 10) {
      // Once scrolled past initial position, always show Total PNL card
      // It stays visible whether scrolling up or down
      shouldShowTotalPnlCard = true;
    } else {
      // At top (offset <= 10), show normal stats (hide Total PNL card)
      shouldShowTotalPnlCard = false;
    }
    
    if (shouldShowTotalPnlCard != _isScrollingUp) {
      _isScrollingUp = shouldShowTotalPnlCard;
      if (_isScrollingUp) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      // Trigger rebuild to show/hide Total PNL card and summary section
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for theme changes here instead of in build
    ref.listenManual(themeProvider, (previous, next) {
      if (previous?.isDarkMode != next.isDarkMode) {
        // Theme changed, clear caches
        if (mounted) {
          setState(() {
            _cachedSummarySection = null;
            _cachedActionButtons = null;
            _cachedEmptyState = null;
            _cachedActionButtonsKey = null;
            _cachedSummaryKey = null;
            // Clear static dividers
            _cachedDarkDivider = null;
            _cachedLightDivider = null;
          });
        }
      }
    });
  }

  // The search field's X button only empties the text box; it never calls
  // onClear. Run the clear here when the box goes from text to empty.
  late final TextEditingController _holdSearchCtrl;
  String _lastHoldSearchText = '';

  void _onHoldSearchTextChanged() {
    final text = _holdSearchCtrl.text;
    final wasNotEmpty = _lastHoldSearchText.isNotEmpty;
    _lastHoldSearchText = text;
    if (text.isEmpty && wasNotEmpty) {
      _resetHoldSearch();
    }
  }

  void _resetHoldSearch() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final holdingProvider = ref.read(portfolioProvider);
      holdingProvider.clearHoldSearch();
      if (holdingProvider.holdingSearchCtrl.text.isEmpty) {
        holdingProvider.showHoldSearch(false);
      }
      // Clear cached widgets when search is cleared
      setState(() {
        _cachedSummarySection = null;
        _cachedActionButtons = null;
        _cachedEmptyState = null;
        _cachedActionButtonsKey = null;
        _cachedSummaryKey = null;
      });
    });
  }

  @override
  void dispose() {
    _holdSearchCtrl.removeListener(_onHoldSearchTextChanged);
    _socketSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _setupSocketSubscription() {
    final socketProvider = ref.read(websocketProvider);

    // Use debounce to reduce update frequency
    _socketSubscription = socketProvider.socketDataStream.listen((socketDatas) {
      if (socketDatas.isEmpty) return;

      // Throttle updates more aggressively to reduce unnecessary rebuilds
      final now = DateTime.now();
      if (now.difference(_lastSocketUpdateTime) < _minUpdateInterval) {
        return; // Skip this update if it's too soon after the last one
      }

      _lastSocketUpdateTime = now;

      // Process updates in a microtask to batch them together
      Future.microtask(() {
        _updateHoldingsData(socketDatas);
      });
    });
  }

  // Update holdings data with socket updates - optimized version
  void _updateHoldingsData(Map socketDatas) {
    final holdingProvider = ref.read(portfolioProvider);
    final holdings = holdingProvider.holdingsModel!;

    if (holdings.isEmpty) return;

    bool hasUpdates = false;
    bool summaryUpdated = false;

    // Reset summary values only if we detect actual updates
    double newTotalPnl = 0.0;
    double newOneDayChng = 0.0;
    double newInvest = 0.0;
    double newTotalCurrentVal = 0.0;

    // Reset updated tokens tracking for this update cycle
    _updatedTokens.clear();

    // Record previous values to detect actual changes
    final double previousTotalPnl = _totalPnlHolding;
    final double previousOneDayChng = _oneDayChng;
    final double previousInvest = _invest;
    final double previousTotalCurrentVal = _totalCurrentVal;

    for (var holding in holdings) {
      if (holding.exchTsym == null || holding.exchTsym!.isEmpty) continue;

      var exchTsym = holding.exchTsym![0];
      if (exchTsym.token == null) continue;

      if (socketDatas.containsKey(exchTsym.token)) {
        final socketData = socketDatas[exchTsym.token];

        // Skip if socketData is empty (heartbeat) or null
        if (socketData == null || socketData.isEmpty) continue;

        // Cache current values for comparison
        final String currentLp = exchTsym.lp ?? "0.00";
        final String currentPerChange = exchTsym.perChange ?? "0.00";
        final String currentClose = exchTsym.close ?? "0.00";
        final String currentValue = holding.currentValue ?? "0.00";

        bool tokenUpdated = false;

        // Only update with non-zero values, otherwise keep existing values
        final lp = socketData['lp']?.toString();
        if (lp != null &&
            lp != "null" &&
            lp != "0" &&
            lp != "0.0" &&
            lp != "0.00" &&
            lp != currentLp) {
          exchTsym.lp = lp;
          tokenUpdated = true;
        }

        final pc = socketData['pc']?.toString();
        if (pc != null &&
            pc != "null" &&
            pc != "0" &&
            pc != "0.0" &&
            pc != "0.00" &&
            pc != currentPerChange) {
          exchTsym.perChange = pc;
          tokenUpdated = true;
        }

        final c = socketData['c']?.toString();
        if (c != null &&
            c != "null" &&
            c != "0" &&
            c != "0.0" &&
            c != "0.00" &&
            c != currentClose) {
          exchTsym.close = c;
          tokenUpdated = true;
        }

        // Track if this token was updated
        if (tokenUpdated) {
          _updatedTokens[exchTsym.token!] = true;
          hasUpdates = true;
        }

        // Only calculate currentValue if we have valid lp AND it changed
        final lpValue = double.tryParse(exchTsym.lp ?? "0.00") ?? 0.0;
        if (lpValue > 0 && (tokenUpdated || !_isInitialized)) {
          // Include npoadt1qty (Non-POA T1 holdings) in financial calculations
          final int t1Qty = int.parse(holding.npoadt1qty ?? "0");
          final int totalQty = (holding.currentQty ?? 0) + t1Qty;
          final newCurrentValue =
              (totalQty * lpValue)
                  .toStringAsFixed(2);

          // Only update if actually changed
          if (newCurrentValue != currentValue) {
            holding.currentValue = newCurrentValue;
            tokenUpdated = true;

            // Use the close value for avgCost only if it's valid
            final closeValue = double.tryParse(exchTsym.close ?? "0.00") ?? 0.0;
            double avgCost = double.parse(
                "${holding.upldprc == "0.00" ? (closeValue > 0 ? closeValue.toString() : "0.00") : holding.upldprc ?? 0.00}");

            if (avgCost > 0) {
              holding.invested =
                  (totalQty * avgCost).toStringAsFixed(2);
            }

            if (totalQty == 0) {
              double sellAmt = double.parse(holding.sellAmt ?? "0.00");
              int usedQty = int.parse(holding.usedqty ?? "0");
              double price = usedQty > 0 ? (sellAmt / usedQty) : 0.0;
              double pnl = price - double.parse(holding.upldprc ?? "0.0");

              exchTsym.profitNloss = (pnl * usedQty).toStringAsFixed(2);
            } else {
              exchTsym.profitNloss =
                  (double.parse(holding.currentValue ?? "0.00") -
                          double.parse(holding.invested ?? "0.00"))
                      .toStringAsFixed(2);
            }

            exchTsym.pNlChng = holding.invested == "0.00"
                ? "0.00"
                : ((double.parse("${exchTsym.profitNloss ?? 0.0}") /
                            double.parse("${holding.invested ?? 0.0}")) *
                        100)
                    .toStringAsFixed(2);

            // Calculate 1D change only if close price is not 0
            if (double.parse(exchTsym.close ?? "0.00") > 0) {
              exchTsym.oneDayChg = ((double.parse(exchTsym.lp ?? "0.00") -
                          double.parse(exchTsym.close ?? "0.00")) *
                      totalQty)
                  .toStringAsFixed(2);
            } else {
              // Skip calculation if close price is 0
              exchTsym.oneDayChg = "0.00";
              }
          }
        }
      }

      // Accumulate summary values
      newTotalPnl += double.parse("${exchTsym.profitNloss ?? 0.0}");
      newOneDayChng += double.parse("${exchTsym.oneDayChg ?? 0.0}");
      newInvest += double.parse("${holding.invested ?? 0.0}");
      newTotalCurrentVal += double.parse("${holding.currentValue ?? 0.0}");
    }

    // Only update summary values if they've changed significantly
    // Using small threshold to avoid rounding issues causing unnecessary updates
    const double threshold = 0.01;
    if (!_isInitialized ||
        (previousTotalPnl - newTotalPnl).abs() > threshold ||
        (previousOneDayChng - newOneDayChng).abs() > threshold ||
        (previousInvest - newInvest).abs() > threshold ||
        (previousTotalCurrentVal - newTotalCurrentVal).abs() > threshold) {
      _totalPnlHolding = newTotalPnl;
      _oneDayChng = newOneDayChng;
      _invest = newInvest;
      _totalCurrentVal = newTotalCurrentVal;

      // Calculate summary percentages
      _oneDayChngPer =
          _totalCurrentVal > 0 ? (_oneDayChng / _totalCurrentVal) * 100 : 0.0;
      _totPnlPercHolding = _invest > 0
          ? ((_totalPnlHolding / _invest) * 100).toStringAsFixed(2)
          : "0.00";

      summaryUpdated = true;
    }

    // Only rebuild if we have actual updates and are mounted
    if ((hasUpdates || summaryUpdated) && mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // Calculate initial values from provider data
  void _calculateInitialValues() {
    if (_isInitialized) return; // Prevent duplicate initialization

    final websocket = ref.read(websocketProvider);

    // Process initial socket data
    if (websocket.socketDatas.isNotEmpty) {
      _processInitialData(websocket.socketDatas);
    } else {
      // If no socket data yet, just mark as initialized
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // Process initial data without triggering setState during build
  void _processInitialData(Map socketDatas) {
    final holdingProvider = ref.read(portfolioProvider);
    final holdings = holdingProvider.holdingsModel!;

    if (holdings.isEmpty) return;

    // Reset summary values
    _totalPnlHolding = 0.0;
    _oneDayChng = 0.0;
    _invest = 0.0;
    _totalCurrentVal = 0.0;

    for (var holding in holdings) {
      if (holding.exchTsym == null || holding.exchTsym!.isEmpty) continue;

      var exchTsym = holding.exchTsym![0];
      if (socketDatas.containsKey(exchTsym.token)) {
        final socketData = socketDatas[exchTsym.token];

        // Skip if socketData is empty (heartbeat) or null
        if (socketData == null || socketData.isEmpty) continue;

        // Update with non-zero values if needed
        final lp = socketData['lp']?.toString();
        if (lp != null &&
            lp != "null" &&
            lp != "0" &&
            lp != "0.0" &&
            lp != "0.00") {
          exchTsym.lp = lp;
        }

        // Update other values as needed
        final pc = socketData['pc']?.toString();
        if (pc != null &&
            pc != "null" &&
            pc != "0" &&
            pc != "0.0" &&
            pc != "0.00") {
          exchTsym.perChange = pc;
        }

        final c = socketData['c']?.toString();
        if (c != null && c != "null" && c != "0" && c != "0.0" && c != "0.00") {
          exchTsym.close = c;
        }

        // Calculate current values
        final lpValue = double.tryParse(exchTsym.lp ?? "0.00") ?? 0.0;
        if (lpValue > 0) {
          // Include npoadt1qty (Non-POA T1 holdings) in financial calculations
          final int t1Qty = int.parse(holding.npoadt1qty ?? "0");
          final int totalQty = (holding.currentQty ?? 0) + t1Qty;
          holding.currentValue =
              (totalQty * lpValue)
                  .toStringAsFixed(2);

          // Use the close value for avgCost only if it's valid
          final closeValue = double.tryParse(exchTsym.close ?? "0.00") ?? 0.0;
          double avgCost = double.parse(
              "${holding.upldprc == "0.00" ? (closeValue > 0 ? closeValue.toString() : "0.00") : holding.upldprc ?? 0.00}");

          if (avgCost > 0) {
            holding.invested =
                (totalQty * avgCost).toStringAsFixed(2);
          }

          if (totalQty == 0) {
            double sellAmt = double.parse(holding.sellAmt ?? "0.00");
            int usedQty = int.parse(holding.usedqty ?? "0");
            double price = usedQty > 0 ? (sellAmt / usedQty) : 0.0;
            double pnl = price - double.parse(holding.upldprc ?? "0.0");

            exchTsym.profitNloss = (pnl * usedQty).toStringAsFixed(2);
          } else {
            exchTsym.profitNloss =
                (double.parse(holding.currentValue ?? "0.00") -
                        double.parse(holding.invested ?? "0.00"))
                    .toStringAsFixed(2);
          }

          exchTsym.pNlChng = holding.invested == "0.00"
              ? "0.00"
              : ((double.parse("${exchTsym.profitNloss ?? 0.0}") /
                          double.parse("${holding.invested ?? 0.0}")) *
                      100)
                  .toStringAsFixed(2);

          // Calculate 1D change only if close price is not 0
          if (double.parse(exchTsym.close ?? "0.00") > 0) {
            exchTsym.oneDayChg = ((double.parse(exchTsym.lp ?? "0.00") -
                        double.parse(exchTsym.close ?? "0.00")) *
                    totalQty)
                .toStringAsFixed(2);
          } else {
            // Skip calculation if close price is 0
            exchTsym.oneDayChg = "0.00";
            }
        }
      }

      // Accumulate summary values
      _totalPnlHolding += double.parse("${exchTsym.profitNloss ?? 0.0}");
      _oneDayChng += double.parse("${exchTsym.oneDayChg ?? 0.0}");
      _invest += double.parse("${holding.invested ?? 0.0}");
      _totalCurrentVal += double.parse("${holding.currentValue ?? 0.0}");
    }

    // Calculate summary percentages
    _oneDayChngPer =
        _totalCurrentVal > 0 ? (_oneDayChng / _totalCurrentVal) * 100 : 0.0;
    _totPnlPercHolding = _invest > 0
        ? ((_totalPnlHolding / _invest) * 100).toStringAsFixed(2)
        : "0.00";

    // Mark as initialized and update UI safely
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read providers only once for static data
    final holdingProvider = ref.read(portfolioProvider);

    // Use a focused Consumer only for the loading status
    return Consumer(builder: (context, watch, _) {
      final isLoading = ref.watch(portfolioProvider).holdloader;

      if (isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      

      if (holdingProvider.holdingsModel!.isEmpty) {
        return ListView(
          children: [
            Center(child:NoDataFound(
                              title: "No Holdings Found",
                              subtitle: "There's nothing here yet. Buy some stocks to see them here.",
                              primaryEnabled: false,
                              onSecondary: () {
                                ref.read(indexListProvider).bottomMenu(1, context);
                              },
                            )),
          ],
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          // Unfocus keyboard when refreshing
          // FocusScope.of(context).unfocus();

          // Clear all cached widgets when manually refreshing
          setState(() {
            _cachedSummarySection = null;
            _cachedActionButtons = null;
            _cachedEmptyState = null;
            _cachedActionButtonsKey = null;
            _cachedSummaryKey = null;
            _updatedTokens.clear();
          });

          // Fetch fresh data
          await ref.read(portfolioProvider).fetchHoldings(context, "Refresh");

          // Recalculate all summaries with the new data
          _calculateSummaryValues();
        },
        child: Stack(
          children: [
            // Scrollable content
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 0 
                            ? constraints.maxHeight + 1 
                            : double.infinity,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Summary section with all stats (original UI) - hide when scrolling up
                          if (!_isScrollingUp && holdingProvider.holdingsModel!.isNotEmpty)
                            _buildSummarySection(),

                          // Action buttons section - using cached buttons when possible
                          holdingProvider.holdingsModel!.isEmpty
                              ? const SizedBox.shrink()
                              : _getActionButtons(),
                          _buildSearchBar(),
                          // Search bar (conditional)

                          // Holdings list with selective rebuilding
                          _buildHoldingsList(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Fixed Total PNL card overlaying the content - show until search bar becomes visible
            if (_isScrollingUp && holdingProvider.holdingsModel!.isNotEmpty)
              Positioned(
                top: -1,
                left: 0,
                right: 0,
                child: _buildTotalPnlCard(),
              ),
          ],
        ),
      );
    });
  }

  // Method to calculate summary values from holdings data
  void _calculateSummaryValues() {
    final holdingProvider = ref.read(portfolioProvider);
    final holdings = holdingProvider.holdingsModel!;

    if (holdings.isEmpty) {
      _totalPnlHolding = 0.0;
      _oneDayChng = 0.0;
      _invest = 0.0;
      _totalCurrentVal = 0.0;
      _oneDayChngPer = 0.0;
      _totPnlPercHolding = "0.00";
      return;
    }

    double newTotalPnl = 0.0;
    double newOneDayChng = 0.0;
    double newInvest = 0.0;
    double newTotalCurrentVal = 0.0;

    for (var holding in holdings) {
      if (holding.exchTsym == null || holding.exchTsym!.isEmpty) continue;
      var exchTsym = holding.exchTsym![0];

      // Accumulate summary values
      newTotalPnl += double.parse("${exchTsym.profitNloss ?? 0.0}") +
          double.parse("${holding.rpnl ?? 0.0}");
      newOneDayChng += double.parse("${exchTsym.oneDayChg ?? 0.0}");
      newInvest += double.parse("${holding.invested ?? 0.0}");
      newTotalCurrentVal += double.parse("${holding.currentValue ?? 0.0}");
    }

    _totalPnlHolding = newTotalPnl;
    _oneDayChng = newOneDayChng;
    _invest = newInvest;
    _totalCurrentVal = newTotalCurrentVal;

    // Calculate summary percentages
    _oneDayChngPer =
        _totalCurrentVal > 0 ? (_oneDayChng / _totalCurrentVal) * 100 : 0.0;
    _totPnlPercHolding = _invest > 0
        ? ((_totalPnlHolding / _invest) * 100).toStringAsFixed(2)
        : "0.00";

    // Reset summary section cache so it will be rebuilt
    _cachedSummarySection = null;
  }

  // Total PNL card - fixed at the top
  Widget _buildTotalPnlCard() {
    final theme = ref.read(themeProvider);

    return Consumer(builder: (context, watch, _) {
      // Watch holdings data to rebuild when it changes
      ref.watch(portfolioProvider);
      
      // Recalculate summary values when provider updates
      _calculateSummaryValues();

      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Translucent background to give glassy feel (same as watchlist)
              color: theme.isDarkMode
                  ? colors.colorBlack
                  : colors.colorWhite,
              // Subtle gradient to enhance the frosted look (same as watchlist)
              // gradient: LinearGradient(
              //   begin: Alignment.topLeft,
              //   end: Alignment.bottomRight,
              //   colors: [
              //     theme.isDarkMode
              //         ? Colors.white.withOpacity(0.02)
              //         : Colors.white.withOpacity(0.06),
              //     theme.isDarkMode
              //         ? Colors.white.withOpacity(0.01)
              //         : Colors.white.withOpacity(0.03),
              //   ],
              // ),
              // Keep the bottom border as before (same as watchlist)
              border: Border(
                bottom: BorderSide(
                  color: theme.isDarkMode ? colors.dividerDark : colors.dividerLight,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total PNL label on the left
                TextWidget.subText(
                  text: "Total PNL",
                  theme: false,
                  color: theme.isDarkMode
                      ? colors.textSecondaryDark
                      : colors.textSecondaryLight,
                  fw: 0,
                ),
                // Total PNL value on the right with animation
                Opacity(
                  opacity: 1.0 - _fadeAnimation.value * 0.3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextWidget.subText(
                        text:
                            "(${_totPnlPercHolding == "NaN" ? 0.00 : _totPnlPercHolding}%)",
                        theme: false,
                        color: _totPnlPercHolding.startsWith("-")
                            ? theme.isDarkMode
                                ? colors.lossDark
                                : colors.lossLight
                            : theme.isDarkMode
                                ? colors.profitDark
                                : colors.profitLight,
                        fw: 0,
                      ),
                      const SizedBox(width: 4),
                      TextWidget.headText(
                        text:
                            getFormatter(value: _totalPnlHolding, v4d: false, noDecimal: false),
                        theme: false,
                        color: _totalPnlHolding.toString().startsWith("-")
                            ? theme.isDarkMode
                                ? colors.lossDark
                                : colors.lossLight
                            : theme.isDarkMode
                                ? colors.profitDark
                                : colors.profitLight,
                        fw: 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // Summary section with investment and P&L information (original UI with Total P&L)
  Widget _buildSummarySection() {
    final theme = ref.read(themeProvider);

    // Add a Consumer to force rebuilds when holdings data changes
    return Consumer(builder: (context, watch, _) {
      // Watch holdings data but don't use it directly
      // This ensures the section rebuilds when API data updates
      ref.watch(portfolioProvider);

      // Recalculate summary values when provider updates
      _calculateSummaryValues();

      // Create a memoized version that only updates when the key data changes
      final memoKey =
          '${_totalPnlHolding.toStringAsFixed(2)}-${_oneDayChng.toStringAsFixed(2)}-' '${_invest.toStringAsFixed(2)}-${_totalCurrentVal.toStringAsFixed(2)}';

      // Add this field to the class to store the cached summary section
      if (_cachedSummarySection != null && _cachedSummaryKey == memoKey) {
        return _cachedSummarySection!;
      }

      // Wrap in RepaintBoundary to isolate painting
      _cachedSummaryKey = memoKey;
      _cachedSummarySection = RepaintBoundary(
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Padding(
              padding: const EdgeInsets.only(top: 0, left: 16, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget.subText(
                                text: "1D Change",
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                fw: 0),
                            const SizedBox(height: 4),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TextWidget.subText(
                                      text:
                                          getFormatter(value: _oneDayChng, v4d: false, noDecimal: false),
                                      theme: false,
                                      color: _oneDayChng
                                              .toStringAsFixed(2)
                                              .startsWith("-")
                                          ? theme.isDarkMode
                                              ? colors.lossDark
                                              : colors.lossLight
                                          : theme.isDarkMode
                                              ? colors.profitDark
                                              : colors.profitLight,
                                      fw: 0),
                                  const SizedBox(width: 4),
                                  TextWidget.subText(
                                      text:
                                          " (${_oneDayChngPer.isNaN ? "0.00" : _oneDayChngPer.toStringAsFixed(2)}%)",
                                      theme: false,
                                      color: _oneDayChngPer
                                              .toStringAsFixed(2)
                                              .startsWith("-")
                                          ? theme.isDarkMode
                                              ? colors.lossDark
                                              : colors.lossLight
                                          : theme.isDarkMode
                                              ? colors.profitDark
                                              : colors.profitLight,
                                      fw: 0),
                                ])
                          ]),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextWidget.subText(
                              text: "Total P&L",
                              theme: false,
                              color: theme.isDarkMode
                                  ? colors.textSecondaryDark
                                  : colors.textSecondaryLight,
                              fw: 0),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextWidget.subText(
                                  text:
                                      "(${_totPnlPercHolding == "NaN" ? 0.00 : _totPnlPercHolding}%)",
                                  theme: false,
                                  color: _totPnlPercHolding.startsWith("-")
                                      ? theme.isDarkMode
                                          ? colors.lossDark
                                          : colors.lossLight
                                      : theme.isDarkMode
                                          ? colors.profitDark
                                          : colors.profitLight,
                                  fw: 0),
                              const SizedBox(width: 4),
                              TextWidget.headText(
                                  text:
                                      getFormatter(value: _totalPnlHolding, v4d: false, noDecimal: false),
                                  theme: false,
                                  color: _totalPnlHolding
                                          .toString()
                                          .startsWith("-")
                                      ? theme.isDarkMode
                                          ? colors.lossDark
                                          : colors.lossLight
                                      : theme.isDarkMode
                                          ? colors.profitDark
                                          : colors.profitLight,
                                  fw: 0),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget.subText(
                                text: "Invested",
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                fw: 0),
                            const SizedBox(height: 4),
                            TextWidget.subText(
                                text:
                                    getFormatter(value: _invest, v4d: false, noDecimal: false),
                                theme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? colors.textPrimaryDark
                                    : colors.textPrimaryLight,
                                fw: 0),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextWidget.subText(
                                text: "Current",
                                theme: false,
                                color: theme.isDarkMode
                                    ? colors.textSecondaryDark
                                    : colors.textSecondaryLight,
                                fw: 0),
                            const SizedBox(height: 4),
                            TextWidget.subText(
                                text:
                                    getFormatter(value: _totalCurrentVal, v4d: false, noDecimal: false),
                                theme: theme.isDarkMode,
                                color: theme.isDarkMode
                                    ? colors.textPrimaryDark
                                    : colors.textPrimaryLight,
                                fw: 0),
                          ],
                        ),
                      ]),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // Divider(
            //   color: colors.colorDivider,
            // ),
          ],
        ),
      ));

      return _cachedSummarySection!;
    });
  }

  // Get cached action buttons or create new ones
  Widget _getActionButtons() {
    // Use a Consumer to watch for holdings data changes that might affect action buttons
    return Consumer(builder: (context, watch, _) {
      // Watch whether there are holdings and the showEdis flag
      final holdingProvider = ref.watch(portfolioProvider);

      // Generate key based on what matters for action buttons
      final hasHoldings = holdingProvider.holdingsModel != null &&
          holdingProvider.holdingsModel!.isNotEmpty;
      final showEdis = holdingProvider.showEdis;
      final showSearch = holdingProvider.showSearchHold;
      final buttonStateKey = '$hasHoldings-$showEdis-$showSearch';

      // Check if we already have these buttons cached
      if (_cachedActionButtons != null &&
          _cachedActionButtonsKey == buttonStateKey) {
        return _cachedActionButtons!;
      }

      // Generate new action buttons and cache them
      _cachedActionButtonsKey = buttonStateKey;
      _cachedActionButtons = _buildActionButtonsSection(
          hasHoldings: hasHoldings, showEdis: showEdis, showSearch: showSearch);

      return _cachedActionButtons!;
    });
  }

  // Action buttons section
  Widget _buildActionButtonsSection(
      {required bool hasHoldings,
      required bool showEdis,
      required bool showSearch}) {
    final holdingProvider = ref.read(portfolioProvider);
    final theme = ref.read(themeProvider);
    final ledgerdate = ref.watch(ledgerProvider);
    final showSearch = ref.watch(portfolioProvider).showSearchHold;

    if (showSearch) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
        child: Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 8),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: theme.isDarkMode
                          ? colors.searchBgDark
                          : colors.searchBg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  splashColor: theme.isDarkMode
                                      ? colors.splashColorDark
                                      : colors.splashColorLight,
                                  highlightColor: theme.isDarkMode
                                      ? colors.highlightDark
                                      : colors.highlightLight,
                                  onTap: () {
                                    Future.delayed(
                                        const Duration(milliseconds: 150),
                                        () async {
                                      ref
                                          .read(portfolioProvider)
                                          .showHoldSearch(true);
                                      setState(() {
                                        _cachedSummarySection = null;
                                        _cachedActionButtons = null;
                                        _cachedEmptyState = null;
                                        _cachedActionButtonsKey = null;
                                        _cachedSummaryKey = null;
                                      });
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SvgPicture.asset(
                                      assets.searchIcon,
                                      color: theme.isDarkMode
                                          ? colors.textSecondaryDark
                                          : colors.textSecondaryLight,
                                      width: 20,
                                      fit: BoxFit.scaleDown,
                                    ),
                                  ),
                                ),
                              ),
                              if (hasHoldings &&
                                  holdingProvider.holdingsModel!.length > 1)
                                Material(
                                  color: Colors.transparent,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.hardEdge,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    splashColor: theme.isDarkMode
                                        ? colors.splashColorDark
                                        : colors.splashColorLight,
                                    highlightColor: theme.isDarkMode
                                        ? colors.highlightDark
                                        : colors.highlightLight,
                                    onTap: () async {
                                      Future.delayed(
                                          const Duration(milliseconds: 150),
                                          () async {
                                        await showModalBottomSheet(
                                          useSafeArea: true,
                                          isScrollControlled: true,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(16)),
                                          ),
                                          context: context,
                                          builder: (context) =>
                                              const HoldingsScripFilterBottomSheet(),
                                        );
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SvgPicture.asset(
                                        assets.filterLinesDark,
                                        width: 18,
                                        color: theme.isDarkMode
                                            ? colors.textSecondaryDark
                                            : colors.textSecondaryLight,
                                        fit: BoxFit.scaleDown,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (hasHoldings && showEdis)
                              Material(
                                color: Colors.transparent,
                                shape: const RoundedRectangleBorder(),
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  customBorder: const RoundedRectangleBorder(),
                                  splashColor: theme.isDarkMode
                                      ? colors.splashColorDark
                                      : colors.splashColorLight,
                                  highlightColor: theme.isDarkMode
                                      ? colors.highlightDark
                                      : colors.highlightLight,
                                  onTap: () async {
                                    Future.delayed(const Duration(milliseconds: 150),
                                        () async {
                                      await ref
                                          .read(fundProvider)
                                          .fetchHstoken(context);
                                      await ref
                                          .read(fundProvider)
                                          .eDis(context);
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    child: TextWidget.subText(
                                      text: "E-DIS",
                                      theme: false,
                                      color: theme.isDarkMode
                                          ? colors.secondaryDark
                                          : colors.secondaryLight,
                                      fw: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Material(
                              color: Colors.transparent,
                              shape: const RoundedRectangleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                customBorder: const RoundedRectangleBorder(),
                                splashColor: theme.isDarkMode
                                    ? colors.splashColorDark
                                    : colors.splashColorLight,
                                highlightColor: theme.isDarkMode
                                    ? colors.highlightDark
                                    : colors.highlightLight,
                                onTap: () async {
                                  Future.delayed(const Duration(milliseconds: 150),
                                      () async {
                                    if (ledgerdate.pledgeandunpledge == null) {
                                      await ledgerdate.getCurrentDate("pandu");
                                      ledgerdate
                                          .fetchpledgeandunpledge(context);
                                    }
                                    if (kIsWeb && WebNavigationHelper.isAvailable) {
                                      WebNavigationHelper.navigateTo("pledgeAndUnpledge");
                                    } else {
                                      Navigator.pushNamed(
                                          context, Routes.pledgeandun,
                                          arguments: "DDDDD");
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  child: TextWidget.subText(
                                    text: "Pledge",
                                    theme: false,
                                    color: theme.isDarkMode
                                        ? colors.secondaryDark
                                        : colors.secondaryLight,
                                    fw: 2,
                                  ),
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              shape: const RoundedRectangleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                customBorder: const RoundedRectangleBorder(),
                                splashColor: theme.isDarkMode
                                    ? colors.splashColorDark
                                    : colors.splashColorLight,
                                highlightColor: theme.isDarkMode
                                    ? colors.highlightDark
                                    : colors.highlightLight,
                                onTap: () async {
                                  Future.delayed(const Duration(milliseconds: 150), () {
                              Navigator.pushNamed(
                                  context, Routes.portfolioDashboard);
                            });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  child: TextWidget.subText(
                                    text: "Insights",
                                    theme: false,
                                    color: theme.isDarkMode
                                        ? colors.secondaryDark
                                        : colors.secondaryLight,
                                    fw: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            )));
  }

  // Search bar section (shown conditionally)
  // Widget _buildSearchBar() {
  //   final holdingProvider = ref.read(portfolioProvider);

  //   // Only watch the search visibility state with a focused Consumer
  //   return Consumer(builder: (context, watch, _) {
  //     // final showSearch = ref.watch(portfolioProvider).showSearchHold;

  //     // if (!showSearch) {
  //     //   return const SizedBox.shrink();
  //     // }

  //     // Save theme reference to prevent repeated lookups
  //     final theme = ref.read(themeProvider);

  //     return RepaintBoundary(
  //       child:
  //     );
  //   });
  // }

  Widget _buildSearchBar() {
    final holdingProvider = ref.read(portfolioProvider);

    // Only watch the search visibility state with a focused Consumer
    return Consumer(builder: (context, watch, _) {
      final showSearch = ref.watch(portfolioProvider).showSearchHold;

      if (!showSearch) {
        return const SizedBox.shrink();
      }



      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
          ),
          child: SizedBox(
            height: 40,
            child: MyntSearchTextField.withSmartClear(
              controller: holdingProvider.holdingSearchCtrl,
              autofocus: true,
              placeholder: "Search",
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                  UpperCaseTextFormatter(),
                  NoEmojiInputFormatter(),
                  FilteringTextInputFormatter.deny(RegExp('[π£•₹€℅™∆√¶/.,]'))
              ],
              leadingIcon: assets.searchIcon,
              onChanged: (value) {
                  // Enable search mode when user starts typing
                  if (value.isNotEmpty) {
                    holdingProvider.showHoldSearch(true);
                  }

                  // Perform the search
                  holdingProvider.holdingSearch(value, context);
              },
              onClear: _resetHoldSearch,
            ),
          ),
        ),
      );
    });
  }

  // Holdings list section
  Widget _buildHoldingsList() {
    return _buildHoldingsListView();
  }

  // Get a cached divider container based on theme
  Widget _getDividerContainer(bool isDarkMode) {
    if (isDarkMode) {
      _cachedDarkDivider ??= Divider(
        thickness: 0,
        color: isDarkMode ? colors.dividerDark : colors.dividerLight,
        height: 0,
      );
      return _cachedDarkDivider!;
    } else {
      _cachedLightDivider ??= Divider(
        thickness: 0,
        color: isDarkMode ? colors.dividerDark : colors.dividerLight,
        height: 0,
      );
      return _cachedLightDivider!;
    }
  }

  // Holdings list view based on search state
  Widget _buildHoldingsListView() {
    final theme = ref.read(themeProvider);
    final isDarkMode = theme.isDarkMode;

    // Use a consumer to watch both the search state AND holdings data for API changes
    return Consumer(builder: (context, watch, _) {
      final portfolioData = ref.watch(portfolioProvider);

      // Watch both search state and actual holdings data
      final showSearch = portfolioData.showSearchHold;
      final searchText = portfolioData.holdingSearchCtrl.text;

      // Get the appropriate list based on search state - this will now update when holdings API updates
      final items = showSearch && searchText.isNotEmpty
          ? (portfolioData.holdingSearchItem ?? [])
          : (portfolioData.holdingsModel ?? []);

      // Show "No Data Found" only when search is active with text and no results found
      if (showSearch && searchText.isNotEmpty && items.isEmpty) {
        _cachedEmptyState ??= const SizedBox(
            height: 400,
            child: Center(child: NoDataFound(
                          title: "No Results Found",
                          subtitle: "Try searching with different keywords",
                          primaryEnabled: false,
                          secondaryEnabled: false,
                        ),),
          );
        return _cachedEmptyState!;
      }

      // Don't show anything if no holdings data at all (not in search mode)
      if (!showSearch && items.isEmpty) {
        return const SizedBox.shrink();
      }

      // Pre-cache the divider containers
      final divider = _getDividerContainer(isDarkMode);

      // Use a more efficient ListView with selective rebuilding
      // Wrap in RepaintBoundary to isolate the whole list
      return RepaintBoundary(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 0),
          // Use a key that only changes when the list fundamentally changes
          key: ValueKey('holdings-list-${items.length}'),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int idx) {
            final index = idx ~/ 2;

            // Return cached divider for odd indices with tap handler to unfocus keyboard
            if (idx.isOdd) {
              return divider;
            }

            final holding = items[index];
            if (holding.exchTsym == null || holding.exchTsym!.isEmpty) {
              return const SizedBox.shrink();
            }

            final token = holding.exchTsym![0].token;
            final isUpdated = _updatedTokens.containsKey(token);

            // Use a consistent key that only changes when the data changes
            return _HoldingItemWrapper(
              key: ValueKey('holding-$token-$isUpdated'),
              holding: holding,
              theme: theme,
              onTap:
                  () {}, // Empty function as navigation is now handled inside the wrapper
              onLongPress:
                  () {}, // Empty function as it's handled inside the wrapper
            );
          },
          itemCount: items.length * 2 - 1,
        ),
      );
    });
  }
}

// A wrapper widget to isolate individual holding items for better performance
class _HoldingItemWrapper extends ConsumerStatefulWidget {
  final dynamic holding;
  final ThemesProvider theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HoldingItemWrapper({
    super.key,
    required this.holding,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_HoldingItemWrapper> createState() =>
      _HoldingItemWrapperState();
}

class _HoldingItemWrapperState extends ConsumerState<_HoldingItemWrapper> {
  // Add navigation lock to prevent multiple taps
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    // Use Builder to get a fresh context for each item
    return Builder(builder: (newContext) {
      // Prevent rebuilds of internal components by using RepaintBoundary
      return RepaintBoundary(
        child: InkWell(
          onTap: () async {
            // Unfocus keyboard when tapping on holding item

            // Prevent multiple navigation events on rapid taps.
            if (_isNavigating) return;

            try {
              setState(() {
                _isNavigating = true;
              });

              // Navigate to holding detail with fresh context
              await _navigateToDetail(newContext);
            } finally {
              // Reset navigation lock after some delay
              if (mounted) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _isNavigating = false;
                    });
                  }
                });
              }
            }
          },
          onLongPress: () {
            // Unfocus keyboard when long pressing on holding item
            // FocusScope.of(context).unfocus();
            // Use the newer context from Builder to avoid deactivated widget issues
            // Navigator.pushNamed(newContext, Routes.holdingExit);
          },
          child: HoldingsList(
            holdingData: widget.holding,
            exchTsym: widget.holding.exchTsym[0],
          ),
        ),
      );
    });
  }

  Future<void> _navigateToDetail(BuildContext context) async {
    final marketWatch = ref.read(marketWatchProvider);

    // Only load data if it's needed (check if current token is different)
    if (marketWatch.getQuotes?.token != widget.holding.exchTsym![0].token) {
      try {
        await marketWatch.fetchLinkeScrip(
            "${widget.holding.exchTsym![0].token}",
            "${widget.holding.exchTsym![0].exch}",
            context);

        if (!mounted) return;

        if (marketWatch.linkedScrips != null &&
            marketWatch.linkedScrips!.stat == "Ok") {
          await marketWatch.fetchScripQuote(
              "${widget.holding.exchTsym![0].token}",
              "${widget.holding.exchTsym![0].exch}",
              context);

          if (!mounted) return;

          // Only fetch tech data for certain exchanges
          if (widget.holding.exchTsym![0].exch == "NSE" ||
              widget.holding.exchTsym![0].exch == "BSE") {
            await ref.read(marketWatchProvider).fetchTechData(
                context: context,
                exch: "${widget.holding.exchTsym![0].exch}",
                tradeSym: "${widget.holding.exchTsym![0].tsym}",
                lastPrc: "${widget.holding.exchTsym![0].lp}");
          }
        }
      } catch (e) {
        print("Error loading holding data: $e");
        // Continue with navigation even if data loading fails
      }
    }

    // Check if widget is still mounted before navigating
    if (!mounted) return;

    // Navigate to detail screen

    showModalBottomSheet(
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      isDismissible: true,
      enableDrag: false,
      useSafeArea: true,
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: HoldingDetailScreen(
          holdingData: widget.holding,
          exchTsym: widget.holding.exchTsym![0],
        ),
      ),
    );

    // Navigator.pushNamed(context, Routes.holdingDetail, arguments: {
    //   "holdingData": widget.holding,
    //   "exchTsym": widget.holding.exchTsym![0]
    // });
  }
}

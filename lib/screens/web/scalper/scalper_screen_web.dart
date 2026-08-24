import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../models/marketwatch_model/search_scrip_model.dart';
import '../../../models/order_book_model/place_order_model.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/portfolio_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/res.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/common_search_fields_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';
import 'scalper_chart_manager.dart';
import 'scalper_provider.dart';
import 'widgets/scalper_app_bar.dart';
import 'widgets/scalper_option_chain_overlay.dart';
import 'widgets/scalper_option_chart_panel.dart';
import 'widgets/scalper_order_bar.dart';
import 'widgets/scalper_positions_panel.dart';

/// Scalper Screen - High-frequency trading interface for index options
/// Layout matches the website exactly:
/// - Top: Index tabs (NIFTY, BANKNIFTY, SENSEX) | Search | Expiry | Settings
/// - Middle: [Call Chart] [Index Chart] [Put Chart]
/// - Order Bar: Buy/Sell buttons, Lot controls, Product/Order type
/// - Bottom: Positions panel
class ScalperScreenWeb extends ConsumerStatefulWidget {
  /// When true, renders without its own Scaffold/AppBar (embedded in split home screen)
  final bool embedded;

  const ScalperScreenWeb({super.key, this.embedded = false});

  @override
  ConsumerState<ScalperScreenWeb> createState() => _ScalperScreenWebState();
}

class _ScalperScreenWebState extends ConsumerState<ScalperScreenWeb> {
  bool _isInitialized = false;
  bool _hasLoadedOptionChain = false;

  /// Symbol+expiry key of a chain load that already came back empty/failed.
  /// build() auto-triggers _loadOptionChain whenever _hasLoadedOptionChain is
  /// false, so without this a failing chain (e.g. a 400 from a wrong exchange)
  /// would re-fire the request on every notifyListeners forever. A user action
  /// (tab switch, symbol/expiry change, refresh) clears it and retries.
  String? _failedOptionChainKey;

  /// Guards against overlapping _loadOptionChain calls (build's post-frame
  /// callback can fire again while the previous request is still in flight).
  bool _optionChainLoadInFlight = false;
  bool _isPlacingShortcutOrder = false;
  int _switchGeneration = 0;
  final GlobalKey _expiryButtonKey = GlobalKey();
  OverlayEntry? _expiryOverlay;

  /// Token the index chart is currently displaying.
  /// Only push ticks when the provider's selected token matches this,
  /// preventing cross-contamination during rapid symbol switches.
  String? _chartIndexToken;

  /// Track the current theme state to detect changes for index chart
  bool? _lastIndexThemeState;

  /// Track wsConnected state across rebuilds. On a false→true transition
  /// (a reconnect), re-subscribe scalper's tokens since WebSubscriptionManager
  /// rebuilds the master subscription list from sources it knows about, and
  /// scalper's option-chain tokens aren't in any of those sources.
  bool? _lastKnownWsConnected;

  // Search
  final GlobalKey _searchFieldKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _searchOverlay;

  /// Reclaim keyboard focus from TradingView chart iframes.
  /// Flutter's glass pane swallows pointer events so document-level listeners
  /// never fire. Instead we use Flutter's own Listener widget (wrapping the
  /// build output) and blur any focused iframe via dart:html.
  void _reclaimFocusFromIframe(PointerDownEvent _) {
    final active = html.document.activeElement;
    if (active != null && active.tagName == 'IFRAME') {
      active.blur();
      final flutterHost = html.document.querySelector('flutter-view')
          ?? html.document.querySelector('flt-glass-pane')
          ?? html.document.body;
      flutterHost?.focus();
    }
  }

  @override
  void initState() {
    super.initState();
    scalperChartManager.initialize();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _searchFocusNode.addListener(_onSearchFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final websocket = ref.read(websocketProvider);
    final scalper = ref.read(scalperProvider);
    final portfolio = ref.read(portfolioProvider);

    // Reload user-specific scalper settings (provider persists across logins)
    scalper.reloadUserSettings();

    // Load TradingView charting library (from static server in debug mode)
    try {
      await scalperChartManager.loadLibrary();
    } catch (e) {
    }

    // Fetch positions for the bottom panel
    portfolio.fetchPositionBook(context, false);

    // Fetch available symbols for search (cached, only fetches once)
    scalper.fetchAvailableSymbols();

    // Fetch initial quotes for ALL indices via API first (for immediate display)
    await scalper.fetchAllIndicesQuotes(context);

    // Subscribe to ALL indices for LTP display (touchline subscription for live
    // updates — the tabs render LTP/change only, no book)
    final allIndicesTokens = ScalperProvider.indices
        .map((idx) => "${idx.exch}|${idx.token}")
        .join('#');

    websocket.establishConnection(
      channelInput: allIndicesTokens,
      task: "t",
      context: context,
    );

    // Load expiry data (this also fetches initial LTP via API)
    await scalper.loadIndexData(context);

    // Update index chart
    _updateIndexChart();

    // Load option chain if we have expiry data
    if (scalper.selectedExpiry != null) {
      await _loadOptionChain();
    }
  }

  void _updateIndexChart({bool forceUpdate = false}) {
    final scalper = ref.read(scalperProvider);
    final index = scalper.selectedIndex;
    // Use the existing isDarkMode helper
    final isDark = isDarkMode(context);

    // Check if we need to update (symbol change or theme change or forced)
    final shouldUpdate = forceUpdate ||
        _chartIndexToken != index.token ||
        (_lastIndexThemeState != null && _lastIndexThemeState != isDark);

    if (!shouldUpdate) return;

    _chartIndexToken = index.token;
    _lastIndexThemeState = isDark;

    // changeSymbol handles clearing old data and fetching new data internally.
    // Do NOT call resetData before changeSymbol — it races with changeSymbol's
    // getBars and corrupts lastBarFromHistory in the JS bridge.
    scalperChartManager.changeSymbol(
      exch: index.exch,
      token: index.token,
      tsym: index.tsym,
      isDarkMode: isDark,
    );
  }

  /// Identifies a specific chain request (symbol + expiry). Used to remember
  /// which request already failed so it isn't retried in a loop.
  String _optionChainKey(ScalperProvider scalper) {
    final index = scalper.selectedIndex;
    return '${index.exch}|${index.token}|${scalper.selectedExpiry?.exd ?? ''}';
  }

  /// Clear the loaded/failed markers so the next load actually runs.
  /// Call from user-initiated actions (tab switch, symbol change, refresh).
  void _resetOptionChainLoad() {
    _hasLoadedOptionChain = false;
    _failedOptionChainKey = null;
  }

  Future<void> _loadOptionChain() async {
    if (_hasLoadedOptionChain || _optionChainLoadInFlight) return;

    final scalper = ref.read(scalperProvider);
    if (scalper.selectedExpiry == null) {
      return;
    }

    // Don't re-issue a request that already failed for this exact symbol+expiry.
    final key = _optionChainKey(scalper);
    if (_failedOptionChainKey == key) return;

    _optionChainLoadInFlight = true;
    try {
      await scalper.loadOptionChain(context);
    } finally {
      _optionChainLoadInFlight = false;
    }

    if (!mounted) return;

    // Only mark as loaded if we actually got data (prevents retry block on failure/cancellation)
    if (scalper.callOptions.isNotEmpty || scalper.putOptions.isNotEmpty) {
      _hasLoadedOptionChain = true;
      _failedOptionChainKey = null;

      // Subscribe to option chain tokens for live updates
      await scalper.subscribeToWebSocket(context);
    } else if (_optionChainKey(scalper) == key) {
      // Empty result for the request we made (not a stale/superseded one):
      // remember it and stop, otherwise build() would re-fire it endlessly.
      _failedOptionChainKey = key;
      final err = scalper.optionChainError;
      if (err != null && err.isNotEmpty) {
        ResponsiveSnackBar.showError(context, err);
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _removeSearchOverlay();
    _removeExpiryOverlay();
    ref.read(scalperProvider).unsubscribeFromWebSocket(context);
    // Only fully reset charts when NOT embedded.
    // When embedded (in split home screen), the widget gets unmounted/remounted
    // on screen switches. Keeping symbol state lets the factory callback
    // recreate charts on new containers automatically.
    if (!widget.embedded) {
      scalperChartManager.reset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scalper = ref.watch(scalperProvider);
    // Watch theme provider to trigger rebuilds when theme changes
    ref.watch(themeProvider);
    final isDark = isDarkMode(context);
    final indexToken = scalper.selectedIndex.token;
    final ws = ref.watch(websocketProvider);
    final indexData = ws.socketDatas[indexToken];

    // Detect WebSocket reconnect (false → true) and re-subscribe scalper's tokens.
    // WebSubscriptionManager handles indices/positions on its own, but scalper's
    // option-chain subscriptions are direct calls and unknown to the manager —
    // without this, call/put charts go silent after a >5s tab switch.
    final wsConnected = ws.wsConnected;
    if (_lastKnownWsConnected == false && wsConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = ref.read(scalperProvider);
        if (s.callOptions.isNotEmpty || s.putOptions.isNotEmpty) {
          s.subscribeToWebSocket(context);
        }
      });
    }
    _lastKnownWsConnected = wsConnected;

    // Update index chart when theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lastIndexThemeState != null && _lastIndexThemeState != isDark) {
        _updateIndexChart(forceUpdate: true);
      }
    });

    // Update LTP from WebSocket when data arrives
    if (indexData != null && indexData['lp'] != null) {
      final ltp = double.tryParse(indexData['lp'].toString()) ?? 0.0;
      if (ltp > 0 && ltp != scalper.currentIndexLTP) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(scalperProvider).updateIndexLTP(ltp);
        });
      }

      // Push live tick data to index TradingView chart for real-time candle updates.
      // Only push when the chart is actually displaying this token — prevents
      // cross-contamination when switching symbols rapidly (e.g. Sensex→Nifty).
      if (_chartIndexToken == indexToken) {
        final tickData = Map<String, dynamic>.from(indexData);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scalperChartManager.pushTick(chartId: 'index', tickData: tickData);
        });
      }
    }

    // Load option chain if not yet loaded and expiry is available.
    // Skip when this exact symbol+expiry already failed — otherwise every
    // notifyListeners would re-fire the request (endless API calls on a 400).
    if (!_hasLoadedOptionChain &&
        !_optionChainLoadInFlight &&
        scalper.selectedExpiry != null &&
        !scalper.isLoadingOptionChain &&
        _failedOptionChainKey != _optionChainKey(scalper)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadOptionChain();
      });
    }

    final body = Column(
      children: [
        // Top header with index tabs
        _buildTopHeader(scalper),
        // Divider
        _buildDivider(),
        // Three chart panels with expansion support
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildChartRow(scalper, indexData),
          ),
        ),
        // Order bar
        const ScalperOrderBar(),
        // Positions panel (collapsible and resizable)
        _buildPositionsPanel(scalper),
      ],
    );

    // Embedded mode: no Scaffold, just the body content
    if (widget.embedded) {
      return Listener(
        onPointerDown: _reclaimFocusFromIframe,
        child: body,
      );
    }

    return Listener(
      onPointerDown: _reclaimFocusFromIframe,
      child: Scaffold(
        backgroundColor: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        appBar: ScalperAppBar(
          onHomeTap: () => Navigator.of(context).pop(),
        ),
        body: body,
      ),
    );
  }

  /// Show option chain as a left-side sheet overlay (matches position/order detail pattern)
  /// Wrapped with PointerInterceptor to handle TradingView iframe z-index
  /// [isLeftChart] determines which chart the selected option goes to
  void _showOptionChainDrawer({required bool isLeftChart}) {
    shadcn.openSheet(
      context: context,
      barrierColor: Colors.transparent,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
        return _ChartIframeProtector(
          child: Container(
            width: sheetWidth,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                context,
                dark: MyntColors.backgroundColorDark,
                light: MyntColors.backgroundColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: ScalperOptionChainOverlay(
              onClose: () => shadcn.closeSheet(sheetContext),
              onOptionSelected: (option) {
                if (isLeftChart) {
                  ref.read(scalperProvider).setLeftChartOption(option);
                } else {
                  ref.read(scalperProvider).setRightChartOption(option);
                }
                shadcn.closeSheet(sheetContext);
              },
            ),
          ),
        );
      },
      position: shadcn.OverlayPosition.start,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: resolveThemeColor(
        context,
        dark: MyntColors.dividerDark,
        light: MyntColors.divider,
      ),
    );
  }

  /// Build positions panel with collapse and resize support
  Widget _buildPositionsPanel(ScalperProvider scalper) {
    final isCollapsed = scalper.isPositionsPanelCollapsed;
    final panelHeight = scalper.positionsPanelHeight;

    if (isCollapsed) {
      // When collapsed, just show the drag handle bar (fixed height)
      return const SizedBox(
        height: 32,
        child: ScalperPositionsPanel(),
      );
    }

    // When expanded, use the stored height
    return SizedBox(
      height: panelHeight,
      child: const ScalperPositionsPanel(),
    );
  }

  /// Build chart row with expansion support
  /// All charts stay in the widget tree to prevent iframe reload
  /// Uses Stack layout so charts are never unmounted
  Widget _buildChartRow(ScalperProvider scalper, Map<String, dynamic>? indexData) {
    final expandedChart = scalper.expandedChart;

    // Determine visibility for each chart
    final showCall = expandedChart == null || expandedChart == 'call';
    final showIndex = expandedChart == null || expandedChart == 'index';
    final showPut = expandedChart == null || expandedChart == 'put';

    // Build chart widgets
    final callChart = ScalperOptionChartPanel(
      key: const ValueKey('scalper-call-chart'),
      isCall: true,
      option: scalper.selectedCall,
      selectedStrike: scalper.callStrike,
      onStrikeTap: () => _showOptionChainDrawer(isLeftChart: true),
    );

    final indexChart = _buildIndexChartPanel(scalper, indexData);

    final putChart = ScalperOptionChartPanel(
      key: const ValueKey('scalper-put-chart'),
      isCall: false,
      option: scalper.selectedPut,
      selectedStrike: scalper.putStrike,
      onStrikeTap: () => _showOptionChainDrawer(isLeftChart: false),
    );

    // Use LayoutBuilder to get available width for positioning
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final chartWidth = totalWidth / 3;

        return Stack(
          children: [
            // CALL chart (left) - always at position 0
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: 0,
              top: 0,
              bottom: 0,
              width: showCall ? (expandedChart == 'call' ? totalWidth : chartWidth) : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showCall ? 1.0 : 0.0,
                child: callChart,
              ),
            ),
            // INDEX chart (center)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: expandedChart == null
                  ? chartWidth
                  : (expandedChart == 'index' ? 0 : (showIndex ? chartWidth : totalWidth)),
              top: 0,
              bottom: 0,
              width: showIndex ? (expandedChart == 'index' ? totalWidth : chartWidth) : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showIndex ? 1.0 : 0.0,
                child: indexChart,
              ),
            ),
            // PUT chart (right)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: expandedChart == null
                  ? chartWidth * 2
                  : (expandedChart == 'put' ? 0 : totalWidth),
              top: 0,
              bottom: 0,
              width: showPut ? (expandedChart == 'put' ? totalWidth : chartWidth) : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showPut ? 1.0 : 0.0,
                child: putChart,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Top header matching website: Index tabs | Search | Expiry | Settings
  Widget _buildTopHeader(ScalperProvider scalper) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
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
        children: [
          // Default index tabs (always shown)
          ...ScalperProvider.indices.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final isSelected = scalper.selectedIndexType == index;

            // Get LTP from websocket, fallback to provider data from API
            final socketData = ref.watch(websocketProvider).socketDatas[data.token];
            final providerData = scalper.indicesData[data.token];

            // Use WebSocket data if available, otherwise use API data
            final ltp = socketData?['lp']?.toString() ??
                        providerData?['lp'] ?? '--';
            final change = socketData?['chng']?.toString() ??
                           providerData?['chng'] ?? '0.00';
            final perChange = socketData?['pc']?.toString() ??
                              providerData?['pc'] ?? '0.00';
            final isPositive = !change.startsWith('-') && change != '0.00' && change != '0';

            return _buildIndexTab(
              name: data.name,
              ltp: ltp,
              change: '$change ($perChange%)',
              isSelected: isSelected,
              isPositive: isPositive,
              onTap: () async {
                if (ref.read(scalperProvider).selectedIndexType == index) return;
                final gen = ++_switchGeneration;
                _resetOptionChainLoad();

                // setSelectedIndex sets _selectedIndexType synchronously before
                // the async loadIndexData. Start the chart change immediately
                // (JS debounces rapid calls) instead of waiting for the API.
                final loadFuture = ref.read(scalperProvider).setSelectedIndex(index, context);
                _updateIndexChart();

                await loadFuture;
                if (_switchGeneration != gen) return;
                if (ref.read(scalperProvider).selectedExpiry != null) {
                  await _loadOptionChain();
                }
              },
            );
          }),
          // 4th tab — custom symbol from search (persists until replaced)
          if (scalper.customIndex != null)
            Builder(builder: (_) {
              final custom = scalper.customIndex!;
              final isSelected = scalper.selectedIndexType == 3;
              final socketData = ref.watch(websocketProvider).socketDatas[custom.token];
              final providerData = scalper.indicesData[custom.token];
              final ltp = socketData?['lp']?.toString() ??
                          providerData?['lp'] ?? '--';
              final change = socketData?['chng']?.toString() ??
                             providerData?['chng'] ?? '0.00';
              final perChange = socketData?['pc']?.toString() ??
                                providerData?['pc'] ?? '0.00';
              final isPositive = !change.startsWith('-') && change != '0.00' && change != '0';
              return _buildIndexTab(
                name: custom.name,
                ltp: ltp,
                change: '$change ($perChange%)',
                isSelected: isSelected,
                isPositive: isPositive,
                onTap: () async {
                  if (ref.read(scalperProvider).selectedIndexType == 3) return;
                  final gen = ++_switchGeneration;
                  _resetOptionChainLoad();
                  final loadFuture = ref.read(scalperProvider).selectCustomIndex(context);
                  _updateIndexChart();
                  await loadFuture;
                  if (_switchGeneration != gen) return;
                  if (ref.read(scalperProvider).selectedExpiry != null) {
                    await _loadOptionChain();
                  }
                },
              );
            }),
          const Spacer(),
          // Search field
          _buildSearchField(),
          const SizedBox(width: 16),
          // Expiry dropdown
          if (scalper.expiryDates.isNotEmpty)
            _buildExpiryDropdown(scalper),
          const SizedBox(width: 16),
          // Settings button
          IconButton(
            onPressed: _showSettingsDialog,
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            tooltip: 'Settings',
          ),
          // Refresh button
          IconButton(
            onPressed: () async {
              // Force-rebuild all 3 charts to clear any stuck JS-side state
              // (current strikes are preserved via the manager's cached symbols).
              scalperChartManager.recreateAllCharts();

              _resetOptionChainLoad();
              await _loadOptionChain();
              // Re-apply preference-based strikes (user may have manually changed them)
              if (mounted) {
                final scalper = ref.read(scalperProvider);
                scalper.reapplyPreferenceStrikes();
                ResponsiveSnackBar.showInfo(
                  context,
                  'Strikes reset to preference defaults',
                );
              }
            },
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildIndexTab({
    required String name,
    required String ltp,
    required String change,
    required bool isSelected,
    required bool isPositive,
    required VoidCallback onTap,
  }) {
    final changeColor = isPositive
        ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);

    final primary = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: isSelected
                ? Border.all(color: primary.withValues(alpha: 0.08))
                : null,
          ),
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
            children: [
              // Index name
              Text(
                name,
                style: MyntWebTextStyles.symbol(
                  context,
                  fontWeight:  MyntFonts.medium,
                  // isSelected ? MyntFonts.semiBold :
                  color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),

                  // isSelected ? primary : 
                ),
                 maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // LTP + Change stacked
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ltp,
                    style: MyntWebTextStyles.price(
                      context,
                      fontWeight: MyntFonts.medium,
                      color: changeColor 
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    change,
                    style: MyntWebTextStyles.exch(
                      context,
                      color: resolveThemeColor(
                            context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      key: _searchFieldKey,
      width: 240,
      child: MyntSearchTextField.withSmartClear(
        controller: _searchController,
        focusNode: _searchFocusNode,
        placeholder: 'Search',
        leadingIcon: assets.searchIcon,
        borderRadius: 6,
        onChanged: (_) => _updateSearchOverlay(),
        onClear: () {
          _searchController.clear();
          _updateSearchOverlay();
        },
      ),
    );
  }

  // ─── Search Overlay ─────────────────────────────────────────────

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus) {
      _showSearchOverlay();
    }
    // Don't dismiss on focus loss — scrollbar drags cause focus loss.
    // The full-screen dismiss area handles all "click outside" cases.
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();

    final renderBox =
        _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    ChartIframeGuard.acquire();
    _disableScalperCharts();

    _searchOverlay = OverlayEntry(
      builder: (overlayContext) => _buildSearchOverlayContent(position, size),
    );

    Overlay.of(context).insert(_searchOverlay!);
  }

  void _updateSearchOverlay() {
    _searchOverlay?.markNeedsBuild();
    setState(() {}); // Rebuild to show/hide clear icon
  }

  void _removeSearchOverlay() {
    if (_searchOverlay != null) {
      _searchOverlay!.remove();
      _searchOverlay = null;
      ChartIframeGuard.release();
      _enableScalperCharts();
    }
  }

  Widget _buildSearchOverlayContent(Offset position, Size size) {
    final scalper = ref.watch(scalperProvider);
    final allSymbols = scalper.availableSymbols;
    final query = _searchController.text.trim().toUpperCase();

    // Filter symbols based on search text
    final filtered = query.isEmpty
        ? allSymbols
        : allSymbols.where((s) {
            final tsym = (s.tsym ?? '').toUpperCase();
            final cname = (s.cname ?? '').toUpperCase();
            return tsym.contains(query) || cname.contains(query);
          }).toList();

    final bgColor = resolveThemeColor(
      context,
      dark: MyntColors.listItemBgDark,
      light: Colors.white,
    );
    final textColor = resolveThemeColor(
      context,
      dark: MyntColors.textPrimaryDark,
      light: MyntColors.textPrimary,
    );
    final secondaryColor = resolveThemeColor(
      context,
      dark: MyntColors.textSecondaryDark,
      light: MyntColors.textSecondary,
    );
    final borderColor = resolveThemeColor(
      context,
      dark: MyntColors.dividerDark,
      light: MyntColors.divider,
    );
    final selectedBg = resolveThemeColor(
      context,
      dark: MyntColors.primaryDark,
      light: MyntColors.primary,
    ).withValues(alpha: 0.12);

    return Stack(
      children: [
        // Full-screen dismiss area
        Positioned.fill(
          child: PointerInterceptor(
            child: GestureDetector(
              onTap: () {
                _searchFocusNode.unfocus();
                _removeSearchOverlay();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Dropdown positioned below search field
        Positioned(
          left: position.dx,
          top: position.dy + size.height + 4,
          child: PointerInterceptor(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(5),
              color: bgColor,
              child: Container(
                width: size.width,
                constraints: const BoxConstraints(maxHeight: 350),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Loading state
                    if (scalper.isLoadingSymbols)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    // Empty state
                    else if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          query.isEmpty ? 'No symbols available' : 'No results for "$query"',
                           style: MyntWebTextStyles.para(
                    context,
                    fontWeight: FontWeight.w500,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary,
                    ),
                  ),
                  textAlign: TextAlign.center,
                        ),
                      )
                    // Results list
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final symbol = filtered[index];
                            final isCurrentlySelected =
                                symbol.token == scalper.selectedIndex.token;

                            return InkWell(
                              onTap: () => _onSymbolSelected(symbol),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                color: isCurrentlySelected ? selectedBg : null,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        symbol.tsym ?? '',
                                        style: MyntWebTextStyles.body(
                                          context,
                                          fontWeight: isCurrentlySelected
                                              ? MyntFonts.semiBold
                                              : MyntFonts.medium,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // const SizedBox(width: 8),
                                    Text(
                                      symbol.exch ?? '',
                                      style: MyntWebTextStyles.exch(
                                        context,
                                        color: secondaryColor,
                                        fontWeight: isCurrentlySelected
                                              ? MyntFonts.semiBold
                                              : MyntFonts.medium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSymbolSelected(ScripValue symbol) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _removeSearchOverlay();

    final gen = ++_switchGeneration;
    _resetOptionChainLoad();
    final scalper = ref.read(scalperProvider);
    await scalper.setSelectedSymbol(symbol, context);
    if (_switchGeneration != gen) return;

    // Update index chart
    _updateIndexChart();

    // Load option chain
    if (scalper.selectedExpiry != null) {
      await _loadOptionChain();
    }
    if (_switchGeneration != gen) return;

    // Subscribe to WebSocket
    if (scalper.callOptions.isNotEmpty || scalper.putOptions.isNotEmpty) {
      await scalper.subscribeToWebSocket(context);
    }

    // Subscribe custom index token for tab LTP display (persists across tab switches)
    if (scalper.customIndex != null) {
      ref.read(websocketProvider).establishConnection(
        channelInput: "${scalper.customIndex!.exch}|${scalper.customIndex!.token}",
        task: "t",
        context: context,
      );
    }
  }

  Widget _buildExpiryDropdown(ScalperProvider scalper) {
    return GestureDetector(
      key: _expiryButtonKey,
      onTap: () => _showExpiryOverlay(scalper),
      child: Container(
        width: 160,
        height: 40,
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.transparent,
            light: const Color(0xffF1F3F8),
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.primary,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                scalper.selectedExpiry?.exd ?? 'Select',
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textWhite,
                  lightColor: MyntColors.textBlack,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Show expiry dates as a custom overlay with PointerInterceptor
  void _showExpiryOverlay(ScalperProvider scalper) {
    _removeExpiryOverlay();

    final renderBox =
        _expiryButtonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    ChartIframeGuard.acquire();
    _disableScalperCharts();

    _expiryOverlay = OverlayEntry(
      builder: (overlayContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? MyntColors.overlayBgDark : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF444444)
            : const Color(0xFFE0E0E0);

        return Stack(
          children: [
            // Full-screen dismiss area
            Positioned.fill(
              child: PointerInterceptor(
                child: GestureDetector(
                  onTap: _removeExpiryOverlay,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Dropdown positioned below button
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              child: PointerInterceptor(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(6),
                  color: bgColor,
                  child: Container(
                    width: size.width,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: scalper.expiryDates.map((exp) {
                            final isSelected =
                                exp.exd == scalper.selectedExpiry?.exd;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  _removeExpiryOverlay();
                                  _resetOptionChainLoad();
                                  await ref
                                      .read(scalperProvider)
                                      .setSelectedExpiry(exp, context);
                                  await ref
                                      .read(scalperProvider)
                                      .subscribeToWebSocket(context);
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
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Text(
                                    exp.exd ?? '',
                                    style: MyntWebTextStyles.body(
                                      context,
                                      fontWeight: isSelected
                                          ? MyntFonts.semiBold
                                          : MyntFonts.medium,
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
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_expiryOverlay!);
  }

  /// Remove expiry overlay and re-enable chart iframes
  void _removeExpiryOverlay() {
    if (_expiryOverlay != null) {
      _expiryOverlay!.remove();
      _expiryOverlay = null;
      ChartIframeGuard.release();
      _enableScalperCharts();
    }
  }

  // ─── Keyboard Shortcuts ───────────────────────────────────────────

  /// Check if a text field is currently focused
  bool _isTextFieldFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) return false;

    bool result = false;
    primaryFocus.context!.visitAncestorElements((element) {
      if (element.widget is EditableText || element.widget is TextField) {
        result = true;
        return false;
      }
      return true;
    });
    return result;
  }

  /// Global keyboard event handler for order shortcuts
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final scalper = ref.read(scalperProvider);
    if (!scalper.isShortcutsEnabled) return false;

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Don't intercept when typing in text fields — EXCEPT Shift/Ctrl+arrow for order shortcuts
    if (_isTextFieldFocused() && !isShift && !isCtrl) return false;

    // Shift + ↑ = Buy CE (left)
    if (isShift && !isCtrl && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _placeShortcutOrder(isBuy: true, isCall: true);
      return true;
    }
    // Shift + ↓ = Sell CE (left)
    if (isShift && !isCtrl && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _placeShortcutOrder(isBuy: false, isCall: true);
      return true;
    }
    // Ctrl + ↑ = Buy PE (right)
    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _placeShortcutOrder(isBuy: true, isCall: false);
      return true;
    }
    // Ctrl + ↓ = Sell PE (right)
    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _placeShortcutOrder(isBuy: false, isCall: false);
      return true;
    }

    return false;
  }

  /// Place an order via keyboard shortcut
  Future<void> _placeShortcutOrder({required bool isBuy, required bool isCall}) async {
    if (_isPlacingShortcutOrder) return;

    final scalper = ref.read(scalperProvider);
    final option = isCall ? scalper.selectedCall : scalper.selectedPut;

    if (option == null) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          'No ${isCall ? 'CE' : 'PE'} option selected',
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    _isPlacingShortcutOrder = true;

    try {
      final isMarket = scalper.isMarketOrder;
      String price = '0';

      if (!isMarket) {
        // Read limit prices from provider (synced from order bar text fields)
        final priceKey = '${isCall ? "left" : "right"}_${isBuy ? "buy" : "sell"}';
        price = scalper.getLimitPrice(priceKey);
        if (price.isEmpty || price == '0' || price == '0.00') {
          // Fallback to websocket ASK/BID if no limit price set
          final wsData = ref.read(websocketProvider).socketDatas[option.token];
          price = isBuy
              ? (wsData?['sp1']?.toString() ?? option.lp ?? '0')
              : (wsData?['bp1']?.toString() ?? option.lp ?? '0');
        }
      }

      final qty = scalper.totalOrderQuantity.toString();
      // Options (NFO/BFO) use NRML for delivery, not CNC
      final prd = scalper.isIntraday ? 'I' : 'NRML';
      final prcType = isMarket ? 'MKT' : 'LMT';

      final orderInput = PlaceOrderInput(
        exch: option.exch ?? 'NFO',
        tsym: option.tsym ?? '',
        qty: qty,
        prc: price,
        prctype: prcType,
        trantype: isBuy ? 'B' : 'S',
        prd: prd,
        ret: 'DAY',
        amo: 'No',
        trgprc: '',
        trailprc: '',
        blprc: '',
        bpprc: '',
        dscqty: '',
        mktProt: (isMarket && scalper.isMktProtectionEnabled)
            ? scalper.mktProtectionPoints.toString()
            : '',
        channel: 'WEB',
      );

      await ref.read(orderProvider).fetchPlaceOrder(
            context,
            orderInput,
            false,
            quickOrder: true,
          );

      // Order provider already shows success/error toast via ResponsiveSnackBar
    } catch (_) {
    } finally {
      _isPlacingShortcutOrder = false;
    }
  }

  // ─── Settings Dialog ──────────────────────────────────────────────

  void _showSettingsDialog() async {
    final newSymbolIndex = await showDialog<int?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _ScalperSettingsDialog(),
    );

    // If the user changed the default symbol, do a full tab switch
    // (same flow as tapping a tab — updates charts + option chain)
    if (newSymbolIndex != null && mounted) {
      final gen = ++_switchGeneration;
      _resetOptionChainLoad();

      final loadFuture = ref.read(scalperProvider).setSelectedIndex(newSymbolIndex, context);
      _updateIndexChart();

      await loadFuture;
      if (_switchGeneration != gen) return;
      if (ref.read(scalperProvider).selectedExpiry != null) {
        await _loadOptionChain();
      }
    }
  }

  /// Index chart panel (center) with card styling matching option panels
  Widget _buildIndexChartPanel(ScalperProvider scalper, Map<String, dynamic>? indexData) {
    // Use provider data as fallback
    final providerData = scalper.indicesData[scalper.selectedIndex.token];
    final ltp = indexData?['lp']?.toString() ?? providerData?['lp'] ?? '--';
    final change = indexData?['chng']?.toString() ?? providerData?['chng'] ?? '0.00';
    final perChange = indexData?['pc']?.toString() ?? providerData?['pc'] ?? '0.00';
    final isPositive = !change.startsWith('-') && change != '0.00' && change != '0';
    final changeColor = isPositive
        ? resolveThemeColor(context, dark: MyntColors.profitDark, light: MyntColors.profit)
        : resolveThemeColor(context, dark: MyntColors.lossDark, light: MyntColors.loss);
    final isExpanded = scalper.expandedChart == 'index';

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: resolveThemeColor(
          context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor,
        ),
        border: Border.all(
          color: resolveThemeColor(
            context,
            dark: MyntColors.dividerDark,
            light: MyntColors.divider,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Header with consistent height matching option panels
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: resolveThemeColor(
                  context,
                  dark: MyntColors.listItemBgDark,
                  light: MyntColors.listItemBg,
                ),
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
                children: [
                  // Left: Symbol name + LTP/Change (horizontal, matching option chart panels)
                  Expanded(
                    child: Row(
                      children: [
                        // Index name
                        Flexible(
                          child: Text(
                            scalper.selectedIndex.name,
                            style: MyntWebTextStyles.symbol(
                              context,
                              fontWeight: MyntFonts.medium,
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // LTP
                        Text(
                          ltp,
                          style: MyntWebTextStyles.price(
                            context,
                            // fontWeight: MyntFonts.bold,
                            color: changeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Change
                        Text(
                          '$change ($perChange%)',
                          style: MyntWebTextStyles.exch(
                            context,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right column: INDEX badge + Expand icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // INDEX badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context,
                              dark: MyntColors.secondary, light: MyntColors.primary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'INDEX',
                          style: MyntWebTextStyles.caption(
                            context,
                            fontWeight: MyntFonts.medium,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Expand/Collapse icon
                      InkWell(
                        onTap: () => ref.read(scalperProvider).toggleChartExpansion('index'),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isExpanded ? Icons.close_fullscreen : Icons.open_in_full,
                            size: 16,
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.textSecondaryDark,
                              light: MyntColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chart
            Expanded(
              child: ClipRect(
                child: HtmlElementView(
                  key: const ValueKey(ScalperChartManager.indexViewType),
                  viewType: ScalperChartManager.indexViewType,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings dialog for scalper screen
class _ScalperSettingsDialog extends ConsumerStatefulWidget {
  const _ScalperSettingsDialog();

  @override
  ConsumerState<_ScalperSettingsDialog> createState() =>
      _ScalperSettingsDialogState();
}

class _ScalperSettingsDialogState
    extends ConsumerState<_ScalperSettingsDialog> {
  late final TextEditingController _callPremiumCtrl;
  late final TextEditingController _putPremiumCtrl;
  late final TextEditingController _mktProtCtrl;

  // Local settings state (only pushed to provider on Apply)
  late String _mode;
  late int _callOffset;
  late int _putOffset;
  late int _defaultSymbol;
  late bool _mktProtEnabled;
  late String _posFilter;
  late bool _shortcutsEnabled;

  final GlobalKey _symbolButtonKey = GlobalKey();
  OverlayEntry? _symbolOverlay;

  final GlobalKey _callOffsetKey = GlobalKey();
  final GlobalKey _putOffsetKey = GlobalKey();
  OverlayEntry? _callOffsetOverlay;
  OverlayEntry? _putOffsetOverlay;

  @override
  void initState() {
    super.initState();
    ChartIframeGuard.acquire();
    _disableScalperCharts();
    final s = ref.read(scalperProvider);
    _callPremiumCtrl = TextEditingController(text: s.callPremiumTarget.toStringAsFixed(0));
    _putPremiumCtrl = TextEditingController(text: s.putPremiumTarget.toStringAsFixed(0));
    _mktProtCtrl = TextEditingController(text: s.mktProtectionPoints.toString());
    _mode = s.strikeSelectionMode;
    _callOffset = s.defaultCallOffset;
    _putOffset = s.defaultPutOffset;
    _defaultSymbol = s.defaultSymbolIndex;
    _mktProtEnabled = s.isMktProtectionEnabled;
    _posFilter = s.positionFilter;
    _shortcutsEnabled = s.isShortcutsEnabled;
  }

  @override
  void dispose() {
    _callPremiumCtrl.dispose();
    _putPremiumCtrl.dispose();
    _mktProtCtrl.dispose();
    _removeSymbolOverlay();
    _removeCallOffsetOverlay();
    _removePutOffsetOverlay();
    ChartIframeGuard.release();
    _enableScalperCharts();
    super.dispose();
  }

  void _showSymbolOverlay(Color primary, Color textColor, Color dividerColor) {
    _removeSymbolOverlay();

    final renderBox = _symbolButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);

    _symbolOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeSymbolOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 4,
            width: size.width,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(6),
              color: bgColor,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: ScalperProvider.indices.asMap().entries.map((e) {
                        final isSelected = e.key == _defaultSymbol;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _defaultSymbol = e.key);
                              _removeSymbolOverlay();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(
                                e.value.name,
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                                  color: isSelected ? primary : textColor,
                                ),
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
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_symbolOverlay!);
  }

  void _removeSymbolOverlay() {
    _symbolOverlay?.remove();
    _symbolOverlay = null;
  }

  void _showOffsetOverlay({
    required GlobalKey key,
    required int currentOffset,
    required Color primary,
    required Color textColor,
    required bool isCall,
    required void Function(int) onSelected,
  }) {
    _removeCallOffsetOverlay();
    _removePutOffsetOverlay();

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? MyntColors.overlayBgDark : Colors.white;
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);

    const options = <int>[-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5];
    String labelFor(int o) {
      if (o == 0) return 'ATM';
      if (o < 0) return 'ITM ${-o}';
      return 'OTM $o';
    }

    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: isCall ? _removeCallOffsetOverlay : _removePutOffsetOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 4,
            width: size.width,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(6),
              color: bgColor,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: options.map((o) {
                        final isSelected = o == currentOffset;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              onSelected(o);
                              if (isCall) _removeCallOffsetOverlay(); else _removePutOffsetOverlay();
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(
                                labelFor(o),
                                style: MyntWebTextStyles.body(
                                  context,
                                  fontWeight: isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                                  color: isSelected ? primary : textColor,
                                ),
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
          ),
        ],
      ),
    );

    if (isCall) {
      _callOffsetOverlay = entry;
    } else {
      _putOffsetOverlay = entry;
    }
    Overlay.of(context).insert(entry);
  }

  void _removeCallOffsetOverlay() {
    _callOffsetOverlay?.remove();
    _callOffsetOverlay = null;
  }

  void _removePutOffsetOverlay() {
    _putOffsetOverlay?.remove();
    _putOffsetOverlay = null;
  }

  void _apply() {
    final scalper = ref.read(scalperProvider);
    final symbolChanged = _defaultSymbol != scalper.selectedIndexType;

    scalper.applyAllSettings(
      strikeSelectionMode: _mode,
      defaultCallOffset: _callOffset,
      defaultPutOffset: _putOffset,
      callPremiumTarget: double.tryParse(_callPremiumCtrl.text) ?? 100,
      putPremiumTarget: double.tryParse(_putPremiumCtrl.text) ?? 100,
      defaultSymbolIndex: _defaultSymbol,
      isMktProtectionEnabled: _mktProtEnabled,
      mktProtectionPoints: int.tryParse(_mktProtCtrl.text) ?? 5,
      positionFilter: _posFilter,
      isShortcutsEnabled: _shortcutsEnabled,
    );

    // Pop with the new symbol index if it changed, so the screen can do a full tab switch
    Navigator.of(context).pop(symbolChanged ? _defaultSymbol : null);
  }

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary);
    final textColor = resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary);
    final secondaryColor = resolveThemeColor(context, dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    final dividerColor = resolveThemeColor(context, dark: MyntColors.dividerDark, light: MyntColors.divider);

    return PointerInterceptor(
      child: Center(
        child: shadcn.Card(
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Settings', style: MyntWebTextStyles.title(context, color: textColor)),
                      MyntCloseButton(onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
                // Scrollable content
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // ─── Default Symbol ─────────────────────────
                        _sectionLabel(context, 'Default Symbol', textColor),
                        const SizedBox(height: 10),
                        _buildDefaultSymbolDropdown(context, primary, textColor, secondaryColor, dividerColor),
                        const SizedBox(height: 16),

                        // ─── Strike Selection ───────────────────────
                        _sectionLabel(context, 'Strike Selection', textColor),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildRadioRow(
                              context,
                              value: 'offset',
                              groupValue: _mode,
                              label: 'ATM Offset',
                              primary: primary,
                              textColor: textColor,
                              onChanged: (v) => setState(() => _mode = v),
                            ),
                            const SizedBox(width: 24),
                            _buildRadioRow(
                              context,
                              value: 'premium',
                              groupValue: _mode,
                              label: 'Premium',
                              primary: primary,
                              textColor: textColor,
                              onChanged: (v) => setState(() => _mode = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ─── Call / Put Strike ──────────────────────
                        if (_mode == 'offset') ...[
                          Row(
                            children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel(context, 'Default Call Strike', textColor),
                                  const SizedBox(height: 10),
                                  _buildOffsetDropdown(context, _callOffset, primary, textColor, secondaryColor, dividerColor,
                                    (v) => setState(() => _callOffset = v), isCall: true),
                                ],
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel(context, 'Default Put Strike', textColor),
                                  const SizedBox(height: 10),
                                  _buildOffsetDropdown(context, _putOffset, primary, textColor, secondaryColor, dividerColor,
                                    (v) => setState(() => _putOffset = v), isCall: false),
                                ],
                              )),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel(context, 'Call Premium', textColor),
                                  const SizedBox(height: 10),
                                  _buildNumberInput(context, _callPremiumCtrl, dividerColor, textColor, primary),
                                ],
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel(context, 'Put Premium', textColor),
                                  const SizedBox(height: 10),
                                  _buildNumberInput(context, _putPremiumCtrl, dividerColor, textColor, primary),
                                ],
                              )),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Selects the strike whose LTP is closest to the target premium.',
                            style: MyntWebTextStyles.caption(context, color: secondaryColor),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ─── Market Protection ──────────────────────
                        _sectionLabel(context, 'Market Protection', textColor),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _mktProtEnabled,
                                onChanged: (v) => setState(() => _mktProtEnabled = v ?? false),
                                activeColor: primary,
                                side: BorderSide(color: dividerColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Enable MKT Protection', style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.regular, color: textColor)),
                            const SizedBox(width: 16),
                            if (_mktProtEnabled)
                              SizedBox(
                                width: 100,
                                height: 40,
                                child: _buildNumberInput(context, _mktProtCtrl, dividerColor, textColor, primary),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Adds protection points to market orders (max 20).',
                          style: MyntWebTextStyles.caption(context, color: secondaryColor),
                        ),
                        const SizedBox(height: 16),

                        // ─── Position Filter ────────────────────────
                        _sectionLabel(context, 'Position Filter', textColor),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildRadioRow(
                              context,
                              value: 'all',
                              groupValue: _posFilter,
                              label: 'All Positions',
                              primary: primary,
                              textColor: textColor,
                              onChanged: (v) => setState(() => _posFilter = v),
                            ),
                            const SizedBox(width: 24),
                            _buildRadioRow(
                              context,
                              value: 'fno',
                              groupValue: _posFilter,
                              label: 'FNO Positions Only',
                              primary: primary,
                              textColor: textColor,
                              onChanged: (v) => setState(() => _posFilter = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ─── Keyboard Shortcuts ─────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _sectionLabel(context, 'Keyboard Shortcuts', textColor),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _shortcutsEnabled,
                                onChanged: (val) => setState(() => _shortcutsEnabled = val),
                                activeTrackColor: primary,
                                activeThumbColor: Colors.white,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        if (_shortcutsEnabled) ...[
                          const SizedBox(height: 10),
                          // Display shortcuts in 2 columns
                          Row(
                            children: [
                              Expanded(
                                child: _buildShortcutRow(context, 'Shift + ↑', 'Buy CE (Left)', resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildShortcutRow(context, 'Shift + ↓', 'Sell CE (Left)', resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildShortcutRow(context, 'Ctrl + ↑', 'Buy PE (Right)', resolveThemeColor(context, dark: MyntColors.secondary, light: MyntColors.primary)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildShortcutRow(context, 'Ctrl + ↓', 'Sell PE (Right)', resolveThemeColor(context, dark: MyntColors.errorDark, light: MyntColors.tertiary)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: dividerColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text('Apply', style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.semiBold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(BuildContext context, String text, Color color) {
    return Text(text, style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium, color: color));
  }

  Widget _buildRadioRow(
    BuildContext context, {
    required String value,
    required String groupValue,
    required String label,
    required Color primary,
    required Color textColor,
    required void Function(String) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Radio<String>(
                value: value,
                groupValue: groupValue,
                onChanged: (v) => onChanged(v!),
                activeColor: primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: MyntWebTextStyles.body(context, fontWeight: MyntFonts.regular, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultSymbolDropdown(
    BuildContext context,
    Color primary, Color textColor, Color secondaryColor, Color dividerColor,
  ) {
    return GestureDetector(
      key: _symbolButtonKey,
      onTap: () => _showSymbolOverlay(primary, textColor, dividerColor),
      child: Container(
        width: 200,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.transparent,
            light: const Color(0xffF1F3F8),
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.primary,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                ScalperProvider.indices[_defaultSymbol].name,
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textWhite,
                  lightColor: MyntColors.textBlack,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffsetDropdown(
    BuildContext context, int currentOffset,
    Color primary, Color textColor, Color secondaryColor, Color dividerColor,
    void Function(int) onSelected, {
    required bool isCall,
  }) {
    String labelFor(int offset) {
      if (offset == 0) return 'ATM';
      if (offset < 0) return 'ITM ${-offset}';
      return 'OTM $offset';
    }

    final key = isCall ? _callOffsetKey : _putOffsetKey;

    return GestureDetector(
      onTap: () => _showOffsetOverlay(
        key: key,
        currentOffset: currentOffset,
        primary: primary,
        textColor: textColor,
        isCall: isCall,
        onSelected: onSelected,
      ),
      child: Container(
        key: key,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: resolveThemeColor(
            context,
            dark: MyntColors.transparent,
            light: const Color(0xffF1F3F8),
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: resolveThemeColor(
              context,
              dark: MyntColors.textSecondaryDark,
              light: MyntColors.primary,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                labelFor(currentOffset),
                style: MyntWebTextStyles.body(
                  context,
                  darkColor: MyntColors.textWhite,
                  lightColor: MyntColors.textBlack,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: resolveThemeColor(
                context,
                dark: MyntColors.textSecondaryDark,
                light: MyntColors.textSecondary,
              ),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(
    BuildContext context, TextEditingController controller,
    Color dividerColor, Color textColor, Color primary,
  ) {
    return SizedBox(
      height: 40,
      child: MyntTextField(
        controller: controller,
        placeholder: '0',
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        backgroundColor: resolveThemeColor(
          context,
          dark: const Color(0xFF2A2A2A),
          light: const Color(0xFFF1F3F8),
        ),
        textStyle: MyntWebTextStyles.body(
          context,
          fontWeight: MyntFonts.medium,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildShortcutRow(BuildContext context, String shortcut, String description, Color actionColor) {
    // Parse the shortcut string to extract modifier and key
    final parts = shortcut.split(' + ');
    final keys = <LogicalKeyboardKey>[];

    for (var part in parts) {
      switch (part.trim().toLowerCase()) {
        case 'shift':
          keys.add(LogicalKeyboardKey.shift);
          break;
        case 'ctrl':
        case 'control':
          keys.add(LogicalKeyboardKey.control);
          break;
        case 'alt':
          keys.add(LogicalKeyboardKey.alt);
          break;
        case '↑':
          keys.add(LogicalKeyboardKey.arrowUp);
          break;
        case '↓':
          keys.add(LogicalKeyboardKey.arrowDown);
          break;
        case '←':
          keys.add(LogicalKeyboardKey.arrowLeft);
          break;
        case '→':
          keys.add(LogicalKeyboardKey.arrowRight);
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Use shadcn_flutter's built-in KeyboardDisplay
          shadcn.KeyboardDisplay(
            keys: keys,
          ).small(),
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: actionColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: MyntWebTextStyles.para(context, fontWeight: MyntFonts.medium,
                color: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Disable pointer events on all scalper chart containers and iframes
void _disableScalperCharts() {
  try {
    final iframes = html.document.querySelectorAll('iframe');
    for (var iframe in iframes) {
      if (iframe is html.IFrameElement) {
        iframe.style.pointerEvents = 'none';
        iframe.style.cursor = 'default';
      }
    }
    final divs = html.document.querySelectorAll('[id^="scalper-"]');
    for (var div in divs) {
      div.style.pointerEvents = 'none';
    }
    html.document.body?.style.cursor = 'default';
  } catch (e) {
  }
}

/// Re-enable pointer events on all scalper chart containers and iframes
void _enableScalperCharts() {
  try {
    final iframes = html.document.querySelectorAll('iframe');
    for (var iframe in iframes) {
      if (iframe is html.IFrameElement) {
        iframe.style.pointerEvents = 'auto';
        iframe.style.cursor = '';
      }
    }
    final divs = html.document.querySelectorAll('[id^="scalper-"]');
    for (var div in divs) {
      div.style.pointerEvents = 'auto';
    }
    html.document.body?.style.cursor = '';
  } catch (e) {
  }
}

/// Wrapper that disables scalper chart iframes while its subtree is mounted.
/// Automatically re-enables charts when the widget is disposed (e.g. sheet closed).
class _ChartIframeProtector extends StatefulWidget {
  final Widget child;
  const _ChartIframeProtector({required this.child});

  @override
  State<_ChartIframeProtector> createState() => _ChartIframeProtectorState();
}

class _ChartIframeProtectorState extends State<_ChartIframeProtector> {
  @override
  void initState() {
    super.initState();
    ChartIframeGuard.acquire();
    _disableScalperCharts();
  }

  @override
  void dispose() {
    ChartIframeGuard.release();
    _enableScalperCharts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(child: widget.child);
  }
}


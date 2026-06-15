import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mynt_plus/models/marketwatch_model/get_quotes.dart';
import 'package:mynt_plus/models/marketwatch_model/market_watch_scrip_model.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/screens/web/chart/web_chart_manager.dart';
import 'package:mynt_plus/screens/web/market_watch/scrip_depth_info_web.dart';
import 'package:mynt_plus/screens/web/market_watch/state/trade_from_chart_mode_provider.dart';
import 'package:mynt_plus/screens/web/market_watch/tv_chart/webview_chart.dart';
import 'package:mynt_plus/screens/web/market_watch/widgets/embedded_chart_view.dart';
import 'package:mynt_plus/screens/web/market_watch/options/option_chain_ss_web.dart';
import 'package:mynt_plus/screens/web/market_watch/search_dialog_web.dart';
import 'package:mynt_plus/screens/web/market_watch/set_alert_web.dart';
import 'package:mynt_plus/screens/web/market_watch/stock_report_web.dart';
import 'package:mynt_plus/screens/web/market_watch/scrip_detail_web.dart';
import 'package:mynt_plus/sharedWidget/common_buttons_web.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../../provider/websocket_provider.dart';
import 'tv_chart/chart_iframe_guard.dart';

class ChartWithDepthWeb extends ConsumerStatefulWidget {
  final DepthInputArgs wlValue;
  final String isBasket;

  const ChartWithDepthWeb(
      {super.key, required this.wlValue, this.isBasket = ""});

  @override
  ConsumerState<ChartWithDepthWeb> createState() => _ChartWithDepthWebState();
}

class _ChartWithDepthWebState extends ConsumerState<ChartWithDepthWeb>
    with TickerProviderStateMixin {
  String? _loadedToken;
  TabController? _tabController;
  VoidCallback?
      _tabControllerListener; // Store listener reference for proper cleanup
  int _selectedTabIndex = 0; // 0 for Overview, 1 for Chart, 2 for Options (if hasOptions), 2/3 for Stock Report
  bool _isBasketMode = false; // Track basket mode from OptionChainSSWeb
  VoidCallback? _toggleBasketModeCallback; // Callback to toggle basket mode
  BuildContext? _storedContext; // Store context for cleanup in dispose
  ProviderContainer? _storedContainer; // Store container for cleanup in dispose
  // bool _isDepthVisible = false; // Controlled by wlValue.showDepthInitially

  // LayerLink for persistent chart portal positioning
  final LayerLink _chartLayerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    // Store context and container for later use in dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _storedContext = context;
        try {
          _storedContainer = ProviderScope.containerOf(context, listen: false);
        } catch (e) {
          // Container might not be available yet
        }
        // Subscribe to depth data for Overview tab (default tab)
        // Pass context and scrip info to trigger WebSocket depth subscription (task "d")
        final mw = ref.read(marketWatchProvider);
        // Only subscribe if depth should be visible (Overview tab is default)
        // The initial tab is 0 (Overview) unless it's an option
        final initialTabIsOverview = !widget.wlValue.isOption;
        if (initialTabIsOverview || mw.isDepthVisible) {
          mw.setIsDepthVisibleWeb(
            true,
            context: context,
            exch: widget.wlValue.exch,
            token: widget.wlValue.token,
            tsym: widget.wlValue.tsym,
          );
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChartWithDepthWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if isOption flag changed (even for the same scrip)
    if (oldWidget.wlValue.isOption != widget.wlValue.isOption) {
      if (_tabController != null) {
        // Options tab is now at index 2 (Overview=0, Chart=1, Options=2)
        final targetIndex = widget.wlValue.isOption ? 2 : 0;
        if (_tabController!.index != targetIndex) {
          _tabController!.animateTo(targetIndex);
        }
      }
    }

    if (oldWidget.wlValue.token != widget.wlValue.token ||
        oldWidget.wlValue.exch != widget.wlValue.exch) {
      // Clear fundamental data silently (without notifyListeners) to prevent
      // stale data. The notification is deferred to after the build phase.
      ref.read(marketWatchProvider).clearFundamentalDataSilent();

      // Reset depth subscription for new scrip when scrip changes
      // Delay provider modification until after build phase completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final mw = ref.read(marketWatchProvider);
          // Use _selectedTabIndex instead of _tabController?.index ?? 0
          // This prevents defaulting to 0 (Overview) when tab controller isn't ready
          // and preserves the user's current tab state
          final isOverviewTab = _selectedTabIndex == 0;

          // Only change depth visibility if we're on Overview tab
          // For other tabs (Chart, Options, Stock Report), preserve current depth state
          // This prevents depth from opening and closing when switching symbols
          if (isOverviewTab) {
            // Overview tab: show depth with new scrip data
            mw.setIsDepthVisibleWeb(
              true,
              context: context,
              exch: widget.wlValue.exch,
              token: widget.wlValue.token,
              tsym: widget.wlValue.tsym,
            );
          }
          // Note: We don't hide depth on other tabs here anymore
          // Depth visibility is managed by the tab listener when user switches tabs
        }
      });

      Future.microtask(() async {
        await _ensureDataLoaded(force: true);

        // If Options tab is active when scrip changes, prepare options for new scrip
        // Options tab is now at index 2 (Overview=0, Chart=1, Options=2)
        final mw = ref.read(marketWatchProvider);
        final hasOptions =
            mw.getOptionawait(widget.wlValue.exch, widget.wlValue.token);
        if (hasOptions && (_tabController?.index ?? 0) == 2) {
          mw.setOptionScript(context, widget.wlValue.exch, widget.wlValue.token,
              widget.wlValue.tsym);
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove listener before disposing to prevent memory leaks
    if (_tabController != null && _tabControllerListener != null) {
      _tabController!.removeListener(_tabControllerListener!);
      _tabControllerListener = null;
    }
    _tabController?.dispose();
    _tabController = null;

    // Hide inline chart portal when this widget is disposed.
    // Use hideInlineChartSilent to avoid notifyListeners during unmount,
    // which would trigger "Tried to modify a provider while the widget tree was building".
    if (_storedContainer != null) {
      try {
        _storedContainer!.read(userProfileProvider).hideInlineChartSilent();
      } catch (e) {
        // Ignore if provider is not available
      }
    }

    // Unsubscribe from depth data using stored container (ref is not available in dispose)
    if (_storedContainer != null) {
      try {
        final mw = _storedContainer!.read(marketWatchProvider);
        if (_storedContext != null && _storedContext!.mounted) {
          mw.unsubscribeFromDepthData(context: _storedContext);
        } else {
          // Context not mounted, but still try to unsubscribe without context
          mw.unsubscribeFromDepthData(context: _storedContext);
        }
      } catch (e) {
        // Depth will be cleaned up when scrip changes anyway
      }
    }

    super.dispose();
  }

  Future<void> _ensureDataLoaded({bool force = false}) async {
    final mw = ref.read(marketWatchProvider);
    final currentToken = mw.getQuotes?.token?.toString();
    final targetToken = widget.wlValue.token;

    if (force || _loadedToken != targetToken || currentToken != targetToken) {
      // Only load if it's a different scrip - calldepthApis handles duplicate prevention internally
      mw.scripdepthsize(false);
      await mw.calldepthApis(context, widget.wlValue, "");
      // Keep chart in sync with the same scrip
      mw.setChartScript(
          widget.wlValue.exch, widget.wlValue.token, widget.wlValue.tsym);
      _loadedToken = targetToken;
    }
  }

  void _setupTabControllerIfNeeded({required bool hasOptions, required bool hasFundamentalData}) {
    // Tab structure depends on hasOptions and hasFundamentalData:
    // - hasOptions && hasFundamentalData: [Overview, Chart, Options, Stock Report] (4 tabs)
    // - hasOptions && !hasFundamentalData: [Overview, Chart, Options] (3 tabs)
    // - !hasOptions && hasFundamentalData: [Overview, Chart, Stock Report] (3 tabs)
    // - !hasOptions && !hasFundamentalData: [Overview, Chart] (2 tabs)
    int targetLength = 2; // Base: Overview, Chart
    if (hasOptions) targetLength++; // +1 for Options
    if (hasFundamentalData) targetLength++; // +1 for Stock Report

    if (_tabController == null || _tabController!.length != targetLength) {
      // Preserve the current selected tab index if possible
      final previousIndex = _selectedTabIndex;

      // Remove old listener before disposing to prevent memory leaks
      if (_tabController != null && _tabControllerListener != null) {
        _tabController!.removeListener(_tabControllerListener!);
        _tabControllerListener = null;
      }
      _tabController?.dispose();

      // Determine initial index:
      // 1. If we had a previous selection, try to preserve it (clamped to valid range)
      // 2. Otherwise, use Options tab (index 2) if isOption, else Overview (index 0)
      int initialIndex;
      if (previousIndex > 0 && previousIndex < targetLength) {
        // Preserve current tab if it's still valid
        initialIndex = previousIndex;
      } else if (previousIndex >= targetLength) {
        // If previous index is out of range (e.g., Stock Report tab was removed), go to last valid tab
        initialIndex = targetLength - 1;
      } else {
        // Default: Options tab is at index 2 when hasOptions and isOption
        initialIndex = widget.wlValue.isOption && hasOptions ? 2 : 0;
      }

      _tabController = TabController(
          length: targetLength, vsync: this, initialIndex: initialIndex);
      _selectedTabIndex = _tabController!.index;
      // Store listener reference for proper cleanup
      _tabControllerListener = () {
        // Update UI when tab changes (for search icon visibility)
        if (mounted && _tabController!.indexIsChanging == false) {
          final currentIndex = _tabController!.index;
          setState(() {
            _selectedTabIndex = currentIndex;
          });

          // Handle depth visibility based on tab
          // Get fresh values from provider
          final mw = ref.read(marketWatchProvider);
          final currentHasOptions = mw.getOptionawait(widget.wlValue.exch, widget.wlValue.token);

          if (currentIndex == 0) {
            // Overview tab: show depth and subscribe to depth WebSocket
            mw.setIsDepthVisibleWeb(
              true,
              context: context,
              exch: widget.wlValue.exch,
              token: widget.wlValue.token,
              tsym: widget.wlValue.tsym,
            );
          } else {
            // All other tabs (Chart, Options, Stock Report): hide depth
            mw.setIsDepthVisibleWeb(false, context: context);
          }

          // Options tab is at index 2 when hasOptions
          if (currentHasOptions && currentIndex == 2) {
          // Prepare option chain data when switching to Options tab
          mw.setOptionScript(context, widget.wlValue.exch, widget.wlValue.token,
              widget.wlValue.tsym);
          }
        }
      };
      _tabController!.addListener(_tabControllerListener!);
    }
  }

  Future<void> _placeOrderInput(
      BuildContext ctx, GetQuotes? depthData, bool transType) async {
    if (depthData == null) return;

    await ref.read(marketWatchProvider).fetchScripInfo(
        widget.wlValue.token, widget.wlValue.exch, context, true);

    // Use lot size from scripInfoModel if available, otherwise use depthData
    final lotSize = depthData.ls?.isNotEmpty == true
        ? depthData.ls
        : ref.read(marketWatchProvider).scripInfoModel?.ls.toString();

    OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: widget.wlValue.exch,
        tSym: widget.wlValue.tsym,
        isExit: false,
        token: widget.wlValue.token,
        transType: transType,
        lotSize: lotSize,
        ltp: "${depthData.lp ?? depthData.c ?? 0.00}",
        perChange: depthData.pc ?? "0.00",
        orderTpye: '',
        holdQty: '',
        isModify: false,
        raw: {});

    ResponsiveNavigation.toPlaceOrderScreen(
      context: ctx,
      arguments: {
        "orderArg": orderArgs,
        "scripInfo": ref.read(marketWatchProvider).scripInfoModel!,
        "isBskt": widget.isBasket
      },
    );
  }

  void _showStrikesDropdown(BuildContext context, MarketWatchProvider mw) {
    final numStrikes = mw.numStrikes;
    final numStrike = mw.numStrike;

    shadcn.showPopover(
      context: context,
      alignment: Alignment.bottomCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (popoverContext) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(popoverContext).borderRadiusLg,
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
              width: 150,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: numStrikes.map((String value) {
                    final isSelected = value == numStrike;
                    return _buildStrikeMenuItem(
                      popoverContext,
                      value,
                      isSelected,
                      () async {
                        shadcn.closeOverlay(popoverContext);
                        mw.selecNumStrike(value);
                        await mw.fetchOPtionChain(
                          context: popoverContext,
                          exchange: mw.optionExch!,
                          numofStrike: value,
                          strPrc: mw.optionStrPrc,
                          tradeSym: mw.selectedTradeSym!,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStrikeMenuItem(
    BuildContext context,
    String title,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: isActive ? MyntFonts.semiBold : MyntFonts.medium,
                    color: isActive
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
              if (isActive)
                Icon(
                  Icons.check,
                  size: 18,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark,
                    light: MyntColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mw = ref.watch(marketWatchProvider);
    final hasOptions =
        mw.getOptionawait(widget.wlValue.exch, widget.wlValue.token);
    final depthData = mw.getQuotes;
    // Check if fundamental data is available for Stock Report tab
    final hasFundamentalData = mw.fundamentalData != null &&
        mw.fundamentalData?.msg != "no data found";
    _setupTabControllerIfNeeded(hasOptions: hasOptions, hasFundamentalData: hasFundamentalData);

    return Container(
      color: resolveThemeColor(context,
          dark: MyntColors.backgroundColorDark,
          light: MyntColors.backgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Header - Full Width
          Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: shadcn.Theme.of(context).colorScheme.card,
                        border: Border(
                          bottom: BorderSide(
                            color: resolveThemeColor(
                              context,
                              dark: MyntColors.dividerDark,
                              light: MyntColors.divider,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tabs
                          _buildSegmentedControl(context, hasOptions, hasFundamentalData),
                          const Spacer(),
                          // Right side: Buy/Sell/Alert/Sidebar icons
                          // Hide for indices (UNDIND/idx=yes) and commodities (COM)
                          if (widget.wlValue.instname != "UNDIND" &&
                              widget.wlValue.instname != "COM" &&
                              widget.wlValue.idx != "yes" &&
                              mw.scripInfoModel?.idx != "yes") ...[
                            // Buy button
                            SizedBox(
                              width: 70,
                              height: 32,
                              child: MyntButton(
                                label: "Buy",
                                size: MyntButtonSize.small,
                                backgroundColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.secondary,
                                    light: MyntColors.primary),
                                textColor: Colors.white,
                                onPressed: () async {
                                  await _placeOrderInput(context, depthData, true);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Sell button
                            SizedBox(
                              width: 70,
                              height: 32,
                              child: MyntButton(
                                label: "Sell",
                                size: MyntButtonSize.small,
                                backgroundColor: resolveThemeColor(
                                    context,
                                    dark: MyntColors.errorDark,
                                    light: MyntColors.tertiary),
                                textColor: Colors.white,
                                onPressed: () async {
                                  await _placeOrderInput(context, depthData, false);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Create Alert icon
                            Tooltip(
                              message: "Set Alert",
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
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
                                  onTap: () {
                                    if (depthData == null) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (BuildContext dialogContext) {
                                        return SetAlertWeb(
                                          depthdata: depthData,
                                          wlvalue: widget.wlValue,
                                        );
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.notifications_none_outlined,
                                      size: 20,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.iconDark,
                                        light: MyntColors.icon,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Scrip Info icon
                            Tooltip(
                              message: "Scrip Info",
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
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
                                  onTap: () async {
                                    // Fetch scrip info before showing dialog
                                    await ref.read(marketWatchProvider).fetchScripInfo(
                                        widget.wlValue.token, widget.wlValue.exch, context, true);
                                    if (!context.mounted) return;
                                    showDialog(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (BuildContext dialogContext) {
                                        return const _ScripInfoDialogWrapper();
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: resolveThemeColor(
                                        context,
                                        dark: MyntColors.iconDark,
                                        light: MyntColors.icon,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Sidebar toggle icon — always visible. The depth
                          // panel is user-controlled and stays open/closed
                          // independent of the Trade-from-Chart mode.
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
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
                              onTap: () {
                                ref
                                    .read(marketWatchProvider)
                                    .setIsDepthVisibleWeb(
                                      !mw.isDepthVisible,
                                      context: context,
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  mw.isDepthVisible
                                      ? Icons.view_sidebar
                                      : Icons.view_sidebar_outlined,
                                  size: 20,
                                  color: mw.isDepthVisible
                                      ? resolveThemeColor(context,
                                          dark: MyntColors.primaryDark,
                                          light: MyntColors.primary)
                                      : resolveThemeColor(context,
                                          dark: MyntColors.iconDark,
                                          light: MyntColors.icon),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Secondary Header (Options-specific controls) - Only visible when Options tab is active
                    if (hasOptions && _selectedTabIndex == 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: shadcn.Theme.of(context).colorScheme.card),
                          border: Border(
                            bottom: BorderSide(
                              color: resolveThemeColor(
                                context,
                                dark: MyntColors.dividerDark,
                                light: MyntColors.divider,
                              ),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Symbol name + LTP + Price change (Options only)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${(depthData?.symname ?? depthData?.symbol ?? depthData?.tsym ?? widget.wlValue.symbol).replaceAll('-EQ', '').toUpperCase()}${depthData?.expDate ?? widget.wlValue.expDate} ${depthData?.option ?? widget.wlValue.option} ",
                                  overflow: TextOverflow.ellipsis,
                                  style: MyntWebTextStyles.title(
                                    context,
                                    fontWeight: MyntFonts.medium,
                                    darkColor: MyntColors.textPrimaryDark,
                                    lightColor: MyntColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                StreamBuilder<Map>(
                                  stream: ref
                                      .read(websocketProvider)
                                      .socketDataStream,
                                  builder: (context, snapshot) {
                                    // CRITICAL FIX: Fall back to existing socket data
                                    final socketDatas = snapshot.data ?? ref.read(websocketProvider).socketDatas;
                                    final currentToken =
                                        depthData?.token?.toString() ??
                                            widget.wlValue.token;
                                    String ltp =
                                        depthData?.lp ?? depthData?.c ?? '0.00';
                                    String ch = depthData?.chng ?? '0.00';
                                    String pc = depthData?.pc ?? '0.00';
                                    if (socketDatas.containsKey(currentToken)) {
                                      final s = socketDatas[currentToken];
                                      ltp = "${s['lp'] ?? s['c'] ?? ltp}";
                                      ch = "${s['chng'] ?? ch}";
                                      pc = "${s['pc'] ?? pc}";
                                    }
                                    final ltpStr = (double.tryParse(ltp) ?? 0)
                                        .toStringAsFixed(2);
                                    final chVal = double.tryParse(ch) ?? 0;
                                    final pcVal = double.tryParse(pc) ?? 0;
                                    final chStr = chVal.toStringAsFixed(2);
                                    final pcStr = pcVal.toStringAsFixed(2);
                                    final isUp = pcVal >= 0;

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          ltpStr,
                                          style: MyntWebTextStyles.body(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            color: isUp
                                                ? resolveThemeColor(context,
                                                    dark: MyntColors.profitDark,
                                                    light: MyntColors.profit)
                                                : resolveThemeColor(context,
                                                    dark: MyntColors.lossDark,
                                                    light: MyntColors.loss),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "$chStr ($pcStr%)",
                                          style: MyntWebTextStyles.para(
                                            context,
                                            fontWeight: MyntFonts.medium,
                                            darkColor:
                                                MyntColors.textPrimaryDark,
                                            lightColor: MyntColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            // Expiry date selector
                            Builder(
                              builder: (buttonContext) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
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
                                    onTap: () {
                                      _showExpiryDatePopup(buttonContext, mw);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.dividerDark,
                                            light: MyntColors.divider,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            mw.selectedExpDate
                                                    ?.replaceAll("-", " ") ??
                                                '',
                                            style: MyntWebTextStyles.body(
                                              context,
                                              fontWeight: MyntFonts.medium,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 16,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.iconDark,
                                              light: MyntColors.icon,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            // Strikes dropdown
                            Builder(
                              builder: (buttonContext) {
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
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
                                    onTap: () {
                                      _showStrikesDropdown(buttonContext, mw);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: resolveThemeColor(
                                            context,
                                            dark: MyntColors.dividerDark,
                                            light: MyntColors.divider,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "${mw.numStrike} Strike",
                                            style: MyntWebTextStyles.body(
                                              context,
                                              fontWeight: MyntFonts.medium,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 16,
                                            color: resolveThemeColor(
                                              context,
                                              dark: MyntColors.iconDark,
                                              light: MyntColors.icon,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Basket mode toggle button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
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
                                onTap: () {
                                  _toggleBasketModeCallback?.call();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    _isBasketMode
                                        ? Icons.shopping_basket
                                        : Icons.shopping_basket_outlined,
                                    size: 20,
                                    color: _isBasketMode
                                        ? resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary)
                                        : resolveThemeColor(
                                            context,
                                            dark: MyntColors.iconDark,
                                            light: MyntColors.icon,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          // Content area below headers
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chart/Options/Stock Report area - 100% when depth hidden, 70% when visible
                Expanded(
                  flex: mw.isDepthVisible ? 7 : 1,
                  child: _buildContentArea(hasOptions, hasFundamentalData, depthData),
                ),
                // Divider between chart and depth (only when depth is visible)
                if (mw.isDepthVisible)
                  Container(
                    width: 1,
                    color: resolveThemeColor(
                      context,
                      dark: MyntColors.dividerDark,
                      light: MyntColors.divider,
                    ),
                  ),
                // Depth/Overview area - 30% (only when visible)
                if (mw.isDepthVisible)
                  Expanded(
                    flex: 3,
                    child: ScripDepthInfoWeb(
                      wlValue: widget.wlValue,
                      isBasket: widget.isBasket,
                      onClose: () {
                        mw.setIsDepthVisibleWeb(false);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiryDatePopup(BuildContext context, MarketWatchProvider mw) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.bottomCenter,
      offset: const Offset(0, 4),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (popoverContext) {
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
              width: 200,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: mw.sortDate.map((date) {
                      return _buildExpiryMenuItem(
                        popoverContext,
                        date,
                        mw,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiryMenuItem(
    BuildContext context,
    String date,
    MarketWatchProvider mw,
  ) {
    final isSelected = date == mw.selectedExpDate;
    final primaryColor = resolveThemeColor(
      context,
      dark: MyntColors.primaryDark,
      light: MyntColors.primary,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          shadcn.closeOverlay(context);
          if (date != mw.selectedExpDate) {
            for (var i = 0; i < (mw.optExp?.length ?? 0); i++) {
              if (date == mw.optExp![i].exd) {
                mw.selecTradSym("${mw.optExp![i].tsym}");
                mw.optExch("${mw.optExp![i].exch}");
              }
            }
            mw.selecexpDate(date);

            await mw.fetchOPtionChain(
              context: this.context,
              exchange: mw.optionExch!,
              numofStrike: mw.numStrike,
              strPrc: mw.optionStrPrc,
              tradeSym: mw.selectedTradeSym!,
            );
          }
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date.replaceAll("-", " "),
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight:
                        isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                    color: isSelected
                        ? primaryColor
                        : resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                child: isSelected
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check,
                            size: 18,
                            color: primaryColor,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(bool hasOptions, bool hasFundamentalData, GetQuotes? depthData) {
    // Stock Report tab index depends on whether Options tab exists
    // Options is always at index 2 if it exists
    // Stock Report comes after Options (if exists), so index is 3 if hasOptions, 2 if !hasOptions
    // But Stock Report only shows if hasFundamentalData is true
    final stockReportIndex = hasOptions ? 3 : 2;

    // Options tab (index 2) - only when hasOptions
    if (hasOptions && _selectedTabIndex == 2) {
      return OptionChainSSWeb(
        wlValue: widget.wlValue,
        onBasketModeChanged: (bool isBasketMode) {
          setState(() {
            _isBasketMode = isBasketMode;
          });
        },
        onToggleCallbackReady: (VoidCallback toggleCallback) {
          setState(() {
            _toggleBasketModeCallback = toggleCallback;
          });
        },
        onChartRequested: () {
          // Defer one frame: a strike change can trigger _setupTabControllerIfNeeded
          // to dispose and recreate _tabController (e.g. underlying with fundamentals
          // -> option without fundamentals: 4 tabs -> 3 tabs). Switching synchronously
          // would target the old controller and the recreated one would land back on
          // its initialIndex.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_tabController != null && _tabController!.index != 1) {
              _tabController!.animateTo(1);
            }
          });
        },
      );
    }

    // Stock Report tab - only if hasFundamentalData
    if (hasFundamentalData && _selectedTabIndex == stockReportIndex && depthData != null) {
      return NewFundamentalScreen(
        wlValue: widget.wlValue,
        depthData: depthData,
        showHeader: false,
      );
    }

    // Overview (index 0) and Chart (index 1) tabs - show chart via persistent portal
    // UNLESS the user has toggled "Trade from Chart" on, in which case the
    // in-house chart engine replaces the TradingView portal here.
    final tradeFromChart = ref.watch(tradeFromChartModeProvider);
    if (tradeFromChart) {
      // Hide the TradingView portal so it doesn't bleed through behind the
      // embedded iframe. The portal stays mounted (its state persists) —
      // we just flip its visibility flag.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(userProfileProvider).hideInlineChart();
      });
      return EmbeddedChartView(wlValue: widget.wlValue);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Set up the portal target and update symbol
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // IMPORTANT: Change symbol FIRST (before making chart visible)
            // This ensures the correct symbol is ready when the chart appears
            // and avoids showing a flash of the old symbol
            webChartManager.changeSymbol(
              exch: widget.wlValue.exch,
              token: widget.wlValue.token,
              tsym: widget.wlValue.tsym,
              isDarkMode: ref.read(themeProvider).isDarkMode,
            );
            // Then update portal position and make it visible
            ref.read(userProfileProvider).setInlineChartTarget(
              _chartLayerLink,
              Size(constraints.maxWidth, constraints.maxHeight),
            );
          }
        });

        // Return placeholder target that the portal follows
        return CompositedTransformTarget(
          link: _chartLayerLink,
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.transparent, // Transparent placeholder, chart renders via portal
          ),
        );
      },
    );
  }

  Widget _buildSegmentedControl(BuildContext context, bool hasOptions, bool hasFundamentalData) {
    // Build tabs list dynamically based on options and fundamental data availability
    final tabs = <String>['Overview', 'Chart'];
    if (hasOptions) tabs.add('Options');
    if (hasFundamentalData) tabs.add('Stock Report');

    final theme = shadcn.Theme.of(context);
    final isDark = isDarkMode(context);

    final tradeFromChart = ref.watch(tradeFromChartModeProvider);
    final accent = resolveThemeColor(context,
        dark: MyntColors.primaryDark, light: MyntColors.primary);
    // The Trade from Chart pill only makes sense when the chart area is
    // actually visible — Overview (0) and Chart (1) tabs. Hidden on
    // Options / Stock Report tabs where the chart isn't shown.
    final showTradeFromChartPill =
        _selectedTabIndex == 0 || _selectedTabIndex == 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int index = 0; index < tabs.length; index++) ...[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (mounted && _selectedTabIndex != index && _tabController != null) {
                  // Just animate to the new tab - the listener will handle state updates
                    _tabController!.animateTo(index);
                  }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == index
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: null,
                ),
                child: Text(
                  tabs[index],
                  style: MyntWebTextStyles.body(
                    context,
                    fontWeight: _selectedTabIndex == index
                        ? MyntFonts.semiBold
                        : MyntFonts.medium,
                  ).copyWith(
                    color: _selectedTabIndex == index
                        ? theme.colorScheme.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          if (index < tabs.length - 1) const SizedBox(width: 8),
        ],
        // "Trade from Chart" toggle pill — swaps the chart area between
        // the TradingView portal (OFF, default) and our in-house chart
        // engine (ON). Persisted via SharedPreferences per session. Only
        // visible on Overview/Chart tabs (chart-bearing tabs).
        if (showTradeFromChartPill) ...[
        const SizedBox(width: 16),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () =>
                ref.read(tradeFromChartModeProvider.notifier).toggle(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tradeFromChart
                    ? accent
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tradeFromChart
                      ? accent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.candlestick_chart,
                    size: 14,
                    color: tradeFromChart
                        ? Colors.white
                        : theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Trade from Chart',
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: MyntFonts.semiBold,
                    ).copyWith(
                      color: tradeFromChart
                          ? Colors.white
                          : theme.colorScheme.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ],
    );
  }
}

/// Wrapper widget for ScripDetailWeb dialog to prevent chart cursor bleeding through
class _ScripInfoDialogWrapper extends StatefulWidget {
  const _ScripInfoDialogWrapper();

  @override
  State<_ScripInfoDialogWrapper> createState() => _ScripInfoDialogWrapperState();
}

class _ScripInfoDialogWrapperState extends State<_ScripInfoDialogWrapper> {
  // Disable all chart iframes to prevent cursor bleeding
  void _disableAllChartIframes() {
    if (!kIsWeb) return;
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          iframe.style.cursor = 'default';
        }
      }
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  // Re-enable chart iframes when dialog closes
  void _enableAllChartIframes() {
    if (!kIsWeb) return;
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  @override
  void dispose() {
    ChartIframeGuard.release();
    _enableAllChartIframes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.transparent,
      child: PointerInterceptor(
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) {
            ChartIframeGuard.acquire();
            _disableAllChartIframes();
          },
          onHover: (_) {
            _disableAllChartIframes();
          },
          onExit: (_) {
            ChartIframeGuard.release();
            _enableAllChartIframes();
          },
          child: Listener(
            onPointerMove: (_) {
              _disableAllChartIframes();
            },
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating to background
              child: const ScripDetailWeb(),
            ),
          ),
        ),
      ),
    );
  }
}

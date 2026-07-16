import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/screens/web/ordersbook/basket/basket_list_web.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/notification_provider.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/res.dart';
import '../../../res/web_colors.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../res/responsive_extensions.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../sharedWidget/splash_loader.dart';
import 'orders_download_helper.dart';
// import 'mf/mf_order_book_screen_web.dart';
// import 'mf/mf_sip_screen_web.dart';
import 'pending_alert_card_web.dart';
import 'screens/open_orders_screen.dart';
import 'screens/executed_orders_screen.dart';
import 'screens/trade_book_screen.dart';
import 'screens/gtt_orders_screen.dart';
import 'screens/sip_orders_screen_web.dart';
import '../../../sharedWidget/common_search_fields_web.dart';
import '../../../sharedWidget/custom_text_form_field.dart' show UpperCaseTextFormatter;
import '../../../models/order_book_model/order_book_model.dart';
import 'cancel_all_orders_dialog_web.dart';

/// Main Order Book Screen - Now just a coordinator
/// All table logic is in separate screen widgets
class OrderBookScreenWeb extends ConsumerStatefulWidget {
  const OrderBookScreenWeb({super.key});

  @override
  ConsumerState<OrderBookScreenWeb> createState() => _OrderBookScreenWebState();
}

class _OrderBookScreenWebState extends ConsumerState<OrderBookScreenWeb>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final ScrollController _openOrdersHorizontalScrollController =
      ScrollController();
  final ScrollController _openOrdersVerticalScrollController =
      ScrollController();
  final ScrollController _executedOrdersHorizontalScrollController =
      ScrollController();
  final ScrollController _executedOrdersVerticalScrollController =
      ScrollController();
  final ScrollController _tradeBookHorizontalScrollController =
      ScrollController();
  final ScrollController _tradeBookVerticalScrollController =
      ScrollController();
  final ScrollController _gttVerticalScrollController = ScrollController();
  final ScrollController _gttHorizontalScrollController = ScrollController();
  final ScrollController _sipVerticalScrollController = ScrollController();
  final ScrollController _sipHorizontalScrollController = ScrollController();
  final ScrollController _tabScrollController = ScrollController();

  // MF tab state
  int _mfTabIndex = 0; // 0 for Orders, 1 for SIP

  // Track initialization state
  bool _isInitialized = false;

  // Store reference to search controller for safe disposal
  TextEditingController? _orderSearchCtrl;

  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  // Refresh state
  bool _isRefreshing = false;

  // Cache LayoutBuilder constraints to avoid unnecessary callbacks
  BoxConstraints? _lastConstraints;

  void _updateScrollArrows() {
    if (!mounted) return;
    // Additional safety check to prevent setState after dispose
    try {
      if (!_tabScrollController.hasClients) return;
      final newCanScrollLeft = _tabScrollController.offset > 0;
      final newCanScrollRight =
          _tabScrollController.offset < _tabScrollController.position.maxScrollExtent;

      // Only call setState if values actually changed
      if (_canScrollLeft != newCanScrollLeft || _canScrollRight != newCanScrollRight) {
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

  // Refresh orders based on current tab
  Future<void> _refreshOrders() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final orderBook = ref.read(orderProvider);
      final currentTab = _tabController?.index ?? orderBook.selectedTab;

      switch (currentTab) {
        case 0: // Open Orders
        case 1: // Executed Orders
          await orderBook.fetchOrderBook(context, true);
          break;
        case 2: // Trade Book
          await orderBook.fetchTradeBook(context);
          break;
        case 3: // GTT Orders
          if (orderBook.showTriggeredGtt) {
            await orderBook.fetchTriggeredGTTOrders(context);
          } else {
            await orderBook.fetchGTTOrderBook(context, "");
          }
          break;
        case 4: // Basket
          await orderBook.getBasketName();
          break;
        case 5: // SIP — previous code wrongly fetched pending alerts here
          // because the case was mislabeled. Tab 5 is the SIP screen
          // (see _buildTabContent at the bottom of this file).
          await orderBook.fetchSipOrderHistory(context);
          break;
        case 6: // Pending Alerts — Alerts is tab index 6, not 5.
          await ref.read(marketWatchProvider).fetchPendingAlert(context);
          await ref.read(notificationprovider).fetchbrokermsg(context);
          break;
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _setupListeners() {
    _tabScrollController.addListener(_updateScrollArrows);
    // Initial check - use addPostFrameCallback for safer initial update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollArrows();
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize non-blocking components immediately
    try {
      FirebaseAnalytics.instance.logScreenView(
      screenName: 'Order Book Screen Web',
      screenClass: 'OrderBookScreenWeb',
    );
    } catch (e) {
    }

    // Defer heavy operations until after UI renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHeavyComponents();
      _setupSearchListener();
      _setupListeners();
    });
  }

  void _setupSearchListener() {
    if (!mounted) return;
    final orderBook = ref.read(orderProvider);
    _orderSearchCtrl = orderBook.orderSearchCtrl;
    _orderSearchCtrl?.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final orderBook = ref.read(orderProvider);
    final context = this.context;
    if (context.mounted) {
      // Ensure _selectedTab is synced with current tab controller index
      final currentTabIndex = _tabController?.index ?? orderBook.selectedTab;
      if (currentTabIndex != orderBook.selectedTab) {
        // Sync the tab index if it's out of sync
        orderBook.changeTabIndex(currentTabIndex, context);
      }
      orderBook.searchOrders(orderBook.orderSearchCtrl.text, context);
    }
  }

  void _initializeHeavyComponents() async {
    if (!mounted) return;

    try {
      // Initialize TabController after UI renders
      final orderProviderRef = ref.read(orderProvider);
      _tabController = TabController(
        length: orderProviderRef.orderTabName.length,
        vsync: this,
        initialIndex: orderProviderRef.selectedTab, // Use current selected tab from provider
      );

      // Sync the provider's tab controller with this local one
      orderProviderRef.tabCtrl = _tabController!;

      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          // Only call when tab change is complete, not during animation
          if (mounted) {
            final orderBook = ref.read(orderProvider);

            // Clear search when tab change completes (prevents showing wrong data)
            orderBook.clearOrderSearch();

            // Update tab index in provider - this will handle all tab-related logic
            orderBook.changeTabIndex(_tabController!.index, context);

            setState(() {
              // Trigger rebuild to update tab selection UI
            });
          }
        }
      });

      // Initialize the first tab (Open Orders) immediately to set up WebSocket
      if (mounted) {
        final orderProviderRef = ref.read(orderProvider);
        orderProviderRef.changeTabIndex(0, context);
        // Force WebSocket subscription for order tokens
        // (changeTabIndex may skip if already on tab 0, so call directly)
        orderProviderRef.requestWSOrderBook(isSubscribe: true, context: context);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Fallback initialization
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // Remove search listener using stored reference (safe during dispose)
    _orderSearchCtrl?.removeListener(_onSearchChanged);

    // Remove scroll listener BEFORE disposing the controller to prevent
    // "Trying to render a disposed EngineFlutterView" error
    _tabScrollController.removeListener(_updateScrollArrows);

    _tabController?.dispose();
    _openOrdersHorizontalScrollController.dispose();
    _openOrdersVerticalScrollController.dispose();
    _executedOrdersHorizontalScrollController.dispose();
    _executedOrdersVerticalScrollController.dispose();
    _tradeBookHorizontalScrollController.dispose();
    _tradeBookVerticalScrollController.dispose();
    _gttVerticalScrollController.dispose();
    _gttHorizontalScrollController.dispose();
    _sipVerticalScrollController.dispose();
    _sipHorizontalScrollController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    // Always show the UI structure immediately for better UX
    // DrawerOverlay is now at app level in main.dart
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.isDarkMode ? MyntColors.backgroundColorDark : Colors.white,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isInitialized
            ? _buildInitializedContent(theme)
            : _buildLoadingContent(theme),
      ),
    );
  }

  Widget _buildInitializedContent(ThemesProvider theme) {
    // Only watch the specific fields we need for reactive UI updates
    final orderTabName = ref.watch(orderProvider.select((p) => p.orderTabName));
    final orderBook = ref.read(orderProvider);

    return SizedBox.expand(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(orderProvider).fetchOrderBook(context, true);
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Content Area (includes tabs and search bar)
              Expanded(
                child: _buildMainContent(theme, orderBook, orderTabName),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent(ThemesProvider theme) {
    return const CircularLoaderImage();
  }

  Widget _buildMainContent(ThemesProvider theme, OrderProvider orderBook, List<Tab> orderTabName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs and Search Bar in same row
        _buildTabsAndActionBar(theme, orderBook, orderTabName),

        // Content Area - Now just delegates to separate screens
        Expanded(
          child: _buildContentArea(theme, orderBook),
        ),
      ],
    );
  }

  Widget _buildTabsAndActionBar(ThemesProvider theme, OrderProvider orderBook, List<Tab> orderTabName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Only update scroll arrows when constraints actually change
          if (_lastConstraints != constraints) {
            _lastConstraints = constraints;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _updateScrollArrows();
            });
          }

          final double availableWidth = constraints.maxWidth;
          double searchWidth;
          if (availableWidth >= 1100) {
            searchWidth = 400;
          } else if (availableWidth >= 800) {
            searchWidth = 300;
          } else if (availableWidth >= 500) {
            searchWidth = 200;
          } else {
            searchWidth = 140;
          }

          return Row(
            children: [
              // Shadcn TabList on the left - Direct implementation for better responsiveness
              // Wrap with shadcn.Theme to use custom primary color for active tab
              Expanded(
                child: Row(
                  children: [
                    if (availableWidth < 1300)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: _canScrollLeft
                              ? () => _scrollTabs(left: true)
                              : null,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: _canScrollLeft
                                  ? (theme.isDarkMode
                                      ? Colors.white
                                      : Colors.black)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _tabScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(orderTabName.length, (tabIndex) {
                            final tabString = orderTabName[tabIndex];
                            final parts = tabString.text?.split(' ') ?? [];
                            final title = parts.first;
                            final badge = parts.length > 1 ? parts[1] : null;

                            final isActive =
                                (_tabController?.index ?? 0) == tabIndex;

                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  if (_tabController != null &&
                                      _tabController!.index != tabIndex) {
                                    _tabController!.animateTo(tabIndex);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (theme.isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.05))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: MyntWebTextStyles.body(
                                          context,
                                          fontWeight: isActive
                                              ? MyntFonts.semiBold
                                              : MyntFonts.medium,
                                        ).copyWith(
                                          color: isActive
                                              ? shadcn.Theme.of(context)
                                                  .colorScheme
                                                  .foreground
                                              : shadcn.Theme.of(context)
                                                  .colorScheme
                                                  .mutedForeground,
                                        ),
                                      ),
                                      if (badge != null) ...[
                                        const SizedBox(width: 4),
                                        Transform.translate(
                                          offset: const Offset(0, -6),
                                          child: Text(
                                            badge,
                                            style: MyntWebTextStyles.bodySmall(
                                              context,
                                              fontWeight: isActive
                                                  ? MyntFonts.semiBold
                                                  : MyntFonts.medium,
                                            ).copyWith(
                                              fontSize: 13,
                                              color: isActive
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
                            );
                          }),
                        ),
                      ),
                    ),
                    if (availableWidth < 1300)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: InkWell(
                          onTap: _canScrollRight
                              ? () => _scrollTabs(left: false)
                              : null,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: _canScrollRight
                                  ? (theme.isDarkMode
                                      ? Colors.white
                                      : Colors.black)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Gap between tabs and search
              const SizedBox(width: 16),
              // Search Bar with MyntSearchTextField matching positions page styling
              SizedBox(
                height: 40,
                width: searchWidth,
                child: MyntSearchTextField.withSmartClear(
                  controller: orderBook.orderSearchCtrl,
                  placeholder: 'Search orders',
                  leadingIcon: assets.searchIcon,
                  // Same formatters as the positions search so typed text
                  // displays identically (uppercase) on both screens.
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9& \-]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.startsWith(' ')) return oldValue;
                      return newValue;
                    }),
                  ],
                  onClear: () {
                    FocusScope.of(context).unfocus();
                    orderBook.clearOrderSearch();
                  },
                ),
              ),
              // Cancel All Button - only show on Open Orders tab (tab index 0)
              if ((_tabController?.index ?? 0) == 0)
                Consumer(
                  builder: (context, ref, _) {
                    final selectedCount =
                        ref.watch(orderProvider.select((p) => p.exitOrderQty));
                    final openOrders =
                        ref.watch(orderProvider).openOrder ?? [];
                    final pendingOrders = openOrders.where((o) {
                      final status = o.status?.toUpperCase() ?? '';
                      return status == 'PENDING' ||
                          status == 'OPEN' ||
                          status == 'TRIGGER_PENDING';
                    }).toList();

                    // Hide button if no pending orders
                    if (pendingOrders.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                          left: context.responsive<double>(
                              mobile: 6, tablet: 8, desktop: 12)),
                      child: SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          onPressed: () => _cancelAllOrders(pendingOrders, selectedCount > 0),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: resolveThemeColor(
                              context,
                              dark: MyntColors.errorDark,
                              light: MyntColors.tertiary,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            selectedCount == 0
                                ? 'Cancel All'
                                : 'Cancel ($selectedCount)',
                            style: MyntWebTextStyles.body(
                              context,
                              color: Colors.white,
                              fontWeight: MyntFonts.semiBold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Gap between search/cancel and download/refresh
              SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
              // Download Button
              _buildDownloadButton(theme, orderBook),
              SizedBox(width: context.responsive<double>(mobile: 6, tablet: 8, desktop: 12)),
              // Refresh Button - Matching positions page style
              _buildIconButton(
                icon: Icons.refresh,
                onPressed: _isRefreshing ? null : _refreshOrders,
                theme: theme,
                isLoading: _isRefreshing,
              ),
            ],
          );
        },
      ),
    );
  }

  // Cancel all orders dialog
  void _cancelAllOrders(List<OrderBookModel> openOrders, bool hasSelection) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CancelAllOrdersDialogWeb(
        openOrders: openOrders,
        isCancelAll: !hasSelection,
      ),
    );
  }

  Widget _buildContentArea(ThemesProvider theme, OrderProvider orderBook) {
    final index = _tabController?.index ?? 0;
    // Only build the active tab — disposes previous tab's widgets and stream listeners
    return KeyedSubtree(
      key: ValueKey(index),
      child: _buildTabContent(index),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return OpenOrdersScreen(
          horizontalScrollController: _openOrdersHorizontalScrollController,
          verticalScrollController: _openOrdersVerticalScrollController,
        );
      case 1:
        return ExecutedOrdersScreen(
          horizontalScrollController: _executedOrdersHorizontalScrollController,
          verticalScrollController: _executedOrdersVerticalScrollController,
        );
      case 2:
        return TradeBookScreen(
          horizontalScrollController: _tradeBookHorizontalScrollController,
          verticalScrollController: _tradeBookVerticalScrollController,
        );
      case 3:
        return GttOrdersScreen(
          horizontalScrollController: _gttHorizontalScrollController,
          verticalScrollController: _gttVerticalScrollController,
        );
      case 4:
        return const BasketList();
      case 5:
        return SipOrdersScreenWeb(
          horizontalScrollController: _sipHorizontalScrollController,
          verticalScrollController: _sipVerticalScrollController,
        );
      case 6:
        return const PendingAlertWeb();
      default:
        return OpenOrdersScreen(
          horizontalScrollController: _openOrdersHorizontalScrollController,
          verticalScrollController: _openOrdersVerticalScrollController,
        );
    }
  }

  // Icon button helper matching Positions page
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemesProvider theme,
    bool isLoading = false,
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

    return Container(
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
            child: isLoading
                ? SizedBox(
                    width: iconSize * 0.7,
                    height: iconSize * 0.7,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.iconDark,
                        light: MyntColors.icon,
                      ),
                    ),
                  )
                : Icon(
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
  }

  // Download button for orders (PDF & Excel)
  Widget _buildDownloadButton(ThemesProvider theme, OrderProvider orderBook) {
    final currentTab = _tabController?.index ?? 0;
    // Only show download for Open Orders (0), Executed Orders (1), Trade Book (2)
    if (currentTab > 2) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.download,
        size: context.responsive<double>(mobile: 22, tablet: 25, desktop: 28),
        color: resolveThemeColor(context,
            dark: MyntColors.iconDark, light: MyntColors.icon),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Download',
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: MyntColors.card),
      onSelected: (value) {
        final pref = locator<Preferences>();
        final clientId = pref.clientId ?? '';
        final clientName = pref.clientName ?? '';
        final socketData = ref.read(websocketProvider).socketDatas;

        switch (currentTab) {
          case 0: // Open Orders
            final orders = orderBook.openOrder ?? [];
            if (orders.isEmpty) {
              warningMessage(context, 'No open orders to download');
              return;
            }
            if (value == 'pdf') {
              OrdersDownloadHelper.downloadOpenOrdersPdf(
                  orders: orders, clientId: clientId, clientName: clientName, socketData: socketData);
            } else {
              OrdersDownloadHelper.downloadOpenOrdersExcel(
                  orders: orders, clientId: clientId, clientName: clientName, socketData: socketData);
            }
            break;
          case 1: // Executed Orders
            final orders = orderBook.executedOrder ?? [];
            if (orders.isEmpty) {
              warningMessage(context, 'No executed orders to download');
              return;
            }
            if (value == 'pdf') {
              OrdersDownloadHelper.downloadExecutedOrdersPdf(
                  orders: orders, clientId: clientId, clientName: clientName, socketData: socketData);
            } else {
              OrdersDownloadHelper.downloadExecutedOrdersExcel(
                  orders: orders, clientId: clientId, clientName: clientName, socketData: socketData);
            }
            break;
          case 2: // Trade Book
            final trades = orderBook.tradeBook ?? [];
            if (trades.isEmpty) {
              warningMessage(context, 'No trades to download');
              return;
            }
            if (value == 'pdf') {
              OrdersDownloadHelper.downloadTradeBookPdf(
                  trades: trades, clientId: clientId, clientName: clientName, socketData: socketData);
            } else {
              OrdersDownloadHelper.downloadTradeBookExcel(
                  trades: trades, clientId: clientId, clientName: clientName, socketData: socketData);
            }
            break;
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
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
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
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // COMMENTED: MF tab functionality
  /*
  Widget _buildMFSubTabs(ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shadcn TabList - Matching holdings screen style
        Container(
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          child: Builder(
            builder: (context) {
              final currentTheme = shadcn.Theme.of(context);
              final isDark = theme.isDarkMode;
              // Create a new ColorScheme based on the default, but with custom primary color
              final baseColorScheme = isDark
                  ? shadcn.ColorSchemes.darkDefaultColor
                  : shadcn.ColorSchemes.lightDefaultColor;

              // Create custom ColorScheme with theme-appropriate primary color
              final primaryColor =
                  theme.isDarkMode ? WebDarkColors.primary : WebColors.primary;
              final customColorScheme = baseColorScheme.copyWith(
                primary: () => primaryColor,
              );

              return shadcn.Theme(
                data: shadcn.ThemeData(
                  colorScheme: customColorScheme,
                  radius: currentTheme.radius,
                ),
                child: shadcn.TabList(
                  index: _mfTabIndex,
                  onChanged: (value) {
                    if (mounted && _mfTabIndex != value) {
                      setState(() {
                        _mfTabIndex = value;
                      });
                    }
                  },
                  children: [
                    shadcn.TabItem(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontFamily: 'Geist',
                          color: _mfTabIndex == 0
                              ? (theme.isDarkMode
                                  ? WebDarkColors.primary
                                  : WebColors.primary)
                              : customColorScheme.mutedForeground,
                          fontWeight: WebFonts.bold,
                        ),
                        child: const Text('Orders'),
                      ),
                    ),
                    shadcn.TabItem(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontFamily: 'Geist',
                          color: _mfTabIndex == 1
                              ? (theme.isDarkMode
                                  ? WebDarkColors.primary
                                  : WebColors.primary)
                              : customColorScheme.mutedForeground,
                          fontWeight: WebFonts.bold,
                        ),
                        child: const Text('SIP'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Content Area - Use IndexedStack to keep both widgets alive
        Expanded(
          child: IndexedStack(
            index: _mfTabIndex,
            children: const [
              MfOrderBookScreenWeb(),
              MFSipdetScreenWeb(),
            ],
          ),
        ),
      ],
    );
  }
  */
}

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/legacy.dart';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mynt_plus/main.dart' show getNavigatorContext;
import 'package:mynt_plus/screens/web/order/order_confirmation_screen_web.dart';
import 'package:mynt_plus/screens/web/order/slice_order_sheet_web.dart';
import 'package:public_ip_address/public_ip_address.dart';
import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/order_book_model/cancel_order_model.dart';
import '../models/order_book_model/get_brokerage.dart';
import '../models/order_book_model/gtt_order_book.dart';
import '../models/order_book_model/modify_order_model.dart';
import '../models/order_book_model/modify_sip_model.dart';
import '../models/order_book_model/order_book_model.dart';
import '../models/order_book_model/order_history_model.dart';
import '../models/order_book_model/order_margin_model.dart';
import '../models/order_book_model/place_gtt_order.dart';
import '../models/order_book_model/place_order_model.dart';
import '../models/order_book_model/sip_order_book.dart';
import '../models/order_book_model/sip_order_cancel.dart';
import '../models/order_book_model/sip_place_order.dart';
import '../models/order_book_model/trade_book_model.dart';
import '../routes/route_names.dart';
import '../sharedWidget/functions.dart';
import '../sharedWidget/snack_bar.dart';
import '../utils/responsive_snackbar.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';
import 'market_watch_provider.dart';
import 'notification_provider.dart';
import 'order_input_provider.dart';
import 'websocket_provider.dart';
import 'portfolio_provider.dart';
import 'mf_provider.dart';
import 'web_subscription_manager.dart';

final orderProvider = ChangeNotifierProvider((ref) => OrderProvider(ref));

class OrderProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();

  int frezQtyOrderSliceMaxLimit = 40;

  /// Most orders (rows) one web basket may hold. Separate from the slice
  /// limit above: GetBasketMargin rejects more than 20 rows, and the vendor
  /// basket caps at 20 too. Normal Place Order still slices up to 40.
  int basketMaxOrders = 20;

  final FToast _fToast = FToast();
  FToast get fToast => _fToast;
  final Ref ref;
  TabController? tabCtrl;
  PlaceOrderModel? _placeOrderModel;
  PlaceOrderModel? get placeOrderModel => _placeOrderModel;
  OrderMarginModel? _orderMarginModel;
  OrderMarginModel? get orderMarginModel => _orderMarginModel;
  OrderMarginModel? _bsktOrderMargin;
  OrderMarginModel? get bsktOrderMargin => _bsktOrderMargin;
  CancelOrderModel? _cancelOrderModel;
  CancelOrderModel? get cancelOrderModel => _cancelOrderModel;
  ModifyOrderModel? _modifyOrderModel;
  ModifyOrderModel? get modifyOrderModel => _modifyOrderModel;
  GetBrokerageModel? _getBrokerageModel;
  GetBrokerageModel? get getBrokerageModel => _getBrokerageModel;
  PlaceGttOrderModel? _placeGttOrderModel;
  PlaceGttOrderModel? get placeGttOrderModel => _placeGttOrderModel;
  PlaceGttOrderModel? _modifyGttOrderModel;
  PlaceGttOrderModel? get modifyGttOrderModel => _modifyGttOrderModel;
  List<OrderBookModel>? _orderBookModel = [];
  List<OrderBookModel>? get orderBookModel => _orderBookModel;
  List<GttOrderBookModel>? _gttOrderBookModel = [];
  List<GttOrderBookModel>? get gttOrderBookModel => _gttOrderBookModel;
  // List<GttOrderBookModel>? _tgttOrderBookModel = [];
  List<GttOrderBookModel>? _gttOrderBookSearch = [];
  List<GttOrderBookModel>? get gttOrderBookSearch => _gttOrderBookSearch;
  List<GttOrderBookModel>? _triggeredGttOrders = [];
  List<GttOrderBookModel>? get triggeredGttOrders => _triggeredGttOrders;
  bool _showTriggeredGtt = false;
  bool get showTriggeredGtt => _showTriggeredGtt;
  final Preferences pref = locator<Preferences>();
  List<TradeBookModel>? _tradeBook = [];
  List<TradeBookModel>? get tradeBook => _tradeBook;
  List<TradeBookModel>? _tradeBooksearch = [];
  List<TradeBookModel>? get tradeBooksearch => _tradeBooksearch;
  List<OrderBookModel>? _allOrder = [];
  List<OrderBookModel>? get allOrder => _allOrder;
  List<OrderBookModel>? _openOrder = [];
  List<OrderBookModel>? get openOrder => _openOrder;
  List<OrderBookModel>? _executedOrder = [];
  List<OrderBookModel>? get executedOrder => _executedOrder;

  List<OrderBookModel>? _orderSearchItem = [];
  List<OrderBookModel>? get orderSearchItem => _orderSearchItem;

  List<OrderBookModel> _orderBookSearchItem = [];
  List<OrderBookModel>? get orderBookSearchItem => _orderBookSearchItem;
  List<OrderHistoryModel> _orderHistoryModel = [];
  List<OrderHistoryModel>? get orderHistoryModel => _orderHistoryModel;

  SipPlaceOrderModel? _sipPlaceOrder;
  SipPlaceOrderModel? get sipPlaceOrder => _sipPlaceOrder;

  SipOrderBookModel? _siporderBookModel;
  SipOrderBookModel? get siporderBookModel => _siporderBookModel;

  List<SipDetails>? _siporderBookSearch = [];
  List<SipDetails>? get siporderBookSearch => _siporderBookSearch;

  CancleSipOrder? _cancleSipOrder;
  CancleSipOrder? get cancleSipOrder => _cancleSipOrder;

  ModifySIPModel? _modifySipModel;
  ModifySIPModel? get modifySipModel => _modifySipModel;

  List _bsktScripList = [];
  List get bsktScripList => _bsktScripList;

  List _bsktList = [];
  List get bsktList => _bsktList;

  Map _bsktScrips = {};
  Map get bsktScrips => _bsktScrips;

  bool _isBasketLoading = false;
  bool get isBasketLoading => _isBasketLoading;

  // Basket order tracking
  Map<String, List<String>> _basketOrderIds = {};
  Map<String, List<String>> get basketOrderIds => _basketOrderIds;

  Map<String, Map<String, String>> _basketOrderStatuses = {};
  Map<String, Map<String, String>> get basketOrderStatuses =>
      _basketOrderStatuses;

  Map<String, String> _basketOverallStatus = {};
  Map<String, String> get basketOverallStatus => _basketOverallStatus;

  String? bsketNameError;

  // In-flight guards for lazy-loaded tab data
  bool _isFetchingTradeBook = false;
  bool _isFetchingGTT = false;
  bool _isFetchingSIP = false;

  final TextEditingController orderSearchCtrl = TextEditingController();
  final TextEditingController orderGttSearchCtrl = TextEditingController();
  final TextEditingController orderSipSearchCtrl = TextEditingController();
  final TextEditingController orderTradebookCtrl = TextEditingController();

  OrderProvider(this.ref) {
    // getBasketName() deferred — loaded lazily when basket tab (index 4) is selected
    tabSize();
  }

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;


  void setSelectedTabSilent(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    tabCtrl?.animateTo(index);
    _updateTabNamesSilent();
    notifyListeners();
  }

  List<Tab> _orderTabName = [];
  List<Tab> get orderTabName => _orderTabName;

  bool _showSearchOrder = false;
  bool get showSearchHold => _showSearchOrder;

  bool _showGttOrderSearch = false;
  bool get showGttOrderSearch => _showGttOrderSearch;

  bool _showSipOrderSearch = false;
  bool get showSipOrderSearch => _showSipOrderSearch;

  bool _showtradebookSearch = false;
  bool get showtradebookSearch => _showtradebookSearch;

  String _ip = "";
  String get ip => _ip;

  String _selectedBsktName = "";
  String get selectedBsktName => _selectedBsktName;

  bool _orderloader = false;
  bool get orderloader => _orderloader;
  int _exitOrderQty = 0;
  int get exitOrderQty => _exitOrderQty;
  bool _isExitAllOrder = false;
  bool get isExitAllOrder => _isExitAllOrder;

  bool _showOrderHistory = false;
  bool get showOrderHistory => _showOrderHistory;

  // Track currently subscribed symbols to avoid duplicate subscriptions
  final Set<String> _subscribedSymbols = {};

  // Add this property to track the last sort method used
  String _lastOrderSortMethod = "TIMEDSC"; // Default sorting
  String get lastOrderSortMethod => _lastOrderSortMethod;

  clearAllorders() async {
    // Order data
    _orderBookModel = [];
    _gttOrderBookModel = [];
    _tradeBook = [];
    _executedOrder = [];
    _openOrder = [];
    _allOrder = [];

    // Search state
    _orderSearchItem = [];
    _orderBookSearchItem = [];
    _tradeBooksearch = [];
    _gttOrderBookSearch = [];
    _siporderBookSearch = [];
    _showSearchOrder = false;
    _showGttOrderSearch = false;
    _showSipOrderSearch = false;
    orderSearchCtrl.clear();
    orderGttSearchCtrl.clear();
    orderSipSearchCtrl.clear();
    orderTradebookCtrl.clear();

    // Order history & SIP
    _orderHistoryModel = [];
    _siporderBookModel = null;
    _triggeredGttOrders = [];
    _showTriggeredGtt = false;

    // Basket state
    _bsktList = [];
    _bsktScrips = {};
    _bsktScripList = [];
    _selectedBsktName = "";
    _basketOverallStatus = {};

    // Reset in-flight guards (prevents stale locks on account switch)
    _isFetchingTradeBook = false;
    _isFetchingGTT = false;
    _isFetchingSIP = false;

    _selectedTab = 0;

    // Clear subscription tracking
    clearSubscriptions();
    tabSize();
    notifyListeners();
  }

  showorderHistory(value) {
    _showOrderHistory = value;
    notifyListeners();
  }

  // Clear subscription tracking
  void clearSubscriptions() {
    _subscribedSymbols.clear();
  }

  setOrderIp() async {
    if (kIsWeb) {
      // Use CORS-friendly service for web
      try {
        final response = await http.get(Uri.parse('https://api.ipify.org?format=text'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _ip = response.body.trim();
          return;
        }
      } catch (_) {}
      _ip = '';
    } else {
      // Use package for mobile
      _ip = await IpAddress().getIp();
    }
  }

  setDOrderloader(bool value) {
    _orderloader = value;
  }

  setOrderloader(bool value) {
    _orderloader = value;
    notifyListeners();
  }

  selectExitOrder(int index) {
    for (var i = 0; i < (_openOrder?.length ?? 0); i++) {
      if (index == i) {
        if (_openOrder?[i] != null) {
          _openOrder![i].isExitSelection =
              !(_openOrder![i].isExitSelection ?? false);
        }
        if (_openOrder![i].isExitSelection!) {
          _exitOrderQty = _exitOrderQty + 1;
        } else {
          _exitOrderQty = _exitOrderQty - 1;
        }
      }

      if (_openOrder!.length == _exitOrderQty) {
        _isExitAllOrder = true;
      } else {
        _isExitAllOrder = false;
      }
    }

    notifyListeners();
  }

  selectExitAllOrders(bool isExitAll) {
    _isExitAllOrder = isExitAll;
    _exitOrderQty = 0;
    for (var i = 0; i < (_openOrder?.length ?? 0); i++) {
      if (_openOrder![i].qty != "0") {
        if (isExitAll) {
          _openOrder![i].isExitSelection = true;
          _exitOrderQty = _exitOrderQty + 1;
        } else {
          _openOrder![i].isExitSelection = false;
        }
      }
    }

    notifyListeners();
  }

// Change tab orderbook tab index
  /// Fetches portfolio data for the given [mode] and returns the parsed list.
  /// Callers assign the result directly — no temp fields needed.
  /// Always returns result['data'] (which is a List) — even for error/no-data
  /// so callers can check for session-expired models in the list.
  Future<List> _fetchPortfolioData(String mode) async {
    final Map<String, dynamic> result;
    if (mode == 'ob') {
      result = await api.getOrderBook();
      // result = await api.mockOrderBookResponse();

      if (result['stat'] == 'no data') {
        _orderBookModel = [];
      }
      return result['data'] as List;
    } else if (mode == 'tb') {
      result = await api.getTradeBook();
      // result = await api.mockTradeBookResponse();

      if (result['stat'] == 'no data') {
        _tradeBook = [];
      }
      return result['data'] as List;
    } else if (mode == 'gtt') {
      result = await api.getGTTOrderBook();
      final gttData = List<GttOrderBookModel>.from(result['data'] as List);
      if (result['stat'] == 'no data') {
        _gttOrderBookModel = [];
      } else {
        _gttOrderBookModel = gttData;
      }
      return _gttOrderBookModel ?? [];
    }
    return [];
  }

  changeTabIndex(int index, BuildContext context) {
    // Skip if already on this tab (prevents unnecessary operations)
    if (_selectedTab == index) return;

    // Unfocus any active text fields when switching tabs
    FocusScope.of(context).unfocus();

    // Store previous tab for unsubscription
    final previousTab = _selectedTab;
    _selectedTab = index;

    // Animate the TabController to the new index if initialized
    tabCtrl?.animateTo(index);

    // --- Batch state changes: set internal state directly, single notifyListeners at the end ---
    // Update tab names without notifying (batched)
    _updateTabNamesSilent();

    // Lazily sort the tab being opened: the fetch only sorts the visible
    // tab's list (performance), so Open/Executed need their sort applied on
    // switch or they render in raw API order.
    if ((index == 0 || index == 1) && _lastOrderSortMethod.isNotEmpty) {
      _applySortingSilent(_lastOrderSortMethod);
    }

    // Reset search states without triggering notifyListeners
    _showSearchOrder = false;
    _orderSearchItem = [];
    _showGttOrderSearch = false;
    _gttOrderBookSearch = [];
    _showSipOrderSearch = false;
    _siporderBookSearch = [];
    ref.read(marketWatchProvider).showAlertPendingSearch(false);
    ref.read(marketWatchProvider).clearAlertSearch();

    // Clear search only if switching away from search-enabled tabs
    if (index == 4) {
      orderSearchCtrl.clear();
      _tradeBooksearch = [];
      ref.read(mfProvider).clearMfSearch();
      ref.read(notificationprovider).clearTriggeredAlertSearch();
      orderGttSearchCtrl.clear();
      orderSipSearchCtrl.clear();
    }

    // Single notifyListeners for all batched state changes
    notifyListeners();

    // Only perform search if there's text and we're on a searchable tab
    if (orderSearchCtrl.text.isNotEmpty && (index <= 3 || index == 5 || index == 6)) {
      searchOrders(orderSearchCtrl.text, context);
    }

    // Lazy load data for tabs that haven't been loaded yet (with in-flight guards)
    // Tab 2: Trade Book
    if (index == 2 && (_tradeBook == null || _tradeBook!.isEmpty) && !_isFetchingTradeBook) {
      _isFetchingTradeBook = true;
      fetchTradeBook(context).whenComplete(() => _isFetchingTradeBook = false);
    }
    // Tab 3: GTT Orders - only fetch if not already loaded or in-flight
    if (index == 3 && (_gttOrderBookModel == null || _gttOrderBookModel!.isEmpty) && !_isFetchingGTT) {
      _isFetchingGTT = true;
      fetchGTTOrderBook(context, "").whenComplete(() => _isFetchingGTT = false);
    }
    // Tab 5: SIP Orders
    if (index == 5 && _siporderBookModel == null && !_isFetchingSIP) {
      _isFetchingSIP = true;
      fetchSipOrderHistory(context).whenComplete(() => _isFetchingSIP = false);
    }

    // Handle WebSocket subscription/unsubscription for order book tabs (0-3)
    // Unsubscribe from previous tab if it was a subscription tab (0-3)
    if (previousTab <= 3) {
      _unsubscribeFromTab(previousTab, context);
    }

    // Subscribe to new tab if it's a subscription tab (0-3)
    if (index <= 3) {
      requestWSOrderBook(isSubscribe: true, context: context);
    }

    // Only fetch basket data when switching to basket tab
    if (index == 4) {
     
      getBasketName();
    
    }
  }

  // Helper method to unsubscribe from a specific tab
  void _unsubscribeFromTab(int tabIndex, BuildContext context) {
    // Temporarily set selectedTab to unsubscribe from the correct tab
    final originalTab = _selectedTab;
    _selectedTab = tabIndex;


    // Unsubscribe from this tab's symbols
    requestWSOrderBook(isSubscribe: false, context: context);

    // Restore original tab
    _selectedTab = originalTab;
  }

  // Method to unsubscribe from current active tab (called when leaving order book screen)
  void unsubscribeFromCurrentTab(BuildContext context) {
    if (_selectedTab > 3) return;

    // Collect tokens for current tab
    final tokens = <String>{};

    switch (_selectedTab) {
      case 0:
        if (_orderBookModel != null && _orderBookModel!.isNotEmpty && _orderBookModel![0].stat != "Not_Ok") {
          for (var e in _orderBookModel!) {
            if (e.exch != null && e.token != null && e.token!.isNotEmpty) {
              tokens.add("${e.exch}|${e.token}");
            }
          }
        }
        break;
      case 1:
        if (_orderBookModel != null && _orderBookModel!.isNotEmpty && _orderBookModel![0].stat != "Not_Ok") {
          for (var e in _orderBookModel!) {
            if (e.exch != null && e.token != null && e.token!.isNotEmpty) {
              tokens.add("${e.exch}|${e.token}");
            }
          }
        }
        if (_executedOrder != null && _executedOrder!.isNotEmpty) {
          for (var e in _executedOrder!) {
            if (e.exch != null && e.token != null && e.token!.isNotEmpty) {
              tokens.add("${e.exch}|${e.token}");
            }
          }
        }
        break;
      case 2:
        if (_tradeBook != null && _tradeBook!.isNotEmpty) {
          for (var e in _tradeBook!) {
            if (e.exch != null && e.token != null && e.token!.isNotEmpty) {
              tokens.add("${e.exch}|${e.token}");
            }
          }
        }
        break;
      case 3:
        if (_gttOrderBookModel != null && _gttOrderBookModel!.isNotEmpty) {
          for (var e in _gttOrderBookModel!) {
            if (e.exch != null && e.token != null && e.token!.isNotEmpty) {
              tokens.add("${e.exch}|${e.token}");
            }
          }
        }
        break;
    }

    if (tokens.isEmpty && !kIsWeb) return;


    if (kIsWeb) {
      // The order book owns its tab's touchline; releasing the owner
      // unsubscribes only what no other screen still shows. (This used to
      // send "u" for a feed subscribed as "d", so nothing was ever released.)
      ref.read(websocketProvider).releaseAllTouchline('orderbook', context);
    } else {
      // On mobile, use direct unsubscription
      requestWSOrderBook(isSubscribe: false, context: context);
    }
  }

  DateTime formatDate(String exdate) {
    List<String> parts = exdate.split(' ');

    if (parts.length == 3 && parts[1].length == 3) {
      String day = parts[0].padLeft(2, '0'); // Ensure day is two digits
      String monthAbbreviation = parts[1];
      String yearShort = parts[2];
      String year = '20$yearShort';

      String formatted = '$year-${_getMonthNumber(monthAbbreviation)}-$day';
      return DateTime.parse(formatted);
    } else {
      throw const FormatException('Invalid date format');
    }
  }

  String _getMonthNumber(String monthAbbreviation) {
    switch (monthAbbreviation.toUpperCase()) {
      case 'JAN':
        return '01';
      case 'FEB':
        return '02';
      case 'MAR':
        return '03';
      case 'APR':
        return '04';
      case 'MAY':
        return '05';
      case 'JUN':
        return '06';
      case 'JUL':
        return '07';
      case 'AUG':
        return '08';
      case 'SEP':
      case 'SEPT':
        return '09';
      case 'OCT':
        return '10';
      case 'NOV':
        return '11';
      case 'DEC':
        return '12';
      default:
        return '00';
    }
  }

// Change Basket name
  chngBsktName(String val, BuildContext context, bool isOpt) async {

    _selectedBsktName = val;

    // Refresh basket data from preferences to ensure latest state
    final userId = pref.clientId;

    if (userId != null && userId.isNotEmpty) {
      final userBasketScrips = pref.getBasketScripsForUser(userId) ?? "";

      _bsktScrips =
          userBasketScrips.isEmpty ? {} : jsonDecode(userBasketScrips);
    } else {
      final generalBasketScrips = pref.bsktScrips ?? "";

      _bsktScrips =
          generalBasketScrips.isEmpty ? {} : jsonDecode(generalBasketScrips);
    }

    _bsktScripList = _bsktScrips[val] ?? [];

    if (_bsktScripList.isNotEmpty) {
      // Clean up expired scripts
      String input = "";
      final now = DateTime.now();
      _bsktScripList.asMap().entries.toList().reversed.forEach((entry) {
        final index = entry.key;
        final item = entry.value;
        try {
          Map spilitSymbol = spilitTsym(value: "${item['tsym']}");
          final expDateStr = spilitSymbol['expDate'];
          if (expDateStr == null || expDateStr.isEmpty) return;

          final parsedDate = formatDate(expDateStr);
          // **FIX: Only remove options that have expired (after expiry date), not on expiry date
          // Options are valid until end of expiry date, so only remove if current date is after expiry date
          final todayDate = DateTime(now.year, now.month, now.day);
          final expiryDate =
              DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
          if (todayDate.isAfter(expiryDate)) {
            removeBsktScrip(index, val);
          }
        } catch (e) {
        }
      });

      if (kIsWeb) {
        // Owned touchline for the selected basket's legs. The old path sent a
        // raw "d" once per scrip and remembered it locally, so after any
        // reconnect the basket LTPs never came back.
        ref.read(websocketProvider).setOwnedTouchline('basket', [
          for (final script in _bsktScripList) "${script['exch']}|${script['token']}"
        ], context);
      }

      // Create input string for WebSocket subscription - only for symbols not already subscribed
      Set<String> symbolsToSubscribe = {};

      for (var script in _bsktScripList) {
        final symbolKey = "${script['exch']}|${script['token']}";
        if (!_subscribedSymbols.contains(symbolKey)) {
          symbolsToSubscribe.add(symbolKey);
          _subscribedSymbols.add(symbolKey);
        }
      }

      // Only establish new connections if needed (mobile)
      if (!kIsWeb && symbolsToSubscribe.isNotEmpty) {
        input = symbolsToSubscribe.join("#");
        ref.read(websocketProvider).establishConnection(
            channelInput: input, task: "t", context: context);
      }

      // Update basket with latest values from socket data
      updateBasketFromSocketData();
    }

    await fetchBasketMargin();

    // Load order tracking data for the selected basket
    await _restoreOrderTrackingData();

    // CO - BO is not allowed in a web basket any more: drop rows saved
    // earlier as Cover (H) / Bracket (B). Runs after the restore so
    // removeBsktScrips re-saves the other rows' statuses at their new index.
    if (kIsWeb) {
      final coboRows = [
        for (int i = 0; i < _bsktScripList.length; i++)
          if (_bsktScripList[i]['prd'] == 'H' ||
              _bsktScripList[i]['prd'] == 'B')
            i
      ];
      if (coboRows.isNotEmpty) {
        await removeBsktScrips(coboRows, val);
        await fetchBasketMargin();
      }
    }

    // Only update basket order status if we have order book data available
    if (_orderBookModel != null && _orderBookModel!.isNotEmpty) {
      updateBasketOrderStatus();
      // Also validate and clean up stale orders immediately after loading
      validateAllBasketOrderStatuses();
      // Save the cleaned basket data back to preferences
      await _saveBasketToPreferences(val);
    }

    if (!isOpt) {
      // Navigate to basket script list screen
      Navigator.pushNamed(context, Routes.bsktScripList, arguments: val);
    }
    // Navigator.pushNamed(context, Routes.bsktScripList, arguments: val);
    notifyListeners();
  }

  // Method to update basket values from existing socket data
  void updateBasketFromSocketData() {
    try {
      final socketDatas = ref.read(websocketProvider).socketDatas;
      if (socketDatas.isEmpty || _bsktScripList.isEmpty) return;

      bool updated = false;

      // Update basket script list with current socket values
      for (var script in _bsktScripList) {
        final token = script['token']?.toString();
        if (token != null && socketDatas.containsKey(token)) {
          final lp = socketDatas[token]['lp']?.toString();
          final pc = socketDatas[token]['pc']?.toString();

          if (lp != null && lp != "null") {
            if (script['lp']?.toString() != lp) {
              script['lp'] = lp;
              updated = true;
            }
          }

          if (pc != null && pc != "null") {
            if (script['pc']?.toString() != pc) {
              script['pc'] = pc;
              updated = true;
            }
          }
        }
      }

      if (updated) {
        notifyBasketUpdates();
      }
    } catch (e) {
    }
  }

  // Notify listeners about basket updates without creating a full rebuild cycle
  void notifyBasketUpdates() {
    notifyListeners();
  }

  tabSize() {
    _updateTabNamesSilent();
    notifyListeners();
  }

  /// Updates tab names without calling notifyListeners (for batched updates)
  void _updateTabNamesSilent() {
    _orderTabName = [
      Tab(text: _openOrder!.isNotEmpty ? "Open ${_openOrder!.length}" : "Open"),
      Tab(
          text: _executedOrder!.isNotEmpty
              ? "Executed ${_executedOrder!.length}"
              : "Executed"),
      Tab(
        text: (_tradeBook != null && _tradeBook!.isNotEmpty)
            ? "Trade ${_tradeBook!.length}"
            : "Trade",
      ),
      Tab(
        text: (_gttOrderBookModel != null && _gttOrderBookModel!.isNotEmpty)
            ? "GTT ${_gttOrderBookModel!.length}"
            : "GTT",
      ),
      Tab(
        text: _bsktList.isNotEmpty ? "Basket ${_bsktList.length}" : "Basket",
      ),
      Tab(
        text: (_siporderBookModel?.sipDetails?.isNotEmpty ?? false)
            ? "SIP ${_siporderBookModel!.sipDetails!.length}"
            : "SIP",
      ),
      Tab(
        text: ref.read(marketWatchProvider).alertPendingModel != null &&
                ref.read(marketWatchProvider).alertPendingModel!.isNotEmpty
            ? "Alerts ${ref.read(marketWatchProvider).alertPendingModel!.length}"
            : "Alerts",
      )
    ];
  }

  /// Applies sorting to current tab's order lists without calling notifyListeners
  void _applySortingSilent(String sorting) {
    List<OrderBookModel>? mainListToSort;
    List<OrderBookModel>? searchListToSort;

    if (_selectedTab == 0) {
      mainListToSort = _openOrder;
      searchListToSort = _orderSearchItem;
    } else if (_selectedTab == 1) {
      mainListToSort = _executedOrder;
      searchListToSort = _orderSearchItem;
    } else {
      mainListToSort = _allOrder;
      searchListToSort = _orderSearchItem;
    }

    if (mainListToSort != null && mainListToSort.isNotEmpty) {
      _applySortingToOrderList(mainListToSort, sorting);
    }
    if (searchListToSort != null && searchListToSort.isNotEmpty) {
      _applySortingToOrderList(searchListToSort, sorting);
    }
  }

  /// Re-runs search filter on current tab's data without calling notifyListeners
  void _reapplySearchSilent(String value) {
    if (value.isEmpty) return;
    if (_selectedTab == 0 && _openOrder != null && _openOrder!.isNotEmpty) {
      _orderSearchItem = _openOrder!
          .where((e) => contractMatches(value, [
                e.masterName,
                e.dname,
                e.tsym,
                e.symbol,
                e.expDate,
                e.option,
                e.exch,
              ]))
          .toList();
    } else if (_selectedTab == 1 && _executedOrder != null && _executedOrder!.isNotEmpty) {
      _orderSearchItem = _executedOrder!
          .where((e) => contractMatches(value, [
                e.masterName,
                e.dname,
                e.tsym,
                e.symbol,
                e.expDate,
                e.option,
                e.exch,
              ]))
          .toList();
    } else if (_selectedTab == 2 && _tradeBook != null && _tradeBook!.isNotEmpty) {
      _tradeBooksearch = _tradeBook!
          .where((e) => contractMatches(value, [
                e.masterName,
                e.dname,
                e.tsym,
                e.symbol,
                e.expDate,
                e.option,
                e.exch,
              ]))
          .toList();
    } else if (_selectedTab == 3 && _gttOrderBookModel != null && _gttOrderBookModel!.isNotEmpty) {
      _gttOrderBookSearch = _gttOrderBookModel!
          .where((e) => contractMatches(value, [
                e.masterName,
                e.tsym,
                e.symbol,
                e.expDate,
                e.option,
                e.exch,
              ]))
          .toList();
    }
  }

  /// Updates basket order status without calling notifyListeners (for batched updates)
  void _updateBasketOrderStatusSilent() {
    try {
      Set<String> basketsToProcess = Set<String>.from(_basketOrderIds.keys);

      if (_selectedBsktName.isNotEmpty && _bsktScripList.isNotEmpty) {
        bool hasItemOrders = _bsktScripList.any(
            (item) => item['orderIds'] != null && item['orderIds'].isNotEmpty);
        if (hasItemOrders) {
          basketsToProcess.add(_selectedBsktName);
        }
      }

      // Build order lookup map once for O(1) lookups
      final Map<String, OrderBookModel> orderLookup = {};
      if (_orderBookModel != null) {
        for (var order in _orderBookModel!) {
          if (order.norenordno != null) {
            orderLookup[order.norenordno!] = order;
          }
        }
      }

      for (String basketName in basketsToProcess) {
        List<String> orderIds = _basketOrderIds[basketName] ?? [];

        if (orderIds.isEmpty && basketName == _selectedBsktName) {
          Set<String> itemOrderIds = {};
          for (var item in _bsktScripList) {
            if (item['orderIds'] != null && item['orderIds'].isNotEmpty) {
              itemOrderIds.addAll(List<String>.from(item['orderIds']));
            }
          }
          orderIds = itemOrderIds.toList();
          if (orderIds.isNotEmpty) {
            _basketOrderIds[basketName] = orderIds;
          }
        }

        if (orderIds.isEmpty) continue;

        Map<String, String> orderIdToStatus = {};
        Map<String, OrderBookModel> orderIdToModel = {};
        int completedCount = 0;
        int rejectedCount = 0;
        int openCount = 0;

        for (String orderId in orderIds) {
          // O(1) lookup instead of linear search
          OrderBookModel? order = orderLookup[orderId];

          if (order != null && order.status != null) {
            String actualStatus = order.status!;
            orderIdToStatus[orderId] = actualStatus;
            orderIdToModel[orderId] = order;

            if (actualStatus == 'COMPLETE') {
              completedCount++;
            } else if (actualStatus == 'REJECTED' || actualStatus == 'CANCELED') {
              rejectedCount++;
            } else {
              openCount++;
            }
          }
        }

        _updateBasketItemStatusesWithOrderBook(
            basketName, orderIdToStatus, orderIdToModel);

        if (completedCount == orderIds.length) {
          _basketOverallStatus[basketName] = 'completed';
        } else if (rejectedCount == orderIds.length) {
          _basketOverallStatus[basketName] = 'failed';
        } else if (rejectedCount > 0 &&
            (rejectedCount + completedCount) == orderIds.length) {
          _basketOverallStatus[basketName] = 'partially_completed';
        } else if (completedCount > 0) {
          _basketOverallStatus[basketName] = 'partially_filled';
        } else {
          _basketOverallStatus[basketName] = 'placed';
        }
      }

      _saveOrderTrackingData();
    } catch (e) {
    }
  }

  /// Validates basket order statuses without calling notifyListeners (for batched updates)
  void _validateAllBasketOrderStatusesSilent() {
    if (_orderBookModel == null || _orderBookModel!.isEmpty) return;

    Set<String> currentOrderIds = {};
    for (var order in _orderBookModel!) {
      if (order.norenordno != null) {
        currentOrderIds.add(order.norenordno!);
      }
    }

    for (var element in _bsktScripList) {
      if (element['orderIds'] != null) {
        List<String> itemOrderIds = List<String>.from(element['orderIds']);

        bool hasValidOrder = false;
        for (String orderId in itemOrderIds) {
          if (currentOrderIds.contains(orderId)) {
            hasValidOrder = true;
            break;
          }
        }

        if (!hasValidOrder) {
          element['orderStatus'] = null;
          element['orderDetails'] = null;
          element['orderIds'] = null;
        }
      }
    }
  }

  showOrderSearch(bool value) {
    _showSearchOrder = value;
    if (!_showSearchOrder) {
      _orderSearchItem = [];
    }
    notifyListeners();
  }

  showGTTOrderSearch(bool value) {
    _showGttOrderSearch = value;
    if (!_showGttOrderSearch) {
      _gttOrderBookSearch = [];
    }
    notifyListeners();
  }

  showSipSearch(bool value) {
    _showSipOrderSearch = value;
    if (!_showSipOrderSearch) {
      _siporderBookSearch = [];
    }
    notifyListeners();
  }

  showTradeSearch(bool value) {
    _showtradebookSearch = value;
    if (!_showtradebookSearch) {
      _tradeBooksearch = [];
    }
    notifyListeners();
  }

  clearGttOrderSearch() {
    orderGttSearchCtrl.clear();
    _gttOrderBookSearch = [];
    notifyListeners();
  }

  clearOrderSearch() {
    orderSearchCtrl.clear();
    _orderSearchItem = [];
    _tradeBooksearch = [];
    _gttOrderBookSearch = [];
    ref.read(marketWatchProvider).clearAlertSearch();
    ref.read(mfProvider).clearMfSearch();
    ref.read(notificationprovider).clearTriggeredAlertSearch();
    notifyListeners();
  }

  clearSipSearch() {
    orderSipSearchCtrl.clear();
    _siporderBookSearch = [];
    notifyListeners();
  }

  clearTradeBookSearch() {
    orderTradebookCtrl.clear();
    _tradeBooksearch = [];
    notifyListeners();
  }

  /// True when [query] appears in any of the contract's name forms (master
  /// display name, dname, raw tsym, parsed symbol/expiry/option, exchange) so
  /// search matches whatever the Instrument column displays. Used by
  /// [searchOrders], [_reapplySearchSilent], and the GTT screen's triggered
  /// list — keep the field lists in sync, and in sync with the positions
  /// search in position_table.dart.
  bool contractMatches(String query, List<String?> fields) {
    final q = query.toLowerCase();
    return fields.any((field) => (field ?? '').toLowerCase().contains(q));
  }

  // A single search function to handle search for all order tabs
  searchOrders(String value, BuildContext context) {

    // Clear all previous search results
    _orderSearchItem = [];
    _tradeBooksearch = [];
    _gttOrderBookSearch = [];
    _siporderBookSearch = [];
    ref.read(marketWatchProvider).clearAlertSearch();
    ref.read(mfProvider).clearMfSearch();
    ref.read(notificationprovider).clearTriggeredAlertSearch();

    if (value.isNotEmpty) {
      switch (_selectedTab) {
        case 0: // Open Orders
          if (_openOrder != null && _openOrder!.isNotEmpty) {
            _orderSearchItem = _openOrder!
                .where((element) => contractMatches(value, [
                      element.masterName,
                      element.dname,
                      element.tsym,
                      element.symbol,
                      element.expDate,
                      element.option,
                      element.exch,
                    ]))
                .toList();
          } else {
            _orderSearchItem = [];
          }
          break;
        case 1: // Executed Orders
          if (_executedOrder != null && _executedOrder!.isNotEmpty) {
            _orderSearchItem = _executedOrder!
                .where((element) => contractMatches(value, [
                      element.masterName,
                      element.dname,
                      element.tsym,
                      element.symbol,
                      element.expDate,
                      element.option,
                      element.exch,
                    ]))
                .toList();
          } else {
            _orderSearchItem = [];
          }
          break;
        case 2: // Trade Book
          if (_tradeBook != null && _tradeBook!.isNotEmpty) {
            _tradeBooksearch = _tradeBook!
                .where((element) => contractMatches(value, [
                      element.masterName,
                      element.dname,
                      element.tsym,
                      element.symbol,
                      element.expDate,
                      element.option,
                      element.exch,
                    ]))
                .toList();
          } else {
            _tradeBooksearch = [];
          }
          break;
        case 3: // GTT Orders
          if (_gttOrderBookModel != null && _gttOrderBookModel!.isNotEmpty) {
            _gttOrderBookSearch = _gttOrderBookModel!
                .where((element) => contractMatches(value, [
                      element.masterName,
                      element.tsym,
                      element.symbol,
                      element.expDate,
                      element.option,
                      element.exch,
                    ]))
                .toList();
          } else {
            _gttOrderBookSearch = [];
          }
          break;
        case 4: // Basket (Web & Mobile)
          // Basket doesn't need search as per current implementation
          break;
        case 5: // SIP Orders
          if (_siporderBookModel?.sipDetails != null) {
            _siporderBookSearch = _siporderBookModel!.sipDetails!
                .where((element) =>
                    element.sipName!.toUpperCase().contains(value.toUpperCase()))
                .toList();
          }
          break;
        case 6: // Alerts
          final alertProvider = ref.read(marketWatchProvider);
          final notificationProvider = ref.read(notificationprovider);

          // Search pending alerts - only if data exists
          if (alertProvider.alertPendingModel != null &&
              alertProvider.alertPendingModel!.isNotEmpty) {
            final searchResult = alertProvider.alertPendingModel!
                .where((element) => contractMatches(value, [
                      DerivativeMaster.nameFor(element.exch, element.token),
                      element.tsym,
                      element.exch,
                    ]))
                .toList();
            alertProvider.setAlertPendingSearch(searchResult);
          } else {
            // Clear search if no data (mobile compatibility)
            alertProvider.setAlertPendingSearch([]);
          }

          // Search triggered alerts (broker messages) - only if data exists
          if (notificationProvider.brokermsg != null &&
              notificationProvider.brokermsg!.isNotEmpty) {
            // First filter by alert-related messages (Ltp, above, below)
            final alertRelatedMessages = notificationProvider.brokermsg!
                .where((msg) =>
                    msg.dmsg != null &&
                    msg.dmsg!.contains("Ltp") &&
                    (msg.dmsg!.contains("above") ||
                        msg.dmsg!.contains("below")))
                .toList();

            // Then apply search filter
            final searchResult = alertRelatedMessages
                .where((msg) => contractMatches(value, [
                      DerivativeMaster.nameFor(msg.exch, msg.token),
                      msg.tsym,
                      msg.dmsg,
                      msg.exch,
                    ]))
                .toList();
            notificationProvider.setTriggeredAlertSearch(searchResult);
          } else {
            // Clear search if no data (mobile compatibility)
            notificationProvider.setTriggeredAlertSearch([]);
          }
          break;
      }
    }
    notifyListeners();
  }

  orderSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _showSearchOrder = true;
      _orderSearchItem = [];
      _orderSearchItem = _allOrder!
          .where((element) =>
              element.tsym!.toLowerCase().contains(value.toLowerCase()) ||
              (element.symbol?.toLowerCase().contains(value.toLowerCase()) ??
                  false))
          .toList();
      if (_orderSearchItem!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
          warningMessage(context, 'No Data Found');
        }
      }
    } else {
      _orderSearchItem = [];
    }

    notifyListeners();
  }

  orderGttSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _gttOrderBookSearch = [];
      _gttOrderBookSearch = _gttOrderBookModel!
          .where((element) =>
              element.tsym!.toUpperCase().contains(value.toUpperCase()))
          .toList();
      if (_gttOrderBookSearch!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
          warningMessage(context, 'No Data Found');
        }
      }
    } else {
      _gttOrderBookSearch = [];
    }

    notifyListeners();
  }

  orderSipSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _siporderBookSearch = [];
      _siporderBookSearch = _siporderBookModel!.sipDetails!
          .where((element) =>
              element.sipName!.toUpperCase().contains(value.toUpperCase()))
          .toList();
      if (_siporderBookSearch!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
          warningMessage(context, 'No Data Found');
        }
      }
    } else {
      _siporderBookSearch = [];
    }

    notifyListeners();
  }

  orderTradeBookSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _tradeBooksearch = [];
      _tradeBooksearch = _tradeBook!
          .where((element) =>
              element.tsym!.toUpperCase().contains(value.toUpperCase()))
          .toList();
      if (_tradeBooksearch!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
          warningMessage(context, 'No Data Found');
        }
      }
    } else {
      _tradeBooksearch = [];
    }

    notifyListeners();
  }

  Future fetchPlaceOrder(
      BuildContext context, PlaceOrderInput placeOrderInput, bool isExit,
      {bool quickOrder = false}) async {
    try {
      placeOrderInput.channel = defaultTargetPlatform == TargetPlatform.android
          ? '${ref.read(authProvider).deviceInfo["brand"]}'
          : "${ref.read(authProvider).deviceInfo["model"]}";

      _placeOrderModel = await api.getPlaceOrder(placeOrderInput, _ip);

      if (_placeOrderModel!.stat == "Ok") {
        ConstantName.sessCheck = true;
        // PAPER TRADING ONLY: there is no exchange order feed, so refresh
        // books and positions ourselves after every placed order.
        if (isPaperTrading && context.mounted) {
          fetchOrderBook(context, true);
          ref.read(portfolioProvider).fetchPositionBook(context, false, isRefresh: true);
        }
        // _orderBookModel = await fetchOrderBook(context, true);
        // if (_orderBookModel!.isNotEmpty) {
        //   if (_orderBookModel![0].stat != "Not_Ok") {
        //     ConstantName.sessCheck = true;
        //     for (var element in _orderBookModel!) {
        //       if (element.norenordno == _placeOrderModel!.norenordno) {
        // successMessage(
        //     context, "Order placed successfully."
        //     // "Your ${element.trantype == "B" ? "buy" : "sell"} order ${element.norenordno} for ${element.tsym} in ${element.exch} is ${element.status}"
        //     ));
        // }
        //     }
        // notifyListeners();
        //   } else {
        //     if (_orderBookModel![0].emsg ==
        //             "Session Expired :  Invalid Session Key" &&
        //         _orderBookModel![0].stat == "Not_Ok") {
        //       ref.read(authProvider).ifSessionExpired(context);
        //     }
        //   }
        // }

        // if (!isExit) {
        //   Navigator.pop(context);
        // } else {

        // }

        // Don't call Navigator.pop for web overlay dialogs - they're closed via overlay entry removal
        // Only pop for mobile or non-overlay dialogs
        if (!quickOrder && !kIsWeb) {
          Navigator.pop(context);
        }

        // PAPER TRADING ONLY: skip the full order confirmation screen when
        // the order is not OPEN/PENDING (i.e. instantly filled/rejected).
        // Live trading keeps the original always-show-modal behavior so the
        // real-API code path is untouched.
        final orderStatus = (_placeOrderModel!.status ?? '').toUpperCase();
        final bool paperSkipModal = isPaperTrading &&
            orderStatus.isNotEmpty &&
            orderStatus != 'OPEN' &&
            orderStatus != 'PENDING';

        if (!paperSkipModal) {
          if (kIsWeb) {
            // For quick order on web, close the dialog first before showing confirmation
            if (quickOrder) {
              Navigator.of(context).maybePop();
              // Small delay to ensure dialog closes before showing confirmation
              await Future.delayed(const Duration(milliseconds: 100));
            }

            // Use root navigator context so the dialog survives overlay removal
            final dialogContext = getNavigatorContext() ?? context;
            if (dialogContext.mounted) {
              showDialog(
                context: dialogContext,
                barrierColor: Colors.black.withValues(alpha: 0.3),
                builder: (BuildContext context) =>
                    OrderConfirmationScreenWeb(orderData: [_placeOrderModel!]),
              );
            }
          } else {
            // Navigate to order confirmation screen
            Navigator.pushNamed(context, Routes.orderConfirmation, arguments: {
              'orderData': [_placeOrderModel!],
            });
          }
        } else {
          // Paper trading: the order already reached its terminal state —
          // show a snackbar instead of the modal.
          if (kIsWeb && quickOrder) {
            Navigator.of(context).maybePop();
          }

          final String feedback;
          final bool isFailure;
          switch (orderStatus) {
            case 'COMPLETE':
            case 'TRADED':
              feedback = 'Order executed successfully';
              isFailure = false;
              break;
            case 'REJECTED':
              feedback = 'Order rejected';
              isFailure = true;
              break;
            case 'CANCELLED':
              feedback = 'Order cancelled';
              isFailure = true;
              break;
            default:
              feedback = 'Order placed successfully';
              isFailure = false;
          }

          if (kIsWeb) {
            if (isFailure) {
              ResponsiveSnackBar.showWarning(context, feedback);
            } else {
              ResponsiveSnackBar.showSuccess(context, feedback);
            }
          } else {
            if (isFailure) {
              warningMessage(context, feedback);
            } else {
              successMessage(context, feedback);
            }
          }
        }
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      } else {
        if (_placeOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(
                context, "${_placeOrderModel!.emsg}");
          } else {
            successMessage(context, "${_placeOrderModel!.emsg}");
          }
        }
      }

      return _placeOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Place Order", "Error": "$e"});

      if (context.mounted) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, "Error on placing order");
        } else {
          warningMessage(context, "Error on placing order");
        }
      }
    } finally {
      notifyListeners();
    }
  }

  final List<PlaceOrderModel> _sliceOrderResults = [];
  List<PlaceOrderModel> get sliceOrderResults => _sliceOrderResults;

  Future slicePlaceOrder(
      BuildContext context, PlaceOrderInput placeOrderInput) async {
    try {
      placeOrderInput.channel = defaultTargetPlatform == TargetPlatform.android
          ? '${ref.read(authProvider).deviceInfo["brand"]}'
          : "${ref.read(authProvider).deviceInfo["model"]}";

      _placeOrderModel = await api.getPlaceOrder(placeOrderInput, _ip);

      if (_placeOrderModel!.emsg == "Session Expired :  Invalid Session Key" &&
          _placeOrderModel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        ConstantName.sessCheck = true;
      }

      return _placeOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Place Slice  Order", "Error": "$e"});
      notifyListeners();
    }
  }

  // New function to handle multiple slice orders and navigate to confirmation
  Future<void> slicePlaceOrderWithConfirmation(
      BuildContext context,
      List<PlaceOrderInput> placeOrderInputs,
      int quantity,
      int reminder,
      {VoidCallback? onWebParentClose}) async {
    try {
      _sliceOrderResults.clear();
      List<Future<PlaceOrderModel?>> orderFutures = [];

      // Create futures for all slice orders
      final iterations = quantity >= frezQtyOrderSliceMaxLimit
          ? frezQtyOrderSliceMaxLimit
          : quantity;

      for (var i = 0; i < iterations; i++) {
        orderFutures.add(_placeSliceOrderInternal(placeOrderInputs[0]));
      }

      // Add reminder order future if needed
      if (reminder != 0 && placeOrderInputs.length > 1) {
        orderFutures.add(_placeSliceOrderInternal(placeOrderInputs[1]));
      }

      // Wait for all orders to complete
      final results = await Future.wait(orderFutures);

      // Process results
      bool hasSessionExpired = false;
      for (final result in results) {
        if (result != null) {
          if (result.emsg == "Session Expired :  Invalid Session Key") {
            hasSessionExpired = true;
            break;
          }
          if (result.stat == "Ok") {
            _sliceOrderResults.add(result);
          }
        }
      }
      // Handle session expiry
      if (hasSessionExpired) {
        ref.read(authProvider).ifSessionExpired(context);
      }

      // Show results
      if (_sliceOrderResults.isNotEmpty) {
        // Update order book
        fetchOrderBook(context, true);

        // Close the slice order dialog/overlay
        if (kIsWeb) {
          // On web, slice order uses Overlay, so close it using the static method
          SliceOrderSheetWeb.closeOverlay();
          // Also close the parent Place Order window (caller passes a
          // sticky-gated callback; mobile closes it via the double pop below).
          onWebParentClose?.call();
        } else {
          Navigator.pop(context);
          Navigator.pop(context);
        }

        // PAPER TRADING ONLY: skip the confirmation screen when every slice
        // already reached a terminal state. Live trading always shows it.
        final bool allSlicesTerminal = _sliceOrderResults.isNotEmpty &&
            _sliceOrderResults.every((r) {
              final s = (r.status ?? '').toUpperCase();
              return s.isNotEmpty && s != 'OPEN' && s != 'PENDING';
            });
        final bool paperSkipModal = isPaperTrading && allSlicesTerminal;

        if (context.mounted) {
          if (!paperSkipModal) {
            if (kIsWeb) {
              final dialogContext = getNavigatorContext() ?? context;
              if (dialogContext.mounted) {
                showDialog(
                  context: dialogContext,
                  barrierColor: Colors.black.withValues(alpha: 0.3),
                  builder: (BuildContext context) =>
                      OrderConfirmationScreenWeb(orderData: _sliceOrderResults),
                );
              }
            } else {
              // Navigate to order confirmation screen
              Navigator.pushNamed(context, Routes.orderConfirmation, arguments: {
                'orderData': _sliceOrderResults,
              });
            }
          } else {
            final msg =
                '${_sliceOrderResults.length} slice order(s) placed successfully';
            if (kIsWeb) {
              ResponsiveSnackBar.showSuccess(context, msg);
            } else {
              successMessage(context, msg);
            }
          }
        }
      } else {
        // Show error if no orders were successful
        if (context.mounted) {
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(
                context, "Failed to place orders. Please try again.");
          } else {
            warningMessage(
                context, "Failed to place orders. Please try again.");
          }
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Slice Order Confirmation", "Error": "$e"});
      if (context.mounted) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Error placing orders: ${e.toString()}");
        } else {
          warningMessage(context, "Error placing orders: ${e.toString()}");
        }
      }
      // notifyListeners();
    } finally {
      notifyListeners();
    }
  }

  // Helper function for placing individual slice orders
  Future<PlaceOrderModel?> _placeSliceOrderInternal(
      PlaceOrderInput placeOrderInput) async {
    try {
      placeOrderInput.channel = defaultTargetPlatform == TargetPlatform.android
          ? '${ref.read(authProvider).deviceInfo["brand"]}'
          : "${ref.read(authProvider).deviceInfo["model"]}";

      final result = await api.getPlaceOrder(placeOrderInput, _ip);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Places a set of pre-sliced child orders for INSTANT mode (no confirmation
  /// UI). Each input already carries a freeze-qty-bounded quantity. Fires them
  /// in parallel (same as [slicePlaceOrderWithConfirmation]), refreshes the
  /// order book, and shows a single summary toast. Unlike the confirmation
  /// variant, this opens/closes no overlay and performs no navigation — it is
  /// the headless slicing path the chart's instant orders use.
  Future<void> placeInstantSlices(
      BuildContext context, List<PlaceOrderInput> inputs) async {
    if (inputs.isEmpty) return;
    try {
      _sliceOrderResults.clear();
      final results = await Future.wait(
          inputs.map((inp) => _placeSliceOrderInternal(inp)));
      int ok = 0;
      int fail = 0;
      bool sessionExpired = false;
      for (final r in results) {
        if (r == null) {
          fail++;
          continue;
        }
        if (r.emsg == "Session Expired :  Invalid Session Key") {
          sessionExpired = true;
          break;
        }
        if (r.stat == "Ok") {
          ok++;
          _sliceOrderResults.add(r);
        } else {
          fail++;
        }
      }
      if (sessionExpired) {
        if (context.mounted) ref.read(authProvider).ifSessionExpired(context);
        return;
      }
      if (ok > 0) fetchOrderBook(context, true);
      if (context.mounted) {
        if (fail == 0) {
          ResponsiveSnackBar.showSuccess(
              context, "Placed $ok slice order${ok == 1 ? '' : 's'}.");
        } else if (ok > 0) {
          ResponsiveSnackBar.showWarning(context,
              "Placed $ok of ${inputs.length} slices; $fail failed.");
        } else {
          ResponsiveSnackBar.showWarning(
              context, "Failed to place sliced order. Please try again.");
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Instant Slice Order", "Error": "$e"});
      if (context.mounted) {
        ResponsiveSnackBar.showWarning(
            context, "Error placing sliced order: ${e.toString()}");
      }
    } finally {
      notifyListeners();
    }
  }

  Future fetchOrderBook(context, bool websocCon) async {
    try {
      final freshOrders = List<OrderBookModel>.from(await _fetchPortfolioData('ob'));
      if (_orderBookModel!.isNotEmpty) {
        if (freshOrders.isNotEmpty) {
          _orderBookModel = freshOrders;
        }
      } else {
        loading = true;
        notifyListeners(); // Show loading indicator immediately
        _executedOrder = [];
        _openOrder = [];
        _allOrder = [];
        _orderBookModel = freshOrders;
      }

      pref.setOBScrip(true);
      pref.setOBPrice(true);
      pref.setOBtime(true);
      pref.setOBqty(true);
      pref.setOBproduct(true);

      if (_orderBookModel!.isNotEmpty) {
        if (_orderBookModel![0].stat != "Not_Ok") {
          ConstantName.sessCheck = true;
          final tempExecuted = <OrderBookModel>[];
          final tempOpen = <OrderBookModel>[];
          final tempAll = <OrderBookModel>[];

          // Process orders in batches and yield to event loop between batches.
          // On web, compute() runs synchronously — without yielding, the main thread
          // stays blocked for seconds and other XHR response callbacks (e.g. getLinkedScrips)
          // can't execute, appearing "pending" even though the server already responded.
          final orders = _orderBookModel!;
          const batchSize = 200;
          for (var i = 0; i < orders.length; i += batchSize) {
            final end = (i + batchSize < orders.length) ? i + batchSize : orders.length;
            for (var j = i; j < end; j++) {
              final element = orders[j];
              if (element.exch == "BFO" && element.dname != null) {
                List<String> splitVal = element.dname!.split(" ");
                element.symbol = splitVal[0];
                // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
                element.expDate = bfoExpiryWithYear(splitVal, element.tsym);
                element.option = splitVal.length > 4
                    ? "${splitVal[3]} ${splitVal[4]}"
                    : splitVal[3];
              } else {
                Map spilitSymbol = spilitTsym(value: "${element.tsym}");
                element.symbol = "${spilitSymbol["symbol"]}";
                element.expDate = "${spilitSymbol["expDate"]}";
                element.option = "${spilitSymbol["option"]}";
              }
              if (element.stat == "Ok") {
                if (element.status == "REJECTED" ||
                    element.status == "CANCELED" ||
                    element.status == "COMPLETE" ||
                    element.status == "INVALID_STATUS_TYPE") {
                  tempExecuted.add(element);
                } else {
                  tempOpen.add(element);
                }
                tempAll.add(element);
              }
            }
            // Yield to event loop between batches so pending XHR callbacks
            // (like getLinkedScrips response) can be processed
            if (end < orders.length) {
              await Future.delayed(Duration.zero);
            }
          }

          _executedOrder = tempExecuted;
          _openOrder = tempOpen;
          _allOrder = tempAll;

          // Reapply the last sort method without notifying (batched).
          // Performance: only the visible tab's list is sorted here; the
          // other tabs are sorted lazily on switch (see changeTabIndex).
          if (_lastOrderSortMethod.isNotEmpty) {
            _applySortingSilent(_lastOrderSortMethod);
          }

          // Re-run search if active (so search results reference fresh data)
          if (orderSearchCtrl.text.trim().isNotEmpty) {
            _reapplySearchSilent(orderSearchCtrl.text.trim());
          }

          if (websocCon) {
            requestWSOrderBook(isSubscribe: true, context: context);
          }
        } else {
          if (_orderBookModel![0].emsg ==
                  "Session Expired :  Invalid Session Key" &&
              _orderBookModel![0].stat == "Not_Ok") {
            ref.read(authProvider).ifSessionExpired(context);
          }
        }
      }
      // Update tab names without notifying (batched)
      _updateTabNamesSilent();
      return _orderBookModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Order Book", "Error": "$e"});
    } finally {
      // Update basket order statuses (without its own notifyListeners)
      _updateBasketOrderStatusSilent();

      // Validate and clean up stale basket order statuses
      _validateAllBasketOrderStatusesSilent();

      loading = false;
      // Single notifyListeners for all state changes
      notifyListeners();
    }
  }

  Future fetchTradeBook(context) async {
    try {
      // Show loader on first load (when no existing data)
      if (_tradeBook == null || _tradeBook!.isEmpty) {
        loading = true;
        notifyListeners();
      }
      final freshTrades = List<TradeBookModel>.from(await _fetchPortfolioData('tb'));
      if (_tradeBook!.isNotEmpty) {
        if (freshTrades.isNotEmpty) {
          _tradeBook = freshTrades;
        }
      } else {
        _tradeBook = freshTrades;
      }
      pref.setTbScrip(true);
      pref.setTbPrice(true);
      pref.setTbBuyOrSell(true);
      pref.setTbTime(true);
      if (_tradeBook!.isNotEmpty) {
        if (_tradeBook![0].stat == "Ok") {
          ConstantName.sessCheck = true;
          for (var element in _tradeBook!) {
            if (element.exch == "BFO" && element.dname != null) {
              List<String> splitVal = element.dname!.split(" ");

              element.symbol = splitVal[0];
              // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
              element.expDate = bfoExpiryWithYear(splitVal, element.tsym);
              element.option = splitVal.length > 4
                  ? "${splitVal[3]} ${splitVal[4]}"
                  : splitVal[3];
            } else {
              Map spilitSymbol = spilitTsym(value: "${element.tsym}");

              element.symbol = "${spilitSymbol["symbol"]}";
              element.expDate = "${spilitSymbol["expDate"]}";
              element.option = "${spilitSymbol["option"]}";
            }
          }
        }
        if (_tradeBook![0].emsg == "Session Expired :  Invalid Session Key" &&
            _tradeBook![0].stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
        if (_tradeBook![0].stat == "Not_Ok") {
          _tradeBook = [];
        }
      }
      _updateTabNamesSilent();
      // Re-run search if active on trade book tab
      if (orderSearchCtrl.text.trim().isNotEmpty && _selectedTab == 2) {
        _reapplySearchSilent(orderSearchCtrl.text.trim());
      }
      return _tradeBook;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Trade Book", "Error": "$e"});
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future fetchGTTOrderBook(context, String initLoad) async {
    try {
      // Show loader on first load (when no existing data)
      if (_gttOrderBookModel == null || _gttOrderBookModel!.isEmpty) {
        loading = true;
        notifyListeners();
      }
      // _fetchPortfolioData('gtt') sets _gttOrderBookModel directly
      await _fetchPortfolioData('gtt');
      if (_gttOrderBookModel!.isNotEmpty) {
        if (_gttOrderBookModel![0].stat == "Ok") {
          ConstantName.sessCheck = true;
          // Only re-subscribe when the GTT tab is the one showing. This used to
          // force `_selectedTab = 3`, and it runs on every order message and
          // reconnect: the order book's search filter and its subscription
          // jumped to GTT while the user was on Open or Executed orders.
          if (initLoad != "initLoad" && _selectedTab == 3) {
            requestWSOrderBook(isSubscribe: true, context: context);
          }

          for (var element in _gttOrderBookModel!) {
            Map spilitSymbol = spilitTsym(value: "${element.tsym}");

            element.symbol = "${spilitSymbol["symbol"]}";
            element.expDate = "${spilitSymbol["expDate"]}";
            element.option = "${spilitSymbol["option"]}";

            element.ordDate = convertToISOFormat("${element.norentm}");
          }
          _gttOrderBookModel!.sort((a, b) => b.ordDate!.compareTo(a.ordDate!));
        }
        if (_gttOrderBookModel![0].emsg ==
                "Session Expired :  Invalid Session Key" &&
            _gttOrderBookModel![0].stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }

        if (_gttOrderBookModel![0].stat == "Not_Ok") {
          _gttOrderBookModel = [];
        }
      }
      _updateTabNamesSilent();
      // Re-run search if active on GTT tab
      if (orderSearchCtrl.text.trim().isNotEmpty && _selectedTab == 3) {
        _reapplySearchSilent(orderSearchCtrl.text.trim());
      }

      return _gttOrderBookModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API GTT Order Book", "Error": "$e"});
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Toggle between pending and triggered GTT orders
  void toggleTriggeredGtt(bool show, BuildContext context) {
    _showTriggeredGtt = show;
    // Always refetch the tab's own list so switching tabs shows fresh data
    // if (show && (_triggeredGttOrders == null || _triggeredGttOrders!.isEmpty)) {
    //   fetchTriggeredGTTOrders(context);
    // }
    if (show) {
      fetchTriggeredGTTOrders(context);
    } else {
      fetchGTTOrderBook(context, "");
    }
    notifyListeners();
  }

  /// Sortable ISO key from norentm — accepts "HH:mm:ss dd-MM-yyyy" or ISO,
  /// returns "" instead of throwing so unparseable rows sink to the bottom.
  String _triggeredGttSortKey(String? norentm) {
    final value = norentm?.trim() ?? '';
    if (value.isEmpty) return '';
    if (value.contains('T')) return value;
    try {
      return convertToISOFormat(value);
    } catch (_) {
      return '';
    }
  }

  /// Fetch triggered GTT orders from API
  Future fetchTriggeredGTTOrders(BuildContext context) async {
    try {
      final result = await api.getTriggeredGTTOrders();
      if (result['stat'] == 'success') {
        _triggeredGttOrders = result['data'];
      } else {
        if (result['stat'] == 'no data') {
          _triggeredGttOrders = [];
        }
      }

      if (_triggeredGttOrders != null && _triggeredGttOrders!.isNotEmpty) {
        if (_triggeredGttOrders![0].stat == "Not_Ok") {
          if (_triggeredGttOrders![0].emsg ==
              "Session Expired :  Invalid Session Key") {
            ref.read(authProvider).ifSessionExpired(context);
          }
          _triggeredGttOrders = [];
        } else {
          for (var element in _triggeredGttOrders!) {
            Map spilitSymbol = spilitTsym(value: "${element.tsym}");
            element.symbol = "${spilitSymbol["symbol"]}";
            element.expDate = "${spilitSymbol["expDate"]}";
            element.option = "${spilitSymbol["option"]}";
            // element.ordDate = convertToISOFormat("${element.norentm}");
            // Guarded parse: one odd norentm must not throw and skip the sort
            element.ordDate = _triggeredGttSortKey(element.norentm);
            // For triggered orders, use 'stat' as the display status
            if (element.stat != null && element.stat!.isNotEmpty) {
              element.gttOrderCurrentStatus = element.stat;
            }
          }
          _triggeredGttOrders!
              .sort((a, b) => b.ordDate!.compareTo(a.ordDate!));
        }
      }

      return _triggeredGttOrders;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Triggered GTT Orders", "Error": "$e"});
    } finally {
      notifyListeners();
    }
  }

  Future fetchOrderHistory(String orderNum, BuildContext context) async {
    try {
      _orderHistoryModel = await api.getOrderHistory(orderNum);
      if (_orderHistoryModel[0].stat == "Not_Ok" &&
          _orderHistoryModel[0].emsg ==
              "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        ConstantName.sessCheck = true;
      }

      notifyListeners();

      return _orderHistoryModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Single Order His", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  orderBookSearch(String Value) {
    if (Value.length > 1) {
      _orderBookSearchItem = [];
      Fluttertoast.cancel();
      _orderBookSearchItem = _executedOrder!
          .where((element) => element.tsym!.toLowerCase().contains(Value))
          .toList();
      if (_orderBookSearchItem.isEmpty) {
        Fluttertoast.showToast(
            msg: "No Data Found",
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    } else {
      _orderBookSearchItem = [];
    }
    notifyListeners();
  }

  exitOrders(context) async {
    for (var element in _openOrder!) {
      if (element.isExitSelection ?? false) {
        if ((element.sPrdtAli == "BO" || element.sPrdtAli == "CO") &&
            element.snonum != null) {
          await fetchExitSNOOrd(element.snonum.toString(),
              element.prd.toString(), context, false);
        } else {
          await fetchOrderCancel(element.norenordno.toString(), context, false);
        }
      }
    }
    await fetchOrderBook(context, true);
    Navigator.pop(context);
    _exitOrderQty = 0;
    _isExitAllOrder = false;
  }

  /// Cancel all pending/open orders
  Future<void> cancelAllPendingOrders(context) async {
    if (_openOrder == null) return;
    for (var element in _openOrder!) {
      final status = element.status?.toUpperCase() ?? '';
      if (status == 'PENDING' || status == 'OPEN' || status == 'TRIGGER_PENDING') {
        if ((element.sPrdtAli == "BO" || element.sPrdtAli == "CO") &&
            element.snonum != null) {
          await fetchExitSNOOrd(element.snonum.toString(),
              element.prd.toString(), context, false);
        } else {
          await fetchOrderCancel(element.norenordno.toString(), context, false);
        }
      }
    }
    await fetchOrderBook(context, true);
    Navigator.pop(context);
  }

  Future fetchOrderCancel(String orderNum, context, bool loop) async {
    try {
      _cancelOrderModel = await api.getCancelOrder(orderNum);
      if (_cancelOrderModel!.stat == "Ok") {
        if (loop) {
          ConstantName.sessCheck = true;
          // Show success feedback immediately — don't block on order book refresh
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(context, 'Order Cancelled');
          } else {
            Navigator.pop(context);
            successMessage(context, 'Order Cancelled');
            Navigator.pop(context);
          }
          // Refresh order book in background (non-blocking)
          fetchOrderBook(context, true);
        }
      } else if (_cancelOrderModel!.stat == "Not_Ok" &&
          _cancelOrderModel!.emsg ==
              "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }

      return _cancelOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Order Canl", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  Future fetchExitSNOOrd(
      String snoOrdNum, String prd, context, bool loop) async {
    try {
      _cancelOrderModel = await api.getExitSNOOrder(snoOrdNum, prd);
      if (_cancelOrderModel!.stat == "Ok" &&
          _cancelOrderModel!.dmsg == "success") {
        if (loop) {
          ConstantName.sessCheck = true;
          // Show success feedback immediately — don't block on order book refresh
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(context, 'Order Exited');
          } else {
            Navigator.pop(context);
            successMessage(context, 'Order Exited');
            Navigator.pop(context);
          }
          // Refresh order book in background (non-blocking)
          fetchOrderBook(context, true);
        }
      } else if (_cancelOrderModel!.stat == "Not_Ok" &&
          _cancelOrderModel!.emsg ==
              "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }

      return _cancelOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Order Canl", "Error": "$e"});
      notifyListeners();
    }
  }

  Future fetchModifyOrder(ModifyOrderInput input, context) async {
    try {
      _modifyOrderModel = await api.getModifyOrder(input, _ip);
      if (_modifyOrderModel!.stat == "Ok") {
        ConstantName.sessCheck = true;
        PlaceOrderModel modifyOrderData = PlaceOrderModel(
          norenordno:
              _modifyOrderModel!.result, // Order number from modify result
          requestTime: _modifyOrderModel!.requestTime,
          stat: _modifyOrderModel!.stat,
        );
        modifyOrderData.emsg = _modifyOrderModel!.emsg;

        // Show feedback immediately — don't block on order book refresh
        if (kIsWeb) {
          // For web, the overlay is already closed by closeNotifier.onClose() in the modify screen
          // So we don't need to call Navigator.pop here
        } else {
          Navigator.pop(context);
          Navigator.pushNamed(context, Routes.orderConfirmation, arguments: {
            'orderData': [modifyOrderData],
          });
        }
        // Refresh order book in background (non-blocking)
        fetchOrderBook(context, true);
      } else {
        if (_modifyOrderModel!.emsg ==
            "Session Expired :  Invalid Session Key") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(
                context, '${_modifyOrderModel!.emsg}');
          } else {
            successMessage(context, '${_modifyOrderModel!.emsg}');
          }
        }
      }
      notifyListeners();
      return _modifyOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Modify Order", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  void resetMargin() {
    _orderMarginModel = null;
    _getBrokerageModel = null;
    notifyListeners();
  }

  Future fetchOrderMargin(OrderMarginInput input, BuildContext context) async {
    try {
      _orderMarginModel = await api.getOrderMargin(input);
      if (_orderMarginModel!.emsg == "Session Expired :  Invalid Session Key" &&
          _orderMarginModel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        ConstantName.sessCheck = true;
      }

      notifyListeners();
      return _orderMarginModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Order Margin", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  Future fetchGetBrokerage(BrokerageInput input, BuildContext context) async {
    try {
      _getBrokerageModel = await api.getBrokerage(input);
      if (_getBrokerageModel!.emsg ==
              "Session Expired :  Invalid Session Key" &&
          _getBrokerageModel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        ConstantName.sessCheck = true;
      }

      notifyListeners();
      return _getBrokerageModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Brokerage", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  requestWSOrderBook(
      {required bool isSubscribe, required BuildContext context}) {
    try {
      toggleLoadingOn(true);
      String input = "";
      List<String> symbolList = [];
      String tabName = "";

      // Determine tab name and collect symbols based on active tab
      switch (_selectedTab) {
        case 0:
          tabName = "Open Orders";
          // Only include open orders for Tab 0
          if (_orderBookModel != null &&
              _orderBookModel!.isNotEmpty &&
              _orderBookModel![0].stat != "Not_Ok") {
            final openTokens = _orderBookModel!
                .where((e) => e.token != null && e.token!.isNotEmpty)
                .map((e) => "${e.exch}|${e.token}")
                .toSet()
                .toList();
            symbolList.addAll(openTokens);
            input = openTokens.join("#");
          }
          break;

        case 1:
          tabName = "Executed Orders";
          // Include both open and executed orders for Tab 1
          if (_orderBookModel != null &&
              _orderBookModel!.isNotEmpty &&
              _orderBookModel![0].stat != "Not_Ok") {
            final openTokens = _orderBookModel!
                .where((e) => e.token != null && e.token!.isNotEmpty)
                .map((e) => "${e.exch}|${e.token}")
                .toSet()
                .toList();
            symbolList.addAll(openTokens);
            input = openTokens.join("#");
          }
          if (_executedOrder != null && _executedOrder!.isNotEmpty) {
            final executedTokens = _executedOrder!
                .where((e) => e.token != null && e.token!.isNotEmpty)
                .map((e) => "${e.exch}|${e.token}")
                .toSet()
                .toList();
            if (executedTokens.isNotEmpty) {
              symbolList.addAll(executedTokens);
              if (input.isNotEmpty) {
                input += "#${executedTokens.join("#")}";
              } else {
                input = executedTokens.join("#");
              }
            }
          }
          break;

        case 2:
          tabName = "Trade Book";
          // Include trade book symbols for Tab 2
          if (_tradeBook != null && _tradeBook!.isNotEmpty) {
            final tradeTokens = _tradeBook!
                .where((e) => e.token != null && e.token!.isNotEmpty)
                .map((e) => "${e.exch}|${e.token}")
                .toSet()
                .toList();
            symbolList.addAll(tradeTokens);
            input = tradeTokens.join("#");
          }
          break;

        case 3:
          tabName = "GTT Orders";
          // Include GTT orders for Tab 3
          if (_gttOrderBookModel!.isNotEmpty) {
            final gttTokens = _gttOrderBookModel!
                .where((e) => e.token != null && e.token!.isNotEmpty)
                .map((e) => "${e.exch}|${e.token}")
                .toSet()
                .toList();
            symbolList.addAll(gttTokens);
            input = gttTokens.join("#");
          }
          break;

        default:
          tabName = "Unknown Tab ($_selectedTab)";
          break;
      }

      // Remove duplicates from symbolList
      final uniqueSymbols = symbolList.toSet().toList();

      // On web, WebSubscriptionManager handles all subscriptions
      // Skip unsubscribe here to avoid conflicts with multi-panel layout
      if (kIsWeb && !isSubscribe) {
        return;
      }

      // Print subscription/unsubscription details
      if (isSubscribe) {
        if (uniqueSymbols.length <= 10) {
        }
      } else {
        if (uniqueSymbols.length <= 10) {
        }
      }

      if (kIsWeb) {
        // Owned touchline: tracked, protected from other screens' "u",
        // restored on every new socket, and replaced as the list changes.
        // The current tab's LTP column; was a raw "d" released with "u" (never released).
        ref.read(websocketProvider).setOwnedTouchline(
            'orderbook', input.split('#'), context);
      } else if (input.isNotEmpty) {
        ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? "t" : "u",
            context: context);
      }
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

  filterTradeBook(String sorting) {
    if (sorting == "ASC") {
      _tradeBook!.sort((a, b) => a.tsym!.compareTo(b.tsym!));
    } else if (sorting == "DSC") {
      _tradeBook!.sort((a, b) => b.tsym!.compareTo(a.tsym!));
    } else if (sorting == "LTPDSC") {
      _tradeBook!.sort((a, b) {
        return double.parse(b.prc ?? "0.00")
            .compareTo(double.parse(a.prc ?? "0.00"));
      });
    } else if (sorting == "LTPASC") {
      _tradeBook!.sort((a, b) {
        return double.parse(a.prc ?? "0.00")
            .compareTo(double.parse(b.prc ?? "0.00"));
      });
    } else if (sorting == "BUY") {
      _tradeBook!.sort((a, b) => a.trantype!.compareTo(b.trantype!));
    } else if (sorting == "SELL") {
      _tradeBook!.sort((a, b) => b.trantype!.compareTo(a.trantype!));
    } else if (sorting == "TIMEHIGH") {
      _tradeBook!.sort((a, b) {
        DateTime dateA = DateTime.parse(formatToDateTime("${a.norentm}"));
        DateTime dateB = DateTime.parse(formatToDateTime("${b.norentm}"));
        return dateA.compareTo(dateB);
      });
    } else if (sorting == "TIMELOW") {
      _tradeBook!.sort((a, b) {
        DateTime dateA = DateTime.parse(formatToDateTime("${a.norentm}"));
        DateTime dateB = DateTime.parse(formatToDateTime("${b.norentm}"));
        return dateB.compareTo(dateA);
      });
    }
    notifyListeners();
  }

  filterGttOrders(String sorting) {
    if (sorting == "ASC") {
      _gttOrderBookModel!.sort((a, b) => a.tsym!.compareTo(b.tsym!));
    } else if (sorting == "DSC") {
      _gttOrderBookModel!.sort((a, b) => b.tsym!.compareTo(a.tsym!));
    } else if (sorting == "LTPDSC") {
      _gttOrderBookModel!.sort((a, b) {
        return double.parse(b.ltp ?? "0.00")
            .compareTo(double.parse(a.ltp ?? "0.00"));
      });
    } else if (sorting == "LTPASC") {
      _gttOrderBookModel!.sort((a, b) {
        return double.parse(a.ltp ?? "0.00")
            .compareTo(double.parse(b.ltp ?? "0.00"));
      });
    } else if (sorting == "QTYDSC") {
      _gttOrderBookModel!.sort((a, b) {
        return int.parse("${b.qty ?? "0"}")
            .compareTo(int.parse("${a.qty ?? "0"}"));
      });
    } else if (sorting == "QTYASC") {
      _gttOrderBookModel!.sort((a, b) {
        return int.parse("${a.qty ?? "0"}")
            .compareTo(int.parse("${b.qty ?? "0"}"));
      });
    } else if (sorting == "PRODUCTASC") {
      _gttOrderBookModel!.sort((a, b) => a.prd!.compareTo(b.prd!));
    } else if (sorting == "PRODUCTDSC") {
      _gttOrderBookModel!.sort((a, b) => b.prd!.compareTo(a.prd!));
    } else if (sorting == "TIMEDSC") {
      _gttOrderBookModel!.sort((a, b) {
        DateTime dateA = DateTime.parse(formatToDateTime("${a.norentm}"));
        DateTime dateB = DateTime.parse(formatToDateTime("${b.norentm}"));
        return dateB.compareTo(dateA);
      });
    } else if (sorting == "TIMEASC") {
      _gttOrderBookModel!.sort((a, b) {
        DateTime dateA = DateTime.parse(formatToDateTime("${a.norentm}"));
        DateTime dateB = DateTime.parse(formatToDateTime("${b.norentm}"));
        return dateA.compareTo(dateB);
      });
    }
    notifyListeners();
  }

  void filterOrders({required String sorting}) {
    // Save the last sort method
    _lastOrderSortMethod = sorting;

    // Determine which lists to sort (both main lists and search results)
    List<OrderBookModel>? mainListToSort;
    List<OrderBookModel>? searchListToSort;

    if (_selectedTab == 0) {
      mainListToSort = _openOrder;
      searchListToSort = _orderSearchItem;
    } else if (_selectedTab == 1) {
      mainListToSort = _executedOrder;
      searchListToSort = _orderSearchItem;
    } else if (_selectedTab == 2) {
      // Trade book - handle separately since it's a different model type
      _sortTradeBook(sorting);
      return;
    } else if (_selectedTab == 3) {
      // GTT orders - handle separately since it's a different model type
      _sortGttOrders(sorting);
      return;
    } else if (_selectedTab == 4) {
      // Alerts - handle separately since it's a different model type
      ref.read(marketWatchProvider).filterPendingAlert(sorting);
      return;
    } else {
      mainListToSort = _allOrder;
      searchListToSort = _orderSearchItem;
    }

    // Sort main list if it exists
    if (mainListToSort != null && mainListToSort.isNotEmpty) {
      _applySortingToOrderList(mainListToSort, sorting);
    }

    // Sort search results if they exist
    if (searchListToSort != null && searchListToSort.isNotEmpty) {
      _applySortingToOrderList(searchListToSort, sorting);
    }

    notifyListeners();
  }

  void _applySortingToOrderList(
      List<OrderBookModel> listToSort, String sorting) {
    // Sorting logic based on the 'sorting' parameter
    switch (sorting) {
      case "ASC":
        listToSort.sort((a, b) => a.tsym!.compareTo(b.tsym!));
        break;
      case "DSC":
        listToSort.sort((a, b) => b.tsym!.compareTo(a.tsym!));
        break;
      case "LTPASC":
        listToSort.sort((a, b) {
          final aLtp = double.tryParse(a.ltp ?? '0.0') ?? 0.0;
          final bLtp = double.tryParse(b.ltp ?? '0.0') ?? 0.0;
          return aLtp.compareTo(bLtp);
        });
        break;
      case "LTPDSC":
        listToSort.sort((a, b) {
          final aLtp = double.tryParse(a.ltp ?? '0.0') ?? 0.0;
          final bLtp = double.tryParse(b.ltp ?? '0.0') ?? 0.0;
          return bLtp.compareTo(aLtp);
        });
        break;
      case "PRODUCTASC":
        listToSort.sort((a, b) => a.sPrdtAli!.compareTo(b.sPrdtAli!));
        break;
      case "PRODUCTDSC":
        listToSort.sort((a, b) => b.sPrdtAli!.compareTo(a.sPrdtAli!));
        break;
      case "QTYASC":
        listToSort.sort((a, b) {
          final aQty = int.tryParse(a.qty ?? '0') ?? 0;
          final bQty = int.tryParse(b.qty ?? '0') ?? 0;
          return aQty.compareTo(bQty);
        });
        break;
      case "QTYDSC":
        listToSort.sort((a, b) {
          final aQty = int.tryParse(a.qty ?? '0') ?? 0;
          final bQty = int.tryParse(b.qty ?? '0') ?? 0;
          return bQty.compareTo(aQty);
        });
        break;
      case "TIMEASC":
      case "TIMEDSC":
        // Parse each timestamp ONCE (N parses) instead of inside the
        // comparator (2 × N·logN parses) — keeps tab switches snappy on
        // large order books.
        final bool descending = sorting == "TIMEDSC";
        final keyed = listToSort
            .map((o) => MapEntry(_orderTimeSortKey(o.norentm), o))
            .toList();
        keyed.sort((a, b) => descending
            ? b.key.compareTo(a.key)
            : a.key.compareTo(b.key));
        for (int i = 0; i < keyed.length; i++) {
          listToSort[i] = keyed[i].value;
        }
        break;
      default:
        // No sorting
        break;
    }
  }

  /// Converts the API's "HH:mm:ss dd-MM-yyyy" order timestamp into a
  /// sortable DateTime; malformed/empty values sort to the very end.
  DateTime _orderTimeSortKey(String? value) {
    if (value == null || value.isEmpty) return DateTime(1970);
    final parts = value.split(' ');
    if (parts.length != 2) return DateTime(1970);
    final dateParts = parts[1].split('-');
    if (dateParts.length != 3) return DateTime(1970);
    return DateTime.tryParse(
            '${dateParts[2]}-${dateParts[1]}-${dateParts[0]} ${parts[0]}') ??
        DateTime(1970);
  }

  void _sortTradeBook(String sorting) {
    // Sort main trade book list
    if (_tradeBook != null && _tradeBook!.isNotEmpty) {
      _applySortingToTradeBookList(_tradeBook!, sorting);
    }

    // Sort trade book search results
    if (_tradeBooksearch != null && _tradeBooksearch!.isNotEmpty) {
      _applySortingToTradeBookList(_tradeBooksearch!, sorting);
    }
  }

  void _applySortingToTradeBookList(List<dynamic> listToSort, String sorting) {
    // Sorting logic for trade book
    switch (sorting) {
      case "ASC":
        listToSort.sort((a, b) => a.tsym!.compareTo(b.tsym!));
        break;
      case "DSC":
        listToSort.sort((a, b) => b.tsym!.compareTo(a.tsym!));
        break;
      case "LTPASC":
        listToSort.sort((a, b) {
          final aPrice = double.tryParse(a.avgprc ?? '0.0') ?? 0.0;
          final bPrice = double.tryParse(b.avgprc ?? '0.0') ?? 0.0;
          return aPrice.compareTo(bPrice);
        });
        break;
      case "LTPDSC":
        listToSort.sort((a, b) {
          final aPrice = double.tryParse(a.avgprc ?? '0.0') ?? 0.0;
          final bPrice = double.tryParse(b.avgprc ?? '0.0') ?? 0.0;
          return bPrice.compareTo(aPrice);
        });
        break;
      case "PRODUCTASC":
        listToSort.sort((a, b) => a.sPrdtAli!.compareTo(b.sPrdtAli!));
        break;
      case "PRODUCTDSC":
        listToSort.sort((a, b) => b.sPrdtAli!.compareTo(a.sPrdtAli!));
        break;
      case "QTYASC":
        listToSort.sort((a, b) {
          final aQty = int.tryParse(a.flqty ?? '0') ?? 0;
          final bQty = int.tryParse(b.flqty ?? '0') ?? 0;
          return aQty.compareTo(bQty);
        });
        break;
      case "QTYDSC":
        listToSort.sort((a, b) {
          final aQty = int.tryParse(a.flqty ?? '0') ?? 0;
          final bQty = int.tryParse(b.flqty ?? '0') ?? 0;
          return bQty.compareTo(aQty);
        });
        break;
      case "TIMEASC":
        listToSort.sort((a, b) {
          final aDate = DateTime.tryParse(formatToDateTime(a.norentm ?? '')) ??
              DateTime(1970);
          final bDate = DateTime.tryParse(formatToDateTime(b.norentm ?? '')) ??
              DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case "TIMEDSC":
        listToSort.sort((a, b) {
          final aDate = DateTime.tryParse(formatToDateTime(a.norentm ?? '')) ??
              DateTime(1970);
          final bDate = DateTime.tryParse(formatToDateTime(b.norentm ?? '')) ??
              DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      default:
        // No sorting
        break;
    }
  }

  void _sortGttOrders(String sorting) {
    // Sort main GTT orders list
    if (_gttOrderBookModel != null && _gttOrderBookModel!.isNotEmpty) {
      _applySortingToGttOrdersList(_gttOrderBookModel!, sorting);
    }

    // Sort GTT orders search results
    if (_gttOrderBookSearch != null && _gttOrderBookSearch!.isNotEmpty) {
      _applySortingToGttOrdersList(_gttOrderBookSearch!, sorting);
    }
  }

  void _applySortingToGttOrdersList(List<dynamic> listToSort, String sorting) {
    // Sorting logic for GTT orders
    switch (sorting) {
      case "ASC":
        listToSort.sort((a, b) => a.tsym!.compareTo(b.tsym!));
        break;
      case "DSC":
        listToSort.sort((a, b) => b.tsym!.compareTo(a.tsym!));
        break;
      case "LTPASC":
        listToSort.sort((a, b) {
          final aPrice = double.tryParse(a.d ?? '0.0') ?? 0.0;
          final bPrice = double.tryParse(b.d ?? '0.0') ?? 0.0;
          return aPrice.compareTo(bPrice);
        });
        break;
      case "LTPDSC":
        listToSort.sort((a, b) {
          final aPrice = double.tryParse(a.d ?? '0.0') ?? 0.0;
          final bPrice = double.tryParse(b.d ?? '0.0') ?? 0.0;
          return bPrice.compareTo(aPrice);
        });
        break;
      case "PRODUCTASC":
        listToSort.sort((a, b) {
          final aProduct = a.placeOrderParams?.sPrdtAli ?? '';
          final bProduct = b.placeOrderParams?.sPrdtAli ?? '';
          return aProduct.compareTo(bProduct);
        });
        break;
      case "PRODUCTDSC":
        listToSort.sort((a, b) {
          final aProduct = a.placeOrderParams?.sPrdtAli ?? '';
          final bProduct = b.placeOrderParams?.sPrdtAli ?? '';
          return bProduct.compareTo(aProduct);
        });
        break;
      case "QTYASC":
        listToSort.sort((a, b) {
          final aQty = a.qty ?? 0;
          final bQty = b.qty ?? 0;
          return aQty.compareTo(bQty);
        });
        break;
      case "QTYDSC":
        listToSort.sort((a, b) {
          final aQty = a.qty ?? 0;
          final bQty = b.qty ?? 0;
          return bQty.compareTo(aQty);
        });
        break;
      case "TIMEASC":
        listToSort.sort((a, b) {
          final aDate = DateTime.tryParse(formatToDateTime(a.norentm ?? '')) ??
              DateTime(1970);
          final bDate = DateTime.tryParse(formatToDateTime(b.norentm ?? '')) ??
              DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case "TIMEDSC":
        listToSort.sort((a, b) {
          final aDate = DateTime.tryParse(formatToDateTime(a.norentm ?? '')) ??
              DateTime(1970);
          final bDate = DateTime.tryParse(formatToDateTime(b.norentm ?? '')) ??
              DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      default:
        // No sorting
        break;
    }
  }

  placeGTTOrder(PlaceGTTOrderInput input, BuildContext context) async {
    try {
      _placeGttOrderModel = await api.placeGTTOrderAPI(input);

      if (_placeGttOrderModel!.stat == "OI created") {
        ConstantName.sessCheck = true;
        // Deliberately NOT clearing the form here. With the sticky order
        // window on the dialog stays open, and clearing left the user staring
        // at three empty boxes. Delivery and Intraday keep their values in the
        // same situation, so GTT now behaves the same way. Stale values cannot
        // leak into a new dialog: place_order_screen_web clears GTT state when
        // the dialog opens.
        // ref.read(ordInputProvider).clearTextField();
        await fetchGTTOrderBook(context, "");

        if (kIsWeb) {
          // On web, let the screen handle closing the dialog
          // Don't call Navigator.pop here as it causes context issues
        } else {
          Navigator.pop(context);
          ref.read(indexListProvider).bottomMenu(2, context);
          // Switch to Orders tab in Portfolio screen
          ref.read(portfolioProvider).changeTabIndex(2);
          changeTabIndex(3, context);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        if (_placeGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          final errorMsg = _placeGttOrderModel!.emsg ??
              _placeGttOrderModel!.stat ??
              "Failed to place GTT order";
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context, errorMsg);
          } else {
            warningMessage(context, errorMsg);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API GTT Order ", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  modifyGTTOrder(PlaceGTTOrderInput input, BuildContext context) async {
    toggleLoadingOn(true);
    try {
      _modifyGttOrderModel = await api.modifyGTTOrderAPI(input);

      if (_modifyGttOrderModel!.stat == "OI replaced") {
        ConstantName.sessCheck = true;
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Modified Order");
        } else {
          successMessage(context, "Modified Order");
        }
        ref.read(ordInputProvider).clearTextField();
        await fetchGTTOrderBook(context, "");

        if (kIsWeb) {
          // On web, skip Navigator.pop and bottomMenu navigation
          // The draggable dialog will handle closing itself
        } else {
          Navigator.pop(context);
          ref.read(indexListProvider).bottomMenu(2, context);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        if (_modifyGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _modifyGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Modify GTT Order ", "Error": "$e"});
    } finally {
      toggleLoadingOn(false);
      notifyListeners();
    }
  }

  /// [isOco] only picks the wording. The cancel API takes just an alert id,
  /// so it cannot tell a single GTT from an OCO - the caller knows and says.
  cancelGttOrder(String canId, BuildContext context,
      {bool isOco = false}) async {
    toggleLoadingOn(true);
    final String label = isOco ? "OCO" : "GTT";
    try {
      _placeGttOrderModel = await api.cancelGTTOrderAPI(canId);

      if (_placeGttOrderModel!.stat == "OI deleted") {
        ConstantName.sessCheck = true;

        // Show success message - ResponsiveSnackBar for web, ScaffoldMessenger for mobile
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(
              context, "$label Order Cancelled Successfully");
        } else {
          showResponsiveSuccess(context, "$label Order Cancelled Successfully");
          Navigator.pop(context);
        }
      } else {
        if (_placeGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      if (_placeGttOrderModel!.stat == "Invalid Oi") {
        await fetchGTTOrderBook(context, "");
        // Show warning message - ResponsiveSnackBar for web, ScaffoldMessenger for mobile
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Provided $label Order is not found");
        } else {
          showResponsiveWarningMessage(
              context, "Provided $label Order is not found");
          Navigator.pop(context);
        }

        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Provided $label Order is not found");
        } else {
          warningMessage(context, "Provided $label Order is not found");
        }
        Navigator.pop(context);
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API GTT Order  CANCEL", "Error": "$e"});
    } finally {
      await fetchGTTOrderBook(context, "");
      toggleLoadingOn(false);
      notifyListeners();
    }
  }

  placeOCOOrder(PlaceOcoOrderInput input, BuildContext context) async {
    try {
      _placeGttOrderModel = await api.placeOCOOrderAPI(input);

      if (_placeGttOrderModel!.stat == "OI created") {
        ConstantName.sessCheck = true;
        // Deliberately NOT clearing the form here. With the sticky order
        // window on the dialog stays open, and clearing left the user staring
        // at three empty boxes. Delivery and Intraday keep their values in the
        // same situation, so GTT now behaves the same way. Stale values cannot
        // leak into a new dialog: place_order_screen_web clears GTT state when
        // the dialog opens.
        // ref.read(ordInputProvider).clearTextField();
        await fetchGTTOrderBook(context, "");

        if (kIsWeb) {
          // On web, let the screen handle closing the dialog
          // Don't call Navigator.pop here as it causes context issues
        } else {
          Navigator.pop(context);
          ref.read(indexListProvider).bottomMenu(2, context);
          ref.read(portfolioProvider).changeTabIndex(2);
          changeTabIndex(3, context);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        if (_placeGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          final errorMsg = _placeGttOrderModel!.emsg ??
              _placeGttOrderModel!.stat ??
              "Failed to place OCO order";
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context, errorMsg);
          } else {
            warningMessage(context, errorMsg);
          }
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API OCO Order ", "Error": "$e"});
    } finally {
      notifyListeners();
    }
  }

  modifyOCOOrder(PlaceOcoOrderInput input, BuildContext context) async {
    toggleLoadingOn(true);
    try {
      _modifyGttOrderModel = await api.modifyOCOOrderAPI(input);

      if (_modifyGttOrderModel!.stat == "OI replaced") {
        ConstantName.sessCheck = true;
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Modified Order");
        } else {
          successMessage(context, "Modified Order");
        }
        ref.read(ordInputProvider).clearTextField();
        await fetchGTTOrderBook(context, "");

        if (kIsWeb) {
          // On web, skip Navigator.pop and bottomMenu navigation
          // The draggable dialog will handle closing itself
        } else {
          Navigator.pop(context);
          ref.read(indexListProvider).bottomMenu(2, context);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        if (_modifyGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _modifyGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Modify OCO Order ", "Error": "$e"});
    } finally {
      toggleLoadingOn(false);
      notifyListeners();
    }
  }

  createBasketOrder(String val, BuildContext context) async {
    String curDate = convDateWithTime();
    getBasketName();

    // Check for duplicate basket names (case-insensitive)
    final trimmedName = val.trim();
    final lowerCaseName = trimmedName.toLowerCase();

    for (var basket in _bsktList) {
      if (basket['bsketName'].toString().toLowerCase() == lowerCaseName) {
        // Show error if duplicate found
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Basket name '$trimmedName' already exists");
        } else {
          warningMessage(context, "Basket name '$trimmedName' already exists");
        }

        return; // Exit without creating duplicate
      }
    }

    _bsktList.add({
      "bsketName": trimmedName,
      "createdDate": curDate,
      "max": basketMaxOrders.toString(),
      "curLength": '0'
    });
    final userId = pref.clientId;
    if (userId != null && userId.isNotEmpty) {
      await pref.setBasketListForUser(userId, jsonEncode(_bsktList));
    } else {
      await pref.setBasketList(jsonEncode(_bsktList));
    }
    getBasketName();

    // Auto-select the newly created basket
    await chngBsktName(val, context, true);

    tabSize();
    Navigator.pop(context);
    notifyListeners();
  }

  renameBasketOrder(
      String oldName, String newName, BuildContext context) async {
    final trimmedNewName = newName.trim();
    final lowerCaseNewName = trimmedNewName.toLowerCase();

    // Nothing to do only when the name is exactly the same. A case-only
    // change ("abc" -> "ABC") used to be dropped here.
    if (oldName == trimmedNewName) {
      Navigator.pop(context);
      return;
    }

    // Check for duplicate basket names (the basket being renamed is not a
    // duplicate of itself, so a case-only rename passes)
    for (var basket in _bsktList) {
      final existing = basket['bsketName'].toString().toLowerCase();
      if (existing == oldName.toLowerCase()) continue;
      if (existing == lowerCaseNewName) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Basket name '$trimmedNewName' already exists");
        } else {
          warningMessage(
              context, "Basket name '$trimmedNewName' already exists");
        }
        return;
      }
    }

    // Update name in _bsktList
    for (int i = 0; i < _bsktList.length; i++) {
      if (_bsktList[i]['bsketName'].toString().toLowerCase() ==
          oldName.toLowerCase()) {
        _bsktList[i]['bsketName'] = trimmedNewName;
        break;
      }
    }

    // Update key in _bsktScrips map
    String? scriptsKey;
    for (var key in _bsktScrips.keys) {
      if (key.toLowerCase() == oldName.toLowerCase()) {
        scriptsKey = key;
        break;
      }
    }
    if (scriptsKey != null) {
      final scripts = _bsktScrips.remove(scriptsKey);
      _bsktScrips[trimmedNewName] = scripts;
    }

    // Update overall status tracking as well
    String? statusKey;
    for (var key in _basketOverallStatus.keys) {
      if (key.toLowerCase() == oldName.toLowerCase()) {
        statusKey = key;
        break;
      }
    }
    if (statusKey != null) {
      final status = _basketOverallStatus.remove(statusKey);
      if (status != null) {
        _basketOverallStatus[trimmedNewName] = status;
      }
    }

    // Sync with storage
    final userId = pref.clientId;
    if (userId != null && userId.isNotEmpty) {
      await pref.setBasketListForUser(userId, jsonEncode(_bsktList));
      await pref.setBasketScripForUser(userId, jsonEncode(_bsktScrips));
    } else {
      await pref.setBasketList(jsonEncode(_bsktList));
      await pref.setBasketScrip(jsonEncode(_bsktScrips));
    }

    // If currently selected, update that too
    if (_selectedBsktName.toLowerCase() == oldName.toLowerCase()) {
      _selectedBsktName = trimmedNewName;
    }

    // Refresh and close dialog
    getBasketName();
    Navigator.pop(context);
    notifyListeners();
  }

  getBasketName() async {
    _isBasketLoading = true;
    notifyListeners();

    final userId = pref.clientId;


    // Check both storages to find where the data actually exists
    final generalBasketScrips = pref.bsktScrips ?? "";
    final userBasketScrips = (userId != null && userId.isNotEmpty)
        ? (pref.getBasketScripsForUser(userId) ?? "")
        : "";


    // Use the storage that has data, prioritizing user-specific if both have data
    bool useUserStorage = false;

    if (userId != null && userId.isNotEmpty) {
      // Check if user-specific storage has been initialized (exists and is not just "{}")
      bool userStorageInitialized =
          userBasketScrips.isNotEmpty && userBasketScrips != "{}";

      if (userStorageInitialized) {
        useUserStorage = true;
      } else if (generalBasketScrips.isNotEmpty &&
          generalBasketScrips != "{}" &&
          generalBasketScrips.length > 10) {
        // Only migrate if user storage has never been initialized
        final userBasketList = pref.getBasketListForUser(userId) ?? "";
        bool userListInitialized =
            userBasketList.isNotEmpty && userBasketList != "[]";

        if (!userListInitialized) {
          // First time migration - user storage is completely uninitialized
          await pref.setBasketScripForUser(userId, generalBasketScrips);

          final generalBasketList = pref.bsktList ?? "";
          if (generalBasketList.isNotEmpty) {
            await pref.setBasketListForUser(userId, generalBasketList);
          }

          // Clear general storage after successful migration
          await pref.setBasketScrip("{}");
          await pref.setBasketList("[]");

          useUserStorage = true;
        } else {
          // User storage exists but is empty - user has cleared their baskets
          useUserStorage = true;
        }
      } else {
        useUserStorage = true; // Default to user storage for new users
      }
    }

    if (useUserStorage && userId != null && userId.isNotEmpty) {
      // User-specific storage
      final userBasketList = pref.getBasketListForUser(userId) ?? "";
      final finalUserBasketScrips = pref.getBasketScripsForUser(userId) ?? "";


      _bsktList = userBasketList.isEmpty ? [] : jsonDecode(userBasketList);
      _bsktScrips = finalUserBasketScrips.isEmpty
          ? {}
          : jsonDecode(finalUserBasketScrips);
    } else {
      // General storage
      final generalBasketList = pref.bsktList ?? "";


      _bsktList =
          generalBasketList.isEmpty ? [] : jsonDecode(generalBasketList);
      _bsktScrips =
          generalBasketScrips.isEmpty ? {} : jsonDecode(generalBasketScrips);
    }


    if (_bsktList.isNotEmpty) {
      for (var element in _bsktList) {
        String basketName = element['bsketName'];
        List scipList = _bsktScrips[basketName] ?? [];
        element['curLength'] = "${scipList.length}";


        if (_selectedBsktName == basketName) {
          _bsktScripList = List.from(scipList);
        }
      }
    }


    _isBasketLoading = false;

    // Restore order tracking data after loading baskets
    await _restoreOrderTrackingData();

    tabSize();
    notifyListeners();
  } 

  // removeBasket(int index) async {

  //   _bsktList.removeAt(index);
  //   final userId = pref.clientId;
  //   if (userId != null && userId.isNotEmpty) {
  //     await pref.setBasketListForUser(userId, jsonEncode(_bsktList));
  //     _bsktList = pref.getBasketListForUser(userId)!.isEmpty
  //         ? []
  //         : jsonDecode(pref.getBasketListForUser(userId)!);
  //   } else {
  //     await pref.setBasketList(jsonEncode(_bsktList));
  //     _bsktList = pref.bsktList!.isEmpty ? [] : jsonDecode(pref.bsktList!);
  //   }
  //   tabSize();
  //   notifyListeners();
  // }

  Future<void> removeBasket(int index) async {
    // 1. Grab the basket name BEFORE you remove it
    final String removedBasketName = _bsktList[index]['bsketName'];

    // 2. Remove from list
    _bsktList.removeAt(index);

    // 3. Persist the updated basket list
    final userId = pref.clientId;
    if (userId != null && userId.isNotEmpty) {
      await pref.setBasketListForUser(userId, jsonEncode(_bsktList));
    } else {
      await pref.setBasketList(jsonEncode(_bsktList));
    }

    // 4. ALSO remove the scripts for that basket
    //    Get the current scripts map
    Map<String, dynamic> allScripts;
    if (userId != null && userId.isNotEmpty) {
      final raw = pref.getBasketScripsForUser(userId) ?? "{}";
      allScripts = raw.isEmpty ? {} : jsonDecode(raw);
      // Remove the key
      allScripts.remove(removedBasketName);
      // Persist back
      await pref.setBasketScripForUser(userId, jsonEncode(allScripts));
    } else {
      final raw = pref.bsktScrips ?? "{}";
      allScripts = raw.isEmpty ? {} : jsonDecode(raw);
      allScripts.remove(removedBasketName);
      await pref.setBasketScrip(jsonEncode(allScripts));
    }

    // 5. Update your in-memory map
    _bsktScrips = allScripts;
    // 5. **Reset all order‑tracking for that basket**
    resetBasketOrderTracking(removedBasketName);
    // TC_487: if the deleted basket was the open one, drop the selection so
    // the option chain sidebar stops showing it and scrips can't be added to it.
    if (_selectedBsktName == removedBasketName) {
      _selectedBsktName = "";
      _bsktScripList = [];
    }
    // 6. Refresh any dependent state (recomputing curLength etc.)
    tabSize();
    notifyListeners();
  }

  removeBsktScrip(int index, String bsktName) async {
    try {

      Map<String, dynamic> data = {};
      final userId = pref.clientId;
      // 1️⃣ Capture the removed item
      final removedItem = _bsktScripList[index];
      final List<String> removedOrderIds =
          List<String>.from(removedItem['orderIds'] ?? <String>[]);

      // Get current basket scrips data
      if (userId != null && userId.isNotEmpty) {
        final userBasketScrips = pref.getBasketScripsForUser(userId) ?? "";
        data = userBasketScrips.isEmpty ? {} : jsonDecode(userBasketScrips);
      } else {
        final generalBasketScrips = pref.bsktScrips ?? "";
        data =
            generalBasketScrips.isEmpty ? {} : jsonDecode(generalBasketScrips);
      }


      // Remove from local list
      if (index >= 0 && index < _bsktScripList.length) {
        final removedItem = _bsktScripList.removeAt(index);
      }

      // Update the basket data with the modified list
      data[bsktName] = List.from(_bsktScripList);

      // Also update the local _bsktScrips to keep it in sync
      _bsktScrips = Map.from(data);

      // Save to preferences
      String jsonData = jsonEncode(data);

      if (userId != null && userId.isNotEmpty) {
        await pref.setBasketScripForUser(userId, jsonData);

        // Clear general storage to prevent conflicts after user makes changes
        if (pref.bsktScrips != null && pref.bsktScrips!.isNotEmpty) {
          await pref.setBasketScrip("{}");
        }
      } else {
        await pref.setBasketScrip(jsonData);
      }

      // 4️⃣ Only remove individual script orders if there actually were any
      if (removedOrderIds.isNotEmpty) {
        // Create a unique key for this script (token + index is more reliable than just token)
        String scriptKey = "${removedItem['token']}_$index";
        // Remove only this script's order tracking, not the entire basket
        removeScriptOrderTracking(bsktName, scriptKey, removedOrderIds);
      }


      // Refresh all basket data
      await getBasketName();
      notifyListeners();
    } catch (e) {
      // Still refresh basket data in case of error
      await getBasketName();
      notifyListeners();
    }
  }

  addToBasket(String basketName, Map<String, dynamic> basketItem,
      {BuildContext? context}) async {
    try {

      Map<String, dynamic> data = {};
      final userId = pref.clientId;

      // Get existing basket scrips data
      if (userId != null && userId.isNotEmpty) {
        final userBasketScrips = pref.getBasketScripsForUser(userId) ?? "";
        data = userBasketScrips.isEmpty ? {} : jsonDecode(userBasketScrips);
      } else {
        final generalBasketScrips = pref.bsktScrips ?? "";
        data =
            generalBasketScrips.isEmpty ? {} : jsonDecode(generalBasketScrips);
      }

      // Get current scripts in the basket
      List currentScripts = data[basketName] ?? [];

      // Check basket limit (frezQtyOrderSliceMaxLimit items max)
      if (currentScripts.length >= frezQtyOrderSliceMaxLimit) {
        if (context != null) {
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context,
                "Basket limit reached. Cannot add more than $frezQtyOrderSliceMaxLimit items to a basket.");
          } else {
            warningMessage(context,
                "Basket limit reached. Cannot add more than $frezQtyOrderSliceMaxLimit items to a basket.");
          }
        }
        return false; // Return false to indicate failure
      }

      // Calculate splits needed for the new item
      final currentQty = int.parse(basketItem['qty'].toString());
      final currentFrzQty = basketItem['frzqty'] != null
          ? int.parse(basketItem['frzqty'].toString())
          : null;

      List<Map<String, dynamic>> itemsToAdd = [];

      if (currentFrzQty != null && currentQty > currentFrzQty) {
        // Calculate number of full splits and remainder
        final fullSplits = currentQty ~/ currentFrzQty; // Integer division
        final remainder = currentQty % currentFrzQty;

        // Add full splits
        for (int i = 0; i < fullSplits; i++) {
          Map<String, dynamic> splitItem = Map.from(basketItem);
          splitItem['qty'] = currentFrzQty.toString();
          itemsToAdd.add(splitItem);
        }

        // Add remainder if exists
        if (remainder > 0) {
          Map<String, dynamic> remainderItem = Map.from(basketItem);
          remainderItem['qty'] = remainder.toString();
          itemsToAdd.add(remainderItem);
        }
      } else {
        // No split needed
        itemsToAdd.add(basketItem);
      }

      // Check if total orders in basket would exceed limit
      int currentBasketOrders = currentScripts.length;
      int newOrders = itemsToAdd.length;

      if (currentBasketOrders + newOrders > frezQtyOrderSliceMaxLimit) {
        if (context != null) {
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context,
                "Cannot add to basket. Total orders would be ${currentBasketOrders + newOrders}, which exceeds the maximum limit of $frezQtyOrderSliceMaxLimit orders.");
          } else {
            warningMessage(context,
                "Cannot add to basket. Total orders would be ${currentBasketOrders + newOrders}, which exceeds the maximum limit of $frezQtyOrderSliceMaxLimit orders.");
          }
        }
        return false; // Return false to indicate failure
      }

      // Add all split items to the basket
      currentScripts.addAll(itemsToAdd);

      // Update the data
      data[basketName] = currentScripts;
      _bsktScrips = Map.from(data);

      // Save back to preferences
      String jsonData = jsonEncode(data);

      if (userId != null && userId.isNotEmpty) {
        await pref.setBasketScripForUser(userId, jsonData);

        // Clear general storage to prevent conflicts
        if (pref.bsktScrips != null && pref.bsktScrips!.isNotEmpty) {
          await pref.setBasketScrip("{}");
        }
      } else {
        await pref.setBasketScrip(jsonData);
      }


      // Refresh basket data
      await getBasketName();
      notifyListeners();
      return true; // Return true to indicate success
    } catch (e) {
      await getBasketName();
      notifyListeners();
      return false; // Return false to indicate failure
    }
  }

  fetchBasketMargin() async {
    try {
      List basket = [];
      if (_bsktScripList.isNotEmpty) {
        // Include ALL scripts in margin calculation (including executed ones)
        for (var i = 1; i < _bsktScripList.length; i++) {
          final prctyp = (_bsktScripList[i]["prctype"] ??
                  _bsktScripList[i]["prctyp"] ??
                  "MKT")
              .toString();
          final prc = _bsktScripList[i]["prc"]?.toString() ?? '0';
          // tsym is already URL-encoded when saved to basket, pass as-is
          basket.add({
            "exch": _bsktScripList[i]["exch"]?.toString() ?? '',
            "tsym": _bsktScripList[i]["tsym"]?.toString() ?? '',
            "qty": _bsktScripList[i]["qty"]?.toString() ?? '0',
            "prc": (prctyp == "MKT" || prctyp == "SL-MKT") ? '0' : prc,
            "prd": _bsktScripList[i]["prd"]?.toString() ?? '',
            "trantype": _bsktScripList[i]["trantype"]?.toString() ?? '',
            "prctyp": prctyp,
            "trgprc": _bsktScripList[i]["trgprc"]?.toString() ?? '',
            "blprc": _bsktScripList[i]["blprc"]?.toString() ?? '',
            "bpprc": _bsktScripList[i]["bpprc"]?.toString() ?? ''
          });
        }

        // Qty is already stored as actual quantity (lots × lotSize) for MCX in web basket
        String qty = _bsktScripList[0]["qty"]?.toString() ?? '0';
        final prctyp0 = (_bsktScripList[0]["prctype"] ??
                _bsktScripList[0]["prctyp"] ??
                "MKT")
            .toString();
        final prc0 = _bsktScripList[0]["prc"]?.toString() ?? '0';
        // tsym is already URL-encoded when saved to basket, decode it here
        // because getBasketMargin will re-encode it for the main input
        final tsym0 = _bsktScripList[0]["tsym"]?.toString() ?? '';
        final decodedTsym0 =
            tsym0.isNotEmpty ? Uri.decodeComponent(tsym0) : '';

        // Use first script as main input with available order parameters
        OrderMarginInput inputs = OrderMarginInput(
            exch: _bsktScripList[0]["exch"]?.toString() ?? '',
            prc: (prctyp0 == "MKT" || prctyp0 == "SL-MKT") ? '0' : prc0,
            prctyp: prctyp0,
            prd: _bsktScripList[0]["prd"]?.toString() ?? '',
            qty: qty,
            trantype: _bsktScripList[0]["trantype"]?.toString() ?? '',
            tsym: decodedTsym0,
            trgprc: _bsktScripList[0]["trgprc"]?.toString() ?? '',
            rorgprc: '', // Not available in basket data
            rorgqty: '', // Not available in basket data
            blprc: _bsktScripList[0]["blprc"]?.toString() ?? '',
            bpprc: _bsktScripList[0]["bpprc"]?.toString() ?? '');
        _bsktOrderMargin = await api.getBasketMargin(inputs, basket);
      }

      notifyListeners();
    } catch (e) {
    }
  }

  fetchSipPlaceOrder(BuildContext context, SipInputField sipOrderInput) async {
    try {
      toggleLoadingOn(true);
      _sipPlaceOrder = await api.getPlaceSipOrder(sipOrderInput);
      if (_sipPlaceOrder!.reqStatus == "OK") {
        changeTabIndex(5, context);
        ref.read(indexListProvider).bottomMenu(2, context);
        // Switch to Orders tab in Portfolio screen
        ref.read(portfolioProvider).changeTabIndex(2);
        fetchSipOrderHistory(context);
        tabSize();
        Navigator.pop(context);

        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(
              context, "Order is Placed Sucessfully");
        } else {
          successMessage(context, "Order is Placed Sucessfully");
        }
        notifyListeners();
      } else if (_sipPlaceOrder!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }

      notifyListeners();
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "API", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  /// Place SIP basket order with multiple scrips
  Future<SipPlaceOrderModel?> placeSipBasketOrder(
      SipBasketInput sipBasketInput, BuildContext context) async {
    try {
      toggleLoadingOn(true);
      _sipPlaceOrder = await api.getPlaceSipBasketOrder(sipBasketInput);
      if (_sipPlaceOrder!.reqStatus == "OK") {
        changeTabIndex(5, context);
        ref.read(indexListProvider).bottomMenu(2, context);
        ref.read(portfolioProvider).changeTabIndex(2);
        fetchSipOrderHistory(context);
        tabSize();
      } else if (_sipPlaceOrder!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _sipPlaceOrder;
    } catch (e) {
      ref.read(indexListProvider).logError.add({"type": "SIP BASKET API", "Error": "$e"});
      notifyListeners();
      return null;
    } finally {
      toggleLoadingOn(false);
    }
  }

  fetchModifySipOrder(
      BuildContext context, ModifySipInput modifysipinput) async {
    try {
      toggleLoadingOn(true);
      _modifySipModel = await api.getmodifysiporder(modifysipinput);
      if (_modifySipModel!.reqStatus == "OK") {
        Navigator.pop(context);
        Navigator.pop(context);
        fetchSipOrderHistory(context);

        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(
              context, "Order is Modified Sucessfully");
        } else {
          successMessage(context, "Order is Modified Successfully");
        }
      }
      if (_modifySipModel!.reqStatus == "NOT_OK") {
        if (kIsWeb) {
          ResponsiveSnackBar.showError(
              context, "${_modifySipModel!.rejreason}");
        } else {
          error(context, "${_modifySipModel!.rejreason}");
        }
      } else if (_modifySipModel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _modifySipModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "MODIFYSIP API", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future<ModifySIPModel?> modifySipBasketOrder(
      BuildContext context, ModifySipInput modifysipinput) async {
    try {
      toggleLoadingOn(true);
      _modifySipModel = await api.getmodifysiporder(modifysipinput);
      if (_modifySipModel!.reqStatus == "OK") {
        fetchSipOrderHistory(context);
      } else if (_modifySipModel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _modifySipModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "MODIFYSIP API", "Error": "$e"});
      notifyListeners();
      return null;
    } finally {
      toggleLoadingOn(false);
    }
  }

  filterSipOrder(String sorting) {
    if (sorting == "ASC") {
      _siporderBookModel!.sipDetails!
          .sort((a, b) => a.sipName!.compareTo(b.sipName!));
    } else if (sorting == "DSC") {
      _siporderBookModel!.sipDetails!
          .sort((a, b) => b.sipName!.compareTo(a.sipName!));
    } else if (sorting == "LTPASC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        return double.parse(a.scrips![0].ltp ?? "0.00")
            .compareTo(double.parse(b.scrips![0].ltp ?? "0.00"));
      });
    } else if (sorting == "LTPDSC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        return double.parse(b.scrips![0].ltp ?? "0.00")
            .compareTo(double.parse(a.scrips![0].ltp ?? "0.00"));
      });
    } else if (sorting == "PRECHANGASC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        return double.parse(a.scrips![0].perChange ?? "0.00")
            .compareTo(double.parse(b.scrips![0].perChange ?? "0.00"));
      });
    } else if (sorting == "PRECHANGDSC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        return double.parse(b.scrips![0].perChange ?? "0.00")
            .compareTo(double.parse(a.scrips![0].perChange ?? "0.00"));
      });
    } else if (sorting == "DATEASC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        String dateA = duedateformate(value: "${a.internal!.dueDate}");
        String dateB = duedateformate(value: "${b.internal!.dueDate}");
        return dateA.compareTo(dateB);
      });
    } else if (sorting == "DATEDSC") {
      _siporderBookModel!.sipDetails!.sort((a, b) {
        String dateA = duedateformate(value: "${a.internal!.dueDate}");
        String dateB = duedateformate(value: "${b.internal!.dueDate}");
        return dateB.compareTo(dateA);
      });
    }
    notifyListeners();
  }

  Future fetchSipOrderHistory(BuildContext context) async {
    try {
      // Show loader on first load (when no existing data)
      if (_siporderBookModel == null) {
        loading = true;
        notifyListeners();
      }
      _siporderBookModel = await api.getSipOrderBook();
      _updateTabNamesSilent();
      List ltpArgs = [];
      if (_siporderBookModel != null) {
        if (_siporderBookModel!.sipDetails != null) {
          ConstantName.sessCheck = true;
          for (var main = 0;
              main < _siporderBookModel!.sipDetails!.length;
              main++) {
            for (var i = 0;
                i < _siporderBookModel!.sipDetails![main].scrips!.length;
                i++) {
              ltpArgs.add({
                "exch":
                    "${_siporderBookModel!.sipDetails![main].scrips![i].exch}",
                "token":
                    "${_siporderBookModel!.sipDetails![main].scrips![i].token}"
              });
            }
          }
          final response = await api.getLTP(ltpArgs);
          Map res = jsonDecode(response.body);

          for (var main = 0;
              main < _siporderBookModel!.sipDetails!.length;
              main++) {
            for (var i = 0;
                i < _siporderBookModel!.sipDetails![main].scrips!.length;
                i++) {
              if (_siporderBookModel!.sipDetails![main].scrips![i].token
                      .toString() ==
                  "${res["data"]["${_siporderBookModel!.sipDetails![main].scrips![i].token}"]['token']}") {
                _siporderBookModel!.sipDetails![main].scrips![i].ltp =
                    "${res["data"]["${_siporderBookModel!.sipDetails![main].scrips![i].token}"]["lp"]}";
                _siporderBookModel!.sipDetails![main].scrips![i].close =
                    "${res["data"]["${_siporderBookModel!.sipDetails![main].scrips![i].token}"]["close"]}";

                _siporderBookModel!.sipDetails![main].scrips![i].perChange =
                    "${res["data"]["${_siporderBookModel!.sipDetails![main].scrips![i].token}"]["change"]}";
                _siporderBookModel!
                    .sipDetails![main].scrips![i].change = (double.parse(
                            "${_siporderBookModel!.sipDetails![main].scrips![i].ltp == "0" ? _siporderBookModel!.sipDetails![main].scrips![i].close : _siporderBookModel!.sipDetails![main].scrips![i].ltp}") -
                        double.parse(
                            "${_siporderBookModel!.sipDetails![main].scrips![i].close}"))
                    .toStringAsFixed(2);
              }
            }
          }
        } else {
          if (_siporderBookModel!.emsg ==
              "Session Expired :  Invalid Session Key") {
            ref.read(authProvider).ifSessionExpired(context);
          }
        }
      }
      notifyListeners();
      return _siporderBookModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "SIP ORDER HISTORY API", "Error": "$e"});
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future fetchSipOrderCancel(String sipOrderno, context) async {
    try {
      _cancleSipOrder = await api.getSipCancelOrder(sipOrderno);
      await fetchSipOrderHistory(context);
      if (_cancleSipOrder!.reqStatus == "OK") {
        tabSize();
        // Only pop navigation on mobile - web handles its own navigation (sheets)
        if (!kIsWeb) {
          Navigator.pop(context);
          Navigator.pop(context);
          successMessage(context, "Order Sucessfully Cancelled");
        } else {
          ResponsiveSnackBar.showSuccess(
              context, "SIP Order Cancelled Successfully");
        }
      } else if (cancleSipOrder!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      return _cancleSipOrder;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "SIP CANCEL API", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  /// Places one basket row. Returns 'ok', 'failed' or 'session' (expired).
  /// Shared by placeBasketOrder (whole basket) and placeBasketItems (TC_324.2).
  Future<String> _placeBasketElement(BuildContext context, Map element,
      String basketName, String itemKey) async {

    // Set channel - use empty string like mobile, or set to WEB for web platform
    String channelValue = '';
    if (kIsWeb) {
      channelValue = 'WEB';
    } else {
      channelValue = defaultTargetPlatform == TargetPlatform.android
          ? '${ref.read(authProvider).deviceInfo["brand"]}'
          : "${ref.read(authProvider).deviceInfo["model"]}";
    }

    // Set default validity (ret) if not provided - same logic as mobile/web place order screens
    String retValue = element['ret']?.toString().trim() ?? '';
    if (retValue.isEmpty) {
      // Default validity based on exchange: EOS for BSE/BFO, DAY for others
      String exchange = element['exch']?.toString() ?? '';
      if (exchange == "BSE" || exchange == "BFO") {
        retValue = "EOS";
      } else {
        retValue = "DAY";
      }
    }

    // Convert prd to correct code format (same as mobile)
    // API expects: "C" (Delivery/CNC), "I" (Intraday/MIS), "F" (MTF), "B" (Bracket), "H" (Cover), "M" (Carry Forward/NRML)
    String prdValue = element['prd']?.toString().trim() ?? '';
    String ordTypeValue = element['ordType']?.toString().trim() ?? '';
    String prdCode = prdValue;

    // If prd is stored as name, convert to code
    if (prdValue.isNotEmpty) {
      // Check if it's already a code (single character)
      if (prdValue.length == 1 &&
          ['C', 'I', 'F', 'B', 'H', 'M'].contains(prdValue.toUpperCase())) {
        prdCode = prdValue.toUpperCase();
      } else {
        // Convert name to code
        // For "CO - BO", check ordType to determine if it's Cover (H) or Bracket (B)
        if (prdValue == 'CO - BO' || prdValue == 'CO-BO') {
          if (ordTypeValue == 'CO') {
            prdCode = 'H'; // Cover Order
          } else if (ordTypeValue == 'BO') {
            prdCode = 'B'; // Bracket Order
          } else {
            // Default to Bracket if ordType is not available
            prdCode = 'B';
          }
        } else {
          Map<String, String> nameToCode = {
            'Delivery': 'C',
            'Intraday': 'I',
            'MTF': 'F',
            'MIS': 'I',
            'CNC': 'C',
            'NRML': 'M',
            'CO': 'H',
            'BO': 'B',
          };
          prdCode =
              nameToCode[prdValue] ?? 'C'; // Default to 'C' if not found
        }
      }

      // Final validation: For NSE/BSE equity orders, "M" (Carry Forward) is not valid
      // Convert "M" to "C" (Delivery) for equity orders to prevent rejection
      String exchange = element['exch']?.toString().trim() ?? '';
      String tsym = element['tsym']?.toString().trim() ?? '';
      bool isEquity = (exchange == "NSE" || exchange == "BSE") &&
          (tsym.endsWith("-EQ") || tsym.contains("EQ"));

      if (prdCode == 'M' && isEquity) {
        prdCode =
            'C'; // Convert Carry Forward to Delivery for equity orders
      }
    } else {
      // Default to 'C' (Delivery) if prd is empty
      prdCode = 'C';
    }

      // Qty is already stored as actual quantity (lots × lotSize) for MCX in web basket
      final int finalQty =
    int.tryParse(element['qty']?.toString() ?? '0') ?? 0;

    PlaceOrderInput placeOrderInput = PlaceOrderInput(
        amo: element['amo'],
        blprc: element['blprc'],
        bpprc: element['bpprc'],
        dscqty: element['dscqty'],
        exch: element['exch'],
        prc: element['mktProt'].toString().isNotEmpty
            ? element['lp']
            : element['prc'],
        prctype: element['prctype'],
        prd: prdCode, // Use converted code
        qty: finalQty.toString(),
        ret: retValue,
        trailprc: '',
        trantype: element['trantype'],
        trgprc: element['trgprc'],
        tsym: element['tsym'],
        mktProt: element['mktProt'],
        channel: channelValue);

    // Print the PlaceOrderInput payload that will be sent to API

    // Print as JSON for easy copy-paste
    Map<String, dynamic> payloadMap = {
      "exch": placeOrderInput.exch,
      "tsym": placeOrderInput.tsym,
      "qty": placeOrderInput.qty,
      "prc": (placeOrderInput.prctype == 'MKT' ||
              placeOrderInput.prctype == 'SL-MKT')
          ? '0'
          : placeOrderInput.prc,
      "prd": placeOrderInput.prd,
      "trantype": placeOrderInput.trantype,
      "prctyp": placeOrderInput.prctype,
      "ret": placeOrderInput.ret.toUpperCase(),
      "channel": placeOrderInput.channel,
      "amo": placeOrderInput.amo,
      "blprc": placeOrderInput.blprc,
      "bpprc": placeOrderInput.bpprc,
      "dscqty": placeOrderInput.dscqty,
      "trgprc": placeOrderInput.trgprc,
      "trailprc": placeOrderInput.trailprc,
      "mkt_protection": placeOrderInput.mktProt,
    };

    _placeOrderModel = await api.getPlaceOrder(placeOrderInput, _ip);

    if (_placeOrderModel != null) {

      // Print full response as JSON
    }

    if (_placeOrderModel!.emsg ==
            "Session Expired :  Invalid Session Key" &&
        _placeOrderModel!.stat == "Not_Ok") {
      ref.read(authProvider).ifSessionExpired(context);
      return 'session';
    } else if (_placeOrderModel!.stat == "Ok" &&
        _placeOrderModel!.norenordno != null) {
      // Store successful order details
      String orderId = _placeOrderModel!.norenordno!;

      _basketOrderIds[basketName]!.add(orderId);
      _basketOrderStatuses[basketName]![itemKey] = 'placed';

      // Add order tracking to basket item
      element['orderIds'] = element['orderIds'] ?? [];
      element['orderIds'].add(orderId);
      element['orderStatus'] = 'placed';

      ConstantName.sessCheck = true;
      return 'ok';
    } else {
      // Handle failed order

      _basketOrderStatuses[basketName]![itemKey] = 'failed';
      element['orderStatus'] = 'failed';
      element['orderError'] = _placeOrderModel!.emsg ?? 'Unknown error';
      // TC_324.1: shown as the tooltip on the FAILED badge in the basket.
      element['rejectionReason'] = _placeOrderModel!.emsg ?? 'Unknown error';

      // IMPORTANT: Even failed orders should be tracked if they have an order number
      // Some APIs return order numbers even for failed orders
      if (_placeOrderModel!.norenordno != null) {
        String failedOrderId = _placeOrderModel!.norenordno!;
        _basketOrderIds[basketName]!.add(failedOrderId);
        element['orderIds'] = element['orderIds'] ?? [];
        element['orderIds'].add(failedOrderId);
      }
      return 'failed';
    }
  }

  placeBasketOrder(BuildContext context,
      {bool navigateToOrderBook = true}) async {
    try {
      // Initialize basket tracking for current basket
      String basketName = _selectedBsktName;

      _basketOrderIds[basketName] = [];
      _basketOrderStatuses[basketName] = {};
      _basketOverallStatus[basketName] = 'placing';

      notifyListeners();

      List<String> successfulOrders = [];
      List<String> failedOrders = [];

      // Sort basket list to place BUY orders before SELL orders
      List<Map<String, dynamic>> sortedBsktScripList =
          List.from(_bsktScripList);
      sortedBsktScripList.sort((a, b) {
        String tranTypeA = a['trantype'] ?? '';
        String tranTypeB = b['trantype'] ?? '';
        // BUY (B) orders first, then SELL (S) orders
        if (tranTypeA == 'B' && tranTypeB == 'S') return -1;
        if (tranTypeA == 'S' && tranTypeB == 'B') return 1;
        return 0;
      });

      for (int index = 0; index < sortedBsktScripList.length; index++) {
        var element = sortedBsktScripList[index];
        String itemKey = "${element['tsym']}_${element['token']}_$index";

        final result =
            await _placeBasketElement(context, element, basketName, itemKey);
        if (result == 'session') break;
        if (result == 'ok') {
          successfulOrders.add((element['orderIds'] as List).last.toString());
        } else {
          failedOrders.add(element['tsym']);
        }
      }


      // Update overall basket status
      if (failedOrders.isEmpty) {
        _basketOverallStatus[basketName] = 'placed';
      } else if (successfulOrders.isEmpty) {
        _basketOverallStatus[basketName] = 'failed';
      } else {
        _basketOverallStatus[basketName] = 'partially_placed';
      }

      if (navigateToOrderBook) {
        ref.read(indexListProvider).bottomMenu(2, context);

        await fetchOrderBook(context, false);

        await changeTabIndex(0, context);
        ref.read(indexListProvider).bottomMenu(2, context);

        Navigator.pop(context);
      }

      // Save order tracking data to preferences
      await _saveOrderTrackingData();

      // Show appropriate success/failure message
      String message;
      if (failedOrders.isEmpty) {
        message =
            "Basket Order Successfully Placed (${successfulOrders.length} orders)";
      } else if (successfulOrders.isEmpty) {
        message = "Basket Order Failed - No orders placed";
      } else {
        message =
            "Basket Order Partially Placed - ${successfulOrders.length} success, ${failedOrders.length} failed";
      }

      if (kIsWeb) {
        ResponsiveSnackBar.showSuccess(context, message);
      } else {
        successMessage(context, message);
      }

      notifyListeners();
    } catch (e, stackTrace) {

      // Update basket status to failed
      if (_selectedBsktName.isNotEmpty) {
        _basketOverallStatus[_selectedBsktName] = 'failed';
      }
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Place Slice  Order", "Error": "$e"});
      notifyListeners();
    }
  }

  /// TC_324.2 (Kite style): place only the given rows of the selected basket.
  /// A row that already has a status (sent before, even if FAILED) is never
  /// sent again. Earlier order tracking is kept; new order ids are appended.
  Future<void> placeBasketItems(BuildContext context, List<int> indices) async {
    final basketName = _selectedBsktName;
    if (basketName.isEmpty) return;
    final previousStatus = _basketOverallStatus[basketName];
    try {
      final rows = <int>[
        for (final i in indices.toSet())
          if (i >= 0 &&
              i < _bsktScripList.length &&
              _bsktScripList[i]['orderStatus'] == null)
            i
      ]..sort();
      if (rows.isEmpty) return;

      // BUY rows before SELL rows, same as placeBasketOrder.
      final ordered = [
        ...rows.where((i) => _bsktScripList[i]['trantype'] != 'S'),
        ...rows.where((i) => _bsktScripList[i]['trantype'] == 'S'),
      ];

      _basketOrderIds.putIfAbsent(basketName, () => []);
      _basketOrderStatuses.putIfAbsent(basketName, () => {});
      _basketOverallStatus[basketName] = 'placing';
      notifyListeners();

      int ok = 0;
      int failed = 0;
      for (final i in ordered) {
        final element = _bsktScripList[i];
        final itemKey = "${element['tsym']}_${element['token']}_$i";
        final result =
            await _placeBasketElement(context, element, basketName, itemKey);
        if (result == 'session') break;
        if (result == 'ok') {
          ok++;
        } else {
          failed++;
        }
      }

      if (ok == 0 && failed == 0) {
        // Session expired before anything was sent.
        if (previousStatus != null) {
          _basketOverallStatus[basketName] = previousStatus;
        } else {
          _basketOverallStatus.remove(basketName);
        }
        notifyListeners();
        return;
      }

      // Refined by the next order-book refresh (_updateBasketOrderStatusSilent).
      _basketOverallStatus[basketName] = failed == 0
          ? 'placed'
          : ok == 0
              ? 'failed'
              : 'partially_placed';

      await _saveOrderTrackingData();

      if (failed == 0) {
        ResponsiveSnackBar.showSuccess(
            context, "Basket Order Successfully Placed ($ok orders)");
      } else if (ok == 0) {
        ResponsiveSnackBar.showError(
            context, "Basket Order Failed - No orders placed");
      } else {
        ResponsiveSnackBar.showSuccess(context,
            "Basket Order Partially Placed - $ok success, $failed failed");
      }
      notifyListeners();
    } catch (e) {
      if (previousStatus != null) {
        _basketOverallStatus[basketName] = previousStatus;
      } else {
        _basketOverallStatus.remove(basketName);
      }
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Place Basket Items", "Error": "$e"});
      notifyListeners();
    }
  }

  /// TC_324.2 (Kite "Delete (N)"): remove several rows from a basket.
  /// Removing a sent row only drops it from the basket — the order itself
  /// stays in the order book.
  Future<void> removeBsktScrips(List<int> indices, String bsktName) async {
    final sorted = indices.toSet().toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      await removeBsktScrip(i, bsktName);
    }
    // Saved row statuses are matched by position — re-save after the shift.
    await _saveOrderTrackingData();
    notifyListeners();
  }

  // Method to update basket order statuses from order book data
  void updateBasketOrderStatus() async {
    try {
      Set<String> basketsToProcess = Set<String>.from(_basketOrderIds.keys);

      if (_selectedBsktName.isNotEmpty && _bsktScripList.isNotEmpty) {
        bool hasItemOrders = _bsktScripList.any(
            (item) => item['orderIds'] != null && item['orderIds'].isNotEmpty);
        if (hasItemOrders) {
          basketsToProcess.add(_selectedBsktName);
        }
      }

      // Build order lookup map once for O(1) lookups
      final Map<String, OrderBookModel> orderLookup = {};
      if (_orderBookModel != null) {
        for (var order in _orderBookModel!) {
          if (order.norenordno != null) {
            orderLookup[order.norenordno!] = order;
          }
        }
      }

      for (String basketName in basketsToProcess) {
        List<String> orderIds = _basketOrderIds[basketName] ?? [];

        if (orderIds.isEmpty && basketName == _selectedBsktName) {
          Set<String> itemOrderIds = {};
          for (var item in _bsktScripList) {
            if (item['orderIds'] != null && item['orderIds'].isNotEmpty) {
              itemOrderIds.addAll(List<String>.from(item['orderIds']));
            }
          }
          orderIds = itemOrderIds.toList();
          if (orderIds.isNotEmpty) {
            _basketOrderIds[basketName] = orderIds;
          }
        }

        if (orderIds.isEmpty) continue;

        Map<String, String> orderIdToStatus = {};
        Map<String, OrderBookModel> orderIdToModel = {};
        int completedCount = 0;
        int rejectedCount = 0;

        for (String orderId in orderIds) {
          // O(1) lookup instead of linear search
          OrderBookModel? order = orderLookup[orderId];

          if (order != null && order.status != null) {
            String actualStatus = order.status!;
            orderIdToStatus[orderId] = actualStatus;
            orderIdToModel[orderId] = order;

            if (actualStatus == 'COMPLETE') {
              completedCount++;
            } else if (actualStatus == 'REJECTED' ||
                actualStatus == 'CANCELED') {
              rejectedCount++;
            }
          }
        }

        // Update individual basket items with real order statuses
        _updateBasketItemStatusesWithOrderBook(
            basketName, orderIdToStatus, orderIdToModel);

        // Update overall basket status based on real statuses
        if (completedCount == orderIds.length) {
          _basketOverallStatus[basketName] = 'completed';
        } else if (rejectedCount == orderIds.length) {
          _basketOverallStatus[basketName] = 'failed';
        } else if (rejectedCount > 0 &&
            (rejectedCount + completedCount) == orderIds.length) {
          _basketOverallStatus[basketName] = 'partially_completed';
        } else if (completedCount > 0) {
          _basketOverallStatus[basketName] = 'partially_filled';
        } else {
          _basketOverallStatus[basketName] = 'placed';
        }
      }

      // Save updated tracking data
      await _saveOrderTrackingData();

      notifyListeners();
    } catch (e) {
    }
  }

  // Helper method to find order by ID in all order lists
  OrderBookModel? _findOrderById(String orderId) {
    if (_orderBookModel != null) {
      try {
        return _orderBookModel!.firstWhere(
          (order) => order.norenordno == orderId,
        );
      } catch (_) {}
    }

    if (_executedOrder != null) {
      try {
        return _executedOrder!.firstWhere(
          (order) => order.norenordno == orderId,
        );
      } catch (_) {}
    }

    if (_openOrder != null) {
      try {
        return _openOrder!.firstWhere(
          (order) => order.norenordno == orderId,
        );
      } catch (_) {}
    }

    return null;
  }

  // Method to update individual basket items with order book data
  void _updateBasketItemStatusesWithOrderBook(
      String basketName,
      Map<String, String> orderIdToStatus,
      Map<String, OrderBookModel> orderIdToModel) {
    // Update basket items with real order data
    for (var element in _bsktScripList) {
      if (element['orderIds'] != null) {
        List<String> itemOrderIds = List<String>.from(element['orderIds']);

        // Find the status for this item's orders
        List<String> itemStatuses = [];
        List<String> itemOrderDetails = [];

        for (String orderId in itemOrderIds) {
          if (orderIdToStatus.containsKey(orderId)) {
            String status = orderIdToStatus[orderId]!;
            itemStatuses.add(status);

            // Add order details for display
            OrderBookModel? orderModel = orderIdToModel[orderId];
            if (orderModel != null) {
              String detail = 'ID: $orderId, Status: $status';
              if (orderModel.avgprc != null && orderModel.avgprc != "0.00") {
                detail += ', Avg: ₹${orderModel.avgprc}';
              }
              itemOrderDetails.add(detail);
            }
          }
        }

        // Set the primary status for this item (worst case scenario)
        if (itemStatuses.isEmpty) {
          element['orderStatus'] = null;
          element['orderDetails'] = null;
        } else if (itemStatuses.contains('REJECTED')) {
          element['orderStatus'] = 'REJECTED';
          // TC_324.1: keep the exchange/RMS reason for the badge tooltip.
          for (String orderId in itemOrderIds) {
            final reason = orderIdToModel[orderId]?.rejreason?.trim() ?? '';
            if (orderIdToStatus[orderId] == 'REJECTED' && reason.isNotEmpty) {
              element['rejectionReason'] = reason;
              break;
            }
          }
        } else if (itemStatuses.contains('CANCELED')) {
          element['orderStatus'] = 'CANCELED';
        } else if (itemStatuses.contains('COMPLETE')) {
          element['orderStatus'] = itemStatuses.every((s) => s == 'COMPLETE')
              ? 'COMPLETE'
              : 'PARTIAL';
        } else {
          element['orderStatus'] = 'OPEN';
        }

        // Store order details for UI display
        if (itemStatuses.isNotEmpty) {
          element['orderDetails'] = itemOrderDetails;
        }

      } else if (element['orderStatus'] == 'failed') {
        // TC_324.1: refused by the API (no order number) — keep FAILED and its
        // reason until the user resets the basket.
      } else {
        // No order IDs means the item was never placed, reset any existing status
        element['orderStatus'] = null;
        element['orderDetails'] = null;
      }
    }
  }

  // Method to validate and clean up stale order statuses for all baskets
  void validateAllBasketOrderStatuses() {
    if (_orderBookModel == null || _orderBookModel!.isEmpty) {
      return;
    }

    // Create map of all current order IDs in orderbook for fast lookup
    Set<String> currentOrderIds = {};
    for (var order in _orderBookModel!) {
      if (order.norenordno != null) {
        currentOrderIds.add(order.norenordno!);
      }
    }

    // Check all basket items and reset status if order ID not found
    for (var element in _bsktScripList) {
      if (element['orderIds'] != null) {
        List<String> itemOrderIds = List<String>.from(element['orderIds']);

        // Check if any of the order IDs still exist in orderbook
        bool hasValidOrder = false;
        for (String orderId in itemOrderIds) {
          if (currentOrderIds.contains(orderId)) {
            hasValidOrder = true;
            break;
          }
        }

        // If no valid orders found, reset the status
        if (!hasValidOrder) {
          element['orderStatus'] = null;
          element['orderDetails'] = null;
          element['orderIds'] = null; // Also clear the order IDs
        }
      }
    }

    notifyListeners();
  }

  // Method to save cleaned basket data back to preferences
  Future<void> _saveBasketToPreferences(String basketName) async {
    try {
      final userId = pref.clientId;
      if (userId != null && userId.isNotEmpty) {
        // Update the basket data in memory
        _bsktScrips[basketName] = _bsktScripList;

        // Save to user-specific preferences
        final updatedBasketData = jsonEncode(_bsktScrips);
        await pref.setBasketScripForUser(userId, updatedBasketData);
      } else {
        // Update the basket data in memory
        _bsktScrips[basketName] = _bsktScripList;

        // Save to general preferences
        final updatedBasketData = jsonEncode(_bsktScrips);
        await pref.setBasketScrip(updatedBasketData);
      }
    } catch (e) {
    }
  }

  // Method to update individual basket item statuses
  void _updateBasketItemStatuses(
      String basketName, Map<String, String> orderStatuses) {
    try {
      for (int index = 0; index < _bsktScripList.length; index++) {
        var element = _bsktScripList[index];
        List<String>? orderIds = element['orderIds'];

        if (orderIds != null && orderIds.isNotEmpty) {
          // Check if any of the order IDs have been updated
          for (String orderId in orderIds) {
            if (orderStatuses.containsKey(orderId)) {
              element['orderStatus'] = orderStatuses[orderId];

              // Find full order details for additional info
              OrderBookModel? order = _orderBookModel?.firstWhere(
                (ord) => ord.norenordno == orderId,
                orElse: () => OrderBookModel(),
              );

              if (order?.avgprc != null) {
                element['avgPrice'] = order!.avgprc;
              }
              if (order?.fillshares != null) {
                element['filledQty'] = order!.fillshares;
              }
              if (order?.rejreason != null) {
                element['rejectionReason'] = order!.rejreason;
              }
            }
          }
        }
      }
    } catch (e) {
    }
  }

  // Method to reset basket order tracking
  void resetBasketOrderTracking(String basketName) {
    _basketOrderIds.remove(basketName);
    _basketOrderStatuses.remove(basketName);
    _basketOverallStatus.remove(basketName);

    // _bsktScripList is the open basket's rows, so only clear it when that
    // is the basket being reset (the option-chain picker can reset another).
    if (basketName == _selectedBsktName) {
      for (var element in _bsktScripList) {
        _clearRowOrderFields(element);
      }
    }

    // Also clear from persistent storage immediately
    _clearBasketFromPersistentStorage(basketName);
    // TC_293: the saved basket rows carry orderIds too (written back when the
    // basket is reopened). Left there, the next reload from storage - adding
    // a scrip, reopening, F5 - brought the old statuses back after a reset.
    _clearBasketRowsOrderFieldsInStorage(basketName);

    // Save the reset state to preferences
    _saveOrderTrackingData();

    notifyListeners();
  }

  void _clearRowOrderFields(Map element) {
    element.remove('orderIds');
    element.remove('orderStatus');
    element.remove('orderError');
    element.remove('avgPrice');
    element.remove('filledQty');
    element.remove('rejectionReason');
  }

  // Strips the sent-order fields from one basket's saved rows, using the same
  // storage the basket scrips are read from (per-user, else general).
  Future<void> _clearBasketRowsOrderFieldsInStorage(String basketName) async {
    try {
      final userId = pref.clientId;
      final bool perUser = userId != null && userId.isNotEmpty;
      final String raw = (perUser
              ? pref.getBasketScripsForUser(userId)
              : pref.bsktScrips) ??
          "";
      if (raw.isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(raw);
      final List? rows = data[basketName];
      if (rows == null || rows.isEmpty) return;
      for (final row in rows) {
        if (row is Map) _clearRowOrderFields(row);
      }

      final String jsonData = jsonEncode(data);
      if (perUser) {
        await pref.setBasketScripForUser(userId, jsonData);
      } else {
        await pref.setBasketScrip(jsonData);
      }
      if (_bsktScrips.containsKey(basketName)) {
        _bsktScrips[basketName] =
            basketName == _selectedBsktName ? _bsktScripList : rows;
      }
    } catch (e) {
    }
  }

  // Helper method to clear specific basket from persistent storage
  Future<void> _clearBasketFromPersistentStorage(String basketName) async {
    try {
      final userId = pref.clientId;
      String? existingJsonData;

      if (userId != null && userId.isNotEmpty) {
        existingJsonData = pref.getOrderTrackingForUser(userId);
      } else {
        existingJsonData = pref.orderTracking;
      }

      if (existingJsonData != null && existingJsonData.isNotEmpty) {
        final existingData = jsonDecode(existingJsonData);

        // Clear this basket from all tracking data in persistent storage
        if (existingData['basketOrderIds'] != null) {
          (existingData['basketOrderIds'] as Map).remove(basketName);
        }
        if (existingData['basketOrderStatuses'] != null) {
          (existingData['basketOrderStatuses'] as Map).remove(basketName);
        }
        if (existingData['basketOverallStatus'] != null) {
          (existingData['basketOverallStatus'] as Map).remove(basketName);
        }
        if (existingData['basketItemsData'] != null) {
          (existingData['basketItemsData'] as Map).remove(basketName);
        }

        // Save the updated data back to persistent storage
        final updatedJsonData = jsonEncode(existingData);
        if (userId != null && userId.isNotEmpty) {
          await pref.setOrderTrackingForUser(userId, updatedJsonData);
        } else {
          await pref.setOrderTracking(updatedJsonData);
        }
      }
    } catch (e) {
    }
  }

  // Method to remove individual script order tracking without affecting other scripts
  void removeScriptOrderTracking(
      String basketName, String scriptKey, List<String> orderIds) {
    // Remove specific order IDs from basket tracking
    if (_basketOrderIds.containsKey(basketName)) {
      for (String orderId in orderIds) {
        _basketOrderIds[basketName]?.remove(orderId);
      }
      // If no more orders left in basket, remove the basket entry
      if (_basketOrderIds[basketName]?.isEmpty ?? true) {
        _basketOrderIds.remove(basketName);
        _basketOrderStatuses.remove(basketName);
        _basketOverallStatus.remove(basketName);
      }
    }

    // Remove from basket order statuses
    if (_basketOrderStatuses.containsKey(basketName)) {
      _basketOrderStatuses[basketName]?.remove(scriptKey);
    }

    // Clear the individual script's order data from persistent storage
    _removeScriptFromPersistentStorage(basketName, scriptKey);

    // Save the updated state
    _saveOrderTrackingData();

    notifyListeners();
  }

  // Helper method to remove specific script from persistent storage
  Future<void> _removeScriptFromPersistentStorage(
      String basketName, String scriptKey) async {
    try {
      final userId = pref.clientId;
      String? existingJsonData;

      if (userId != null && userId.isNotEmpty) {
        existingJsonData = pref.getOrderTrackingForUser(userId);
      } else {
        existingJsonData = pref.orderTracking;
      }

      if (existingJsonData != null && existingJsonData.isNotEmpty) {
        final existingData = jsonDecode(existingJsonData);

        // Remove specific script from basketItemsData
        if (existingData['basketItemsData'] != null &&
            existingData['basketItemsData'][basketName] != null) {
          List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
              existingData['basketItemsData'][basketName]);

          // Remove items matching the script key (token + index combination)
          items.removeWhere((item) {
            String itemKey = "${item['token']}_${item['index']}";
            return itemKey == scriptKey;
          });

          if (items.isNotEmpty) {
            existingData['basketItemsData'][basketName] = items;
          } else {
            (existingData['basketItemsData'] as Map).remove(basketName);
          }
        }

        // Save the updated data back to persistent storage
        final updatedJsonData = jsonEncode(existingData);
        if (userId != null && userId.isNotEmpty) {
          await pref.setOrderTrackingForUser(userId, updatedJsonData);
        } else {
          await pref.setOrderTracking(updatedJsonData);
        }
      }
    } catch (e) {
    }
  }

  // Method to check if basket has been placed
  bool isBasketPlaced(String basketName) {
    String status = _basketOverallStatus[basketName] ?? '';
    return [
      'placed',
      'partially_placed',
      'partially_filled',
      'partially_completed',
      'completed',
      'failed'
    ].contains(status);
  }

  // Method to get basket status for UI display
  String? getBasketStatus(String basketName) {
    return _basketOverallStatus[basketName];
  }

  // Save order tracking data to preferences
  Future<void> _saveOrderTrackingData() async {
    try {
      final userId = pref.clientId;

      // Read existing basket items data first to preserve other baskets' data
      Map<String, List<Map<String, dynamic>>> basketItemsData = {};
      try {
        String? existingJsonData;
        if (userId != null && userId.isNotEmpty) {
          existingJsonData = pref.getOrderTrackingForUser(userId);
        } else {
          existingJsonData = pref.orderTracking;
        }

        if (existingJsonData != null && existingJsonData.isNotEmpty) {
          final existingData = jsonDecode(existingJsonData);
          basketItemsData = Map<String, List<Map<String, dynamic>>>.from(
              (existingData['basketItemsData'] ?? {}).map((key, value) =>
                  MapEntry(key, List<Map<String, dynamic>>.from(value))));
        }
      } catch (e) {
      }

      // Update current basket's item data
      if (_selectedBsktName.isNotEmpty && _bsktScripList.isNotEmpty) {
        String basketName = _selectedBsktName;
        if (_basketOrderIds.containsKey(basketName) &&
            _basketOrderIds[basketName]!.isNotEmpty) {
          List<Map<String, dynamic>> itemsWithOrders = [];
          for (int index = 0; index < _bsktScripList.length; index++) {
            var item = _bsktScripList[index];
            if (item['orderIds'] != null && item['orderIds'].isNotEmpty) {
              itemsWithOrders.add({
                'tsym': item['tsym'],
                'token': item['token'],
                'index': index, // Include index to handle duplicates
                'orderIds': item['orderIds'],
                'orderStatus': item['orderStatus'],
                'orderError': item['orderError'],
                'avgPrice': item['avgPrice'],
                'filledQty': item['filledQty'],
                'rejectionReason': item['rejectionReason'],
              });
            }
          }
          basketItemsData[basketName] = itemsWithOrders;
        }
      }

      final orderTrackingData = {
        'basketOrderIds': _basketOrderIds,
        'basketOrderStatuses': _basketOrderStatuses,
        'basketOverallStatus': _basketOverallStatus,
        'basketItemsData': basketItemsData,
      };

      final jsonData = jsonEncode(orderTrackingData);
      if (userId != null && userId.isNotEmpty) {
        await pref.setOrderTrackingForUser(userId, jsonData);
      } else {
        await pref.setOrderTracking(jsonData);
      }
    } catch (e) {
    }
  }

  // Restore order tracking data from preferences
  Future<void> _restoreOrderTrackingData() async {
    try {
      final userId = pref.clientId;
      String? jsonData;

      if (userId != null && userId.isNotEmpty) {
        jsonData = pref.getOrderTrackingForUser(userId);
      } else {
        jsonData = pref.orderTracking;
      }

      if (jsonData != null && jsonData.isNotEmpty) {
        final data = jsonDecode(jsonData);
        _basketOrderIds = Map<String, List<String>>.from(
            (data['basketOrderIds'] ?? {})
                .map((key, value) => MapEntry(key, List<String>.from(value))));
        _basketOrderStatuses = Map<String, Map<String, String>>.from(
            (data['basketOrderStatuses'] ?? {}).map((key, value) =>
                MapEntry(key, Map<String, String>.from(value))));
        _basketOverallStatus =
            Map<String, String>.from(data['basketOverallStatus'] ?? {});

        // Restore basket item order data
        Map<String, dynamic> basketItemsData = data['basketItemsData'] ?? {};
        _restoreBasketItemOrderDataFromSaved(basketItemsData);

      }
    } catch (e) {
    }
  }

  // Method to restore order tracking data to basket items from saved data
  void _restoreBasketItemOrderDataFromSaved(
      Map<String, dynamic> basketItemsData) {
    if (_selectedBsktName.isEmpty || _bsktScripList.isEmpty) return;

    String basketName = _selectedBsktName;
    List<dynamic>? savedItems = basketItemsData[basketName];

    if (savedItems == null || savedItems.isEmpty) return;


    // Match saved items with current basket items using proper index-based matching
    for (int index = 0; index < _bsktScripList.length; index++) {
      var currentItem = _bsktScripList[index];

      // Find matching saved item by tsym, token, and index (to handle duplicates correctly)
      for (var savedItem in savedItems) {
        if (savedItem['tsym'] == currentItem['tsym'] &&
            savedItem['token'] == currentItem['token'] &&
            savedItem['index'] == index) {
          // Restore all order tracking fields
          currentItem['orderIds'] = savedItem['orderIds'];
          currentItem['orderStatus'] = savedItem['orderStatus'];
          currentItem['orderError'] = savedItem['orderError'];
          currentItem['avgPrice'] = savedItem['avgPrice'];
          currentItem['filledQty'] = savedItem['filledQty'];
          currentItem['rejectionReason'] = savedItem['rejectionReason'];

          break;
        }
      }
    }
  }

  // Method to restore order tracking data to basket items (fallback method)
  void _restoreBasketItemOrderData() {
    if (_selectedBsktName.isEmpty || _bsktScripList.isEmpty) return;

    String basketName = _selectedBsktName;
    List<String> orderIds = _basketOrderIds[basketName] ?? [];

    if (orderIds.isEmpty) return;


    // For each basket item, restore its order tracking data if it exists
    for (int index = 0; index < _bsktScripList.length; index++) {
      var element = _bsktScripList[index];
      String itemKey = "${element['tsym']}_${element['token']}_$index";

      // Check if this item has order data
      String? itemStatus = _basketOrderStatuses[basketName]?[itemKey];
      if (itemStatus != null) {
        // Find matching order IDs for this item
        List<String> itemOrderIds = [];
        for (String orderId in orderIds) {
          // Try to match order to item - this is a simplified approach
          // In a more complex scenario, you might need better mapping
          OrderBookModel? order = _findOrderById(orderId);
          if (order != null && order.tsym == element['tsym']) {
            itemOrderIds.add(orderId);
            break; // Assuming one order per item for now
          }
        }

        if (itemOrderIds.isNotEmpty) {
          element['orderIds'] = itemOrderIds;
          element['orderStatus'] = itemStatus;

          // Get latest status from order book
          OrderBookModel? order = _findOrderById(itemOrderIds.first);
          if (order != null && order.status != null) {
            element['orderStatus'] = order.status!;
          }

        }
      }
    }
  }

  Future fetchPlaceGTTOrder(
      PlaceGTTOrderInput placeGttOrderInput, BuildContext context) async {
    try {
      _placeGttOrderModel = await api.placeGTTOrderAPI(placeGttOrderInput);

      if (_placeGttOrderModel!.stat == "OI created") {
        ConstantName.sessCheck = true;
        ref.read(ordInputProvider).clearTextField();
        await fetchGTTOrderBook(context, "");

        // Show success message - ResponsiveSnackBar for web, ScaffoldMessenger for mobile
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "order triggered successfully");
        } else {
          // ScaffoldMessenger.of(context)
          //     .showSnackBar(successMessage(context, "Order Placed Successfully"));
        }

        if (kIsWeb) {
          // On web, skip Navigator.pop and bottomMenu navigation
          // The draggable dialog will handle closing itself
        } else {
          Navigator.pop(context);
          ref.read(indexListProvider).bottomMenu(2, context);
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        if (_placeGttOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeGttOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          final errorMsg = _placeGttOrderModel!.emsg ??
              _placeGttOrderModel!.stat ??
              "Failed to place GTT order";
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context, errorMsg);
          } else {
            warningMessage(context, errorMsg);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API GTT Order ", "Error": "$e"});
      notifyListeners();
    } finally {}
  }
}

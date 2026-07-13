// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mynt_plus/screens/web/chart/web_chart_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mynt_plus/provider/stocks_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/provider/user_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/marketwatch_model/scrip_overview/eodchartdata_model.dart';
import '../utils/custom_navigator.dart';
import '../screens/web/market_watch/scrip_tabs_manager.dart';
import '../models/marketwatch_model/add_delete_scrip_model.dart';
import '../models/marketwatch_model/alert_model/alert_pending_model.dart';
import '../models/marketwatch_model/alert_model/cancel_alert_model.dart';
import '../models/marketwatch_model/alert_model/manage_price_alert_model.dart';
import '../models/marketwatch_model/alert_model/modify_alert_model.dart';
import '../models/marketwatch_model/alert_model/set_alert_model.dart';
import '../models/marketwatch_model/get_quotes.dart';
import '../models/marketwatch_model/linked_scrips.dart';
import '../models/marketwatch_model/market_watch_scrip_model.dart';
import '../models/marketwatch_model/market_watchlist_model.dart';
import '../models/marketwatch_model/opt_chain_model.dart';
import '../models/marketwatch_model/pre_define_wl_model.dart';
import '../models/marketwatch_model/scrip_info.dart';
import '../models/marketwatch_model/scrip_overview/stock_data.dart';
import '../models/marketwatch_model/scrip_overview/technical_data.dart';
import '../models/marketwatch_model/search_scrip_new_model.dart';
import '../models/marketwatch_model/watchlist_rename_model.dart';
import '../res/global_state_text.dart';
import '../res/res.dart';
import '../screens/Mobile/market_watch/scrip_depth_info.dart';
// import '../screens/market_watch/scrip_depth_info.dart';
import '../sharedWidget/functions.dart';
import '../sharedWidget/snack_bar.dart';
import '../utils/responsive_snackbar.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';
import 'web_subscription_manager.dart';
import 'order_provider.dart';
import 'portfolio_provider.dart';
import 'websocket_provider.dart';
import 'dart:async';

final marketWatchProvider =
    ChangeNotifierProvider((ref) => MarketWatchProvider(ref));

class MarketWatchProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final Ref ref;

  String _searchErrorText = "Enter more than TWO letters";
  String get searchErrorText => _searchErrorText;

  List _depthBtns = [
    {"btnName": "Overview", "imgPath": assets.dInfo},
    {"btnName": "Chart", "imgPath": assets.charticon}
  ];
  String _actDeptBtn = "Overview";
  String get actDeptBtn => _actDeptBtn;

  // When true, the next ChartWithDepthWeb panel that opens lands on the Chart
  // tab (index 1) instead of its default. Set by the watchlist option-chain
  // "Chart" action; consumed (reset) by ChartWithDepthWeb once it switches.
  bool openOnChartTab = false;
  final List<Tab> _scipOverViewTab = [
    const Tab(text: "Overview"),
    const Tab(text: "Chart")
  ];

  final TextEditingController alertPendingSearchtext = TextEditingController();

  String _sortByWL = "";
  String get sortByWL => _sortByWL;

  List _returnsGridview = [];

  List get returnsGridview => _returnsGridview;

  String _optionStrPrc = "0.00";

  String get optionStrPrc => _optionStrPrc;

  String _futToken = "0.00";

  String get futToken => _futToken;
  String __futExch = "";

  String get futExch => __futExch;

  List get depthBtns => _depthBtns;
  List<Tab> get scripOverViewTab => _scipOverViewTab;
  List<bool>? _isAdded;
  List<bool>? get isAdded => _isAdded;

  MarketWatchlist? _marketWatchlist;
  MarketWatchlist? get marketWatchlist => _marketWatchlist;
  // MarketWatchlist? _preDefMWlist;
  // MarketWatchlist? get preDefMWlist => _preDefMWlist;
  List linkedscript = ['NFO', 'BFO', 'MCX', 'NCOM', 'BCOM', 'CDS'];

//  Pre-defined market watchlist

  final List<String> _preDefWLBase = [
    "My Stocks",
    "Nifty50",
    "Niftybank",
    "Sensex"
  ];

  List<String> get _preDefWL {
    final portfolio = ref.read(portfolioProvider);
    final hasPositions = portfolio.postionBookModel != null &&
        portfolio.postionBookModel!.isNotEmpty &&
        (portfolio.postionBookModel![0].stat != "Not_Ok");
    if (hasPositions) {
      return ["My Positions", ..._preDefWLBase];
    }
    return _preDefWLBase;
  }

  // Restricted names that users cannot use for watchlist names
  // Includes both internal names and display names (case-insensitive)
  static final List<String> _restrictedWatchlistNames = [
    "holdings",
    "my stocks",
    "positions",
    "my positions",
    "nifty 50",
    "nifty50",
    "nifty bank",
    "niftybank",
    "sensex"
  ];

  // Centralized validation method for watchlist names
  String? validateWatchlistName(String name) {
    final trimmedName = name.trim();

    // Check if empty
    if (trimmedName.isEmpty) {
      return "Watchlist name cannot be empty";
    }

    final lowerCaseName = trimmedName.toLowerCase();


    // Check against restricted names (predefined display names)
    if (_restrictedWatchlistNames.contains(lowerCaseName)) {
      return "This watchlist name is reserved";
    }


    // Check against existing user watchlists (case-insensitive)
    if (_marketWatchlist != null && _marketWatchlist!.values != null) {
      final existingLowerCase =
          _marketWatchlist!.values!.map((name) => name.toLowerCase()).toList();
      if (existingLowerCase.contains(lowerCaseName)) {
        return "Watchlist name already exists";
      }
    }

    // Check against pending watchlists (case-insensitive)
    final pendingLowerCase =
        _pendingWatchlists.map((name) => name.toLowerCase()).toList();
    if (pendingLowerCase.contains(lowerCaseName)) {
      return "Watchlist name already exists";
    }

    // Validation passed
    return null;
  }

// Search scrip Filter by Instument name

  final List<Tab> _searchTabList = const [
    Tab(text: "All"),
    Tab(text: "Equity"),
    Tab(text: "F&O"),
    Tab(text: "Currency"),
    Tab(text: "Commodity"),
    Tab(text: "Indices")
  ];

  List<Tab> get searchTabList => _searchTabList;

  List<String> get preDefWL => _preDefWL;
  List<WatchListValues> _searchMWLScrip = [];
  List<WatchListValues> get searchMWLScrip => _searchMWLScrip;

  MarketWatchScrip? _marketWatchScrip;
  MarketWatchScrip? get marketWatchScrip => _marketWatchScrip;

  PreDefinedMWlist? _preDefinedMWlist;
  bool _isFetchingPreDefMW = false; // Prevent concurrent fetchPreDefMWScrip calls

  PreDefinedMWlist? get preDefinedMWlist => _preDefinedMWlist;

  List<WatchListValues> _watchListValues = [];
  List<WatchListValues> get watchListValues => _watchListValues;
  ScripInfoModel? _scripInfoModel;
  ScripInfoModel? get scripInfoModel => _scripInfoModel;

  List<ManagePriceAlertModel>? _setManagePrice;
  List<ManagePriceAlertModel>? get setManagePrice => _setManagePrice;
  int _delScripQty = 0;
  int get delScripQty => _delScripQty;

  // Chart and UI state variables
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  String _selectedTimeframe = "3M";
  String get selectedTimeframe => _selectedTimeframe;

  bool _showTooltip = false;
  bool get showTooltip => _showTooltip;

  int _touchedIndex = -1;
  int get touchedIndex => _touchedIndex;

  Set<int> _hoveredEventDots = {};
  Set<int> get hoveredEventDots => _hoveredEventDots;

  int? _selectedEventDot;
  int? get selectedEventDot => _selectedEventDot;

  // GetQuotes? _getQuotes;
  GetQuotes _getQuotes = GetQuotes(
    requestTime: '',
    stat: '',
    exch: '',
    tsym: '',
    cname: '',
    symname: '',
    seg: '',
    instname: '',
    isin: '',
    pp: "0.0",
    ls: "0.0",
    ti: "0",
    mult: "0.0",
    lut: '',
    uc: "0.0",
    lc: "0.0",
    wk52H: "0.0",
    wk52L: "0.0",
    toi: "0",
    issuecap: '',
    cutofAll: '',
    prcftrD: "0.0",
    token: '',
    lp: "0.0",
    c: "0.0",
    h: "0.0",
    l: "0.0",
    ap: "0.0",
    o: "0.0",
    v: "0",
    ltq: "0",
    ltt: '',
    ltd: '',
    tbq: "0.0",
    tsq: "0.0",
    bp1: "0.0",
    sp1: "0.0",
    ordMsg: '',
    emsg: "",
    poi: "",
    chng: "",
    pc: "",
    expDate: "",
    option: "",
    symbol: "",
  );
  GetQuotes? get getQuotes => _getQuotes;

  // State preservation for basket operations
  GetQuotes? _originalContextForBasket;

  // Save current symbol context before basket operations
  void preserveContextForBasket() {
    _originalContextForBasket = GetQuotes(
      requestTime: _getQuotes.requestTime,
      stat: _getQuotes.stat,
      exch: _getQuotes.exch,
      tsym: _getQuotes.tsym,
      cname: _getQuotes.cname,
      symname: _getQuotes.symname,
      seg: _getQuotes.seg,
      instname: _getQuotes.instname,
      isin: _getQuotes.isin,
      pp: _getQuotes.pp,
      ls: _getQuotes.ls,
      ti: _getQuotes.ti,
      mult: _getQuotes.mult,
      lut: _getQuotes.lut,
      uc: _getQuotes.uc,
      lc: _getQuotes.lc,
      wk52H: _getQuotes.wk52H,
      wk52L: _getQuotes.wk52L,
      toi: _getQuotes.toi,
      issuecap: _getQuotes.issuecap,
      cutofAll: _getQuotes.cutofAll,
      prcftrD: _getQuotes.prcftrD,
      token: _getQuotes.token,
      lp: _getQuotes.lp,
      c: _getQuotes.c,
      h: _getQuotes.h,
      l: _getQuotes.l,
      ap: _getQuotes.ap,
      o: _getQuotes.o,
      v: _getQuotes.v,
      ltq: _getQuotes.ltq,
      ltt: _getQuotes.ltt,
      ltd: _getQuotes.ltd,
      tbq: _getQuotes.tbq,
      tsq: _getQuotes.tsq,
      bp1: _getQuotes.bp1,
      sp1: _getQuotes.sp1,
      ordMsg: _getQuotes.ordMsg,
      emsg: _getQuotes.emsg,
      poi: _getQuotes.poi,
      chng: _getQuotes.chng,
      pc: _getQuotes.pc,
      expDate: _getQuotes.expDate,
      option: _getQuotes.option,
      symbol: _getQuotes.symbol,
    );
  }

  // Restore original symbol context after basket operations
  void restoreContextFromBasket() {
    if (_originalContextForBasket != null) {
      _getQuotes = _originalContextForBasket!;
      _originalContextForBasket = null;
      notifyListeners();
    }
  }

  GetQuotes? _getStikePrc;
  GetQuotes? get getStikePrc => _getStikePrc;

  AddDeleteScripModel? _addDeleteScripModel;
  AddDeleteScripModel? get addDeleteScripModel => _addDeleteScripModel;

  // Track watchlists that are created locally but not yet synced to API
  // These are watchlists created without any scrips
  final Set<String> _pendingWatchlists = {};
  Set<String> get pendingWatchlists => _pendingWatchlists;

  SearchScripNewModel? _searchScripModel;

  SearchScripNewModel? get searchScripModel => _searchScripModel;

  List<ScripNewValue>? _allSearchScrip = [];
  List<ScripNewValue>? get allSearchScrip => _allSearchScrip;
  List<ScripNewValue>? _equitySearchScrip = [];
  List<ScripNewValue>? get equitySearchScrip => _equitySearchScrip;
  List<ScripNewValue>? _currencySearchScrip = [];
  List<ScripNewValue>? get currencySearchScrip => _currencySearchScrip;
  List<ScripNewValue>? _commoditySearchScrip = [];
  List<ScripNewValue>? get commoditySearchScrip => _commoditySearchScrip;
  List<ScripNewValue>? _fNoSearchScrip = [];
  List<ScripNewValue>? get fNoSearchScrip => _fNoSearchScrip;

  CancelAlertModel? _cancelalert;
  CancelAlertModel? get cancelalert => _cancelalert;

  SetAlertModel? _setAlertModel;
  SetAlertModel? get setAlertModel => _setAlertModel;

  ModifyAlertModel? _modifyalertmodel;
  ModifyAlertModel? get modifyalertmodel => _modifyalertmodel;

  List<AlertPendingModel>? _alertPendingModel = [];
  List<AlertPendingModel>? get alertPendingModel => _alertPendingModel;

  List<AlertPendingModel>? _alertPendingSearch = [];
  List<AlertPendingModel>? get alertPendingSearch => _alertPendingSearch;

  void setAlertPendingSearch(List<AlertPendingModel> searchResult) {
    _alertPendingSearch = searchResult;
    notifyListeners();
  }

  WatchlistRenameModel? _watchlistRenameModel;
  WatchlistRenameModel? get watchlistRenameModel => _watchlistRenameModel;

  final String _mwSubToken = "";
  String get mwSubToken => _mwSubToken;

// Option chain
  List<String> _sortedDate = [];
  String? _selectedExpDate;
  String? _selectedTradeSym;
  String _numStrike = "10";
  String? _optionExch;
  final List<String> _numStrikes = ["5", "10", "15", "All"];

  List<String> get sortDate => _sortedDate;
  String? get selectedExpDate => _selectedExpDate;
  String? get selectedTradeSym => _selectedTradeSym;
  String get numStrike => _numStrike;
  String? get optionExch => _optionExch;
  List<String> get numStrikes => _numStrikes;

  LinkedScrips? _linkedScrips;
  LinkedScrips? get linkedScrips => _linkedScrips;
  List<Equls>? _equls = [];
  List<Futures>? _fut = [];
  List<OptionExp>? _optExp = [];
  List<Equls>? get equls => _equls;
  List<Futures>? get fut => _fut;
  List<OptionExp>? get optExp => _optExp;
  OptionChainModel? _optionChainModel;
  OptionChainModel? get optionChainModel => _optionChainModel;
  final List<OptionValues> _optChainPut = [];
  final List<OptionValues> _optChainCall = [];
  List<OptionValues> get optChainPut => _optChainPut;
  List<OptionValues> get optChainCall => _optChainCall;

  final List<OptionValues> _optChainPutUp = [];
  final List<OptionValues> _optChainCallUp = [];
  final List<OptionValues> _optChainPutDown = [];
  final List<OptionValues> _optChainCallDown = [];
  List<OptionValues> get optChainPutUp => _optChainPutUp;
  List<OptionValues> get optChainCallUP => _optChainCallUp;
  List<OptionValues> get optChainPutDown => _optChainPutDown;
  List<OptionValues> get optChainCallDown => _optChainCallDown;

  final ScrollController _scrollController = ScrollController();
  ScrollController get scrollController => _scrollController;

  // Track current watchlist page index
  int _currentWatchlistPageIndex = 0;
  int get currentWatchlistPageIndex => _currentWatchlistPageIndex;

  // Method to update current watchlist page index
  void setCurrentWatchlistPageIndex(int index) {
    _currentWatchlistPageIndex = index;
    // Store in SharedPreferences for persistence
    _saveCurrentPageIndex();
  }

  // Method to reset current watchlist page index (used during account switch)
  void resetCurrentWatchlistPageIndex() {
    _currentWatchlistPageIndex = 0;
    _wlName = "";  // Reset watchlist name to force selection of first watchlist
    _saveCurrentPageIndex();
    notifyListeners();
  }

  // Save current page index to SharedPreferences
  Future<void> _saveCurrentPageIndex() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          "currentWatchlistPageIndex", _currentWatchlistPageIndex);
    } catch (e) {
    }
  }

  // Add StreamSubscription for WebSocket data
  StreamSubscription? _socketDataSubscription;

  MarketWatchProvider(this.ref) {
    // Reset sort preference on app start instead of loading saved preference
    _resetSortPreference();
    _setupWebSocketListener();
    // Load saved page index
    // _loadCurrentPageIndex();

    // Load pending watchlists from storage
    _loadPendingWatchlists();

    // Listen to WebSocket data updates using a proper subscription
    _setupWebSocketListener();
  }

  // Load pending watchlists from SharedPreferences
  Future<void> _loadPendingWatchlists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedPending =
          prefs.getStringList('pending_watchlists');
      if (savedPending != null) {
        _pendingWatchlists.addAll(savedPending);
      }
    } catch (e) {
    }
  }

  // Save pending watchlists to SharedPreferences
  Future<void> _savePendingWatchlists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_watchlists', _pendingWatchlists.toList());
    } catch (e) {
    }
  }

  // Clear pending watchlists (called on logout/account switch)
  Future<void> clearPendingWatchlists() async {
    try {
      _exarr = [];
      _pendingWatchlists.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_watchlists');
    } catch (e) {
    }
  }

  // Setup WebSocket listener with proper error handling
  void _setupWebSocketListener() {
    try {
      // Cancel any existing subscription first
      _socketDataSubscription?.cancel();

      // Create a new subscription with proper error handling
      _socketDataSubscription =
          ref.read(websocketProvider).socketDataStream.listen(
        (data) {
          if (data.isNotEmpty) {
            try {
              // Convert to Map<String, dynamic> to match the expected type
              final Map<String, dynamic> typedData =
                  Map<String, dynamic>.from(data);
              updateSocketData(typedData);
            } catch (e) {
            }
          }
        },
        onError: (error) {
        },
      );
    } catch (e) {
    }
  }

  @override
  void dispose() {
    // Cancel the socket data subscription to avoid memory leaks
    if (_socketDataSubscription != null) {
      try {
        _socketDataSubscription?.cancel();
        _socketDataSubscription = null;
      } catch (e) {
      }
    }

    // Call the parent dispose method
    super.dispose();
  }

  // Method to load current page index from SharedPreferences
  Future<void> _loadCurrentPageIndex() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentWatchlistPageIndex =
          prefs.getInt("currentWatchlistPageIndex") ?? 0;
      notifyListeners();
    } catch (e) {
    }
  }

  // Method to load sort preference from SharedPreferences
  Future<void> _loadSortPreference() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _sortByWL = prefs.getString("sortByWL") ?? "";
      notifyListeners();
    } catch (e) {
    }
  }

  // Method to reset sort preference on app start and when adding scrips
  Future<void> _resetSortPreference() async {
    try {
      _sortByWL = "";
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("sortByWL");
      notifyListeners();
    } catch (e) {
    }
  }

  // CRITICAL NEW METHOD: Sync current socket values to the watchlist model before sorting
  void syncSocketDataToModel() {
    if (_scrips.isEmpty) return;

    try {
      final socketDatas = ref.read(websocketProvider).socketDatas;
      bool dataUpdated = false;

      // Update each scrip with current socket data if available
      for (int i = 0; i < _scrips.length; i++) {
        final token = _scrips[i]['token']?.toString();
        if (token != null &&
            token.isNotEmpty &&
            socketDatas.containsKey(token)) {
          final socketData = socketDatas[token];

          // Update ltp from socket 'lp' field. Zero/null filtering happens
          // centrally in WebSocketProvider._sanitizePriceFields, so a simple
          // null check is enough here.
          if (socketData['lp'] != null) {
            _scrips[i]['ltp'] = socketData['lp'].toString();
            dataUpdated = true;
          }

          // Update change from socket 'chng' field
          if (socketData['chng'] != null &&
              socketData['chng'].toString() != "null") {
            _scrips[i]['change'] = socketData['chng'].toString();
            dataUpdated = true;
          }

          // Update percentage change from socket 'pc' field
          if (socketData['pc'] != null &&
              socketData['pc'].toString() != "null") {
            _scrips[i]['perChange'] = socketData['pc'].toString();
            dataUpdated = true;
          }

          // Update other important fields
          final relevantFields = [
            'h',
            'l',
            'o',
            'c',
            'v',
            'ap',
            'bp1',
            'sp1',
            'tbq',
            'tsq'
          ];
          for (var field in relevantFields) {
            if (socketData[field] != null &&
                socketData[field].toString() != "null") {
              _scrips[i][field] = socketData[field].toString();
            }
          }
        }
      }

      if (dataUpdated) {
      }
    } catch (e) {
    }
  }

  // Method to apply saved sorting without server calls
  void _applySavedSorting() {
    if (_sortByWL.isEmpty || _scrips.isEmpty) return;

    try {
      // Make sure we have fresh data before sorting
      syncSocketDataToModel();

      // Create a copy of the list to preserve object references
      final List<dynamic> tempScrips = List<dynamic>.from(_scrips);

      // Apply the current sort
      switch (_sortByWL) {
        case "Scrip - Z to A":
          tempScrips.sort(
              (a, b) => b['tsym'].toString().compareTo(a['tsym'].toString()));
          break;

        case "Scrip - A to Z":
          tempScrips.sort(
              (a, b) => a['tsym'].toString().compareTo(b['tsym'].toString()));
          break;

        case "Price - Low to High":
          tempScrips.sort((a, b) {
            double aPrice =
                double.tryParse(a['ltp']?.toString() ?? '0.00') ?? 0.0;
            double bPrice =
                double.tryParse(b['ltp']?.toString() ?? '0.00') ?? 0.0;
            return aPrice.compareTo(bPrice);
          });
          break;

        case "Price - High to Low":
          tempScrips.sort((a, b) {
            double aPrice =
                double.tryParse(a['ltp']?.toString() ?? '0.00') ?? 0.0;
            double bPrice =
                double.tryParse(b['ltp']?.toString() ?? '0.00') ?? 0.0;
            return bPrice.compareTo(aPrice);
          });
          break;

        case "Per.Chng - High to Low":
          tempScrips.sort((a, b) {
            double aChange =
                double.tryParse(a['perChange']?.toString() ?? '0.00') ?? 0.0;
            double bChange =
                double.tryParse(b['perChange']?.toString() ?? '0.00') ?? 0.0;
            return bChange.compareTo(aChange);
          });
          break;

        case "Per.Chng - Low to High":
          tempScrips.sort((a, b) {
            double aChange =
                double.tryParse(a['perChange']?.toString() ?? '0.00') ?? 0.0;
            double bChange =
                double.tryParse(b['perChange']?.toString() ?? '0.00') ?? 0.0;
            return aChange.compareTo(bChange);
          });
          break;
      }

      // Update the list with the sorted data
      _scrips = tempScrips;

    } catch (e) {
    }
  }

  String _wlName = "";

  String get wlName => _wlName;
  String _isPreDefWLs = "No";

  String get isPreDefWLs => _isPreDefWLs;

  String _tradeSym = "";
  get tradeSym => _tradeSym;
  String _exch = "";
  String get exchange => _exch;
  String _duration = "5m";
  String get duration => _duration;

  String _chartDuration = "5";
  String get chartDuration => _chartDuration;

  double _totBuyQtyPer = 0.00;
  double _totSellQtyPer = 0.00;
  int _maxBuyQty = 0;
  int _maxSellQty = 0;
  double _totBuyQtyPerChng = 0.00;

  double get totBuyQtyPer => _totBuyQtyPer;
  double get totSellQtyPer => _totSellQtyPer;
  int get maxBuyQty => _maxBuyQty;
  int get maxSellQty => _maxSellQty;
  double get totBuyQtyPerChng => _totBuyQtyPerChng;

// Scrip Overview
  TechnicalData? _techData;
  TechnicalData? get techData => _techData;

  final List<PrcComparisionChartData> _prcComChrtData1 = [];
  final List<PrcComparisionChartData> _prcComChrtData2 = [];
  final List<PrcComparisionChartData> _prcComChrtData3 = [];
  final List<PrcComparisionChartData> _prcComChrtData4 = [];
  final List<PrcComparisionChartData> _prcComChrtData5 = [];

  List<PrcComparisionChartData> get prcComChrtData1 => _prcComChrtData1;
  List<PrcComparisionChartData> get prcComChrtData2 => _prcComChrtData2;
  List<PrcComparisionChartData> get prcComChrtData3 => _prcComChrtData3;
  List<PrcComparisionChartData> get prcComChrtData4 => _prcComChrtData4;
  List<PrcComparisionChartData> get prcComChrtData5 => _prcComChrtData5;
  StockData? _fundamentalData;
  StockData? get fundamentalData => _fundamentalData;

  List<EodChartData> _eodChartData = [];
  List<EodChartData> get eodChartData => _eodChartData;

  List<String> _exarr = [];
  List<String> get exarr => _exarr;

  final String _firstGetData = "0";
  String get fistGetData => _firstGetData;

  final FToast _fToast = FToast();
  FToast get fToast => _fToast;

  //   fundamental

  List<String> _mfHoldingDate = [];
  List<String> get mfHoldingDate => _mfHoldingDate;

  String _selectedMfHolddate = "";
  String get selectedMfHolddate => _selectedMfHolddate;

  int _selectedMfHoldindex = 0;
  int get selectedMfHoldindex => _selectedMfHoldindex;

  bool _showAlertSearch = false;
  bool get showAlertSearch => _showAlertSearch;

  bool _scripDepthloader = false;
  bool get scripDepthloader => _scripDepthloader;

  bool _chartDataLoading = false;
  bool get chartDataLoading => _chartDataLoading;

  bool _isFuturesExpanded = false;
  bool get isFuturesExpanded => _isFuturesExpanded;

  bool _isDepthVisible = false;
  bool get isDepthVisible => _isDepthVisible;
  bool _depthDataLoaded = false; // Track if depth data has been loaded
  String? _currentDepthSymbol; // Track current depth subscription (exch|token)
  String? get currentDepthSymbol => _currentDepthSymbol; // Public getter for WebSubscriptionManager

  /// Lazy load market depth data when user opens depth panel
  setIsDepthVisibleWeb(bool value, {BuildContext? context, String? exch, String? token, String? tsym}) async {
    _isDepthVisible = value;
    notifyListeners();

    if (value && context != null) {
      // Use provided exch/token/tsym if available, otherwise fall back to _activeTab
      String? finalExch = exch ?? _activeTab?.exch;
      String? finalToken = token ?? _activeTab?.token;
      String? finalTsym = tsym ?? _activeTab?.tsym;

      if (finalExch != null && finalToken != null && finalTsym != null) {
        final newDepthSymbol = "$finalExch|$finalToken";

        // Only subscribe if it's a different scrip or not already loaded
        if (newDepthSymbol != _currentDepthSymbol || !_depthDataLoaded) {
          await subscribeToDepthData(
            exch: finalExch,
            token: finalToken,
            tsym: finalTsym,
            context: context,
          );
        }
      }
    } else if (!value && _currentDepthSymbol != null) {
      // Unsubscribe when depth panel is closed
      await unsubscribeFromDepthData(context: context);
    }
  }

  /// Subscribe to market depth data for a specific scrip
  /// This is called lazily only when the depth panel is opened
  Future<void> subscribeToDepthData({
    required String exch,
    required String token,
    required String tsym,
    required BuildContext context,
  }) async {
    try {
      final depthSymbol = "$exch|$token";

      // Unsubscribe from old depth socket if different scrip
      if (_currentDepthSymbol != null && _currentDepthSymbol != depthSymbol) {
        await unsubscribeFromDepthData(context: context);
      }

      // Skip if already subscribed to this symbol
      if (_currentDepthSymbol == depthSymbol && _depthDataLoaded) {
        return;
      }


      await ref.read(websocketProvider).establishConnection(
            channelInput: depthSymbol,
            task: "d",
            context: context,
          );

      _currentDepthSymbol = depthSymbol;
      _depthDataLoaded = true;
    } catch (e) {
      _depthDataLoaded = false;
      _currentDepthSymbol = null;
    }
  }

  /// Unsubscribe from market depth data
  Future<void> unsubscribeFromDepthData({BuildContext? context}) async {
    if (_currentDepthSymbol == null) return;

    try {
      final depthSymbol = _currentDepthSymbol!;

      // Clear tracking first so the protective check in WebSubscriptionManager
      // does not see this symbol as "currentDepthSymbol" and block its own ud.
      _currentDepthSymbol = null;
      _depthDataLoaded = false;

      if (context != null && context.mounted) {
        try {
          // Route through WebSubscriptionManager so the ud is skipped when the
          // symbol is still needed by the watchlist / holdings / positions /
          // indices / ticker. The watchlist itself subscribes via task "d" —
          // the same channel as depth — so an unprotected ud would also kill
          // the watchlist's LTP feed for that scrip.
          await ref.read(webSubscriptionManagerProvider).unsubscribeTokens(
                tokensToCheck: {depthSymbol},
                context: context,
                source: 'depth',
              );
        } catch (e) {
          // If unsubscribe fails, it's okay - we've already cleared tracking
        }
      }
    } catch (e) {
      _currentDepthSymbol = null;
      _depthDataLoaded = false;
    }
  }

  /// Reset depth loaded state when scrip changes
  void resetDepthLoadedState() {
    _depthDataLoaded = false;
    _currentDepthSymbol = null;
  }

  // Cache for storing scrip data - limit size to prevent memory issues
  Map<String, Map<String, dynamic>> storeQuotes = {};
  static const int _maxCacheSize = 50; // Maximum number of scrips to cache

  /// Clear oldest cache entries when cache size exceeds limit
  void _manageCacheSize() {
    if (storeQuotes.length > _maxCacheSize) {
      // Remove oldest 10 entries
      final keysToRemove = storeQuotes.keys.take(10).toList();
      for (final key in keysToRemove) {
        storeQuotes.remove(key);
      }
    }
  }

  singlePageloader(bool value) {
    _scripDepthloader = value;
    notifyListeners();
  }

  toggleFuturesExpansion() {
    _isFuturesExpanded = !_isFuturesExpanded;
    notifyListeners();
  }

getOptionawait(String exch, String token) {
    final portfolios = _linkedScrips?.optExp?.isNotEmpty ?? false;
    // bool value = ((portfolios.isNotEmpty));
    // print("options::::: $exch ::: $token $value");
    return portfolios;
  }

  calldepthApis(BuildContext context, raw, basket,
      {bool? isOptionChain}) async {
    String? currentRoute = context.widget.runtimeType.toString();

    ref.read(userProfileProvider).setonloadChartdialog(true);
    chngDephBtn(basket == "Option|-|Deph" ? "Option" : "Overview");
    singlePageloader(true);
    bool flow = raw.runtimeType.toString() == '_Map<String, dynamic>';
// _Map<String, dynamic>
    DepthInputArgs depthArgs = DepthInputArgs(
        exch: '${flow ? raw['exch'] : raw.exch}',
        token: '${flow ? raw['token'] : raw.token}',
        tsym: '${flow ? raw['tsym'] : raw.tsym}',
        instname: flow ? raw['instname'] : raw.instname ?? "",
        symbol: '${flow ? raw['symbol'] : raw.symbol}',
        expDate: '${flow ? raw['expDate'] : raw.expDate}',
        option: '${flow ? raw['option'] : raw.option}',
        isOption: flow
            ? (raw['isOption'] ?? false)
            : (raw is DepthInputArgs ? raw.isOption : false)
            ,idx: flow ? raw['idx'] : raw.idx);

    // Guard: if the same scrip is already being opened/loaded on web, just focus it
    if (kIsWeb) {
      final String incomingToken = depthArgs.token;
      final String incomingExch = depthArgs.exch;
      final bool isSameAsActive = (activeTab?.token == incomingToken);
      if (_scripDepthloader && isSameAsActive) {
        // Ensure panel/charts are focused without re-triggering data fetches
        openScripInWebPanel(context, depthArgs, basket);
        if (basket != "Option||Is") {
          setChartScript(incomingExch, incomingToken, depthArgs.tsym);
        }
        singlePageloader(false);
        return;
      }
    }

    // Depth data subscription is now handled lazily when user opens depth panel
    // This reduces initial load time and memory usage

    // Check if we already have cached data for this scrip
    final String token = flow ? raw['token'].toString() : raw.token.toString();
    final String exch = flow ? raw['exch'].toString() : raw.exch.toString();
    final bool hasQuoteCache = storeQuotes.containsKey(token) && storeQuotes[token]?['q'] != null;
    final bool hasScripInfoCache = storeQuotes.containsKey(token) && storeQuotes[token]?['s'] != null;

    // Fetch scrip quote first if not cached (needed for UI display)
    if (!hasQuoteCache) {
      await fetchScripQuote(token, exch, context);
    }

    // Check if running on web platform
    if (kIsWeb) {
      if (basket != "Option||Is") {
        chngDephBtn("Chart");
      }

      // Only fetch scrip info if not cached
      if (!hasScripInfoCache) {
        await fetchScripInfo(depthArgs.token, depthArgs.exch, context, true);
      }

      openScripInWebPanel(context, depthArgs, basket);
      if (basket != "Option||Is") {
        setChartScript(depthArgs.exch, depthArgs.token, depthArgs.tsym);
      }
    } else {
      // For mobile, use bottom sheet
      showModalBottomSheet(
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: true,
          enableDrag: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          context: context,
          builder: (context) => Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ScripDepthInfo(
                wlValue: depthArgs,
                isBasket: basket,
                isfromOptionChain:
                    currentRoute.toLowerCase().contains("option") ? true : false,
              )));
    }

    singlePageloader(false);

    // Load remaining data in background (non-blocking)
    Future.microtask(() async {
      // Fetch scrip quote if not already fetched
      if (hasQuoteCache) {
        // If we used cache, still fetch quote to update with latest data
        await fetchScripQuote(token, exch, context);
      }

      // Fetch scrip info if not already fetched (avoid duplicate call)
      if (hasScripInfoCache) {
        // If we used cache, still fetch to update with latest data
        await fetchScripInfo(token, exch, context);
      }

      // Fetch linked scrips
      await fetchLinkeScrip(token, exch, context);

      // Only fetch fundamental and tech data for NSE/BSE scrips
      if (exch == "NSE" || exch == "BSE") {
        // Fetch fundamental data in background (non-blocking)
        fetchFundamentalData(
            tradeSym: "$exch:${flow ? raw['tsym'] : raw.tsym}",
            token: token);

        // Fetch tech data
        await fetchTechData(
            context: context,
            exch: exch,
            tradeSym: "${flow ? raw['tsym'] : raw.tsym}",
            lastPrc: "${_getQuotes.lp ?? _getQuotes.c ?? 0.00}");
      }
    });
  }

  showAlertPendingSearch(bool value) {
    _showAlertSearch = value;
    if (!_showAlertSearch) {
      _alertPendingSearch = [];
    }
    notifyListeners();
  }

  clearAlertSearch() {
    alertPendingSearchtext.clear();
    _alertPendingSearch = [];
    notifyListeners();
  }

  chngMfHoldDate(String val, int index) {
    _selectedMfHolddate = val;
    _selectedMfHoldindex = index;
    notifyListeners();
  }

  chngDephBtn(String val) {
    _actDeptBtn = val;
    notifyListeners();
  }

  bool _scripsize = false;
  bool get scripsize => _scripsize;

  scripdepthsize(value) {
    _scripsize = value;
    notifyListeners();
  }

  bool _isETF = false;
  bool get isETF => _isETF;

  // Store ETF category information
  String _etfCategoryTitle = '';
  String _etfCategoryIcon = '';
  String _etfCategoryDescription = '';

  String get etfCategoryTitle => _etfCategoryTitle;
  String get etfCategoryIcon => _etfCategoryIcon;
  String get etfCategoryDescription => _etfCategoryDescription;

  setETF(bool value) {
    _isETF = value;
    notifyListeners();
  }

  setETFCategory(String title, String icon, String description) {
    _etfCategoryTitle = title;
    _etfCategoryIcon = icon;
    _etfCategoryDescription = description;
    notifyListeners();
  }

  List<String> shareHoldType = [
    "Promoter Holding",
    "Foriegn Institution",
    "Other Domestic Institution",
    "Retail and Others",
    "Mutual Funds"
  ];

  String _selctedShareHold = "Promoter Holding";

  String get selctedShareHold => _selctedShareHold;
  chngshareHold(String val) async {
    _selctedShareHold = val;

    notifyListeners();
  }

  List _peersChartKeys = [];

  List get peersChartKeys => _peersChartKeys;

  List<String> mfHoldType = ["Mkt cap held%", "AUM", "Weight%"];

  String _selctedmfHold = "Mkt cap held%";

  String get selctedmfHold => _selctedmfHold;
  chngMfHold(String val) async {
    _selctedmfHold = val;

    notifyListeners();
  }

  List<String> _finnceYears = [];
  List<String> get finnceYears => _finnceYears;

  List<String> finType = ["Standalone", "Consolidated"];

  // Income section financial type
  String _selctedIncomeFinType = "Standalone";
  String get selcteIncomeFinType => _selctedIncomeFinType;
  chngIncomeFinType(String val) async {
    _selctedIncomeFinType = val;
    notifyListeners();
  }

  // Balance Sheet section financial type
  String _selctedBalanceSheetFinType = "Standalone";
  String get selcteBalanceSheetFinType => _selctedBalanceSheetFinType;
  chngBalanceSheetFinType(String val) async {
    _selctedBalanceSheetFinType = val;
    notifyListeners();
  }

  // Cash Flow section financial type
  String _selctedCashFlowFinType = "Standalone";
  String get selcteCashFlowFinType => _selctedCashFlowFinType;
  chngCashFlowFinType(String val) async {
    _selctedCashFlowFinType = val;
    notifyListeners();
  }

  // Keep the old methods for backward compatibility
  String _selctedFinType = "Standalone";
  String get selcteFinType => _selctedFinType;
  chngFinType(String val) async {
    _selctedFinType = val;
    notifyListeners();
  }

  String _selctedFinYear = "";

  String get selcteFinYear => _selctedFinYear;
  chngFinYear(String val) async {
    _selctedFinYear = val;

    notifyListeners();
  }

// Set height for dropdown list items

  List<double> getCustomItemsHeight(List<String> numofList) {
    List<double> itemsHeights = [];
    // Since dividers are commented out, only create heights for the actual items
    for (var i = 0; i < numofList.length; i++) {
      itemsHeights.add(40);
    }
    return itemsHeights;
  }

  List<String> peersType = [
    "LTP",
    "Market Cap",
    "PE Ratio",
    "PB Ratio",
    "ROCE",
    "Evebitda",
    "Debt to EQ",
    "Dividend yield"
  ];

  String _selctedPeers = "LTP";

  String get selctedPeers => _selctedPeers;
  chngPeersType(String val) async {
    _selctedPeers = val;

    notifyListeners();
  }

  // Method to cycle through peers type options
  cyclePeersType() async {
    int currentIndex = peersType.indexOf(_selctedPeers);
    int nextIndex = (currentIndex + 1) % peersType.length;
    _selctedPeers = peersType[nextIndex];
    notifyListeners();
  }

// Add Divider for dropdown list items
  List<DropdownMenuItem<String>> addDividersAfterExpDates(
      List<String> numofList) {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in numofList) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item.toString(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: TextWidget.subText(
                  text: item.toString(),
                  theme: ref.read(themeProvider).isDarkMode,
                  fw: 0,
                ),
              )),
          //If it's last item, we will not add Divider after it.
          // if (item != numofList.last)
          //   DropdownMenuItem<String>(
          //     enabled: false,
          //     child: Padding(
          //         padding: const EdgeInsets.symmetric(vertical: 2.0),
          //         child: Divider(
          //           color: colors.colorDivider,
          //           height: 1,
          //         )),
          //   ),
        ],
      );
    }
    return menuItems;
  }

  List<double> getStochCustomItemsHeight(List<String> numofList) {
    List<double> itemsHeights = [];
    for (var i = 0; i < (numofList.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<DropdownMenuItem<String>> addDividersAfterStock(List<String> numofList) {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in numofList) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
            value: item.toString(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextWidget.subText(
                text: item.toString(),
                theme: ref.read(themeProvider).isDarkMode,
                fw: 0,
              ),
            ),
          ),

          //If it's last item, we will not add Divider after it.
          // if (item != numofList.last)
          //   const DropdownMenuItem<String>(
          //     enabled: false,
          //     child: ListDivider(),
          //   ),
        ],
      );
    }
    return menuItems;
  }

// Option chain options

  void selecexpDate(String value) {
    _selectedExpDate = value;
    notifyListeners();
  }

  void selecTradSym(String value) {
    _selectedTradeSym = value;
    notifyListeners();
  }

  void selecNumStrike(String value) {
    _numStrike = value;
    notifyListeners();
  }

  void optExch(String value) {
    _optionExch = value;
    notifyListeners();
  }

  updateOptStrPrc(String val) {
    _optionStrPrc = val;
  }

// depthWLAddBtn(){
//     _isAdded = List<bool>.filled(_searchScripModel!.values!.length, false);
// }

  void activeTsym(String symbol, String exch) {
    _tradeSym = symbol;
    // pref.setActiveSymbol(symbol);
    _exch = exch;
    // pref.setActiveExchange(exch);
    notifyListeners();
  }

  void activeResolution(String duration) {
    _duration = duration;
    notifyListeners();
  }

  void activeDuration(String duration) {
    _chartDuration = duration;
    notifyListeners();
  }

  void openScripInWebPanel(BuildContext context, DepthInputArgs depthArgs, String basket) {
    // Import the scrip tabs provider to add the new scrip
    final container = ProviderScope.containerOf(context);
    final scripTabsNotifier = container.read(scripTabsProvider.notifier);

    // Check if scrip already exists in tabs
    if (scripTabsNotifier.hasScrip(depthArgs)) {
      // Scrip already exists, just switch to it
      scripTabsNotifier.addScrip(depthArgs); // This will switch to existing tab
    } else {
      // Add the scrip to the tabs manager
      scripTabsNotifier.addScrip(depthArgs);
    }

    // Switch to scrip details panel if callback is available
    if (_onShowScripDepthInfoInPanel != null) {
      _onShowScripDepthInfoInPanel!(depthArgs);
    }
  }

  Function(dynamic)? _onShowScripDepthInfoInPanel;

  // Set callback for showing scrip depth info in panel
  void setOnShowScripDepthInfoInPanel(Function(dynamic) callback) {
    _onShowScripDepthInfoInPanel = callback;
  }

  // Open scrip in web panel using the scrip tabs manager
 

  final List<ChartArgs> _chartTabs = [];
  ChartArgs? _activeTab;
  List<ChartArgs> get chartTabs => _chartTabs;
  ChartArgs? get activeTab => _activeTab;

  final List<ChartArgs> _optionTabs = [];
  ChartArgs? _oactiveTab;
  List<ChartArgs> get optionTabs => _optionTabs;
  ChartArgs? get oactiveTab => _oactiveTab;

  final List<ChartArgs> defaultChartTabs = [
    // ChartArgs(tsym: "Nifty 50", token: "26000", exch: "NSE"),
    // ChartArgs(tsym: "Nifty Bank", token: "26009", exch: "NSE"),
    // ChartArgs(tsym: "Sensex", token: "1", exch: "BSE"),
    // ChartArgs(tsym: "India VIX", token: "26017", exch: "NSE"),
  ];

  void loadDefaultTabs() {
    if (_chartTabs.isEmpty) {
      _chartTabs.addAll(defaultChartTabs);
      _oactiveTab = _chartTabs.first;
      notifyListeners();
    }
    if (_optionTabs.isEmpty) {
      _optionTabs.addAll(defaultChartTabs);
      _oactiveTab = _optionTabs.first;
      notifyListeners();
    }
  }

  void addChartTab(ChartArgs tab, bool type) {
    if (type) {
      if (!_optionTabs.any((t) => t.token == tab.token)) {
        _optionTabs.add(tab);
      }
      _activeTab = tab;
    } else {
      if (!_chartTabs.any((t) => t.token == tab.token)) {
        _chartTabs.add(tab);
      }
      _activeTab = tab;
    }
    notifyListeners();
  }

  void selectChartTab(String token, bool type) {
    if (type) {
      _oactiveTab = _optionTabs.firstWhere(
        (tab) => tab.token == token,
        orElse: () => ChartArgs(
            tsym: '',
            token: '',
            exch: ''), // <- this works if ChartArgs? is allowed
      );
    } else {
      _activeTab = _chartTabs.firstWhere(
        (tab) => tab.token == token,
        orElse: () => ChartArgs(
            tsym: '',
            token: '',
            exch: ''), // <- this works if ChartArgs? is allowed
      );
    }
    notifyListeners();
  }

  void removeChartTab(ChartArgs tab, bool type) {
    if (type) {
      _optionTabs.removeWhere((t) => t.token == tab.token);
    } else {
      _chartTabs.removeWhere((t) => t.token == tab.token);
    }
    notifyListeners();
  }

  void setChartScript(String exch, String token, String tsym) async {
    // Unsubscribe from old depth and reset depth loaded state when changing scrip
    // Note: We don't pass context here as it might not be available,
    // unsubscribe will happen on next depth panel open if needed
    resetDepthLoadedState();

    if (kIsWeb) {
      // On Flutter Web, use WebChartManager to change symbol via postMessage
      final isDarkMode = ref.read(themeProvider).isDarkMode;
      webChartManager.changeSymbol(
        exch: exch,
        token: token,
        tsym: tsym,
        isDarkMode: isDarkMode,
      );
    } else {
      await ConstantName.chartwebViewController!.evaluateJavascript(
          source:
              "window.changeScript([{exch: '$exch', token: '$token', tsym: '$tsym'}], '${ref.read(themeProvider).isDarkMode}')");
    }
    if (_chartTabs.length == 5 &&
        (_chartTabs.any((t) => t.token == token)) != true) {
      removeChartTab(_chartTabs.last, false);
    }
    if (token != "0123") {
      addChartTab(ChartArgs(tsym: tsym, token: token, exch: exch), false);
    }
    selectChartTab(token.toString(), false);
    scrollToSelectedTab(false);
    notifyListeners();
  }

  Future<void> setOptionScript(
      BuildContext context, String exch, String token, String tsym) async {

    try {
      toggleLoad(true);
      // singlePageloader(true);
      notifyListeners();

      // STEP 0: Unsubscribe from old option chain BEFORE clearing the model
      // This must happen first because clearOptionChainData() sets _optionChainModel = null
      if (_optionChainModel != null) {
        await requestWSOptChain(context: context, isSubscribe: false);
      }

      // STEP 1: Clear any previous option chain data immediately
      clearOptionChainData();

      // STEP 1.5: CRITICAL FIX - Clear old socket data immediately to prevent stale LTP
      await _clearOldOptionSocketData();

      // STEP 2: Fetch script quote for the new symbol
      await fetchScripQuoteIndex(token, exch, context);

      // STEP 3: Determine strike price based on instrument type
      if (exch == "BFO" ||
          exch == "NFO" ||
          (exch == "MCX" && _getQuotes.instname == "OPTFUT")) {
        await fetchStikePrc(
            "${_getQuotes.undTk}", "${_getQuotes.undExch}", context);
      } else {
        updateOptStrPrc(_getQuotes.lp.toString());
      }

      // STEP 4: Establish WebSocket connection for underlying
      await ref.read(websocketProvider).establishConnection(
          channelInput: (_getQuotes.exch == "BFO" ||
                  _getQuotes.exch == "NFO" ||
                  (_getQuotes.exch == "MCX" && _getQuotes.instname == "OPTFUT"))
              ? '${_getQuotes.undExch}|${_getQuotes.undTk!}'
              : '${_getQuotes.exch}|${_getQuotes.token!}',
          task: kIsWeb ? "d" : "t",
          context: context);

      // STEP 5: Fetch linked scripts which will set optionExch and selectedTradeSym
      await fetchLinkeScrip(token, exch, context);

      // STEP 6: Verify that required option parameters are set
      if (_optionExch == null || _selectedTradeSym == null) {
        throw Exception(
            "Option parameters not properly initialized after fetchLinkeScrip");
      }

      // STEP 7: Fetch option chain with the properly initialized parameters
      await fetchOPtionChain(
          context: context,
          exchange: _optionExch!,
          numofStrike: numStrike,
          strPrc: optionStrPrc,
          tradeSym: _selectedTradeSym!);

      // STEP 8: Update tab management
      if (_optionTabs.length == 5 &&
          (_optionTabs.any((t) => t.token == token)) != true) {
        removeChartTab(_optionTabs.last, true);
      }
      addChartTab(ChartArgs(tsym: tsym, token: token, exch: exch), true);
      selectChartTab(token.toString(), true);
      scrollToSelectedTab(true);
    } catch (e) {
      setOptionChainError("Failed to initialize option script: $e");
      rethrow; // Re-throw to let caller handle the error
    } finally {
      singlePageloader(false);
      toggleLoad(false);
      notifyListeners();
    }
  }

  void scrollToSelectedTab(bool type) {
    final selectedIndex = type
        ? _optionTabs.indexWhere((tab) => tab.token == _oactiveTab?.token)
        : _chartTabs.indexWhere((tab) => tab.token == _activeTab?.token);
    if (_scrollController.hasClients && selectedIndex != -1) {
      _scrollController.animateTo(
        selectedIndex * 120.0, // Adjust width estimate based on Chip size
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  setpageName(String name) {
    ConstantName.pageName = name;
    notifyListeners();
  }

  // Store holding detail context for returning from chart
  dynamic _holdingDetailExchTsym;
  dynamic _holdingDetailData;

  void setHoldingDetailContext(dynamic exchTsym, dynamic holdingData) {
    _holdingDetailExchTsym = exchTsym;
    _holdingDetailData = holdingData;
  }

  bool hasHoldingDetailContext() {
    return _holdingDetailExchTsym != null && _holdingDetailData != null;
  }

  dynamic getHoldingDetailExchTsym() => _holdingDetailExchTsym;
  dynamic getHoldingDetailData() => _holdingDetailData;

  orderAletrPendingSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _alertPendingSearch = [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _alertPendingSearch = _alertPendingModel!
          .where((element) =>
              element.tsym!.toLowerCase().contains(value.toLowerCase()))
          .toList();
      if (_alertPendingSearch!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
          warningMessage(context, 'No Data Found');
        }
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } else {
      _alertPendingSearch = [];
    }

    notifyListeners();
  }

// Search scrip by tarde symbol

  scripSearch(
      String value, BuildContext context, int? seg, String options) async {
    if (value.length > 2) {
      await fetchSearchScrip(
          searchText: value,
          context: context,
          segment: ["", "EQ", "FO", "CUR", "COM", "IDX"][seg ?? 0],
          option: options == "Option||Is");
    } else {
      searchClear();
    }
    notifyListeners();
  }

  lastScbTok(String val) {
    ConstantName.lastSubscribe = val;
    notifyListeners();
  }

// Change watchlist name
  changeWlName(String name, String isWList) {
    _wlName = name;
    _isPreDefWLs = isWList;
    notifyListeners();
  }

// clear search filter values

  searchClear() {
    _searchErrorText = "Enter more than TWO letters";

    // _searchScripModel!.values = [];
    _allSearchScrip = [];
    _commoditySearchScrip = [];
    _fNoSearchScrip = [];
    _equitySearchScrip = [];
    _currencySearchScrip = [];

    notifyListeners();
  }

// Watchlist scrip delete selection

  isActiveAddBtn(bool val, int index) {
    _isAdded![index] = val;

    notifyListeners();
  }

  Map _marketWatchScripData = {};
  Map get marketWatchScripData => _marketWatchScripData;

  List _scrips = [];
  List get scrips => _scrips;

  // Method to clear current scrips
  void clearCurrentScrips() {
    _scrips.clear();
    notifyListeners();
  }

// Fetching data from the api and stored in a variable

  Future fetchMWList(BuildContext context, bool waitis,
      [bool swit = false]) async {
    try {
      _marketWatchlist = await api.getMWList();
      pref.setMWScrip(true);
      pref.setMWPrice(true);
      pref.setMWPerchnage(true);
      if (_marketWatchlist!.stat == "Ok") {
        ConstantName.sessCheck = true;
        if (_marketWatchlist!.values!.isEmpty) {
          // Default custom watchlist name for new users (when backend
          // returns an empty list). Renamed from "My" → "My Watchlist"
          // for clarity per tester feedback (TC discussion).
          _marketWatchlist!.values!.add("My Watchlist");
        } else {
          _marketWatchlist!.values!.sort((a, b) => a.compareTo(b));

          _marketWatchScripData = {};
          bool isFirst = true;

          for (var element in _marketWatchlist!.values!) {
            if (!waitis) {
              await fetchMWScrip(element, context);
            } else if (isFirst && waitis) {
              await fetchMWScrip(element, context);
              isFirst = false;
            } else {
              fetchMWScrip(element, context); // No await here
            }
          }
        }

        if (_wlName.isEmpty || !_marketWatchlist!.values!.contains(_wlName)) {
          _wlName = _marketWatchlist!.values!.first;
        }

        // Create a new list to build the final watchlist order
        // Filter out any predefined watchlists that might be in the API response
        final updatedValues = _marketWatchlist!.values!
            .where((wl) => !_preDefWL.contains(wl))
            .toList();

        // Add pending watchlists that are not yet synced to API
        for (var pendingWL in _pendingWatchlists) {
          if (!updatedValues.contains(pendingWL)) {
            updatedValues.add(pendingWL);
          }
        }

        // Sort ONLY user watchlists (before adding predefined)
        updatedValues.sort((a, b) => a.compareTo(b));

        // If "My Positions" is in the predefined list (i.e. positions exist),
        // insert it at the very front so it appears as the first tab
        final preDefToAppend = List<String>.from(_preDefWL);
        if (preDefToAppend.contains("My Positions")) {
          preDefToAppend.remove("My Positions");
          updatedValues.insert(0, "My Positions");
        }

        // Now add remaining predefined watchlists at the end
        updatedValues.addAll(preDefToAppend);

        // IMPORTANT: After sorting, update the page index to match the new position
        // Find the current watchlist's new index after sorting
        if (_wlName.isNotEmpty && updatedValues.contains(_wlName)) {
          final newIndex = updatedValues.indexOf(_wlName);
          _currentWatchlistPageIndex = newIndex;
        } else {
          // If current watchlist doesn't exist, default to first watchlist
          _wlName = updatedValues.first;
          _currentWatchlistPageIndex = 0;
        }

        // Create a new MarketWatchlist object to trigger proper change detection
        _marketWatchlist = MarketWatchlist(
          requestTime: _marketWatchlist!.requestTime,
          stat: _marketWatchlist!.stat,
          values: updatedValues,
          emsg: _marketWatchlist!.emsg,
        );

        // Force immediate UI update with the predefined tabs visible
        notifyListeners();

        // Only fetch predefined data if not already loaded
        if (_preDefinedMWlist == null ||
            (_preDefinedMWlist?.nIFTY50NSE?.isEmpty ?? true) ||
            (_preDefinedMWlist?.nIFTYBANKNSE?.isEmpty ?? true) ||
            (_preDefinedMWlist?.sENSEXBSE?.isEmpty ?? true)) {
          await fetchPreDefMWScrip(context);
        }

        // Force another immediate UI update after predefined data is loaded
        notifyListeners();
        if (swit == false) {
          await changeWLScrip(_wlName, context);
        }
      } else {
        if (_marketWatchlist!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _marketWatchlist!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      notifyListeners();
      return _marketWatchlist;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Market WL", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

// Fetching data from the api and stored in a variable

  Future fetchMWScrip(String wlname, context) async {
    try {
      toggleLoadingOn(true);

      // If this is a pending watchlist, return empty scrip list without API call
      if (_pendingWatchlists.contains(wlname)) {
        _watchListValues = [];
        _marketWatchScripData.addAll({wlname: jsonEncode([])});
        toggleLoadingOn(false);
        notifyListeners();
        return null;
      }

//  await requestWSMarketWatchScrip(context: context, isSubscribe: false);
      _marketWatchScrip = await api.getMWScrip(wlname);

      if (_marketWatchScrip!.stat == "Ok") {
        ConstantName.sessCheck = true;
        _watchListValues = _marketWatchScrip!.values;

        if (_watchListValues.isNotEmpty) {
          for (var element in _watchListValues) {
// Seperating Trade symbol(symbol,exp date, Option)

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
              if (element.exch == "MCX" && element.instname == 'FUTCOM') {
                element.option = 'FUT';
              }
            }

            // Holdings Qty add to market watch scrip
            if (ref.read(portfolioProvider).holdingsModel!.isNotEmpty) {
              for (var holding in ref.read(portfolioProvider).holdingsModel!) {
                if (holding.exchTsym![0].exch == "NSE" ||
                    holding.exchTsym![0].exch == "BSE") {
                  if (element.token == holding.exchTsym![0].token) {
                    element.holdingQty = "${holding.currentQty ?? 0}";
                  }
                }
              }
            }
          }
        } else {
          _watchListValues = [];
        }

        _marketWatchScripData.addAll({wlname: jsonEncode(_watchListValues)});

        notifyListeners();
      } else {
        if (_marketWatchScrip!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _marketWatchScrip!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
        _watchListValues = [];
      }

      return _marketWatchScrip;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Market Watch Scrip", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchPreDefMWScrip(BuildContext context) async {
    // Prevent concurrent calls - if already fetching, skip
    if (_isFetchingPreDefMW) {
      return;
    }

    try {
      _isFetchingPreDefMW = true;
      // requestWSMarketWatchScrip(context: context, isSubscribe: false);
      toggleLoadingOn(true);

      _preDefinedMWlist = await api.getPreDefMWScrip();

      if (_preDefinedMWlist != null) {
        if (_preDefinedMWlist!.stat == "Ok") {
          ConstantName.sessCheck = true;

          if (_preDefinedMWlist!.nIFTY50NSE!.isNotEmpty) {
            _preDefinedMWlist!.nIFTY50NSE!.sort((a, b) {
              return a.tsym!.compareTo(b.tsym!);
            });
            for (var element in _preDefinedMWlist!.nIFTY50NSE!) {
              // Seperating Trade symbol(symbol,exp date, Option)
              if (element.exch == "BFO" && element.dname != null) {
                List<String> splitVal = element.dname!.split(" ");

                element.symbol = splitVal[0];
                element.expDate = "${splitVal[1]} ${splitVal[2]}";
                element.option = splitVal.length > 4
                    ? "${splitVal[3]} ${splitVal[4]}"
                    : splitVal[3];
              } else {
                Map spilitSymbol = spilitTsym(value: "${element.tsym}");

                element.symbol = "${spilitSymbol["symbol"]}";
                element.expDate = "${spilitSymbol["expDate"]}";
                element.option = "${spilitSymbol["option"]}";
              }
              if (ref.read(portfolioProvider).holdingsModel!.isNotEmpty) {
                for (var holding
                    in ref.read(portfolioProvider).holdingsModel!) {
                  if (holding.exchTsym![0].exch == "NSE" ||
                      holding.exchTsym![0].exch == "BSE") {
                    if (element.token == holding.exchTsym![0].token) {
                      element.holdingQty = "${holding.currentQty ?? 0}";
                    }
                  }
                }
              }
            }
          }
          if (_preDefinedMWlist!.nIFTYBANKNSE!.isNotEmpty) {
            _preDefinedMWlist!.nIFTYBANKNSE!.sort((a, b) {
              return a.tsym!.compareTo(b.tsym!);
            });
            for (var element in _preDefinedMWlist!.nIFTYBANKNSE!) {
// Seperating Trade symbol(symbol,exp date, Option)

              if (element.exch == "BFO" && element.dname != null) {
                List<String> splitVal = element.dname!.split(" ");

                element.symbol = splitVal[0];
                element.expDate = "${splitVal[1]} ${splitVal[2]}";
                element.option = splitVal.length > 4
                    ? "${splitVal[3]} ${splitVal[4]}"
                    : splitVal[3];
              } else {
                Map spilitSymbol = spilitTsym(value: "${element.tsym}");

                element.symbol = "${spilitSymbol["symbol"]}";
                element.expDate = "${spilitSymbol["expDate"]}";
                element.option = "${spilitSymbol["option"]}";
              }
              if (ref.read(portfolioProvider).holdingsModel!.isNotEmpty) {
                for (var holding
                    in ref.read(portfolioProvider).holdingsModel!) {
                  if (holding.exchTsym![0].exch == "NSE" ||
                      holding.exchTsym![0].exch == "BSE") {
                    if (element.token == holding.exchTsym![0].token) {
                      element.holdingQty = "${holding.currentQty ?? 0}";
                    }
                  }
                }
              }
            }
          }
          if (_preDefinedMWlist!.sENSEXBSE!.isNotEmpty) {
            _preDefinedMWlist!.sENSEXBSE!.sort((a, b) {
              return a.tsym!.compareTo(b.tsym!);
            });
            for (var element in _preDefinedMWlist!.sENSEXBSE!) {
              // Seperating Trade symbol(symbol,exp date, Option)
              if (element.exch == "BFO" && element.dname != null) {
                List<String> splitVal = element.dname!.split(" ");

                element.symbol = splitVal[0];
                element.expDate = "${splitVal[1]} ${splitVal[2]}";
                element.option = splitVal.length > 4
                    ? "${splitVal[3]} ${splitVal[4]}"
                    : splitVal[3];
              } else {
                Map spilitSymbol = spilitTsym(value: "${element.tsym}");

                element.symbol = "${spilitSymbol["symbol"]}";
                element.expDate = "${spilitSymbol["expDate"]}";
                element.option = "${spilitSymbol["option"]}";
              }
              if (ref.read(portfolioProvider).holdingsModel!.isNotEmpty) {
                for (var holding
                    in ref.read(portfolioProvider).holdingsModel!) {
                  if (holding.exchTsym![0].exch == "NSE" ||
                      holding.exchTsym![0].exch == "BSE") {
                    if (element.token == holding.exchTsym![0].token) {
                      element.holdingQty = "${holding.currentQty ?? 0}";
                    }
                  }
                }
              }
            }
          }
// Pre-define market scrip adding to watchlist
          _marketWatchScripData
              .addAll({"Nifty50": jsonEncode(_preDefinedMWlist!.nIFTY50NSE!)});
          _marketWatchScripData.addAll(
              {"Niftybank": jsonEncode(_preDefinedMWlist!.nIFTYBANKNSE!)});
          _marketWatchScripData
              .addAll({"Sensex": jsonEncode(_preDefinedMWlist!.sENSEXBSE!)});
          // If current watchlist is a predefined one, make sure to update scrips
          if (_wlName == "Nifty50" ||
              _wlName == "Niftybank" ||
              _wlName == "Sensex") {
            if (_wlName == "Nifty50") {
              _scrips = jsonDecode(jsonEncode(_preDefinedMWlist!.nIFTY50NSE!));
            } else if (_wlName == "Niftybank") {
              _scrips =
                  jsonDecode(jsonEncode(_preDefinedMWlist!.nIFTYBANKNSE!));
            } else if (_wlName == "Sensex") {
              _scrips = jsonDecode(jsonEncode(_preDefinedMWlist!.sENSEXBSE!));
            }

            // Apply any saved sorting
            if (_sortByWL.isNotEmpty) {
              _applySavedSorting();
            }
          }
          notifyListeners();

          // await requestWSMarketWatchScrip(context: context, isSubscribe: true);
        } else {
          if (_marketWatchScrip?.emsg ==
                  "Session Expired :  Invalid Session Key" &&
              _marketWatchScrip?.stat == "Not_Ok") {
            ref.read(authProvider).ifSessionExpired(context);
          }
          // _watchListValues = [];
        }
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Market Watch Scrip", "Error": "$e"});
      notifyListeners();
    } finally {
      _isFetchingPreDefMW = false;
      toggleLoadingOn(false);
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchScripInfo(String token, String exch, BuildContext context,
      [bool order = false]) async {
    try {
      if (order == false &&
          storeQuotes.containsKey(token) &&
          storeQuotes[token]?['s'] != null) {
        _scripInfoModel = storeQuotes[token]?['s'];
        ConstantName.sessCheck = true;
      } else {
        // print('qqq else');
        _scripInfoModel = await api.getScripInfo(token, exch);

        if (_scripInfoModel!.stat == "Ok") {
          // Seperating Trade symbol(symbol,exp date, Option)
          ConstantName.sessCheck = true;
          if (_scripInfoModel!.exch == "BFO" &&
              _scripInfoModel!.dname != null) {
            List<String> splitVal = _scripInfoModel!.dname!.split(" ");

            _scripInfoModel!.symbol = splitVal[0];
            // BFO: keep dname's day+month, append the year from the tsym. (TC_440)
            _scripInfoModel!.expDate =
                bfoExpiryWithYear(splitVal, _scripInfoModel!.tsym);
            _scripInfoModel!.option = splitVal.length > 4
                ? "${splitVal[3]} ${splitVal[4]}"
                : splitVal[3];
          } else {
            Map spilitSymbol = spilitTsym(value: "${_scripInfoModel!.tsym}");

            _scripInfoModel!.symbol = "${spilitSymbol["symbol"]}";
            _scripInfoModel!.expDate = "${spilitSymbol["expDate"]}";
            _scripInfoModel!.option = "${spilitSymbol["option"]}";
          }
          storeQuotes[token]?['s'] = {};
          storeQuotes[token]?['s'] = _scripInfoModel;
          // Manage cache size to prevent memory issues
          _manageCacheSize();
        }

        if (_scripInfoModel!.emsg == "Session Expired :  Invalid Session Key" &&
            _scripInfoModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }

      notifyListeners();
      return _scripInfoModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Scrip Info", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  Future fetchScripQuoteIndex(
      String token, String exch, BuildContext context) async {
    try {
      if (storeQuotes.isNotEmpty &&
          storeQuotes.containsKey(token) &&
          storeQuotes[token]?['q'] != null) {
        // print('qqq sq if');
        ConstantName.sessCheck = true;
        _getQuotes = storeQuotes[token]?['q'];
      } else {
        // print('qqq qs else');
        _getQuotes = await api.getScripQuote(token, exch);

        if (_getQuotes.stat == "Ok") {
          ConstantName.sessCheck = true;
// Seperating Trade symbol(symbol,exp date, Option)
          if (_getQuotes.exch == "BFO" && _getQuotes.cname != null) {
            List<String> splitVal = _getQuotes.cname!.split(" ");

            _getQuotes.symbol = splitVal[0];
            // BFO: keep cname's day+month, append the year from the tsym. (TC_440)
            _getQuotes.expDate = bfoExpiryWithYear(splitVal, _getQuotes.tsym);
            _getQuotes.option = splitVal.length > 4
                ? "${splitVal[3]} ${splitVal[4]}"
                : splitVal[3];
          } else {
            Map spilitSymbol = spilitTsym(value: "${_getQuotes.tsym}");
            _getQuotes.symbol = "${spilitSymbol["symbol"]}";
            _getQuotes.expDate = "${spilitSymbol["expDate"]}";
            _getQuotes.option = "${spilitSymbol["option"]}";
          }

          storeQuotes[token] = {};
          storeQuotes[token]?['q'] = _getQuotes;
          _optionStrPrc = "${_getQuotes.lp}";

          scripQtyCal();
        }
        if (_getQuotes.emsg == "Session Expired :  Invalid Session Key" &&
            _getQuotes.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      notifyListeners();
      return _getQuotes;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Scrip Quote", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

// Fetching data from the api and stored in a variable
  Future fetchScripQuote(
      String token, String exch, BuildContext context) async {
    try {
      _returnsGridview = [];
      _depthBtns = [
        {
          "btnName": "Overview",
          "imgPath": assets.dInfo,
          "case": "click here to view the market depth."
        },
        {
          "btnName": "Chart",
          "imgPath": assets.charticon,
          "case": "Click here to view the trading view chart."
        }
      ];
      if (getOptionawait(exch, token)) {
        _depthBtns.add({
          "btnName": "Option",
          "imgPath": assets.optChainIcon,
          "case": "Click here to view the Option chain details."
        });
        _depthBtns.add({
          "btnName": "Future",
          "imgPath": assets.optChainIcon,
          "case": "click here to view the futures of the underline scrpit."
        });
      }
      if (exch == 'NSE' || exch == 'BSE') {
        _depthBtns.add({
          "btnName": "Fundamental",
          "imgPath": assets.dInfo,
          "case": "Click here to view fundamental data."
        });
      }
      _depthBtns.add({
        "btnName": "Set Alert",
        "imgPath": assets.calendar,
        "case": "click here to view the futures of the underline scrpit."
      });
      if (storeQuotes.isNotEmpty &&
          storeQuotes.containsKey(token) &&
          storeQuotes[token]?['q'] != null) {
        // print('qqq sq if');
        ConstantName.sessCheck = true;
        _getQuotes = storeQuotes[token]?['q'];
      } else {
        // print('qqq qs else');
        _getQuotes = await api.getScripQuote(token, exch);

        if (_getQuotes.stat == "Ok") {
          ConstantName.sessCheck = true;
// Seperating Trade symbol(symbol,exp date, Option)
          if (_getQuotes.exch == "BFO" && _getQuotes.cname != null) {
            List<String> splitVal = _getQuotes.cname!.split(" ");

            _getQuotes.symbol = splitVal[0];
            // BFO: keep cname's day+month, append the year from the tsym. (TC_440)
            _getQuotes.expDate = bfoExpiryWithYear(splitVal, _getQuotes.tsym);
            _getQuotes.option = splitVal.length > 4
                ? "${splitVal[3]} ${splitVal[4]}"
                : splitVal[3];
          } else {
            Map spilitSymbol = spilitTsym(value: "${_getQuotes.tsym}");
            _getQuotes.symbol = "${spilitSymbol["symbol"]}";
            _getQuotes.expDate = "${spilitSymbol["expDate"]}";
            _getQuotes.option = "${spilitSymbol["option"]}";
          }

          storeQuotes[token] = {};
          storeQuotes[token]?['q'] = _getQuotes;
          _optionStrPrc = "${_getQuotes.lp}";

// Scrip market depth calc
          scripQtyCal();
          // Manage cache size to prevent memory issues
          _manageCacheSize();
        }
        if (_getQuotes.emsg == "Session Expired :  Invalid Session Key" &&
            _getQuotes.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      notifyListeners();
      return _getQuotes;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Scrip Quote", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  // Fetching stike price for  option chain

  Future fetchStikePrc(String token, String exch, BuildContext context) async {
    try {
      _getStikePrc = await api.getScripQuote(token, exch);

      if (_getStikePrc!.stat == "Ok") {
        ConstantName.sessCheck = true;
        if (_getStikePrc!.exch == "NSE" ||
            _getStikePrc!.exch == "BSE" ||
            (_getStikePrc!.exch == "MCX" &&
                _getStikePrc!.instname == "FUTCOM")) {
          _optionStrPrc = "${_getStikePrc!.lp}";
        }
        await ref.read(websocketProvider).establishConnection(
            channelInput: '${_getStikePrc!.exch}|${_getStikePrc!.token!}',
            task: kIsWeb ? "d" : "t",
            context: context);
      }
      if (_getStikePrc!.emsg == "Session Expired :  Invalid Session Key" &&
          _getStikePrc!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Scrip Quote", "Error": "$e"});
      notifyListeners();
    }
  }

// Scrip market depth calc
  void scripQtyCal() {
    if (_getQuotes.instname != "UNDIND" && _getQuotes.instname != "COM") {
      if ((_getQuotes.tbq != "null" && _getQuotes.tbq != null) ||
          (_getQuotes.tsq != "null" && _getQuotes.tsq != null)) {
        _totBuyQtyPer = (int.tryParse(_getQuotes.tbq?.toString() ?? "0") ?? 0) /
            ((int.tryParse(_getQuotes.tbq?.toString() ?? "0") ?? 0) +
                (int.tryParse(_getQuotes.tsq?.contains('.') == true
                        ? _getQuotes.tsq!.split(".")[0]
                        : _getQuotes.tsq ?? "0") ??
                    0)) *
            100;

        int tbqValue = int.tryParse(_getQuotes.tbq ?? "0") ?? 0;
        int tsqValue = int.tryParse(
                _getQuotes.tsq != null && _getQuotes.tsq!.contains('.')
                    ? _getQuotes.tsq!.split(".")[0]
                    : _getQuotes.tsq ?? "0") ??
            0;
        if ((tbqValue + tsqValue) == 0) {
          _totSellQtyPer = 0;
        } else {
          _totSellQtyPer = (tsqValue / (tbqValue + tsqValue)) * 100;
        }
        if (_totBuyQtyPer.isNaN) {
          _totBuyQtyPer = 0.00;
        }
        if (_totSellQtyPer.isNaN) {
          _totSellQtyPer = 0.00;
        }
        _totBuyQtyPerChng = _totBuyQtyPer / 100;
        // Parse each value safely using int.tryParse
        _maxSellQty = [
          int.tryParse(_getQuotes.sq2 ?? "0") ?? 0,
          int.tryParse(_getQuotes.sq1 ?? "0") ?? 0,
          int.tryParse(_getQuotes.sq3 ?? "0") ?? 0,
          int.tryParse(_getQuotes.sq4 ?? "0") ?? 0,
          int.tryParse(_getQuotes.sq5 ?? "0") ?? 0
        ].reduce(max);

// Parse each value safely for maxBuyQty
        _maxBuyQty = [
          int.tryParse(_getQuotes.bq2 ?? "0") ?? 0,
          int.tryParse(_getQuotes.bq1 ?? "0") ?? 0,
          int.tryParse(_getQuotes.bq3 ?? "0") ?? 0,
          int.tryParse(_getQuotes.bq4 ?? "0") ?? 0,
          int.tryParse(_getQuotes.bq5 ?? "0") ?? 0
        ].reduce(max);
      }
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchSearchScrip(
      {required String searchText,
      required BuildContext context,
      required String segment,
      required bool option,
      List<String>? exchanges}) async {
    try {
      toggleLoadingOn(true);
      // Use provided exchanges or default to user profile exchanges
      List<String> exchFilter;
      if (exchanges != null && exchanges.isNotEmpty) {
        exchFilter = exchanges.map((e) => '"$e"').toList();
      } else {
        if (_exarr.isEmpty) {
          List<String> rawList =
              ref.read(userProfileProvider).userDetailModel?.exarr ?? [];
          _exarr = rawList.map((e) => '"${e.toString()}"').toList();
        }
        exchFilter = _exarr;
      }
      _searchScripModel = await api.getSearchScripNew(
          searchText: searchText, categ: segment, exchs: exchFilter, opt: option);
      _allSearchScrip = [];
      // _equitySearchScrip = [];
      // _fNoSearchScrip = [];
      // _currencySearchScrip = [];
      // _commoditySearchScrip = [];
      if (_searchScripModel?.stat == "Ok") {
        ConstantName.sessCheck = true;

        final values = _searchScripModel!.values!;
        _isAdded = List<bool>.filled(values.length, false);

        if (values.isNotEmpty) {
          // final Set<String> currencySet = {
          //   "FUTCUR",
          //   "FUTIRC",
          //   "FUTIRT",
          //   "OPTCUR",
          //   "OPTIRC"
          // };
          // final Set<String> commoditySet = {
          //   "AUCSO",
          //   "FUTCOM",
          //   "FUTIDX",
          //   "OPTFUT"
          // };
          // final Set<String> fnoSet = {"FUTIDX", "FUTSTK", "OPTIDX", "OPTSTK"};

          for (int i = 0; i < values.length; i++) {
            final val = values[i];
            final exch = val.exch;
            final dname = val.dname;
            // final instname = val.instname?.toUpperCase() ?? "";
            final tsym = val.tsym;

            if (exch == "BFO" && dname != null) {
              final splitVal = dname.split(" ");
              val.symbol = splitVal[0];
              // BFO: keep dname's day+month, append the year from the tsym —
              // same helper as every other BFO branch. (TC_440)
              val.expDate = bfoExpiryWithYear(splitVal, tsym);
              // Search sends BFO futures as "... FUT 0" (empty strike slot); drop
              // the "0" so it reads just "FUT". Options keep type + strike. (FUT0)
              val.option = (splitVal.length > 3 &&
                      splitVal[3].toUpperCase() == "FUT")
                  ? "FUT"
                  : (splitVal.length > 4
                      ? "${splitVal[3]} ${splitVal[4]}"
                      : splitVal[3]);
            } else {
              final spilitSymbol = spilitTsym(value: tsym ?? "");
              val.symbol = spilitSymbol["symbol"];
              val.expDate = spilitSymbol["expDate"];
              val.option = spilitSymbol["option"];
            }

            for (var scrip in _scrips) {
              if (tsym == scrip['tsym']) {
                _isAdded![i] = true;
                break;
              }
            }

            // if (instname != "COM") {
            _allSearchScrip?.add(val);

            //   if (currencySet.contains(instname)) {
            //     _currencySearchScrip?.add(val);
            //   } else if (commoditySet.contains(instname)) {
            //     _commoditySearchScrip?.add(val);
            //   } else if (fnoSet.contains(instname)) {
            //     _fNoSearchScrip?.add(val);
            //   } else {
            //     _equitySearchScrip?.add(val);
            //   }
            // }
          }

          _searchErrorText = "";
          notifyListeners();
        }
      } else {
        _searchErrorText = "No Data Found";

        if (_searchScripModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _searchScripModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }

      notifyListeners();
      return _searchScripModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Search", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  // Normalises an expiry string to the expiry-list format "DD-MON-YYYY"
  // (e.g. "14 JUL 26" -> "14-JUL-2026"), so a selected contract's expiry can be
  // matched against the option expiry list regardless of separators / year length.
  String _normalizeExpiry(String e) {
    final parts = e.trim().toUpperCase().split(RegExp(r'[\s\-]+'));
    if (parts.length != 3) return e.trim().toUpperCase();
    final day = parts[0].padLeft(2, '0');
    final mon = parts[1];
    var yr = parts[2];
    if (yr.length == 2) yr = '20$yr';
    return '$day-$mon-$yr';
  }

  // When the option chain is opened from a specific option contract, returns
  // that contract's expiry (in the expiry-list format) so the chain opens on the
  // selected contract's expiry instead of the nearest. Returns null for
  // indices/stocks (no own expiry), for expiries not in the list, or when the
  // current quote isn't this token (guards against a stale quote from another
  // scrip, so only a genuine contract-open is ever affected). (TC_408)
  String? _matchedContractExpiry(String token) {
    if (_getQuotes.token?.toString() != token) return null;
    final raw = _getQuotes.expDate;
    if (raw == null || raw.trim().isEmpty) return null;
    final target = _normalizeExpiry(raw);
    for (final e in (_optExp ?? [])) {
      final exd = e.exd;
      if (exd != null && _normalizeExpiry(exd) == target) return exd;
    }
    return null;
  }

  // Fetching data from the api and stored in a variable

  Future fetchLinkeScrip(
      String token, String exch, BuildContext context) async {
    try {
      // _depthBtns = [
      //   {
      //     "btnName": "Overview",
      //     "imgPath": assets.dInfo,
      //     "case": "click here to view the market depth."
      //   },
      //   {
      //     "btnName": "Chart",
      //     "imgPath": assets.charticon,
      //     "case": "Click here to view the trading view chart."
      //   }
      // ];
      if (storeQuotes.containsKey(token) && storeQuotes[token]?['l'] != null) {
        ConstantName.sessCheck = true;
        _linkedScrips = storeQuotes[token]?['l']['all'];
        _equls = storeQuotes[token]?['l']['eq'];
        _fut = storeQuotes[token]?['l']['fu'];
        _optExp = storeQuotes[token]?['l']['op'];
        if (_optExp!.isNotEmpty) {
          _sortedDate = storeQuotes[token]?['l']['sortdate'];
          _selectedExpDate = _sortedDate[0];

          _optionExch = storeQuotes[token]?['l']['optionExch'];
          _selectedTradeSym = storeQuotes[token]?['l']['selectedTradeSym'];
          // If opened from a specific option contract, prefer that contract's
          // expiry over the nearest and re-derive its exch/tradeSym (TC_408).
          final matchedExp = _matchedContractExpiry(token);
          if (matchedExp != null) {
            _selectedExpDate = matchedExp;
            for (var i = 0; i < _optExp!.length; i++) {
              if (_selectedExpDate == _optExp![i].exd) {
                _optionExch = _optExp![i].exch;
                _selectedTradeSym = _optExp![i].tsym;
              }
            }
          }
        }
        if (_fut!.isNotEmpty) {
          _futToken = "${_fut![0].token}";
          __futExch = "${_fut![0].exch}";
        }
      } else {
        _linkedScrips = await api.getLinkedScrip(token, exch);
        if (_linkedScrips != null &&
            _linkedScrips!.emsg == "Session Expired :  Invalid Session Key" &&
            _linkedScrips!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
          return _linkedScrips;
        }
        if (_linkedScrips!.stat == "Ok") {
          ConstantName.sessCheck = true;
          _equls = _linkedScrips!.equls;
          _fut = _linkedScrips!.fut;
          _optExp = _linkedScrips!.optExp;

          if (_optExp!.isNotEmpty) {
// Option expiry Date wise sorting

            List<DateTime> dates = _optExp!.map((dateString) {
              List<String> parts = dateString.exd!.split('-');
              int day = int.parse(parts[0]);
              int year = int.parse(parts[2]);

              Map<String, int> monthMap = {
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
              int month = monthMap[parts[1].toUpperCase()]!;

              return DateTime(year, month, day);
            }).toList();
            dates.sort((a, b) => a.compareTo(b));
            _sortedDate = dates.map((date) {
              String day = date.day.toString().padLeft(2, '0');
              // String month = date.month.toString().padLeft(2, '0');
              String year = date.year.toString();

              Map<int, String> monthMap = {
                1: 'JAN',
                2: 'FEB',
                3: 'MAR',
                4: 'APR',
                5: 'MAY',
                6: 'JUN',
                7: 'JUL',
                8: 'AUG',
                9: 'SEP',
                10: 'OCT',
                11: 'NOV',
                12: 'DEC'
              };
              String monthString = monthMap[date.month]!.toUpperCase();

              return "$day-$monthString-$year";
            }).toList();

            // print("########### $_sortedDate");
            _selectedExpDate = _sortedDate[0];
            // If opened from a specific option contract, default the expiry to
            // that contract's expiry instead of the nearest (TC_408). Falls back
            // to nearest for indices/stocks or unknown expiries.
            final matchedExp = _matchedContractExpiry(token);
            if (matchedExp != null) _selectedExpDate = matchedExp;
            for (var i = 0; i < _optExp!.length; i++) {
              if (_selectedExpDate == _optExp![i].exd) {
                _optionExch = _optExp![i].exch;
                _selectedTradeSym = _optExp![i].tsym;
              }
            }
          }
          if (_fut!.isNotEmpty) {
            _futToken = "${_fut![0].token}";
            __futExch = "${_fut![0].exch}";

            // print("Future $_futToken  $__futExch ");

            // Seperating Trade symbol(symbol,exp date, Option)
            for (var element in _fut!) {
              Map spilitSymbol = spilitTsym(value: "${element.tsym}");

              element.symbol = "${spilitSymbol["symbol"]}";
              element.expDate = "${spilitSymbol["expDate"]}";
              element.option = "${spilitSymbol["option"]}";
            }
          }
          storeQuotes[token]?['l'] = {};
          storeQuotes[token]?['l'] = {
            'all': _linkedScrips,
            'eq': _equls,
            'fu': _fut,
            'op': _optExp,
            'sortdate': _sortedDate,
            'optionExch': _optionExch,
            'selectedTradeSym': _selectedTradeSym,
          };
          // Manage cache size to prevent memory issues
          _manageCacheSize();
        } else {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      notifyListeners();
      return _linkedScrips;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Linked Scrip", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

// Fetching data from the api and stored in a variable
  Future fetchOPtionChain(
      {required String strPrc,
      required String tradeSym,
      required String exchange,
      required BuildContext context,
      required String numofStrike}) async {
    try {
      if (numofStrike == "All") {
        numofStrike = "100";
      }
      toggleLoad(true);

      // STEP 1: Immediately clear old option chain data to prevent stale UI
      _optChainCall.clear();
      _optChainPut.clear();
      _optChainCallDown.clear();
      _optChainCallUp.clear();
      _optChainPutDown.clear();
      _optChainPutUp.clear();

      // STEP 2: Unsubscribe from old WebSocket connections AND clear socket data
      if (_optionChainModel != null) {
        await requestWSOptChain(context: context, isSubscribe: false);

        // CRITICAL FIX: Clear old option chain socket data from WebSocket provider
        await _clearOldOptionSocketData();
      }

      // STEP 3: Clear the model to ensure fresh data
      _optionChainModel = null;
      notifyListeners(); // Update UI immediately with cleared data


      // Debug: Print current socket data state
      final socketDatas = ref.read(websocketProvider).socketDatas;

      // Print relevant socket data for current option chain context
      if (socketDatas.isNotEmpty) {

        // Try to find data for the underlying instrument
        socketDatas.forEach((token, data) {
          if (data['tsym'] != null &&
              (data['tsym'].toString().contains('NIFTY') ||
                  data['tsym'].toString().contains('BANKNIFTY') ||
                  data['tsym'].toString().contains('SENSEX'))) {
          }
        });
      }

      // STEP 4: Fetch new option chain data
      _optionChainModel = await api.getOptionChain(
          context: context,
          strPrc: strPrc,
          tradeSym: tradeSym,
          exchange: exchange,
          numofStrike: numofStrike);

      if (_optionChainModel!.stat == "Ok") {
        ConstantName.sessCheck = true;

        // STEP 5: Process and split option chain data
        await splitOptionChain(context, double.parse(strPrc));
      } else {
        // STEP 6: Handle API failure - ensure data is cleared
        _optChainCall.clear();
        _optChainPut.clear();
        _optChainCallDown.clear();
        _optChainCallUp.clear();
        _optChainPutDown.clear();
        _optChainPutUp.clear();

        if (_optionChainModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _optionChainModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }

      notifyListeners();
    } catch (e) {
      // STEP 7: Handle errors by clearing data and logging
      clearOptionChainData();
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Option Chain", "Error": "$e"});
      notifyListeners();
      rethrow; // Re-throw to let caller handle the error
    } finally {
      toggleLoad(false);
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchTechData(
      {required String exch,
      required String tradeSym,
      required String lastPrc,
      required BuildContext context}) async {
    try {
      String? token = _getQuotes.token;
      if (storeQuotes.containsKey(token) && storeQuotes[token]?['t'] != null) {
        ConstantName.sessCheck = true;
        _techData = storeQuotes[token]?['t'];
      } else {
        _techData = await api.getTechData(exch, tradeSym);
        _returnsGridview = [];
        if (_techData!.stat == "OK") {
          ConstantName.sessCheck = true;
          storeQuotes[token]?['t'] = {};
          storeQuotes[token]?['t'] = _techData;
          // Manage cache size to prevent memory issues
          _manageCacheSize();
        }

        if (_techData!.emsg == "Session Expired :  Invalid Session Key" &&
            _techData!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
      techDataCalc(lastPrc);

      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Tech Data", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoad(false);
    }
  }

// Fetching fundametal datas
  Future fetchFundamentalData({required String tradeSym, String? token}) async {
    try {
      // Use provided token or fallback to _getQuotes.token
      String? cacheToken = token ?? _getQuotes.token;

      // Clear cache for this specific token to ensure fresh data
      if (cacheToken != null && storeQuotes.containsKey(cacheToken)) {
        storeQuotes[cacheToken]?['f'] = null;
      }

      _fundamentalData = await api.getFundamentalData(tradeSym);

      List ltpArgs = [];

      if (_fundamentalData!.msg != "no data found") {
        if (cacheToken != null) {
          if (storeQuotes[cacheToken] == null) {
            storeQuotes[cacheToken] = {};
          }
          storeQuotes[cacheToken]?['f'] = _fundamentalData;
          // Manage cache size to prevent memory issues
          _manageCacheSize();
        }
        _peersChartKeys = _fundamentalData!.peerComparisonChart!.keys.toList();
        DateFormat format = DateFormat("yyyy-MM-dd");
        _mfHoldingDate = [];

        void sortAndFormatDates(
            List<dynamic> data,
            String Function(dynamic) getDate,
            void Function(dynamic, String) setConvDate) {
          data.sort((a, b) =>
              format.parse(getDate(b)).compareTo(format.parse(getDate(a))));
          for (var element in data) {
            String formattedDate =
                DateFormat.yMMMMd().format(format.parse(getDate(element)));
            List<String> date = formattedDate.split(" ");
            setConvDate(
                element, "${date[0].substring(0, 3)} ${date[2].substring(2)}");
          }
        }

        if (fundamentalData != null && fundamentalData!.shareholdings != null) {
          sortAndFormatDates(
            _fundamentalData!.shareholdings!,
            (element) => element.date!,
            (element, value) => element.convDate = value,
          );
        }

        // Shareholding dates
        sortAndFormatDates(
          _fundamentalData!.stockFinancialsConsolidated!.balanceSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );

        // Financial statements
        var consolidated = _fundamentalData!.stockFinancialsConsolidated!;
        var standalone = _fundamentalData!.stockFinancialsStandalone!;
        sortAndFormatDates(
          consolidated.balanceSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );

        sortAndFormatDates(
          consolidated.incomeSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );
        sortAndFormatDates(
          consolidated.cashflowSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );
        sortAndFormatDates(
          standalone.balanceSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );
        sortAndFormatDates(
          standalone.incomeSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );
        sortAndFormatDates(
          standalone.cashflowSheet!,
          (element) => element.yearEndDate!,
          (element, value) => element.convDate = value,
        );

        _selctedFinYear = standalone.balanceSheet![0].convDate!;
        _finnceYears = standalone.incomeSheet!.map((e) => e.convDate!).toList();

        // Peer comparisons
        for (var peers in [
          _fundamentalData!.peersComparison!.stock!,
          _fundamentalData!.peersComparison!.peers!
        ]) {
          for (var element in peers) {
            String ltp = element.sYMBOL!.substring(0, 3);
            String tok = element.zebuToken!;
            if (ltp.isNotEmpty && tok.isNotEmpty) {
              ltpArgs.add({"exch": ltp, "token": tok});
            }
          }
        }

        final response = await api.getLTP(ltpArgs);
        Map res = jsonDecode(response.body);

        void updateLtpData(List data) {
          for (var element in data) {
            String tok = element.zebuToken!;
            if (tok.isNotEmpty && tok == res["data"][tok]?['token']) {
              element.ltp = res["data"][tok]["lp"];
            }
          }
        }

        updateLtpData(_fundamentalData!.peersComparison!.stock!);
        updateLtpData(_fundamentalData!.peersComparison!.peers!);

        // Price comparison chart data
        List<List<PrcComparisionChartData>> chartDataLists = [
          _prcComChrtData1,
          _prcComChrtData2,
          _prcComChrtData3,
          _prcComChrtData4,
          _prcComChrtData5,
        ];

        for (var i = 0; i < _peersChartKeys.length; i++) {
          var close = _fundamentalData!.peerComparisonChart![_peersChartKeys[i]]
              ['close'];
          var dates = _fundamentalData!.peerComparisonChart![_peersChartKeys[i]]
              ['date'];
          for (var j = 0; j < dates.length; j++) {
            String formattedDate =
                DateFormat('MMM dd').format(DateTime.parse(dates[j]));
            String date = formattedDate.split(" ")[0];
            chartDataLists[i].add(PrcComparisionChartData(date, close[j]));
          }
        }
      }

      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Fundamental ", "Error": "$e"});
      notifyListeners();
    } finally {}
  }

  // Method to clear chart data
  void clearChartData() {
    _eodChartData = [];
    _chartDataLoading = false;
    notifyListeners();
  }

  // Method to clear fundamental data
  void clearFundamentalData() {
    _fundamentalData = null;
    notifyListeners();
  }

  /// Clears fundamental data without notifying listeners.
  /// Use in didUpdateWidget to avoid modifying provider during build.
  void clearFundamentalDataSilent() {
    _fundamentalData = null;
  }

  // Method to clear cache for a specific token
  void clearCacheForToken(String token) {
    if (storeQuotes.containsKey(token)) {
      storeQuotes[token]?['f'] = null;
    }
    notifyListeners();
  }

  Future<void> fetchEODChartData(String tsym, String exch,
      {String timeframe = "1Y", BuildContext? context}) async {
    try {
      // Clear old data and set loading state
      _eodChartData = [];
      _chartDataLoading = true;
      notifyListeners();

      _eodChartData = await api.getEODChartData(tsym, exch, timeframe: timeframe);

      _chartDataLoading = false;
      notifyListeners();
    } catch (e) {
      _chartDataLoading = false;
   
      // The api method throws this exact message when the vendor returns the
      // session-expired response. EodChartData has no stat/emsg fields, so
      // detecting it here via the exception message is the only signal we get.
      if (context != null &&
          context.mounted &&
          e.toString().contains("Session Expired :  Invalid Session Key")) {
        ref.read(authProvider).ifSessionExpired(context);
      }
      notifyListeners();
      rethrow;
    }
  }


// Scrip returns data(Year/Month/Week/Day)
  techDataCalc(String lastPrc) {
    _returnsGridview = [];
    double ltp = lastPrc != "null" ? double.parse(lastPrc) : 0.0;

    if (_techData != null) {
      double wk1c =
          double.parse(_techData == null ? "0.00" : _techData!.wk1C ?? "0.00");
      double wk1Def = ltp - wk1c;
      _techData!.wk1Pc = ((wk1Def / wk1c) * 100).toStringAsFixed(2);

      _returnsGridview.add({
        "duration": "One Week",
        "low": "${_techData!.wk1L}",
        "high": "${_techData!.wk1H}",
        "percent":
            _techData!.wk1Pc == "Infinity" ? "0.00" : "${_techData!.wk1Pc}",
        "ltp": lastPrc
      });

      double wk2c = double.parse(_techData!.wk2C ?? "0.00");
      double wk2Def = ltp - wk2c;
      _techData!.wk2Pc = ((wk2Def / wk2c) * 100).toStringAsFixed(2);

      _returnsGridview.add({
        "duration": "Two Week",
        "low": "${_techData!.wk2L}",
        "high": "${_techData!.wk2H}",
        "percent":
            _techData!.wk2Pc == "Infinity" ? "0.00" : "${_techData!.wk2Pc}",
        "ltp": lastPrc
      });
      double mnth1c = double.parse(_techData!.mnth1C ?? "0.00");
      double mnth1Def = ltp - mnth1c;
      _techData!.mnth1Pc = ((mnth1Def / mnth1c) * 100).toStringAsFixed(2);

      _returnsGridview.add({
        "duration": "One Month",
        "low": "${_techData!.mnth1L}",
        "high": "${_techData!.mnth1H}",
        "percent":
            _techData!.mnth1Pc == "Infinity" ? "0.00" : "${_techData!.mnth1Pc}",
        "ltp": lastPrc
      });
      double mnth3c = double.parse(_techData!.mnth3C ?? "0.00");
      double mnth3Def = ltp - mnth3c;
      _techData!.mnth3Pc = ((mnth3Def / mnth3c) * 100).toStringAsFixed(2);

      _returnsGridview.add({
        "duration": "Three Month",
        "low": "${_techData!.mnth3L}",
        "high": "${_techData!.mnth3H}",
        "percent":
            _techData!.mnth3Pc == "Infinity" ? "0.00" : "${_techData!.mnth3Pc}",
        "ltp": lastPrc
      });
      double wk52c = double.parse(_techData!.wk52C ?? "0.00");
      double wk52Def = ltp - wk52c;
      _techData!.wk52Pc = ((wk52Def / wk52c) * 100).toStringAsFixed(2);

      _returnsGridview.add({
        "duration": "52 Week",
        "low": "${_techData!.wk52L}",
        "high": "${_techData!.wk52H}",
        "percent":
            _techData!.wk52Pc == "Infinity" ? "0.00" : "${_techData!.wk52Pc}",
        "ltp": lastPrc
      });
    }
  }

  // Seprating option chain scrips (Call / Put)
  Future<void> splitOptionChain(BuildContext context, double strPrc) async {
    _optChainCall.clear();
    _optChainPut.clear();
    _optChainCallDown.clear();
    _optChainCallUp.clear();
    _optChainPutDown.clear();
    _optChainPutUp.clear();
// Seperating Trade symbol(symbol,exp date, Option)
    final List<OptionValues>? opt = _optionChainModel!.optValue;
    for (var el in List<OptionValues>.from(opt!)) {
      String complementType = el.optt == 'PE' ? 'CE' : 'PE';

      bool exists = opt.any((item) =>
          item.optt == complementType &&
          num.parse(item.strprc.toString()) == num.parse(el.strprc.toString()));

      if (!exists) {
        _optionChainModel!.optValue!.add(OptionValues(
          exch: el.exch,
          token: "${el.token}${el.token}",
          tsym: "|||",
          optt: complementType,
          pp: el.pp,
          ls: el.ls,
          ti: el.ti,
          strprc: el.strprc,
        ));
      }
    }

    _optionChainModel!.optValue!.sort((a, b) {
      return num.parse(a.strprc.toString())
          .compareTo(num.parse(b.strprc.toString()));
    });

    for (var element in _optionChainModel!.optValue!) {
      Map spilitSymbol = spilitTsym(value: "${element.tsym}");

      element.symbol = "${spilitSymbol["symbol"]}";
      element.expDate = "${spilitSymbol["expDate"]}";
      element.option = "${spilitSymbol["option"]}";
      if (element.optt == "CE") {
        _optChainCall.add(element);
        // int callLength = _optChainCall.length ~/ 2;
        if (strPrc < double.parse(element.strprc.toString())) {
          _optChainCallDown.add(element);
        } else {
          _optChainCallUp.add(element);
        }
      } else {
        _optChainPut.add(element);
        // int putLength = _optChainPut.length ~/ 2;
        if (strPrc < double.parse(element.strprc.toString())) {
          _optChainPutDown.add(element);
        } else {
          _optChainPutUp.add(element);
        }
      }
    }

    // Debug: Print socket data after option chain processing
    final socketDatas = ref.read(websocketProvider).socketDatas;

    // Print sample option chain tokens and their socket data
    if (_optionChainModel?.optValue != null &&
        _optionChainModel!.optValue!.isNotEmpty) {
      for (int i = 0; i < min(5, _optionChainModel!.optValue!.length); i++) {
        final option = _optionChainModel!.optValue![i];
        final token = option.token;
        if (socketDatas.containsKey(token)) {
          final data = socketDatas[token];
        }
      }
    }

    notifyListeners();
    await requestWSOptChain(context: context, isSubscribe: true);
  }

// websocket Connection Request for Option chain list

  Future<void> requestWSOptChain(
      {required bool isSubscribe, required BuildContext context}) async {
    // Collect option chain tokens
    final Set<String> optionTokens = {};
    if (_optionChainModel != null) {
      if (_optionChainModel!.optValue != null) {
        for (var element in _optionChainModel!.optValue!) {
          if (element.exch != null && element.token != null) {
            optionTokens.add("${element.exch}|${element.token}");
          }
        }
      }
    }


    if (optionTokens.isEmpty) {
      return;
    }

    if (kIsWeb) {
      if (!isSubscribe) {
        // On web, use WebSubscriptionManager to smart-unsubscribe
        // This protects symbols used by watchlist, depth, futures, etc.
        await ref.read(webSubscriptionManagerProvider).unsubscribeTokens(
          tokensToCheck: optionTokens,
          context: context,
          source: 'optionChain',
        );
      } else {
        // Subscribe using depth task for web
        final input = optionTokens.join('#');
        await ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: "d",
            context: context);
      }
    } else {
      // Mobile: use original logic
      final input = optionTokens.join('#');
      await ref.read(websocketProvider).establishConnection(
          channelInput: input,
          task: isSubscribe ? "t" : "u",
          context: context);
    }
  }

// websocket Connection Request for Future list
  Future<void> requestWSFut({required bool isSubscribe, required BuildContext context}) async {
    // Collect futures tokens
    final Set<String> futuresTokens = {};
    if (_fut != null && _fut!.isNotEmpty) {
      for (var element in _fut!) {
        if (element.exch != null && element.token != null) {
          futuresTokens.add("${element.exch}|${element.token}");
        }
      }
    }

    notifyListeners();

    if (futuresTokens.isEmpty) return;

    if (kIsWeb) {
      if (!isSubscribe) {
        // On web, use WebSubscriptionManager to smart-unsubscribe
        // This protects symbols used by watchlist, depth, option chain, etc.
        await ref.read(webSubscriptionManagerProvider).unsubscribeTokens(
          tokensToCheck: futuresTokens,
          context: context,
          source: 'futures',
        );
      } else {
        // Subscribe using depth task for web
        final input = futuresTokens.join('#');
        await ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: "d",
            context: context);
      }
    } else {
      // Mobile: use original logic
      final input = futuresTokens.join('#');
      ref.read(websocketProvider).establishConnection(
          channelInput: input,
          task: isSubscribe ? "t" : "u",
          context: context);
    }
  }

  marketWatchScripSearch(String value) {
    if (value.length > 1) {
      _searchMWLScrip = [];
      Fluttertoast.cancel();
      _searchMWLScrip = _watchListValues
          .where((element) => element.tsym!.toLowerCase().contains(value))
          .toList();
      if (_searchMWLScrip.isEmpty) {}
    } else {
      _searchMWLScrip = [];
    }
    notifyListeners();
  }

//  REWORK TO CHANGE FLOW =========

// Swipe or Change to watchlist

  changeWLScrip(String wName, BuildContext context) async {
    try {

      // Clear current scrips first to ensure clean state
      _scrips.clear();

      // Check if this is a pending watchlist (not yet synced to API)
      if (_pendingWatchlists.contains(wName)) {
        // Don't subscribe to WebSocket for pending watchlists
        await requestMWScrip(context: context, isSubscribe: false);
        notifyListeners();
        return;
      }

      // Special handling for predefined watchlists
      bool isPredefined =
          (wName == "Nifty50" || wName == "Niftybank" || wName == "Sensex");

      // Check if we have cached data for this watchlist
      bool wlis = _marketWatchScripData.containsKey(wName);

      if (isPredefined) {
        if (wlis) {
          _scrips = jsonDecode(_marketWatchScripData[wName]) ?? [];

          // If the data is empty for some reason, use preDefinedMWlist if available
          if (_scrips.isEmpty) {
            // Only fetch if preDefinedMWlist doesn't have data for this watchlist
            bool needsFetch = false;
            if (wName == "Nifty50" && (_preDefinedMWlist?.nIFTY50NSE == null || _preDefinedMWlist!.nIFTY50NSE!.isEmpty)) {
              needsFetch = true;
            } else if (wName == "Niftybank" && (_preDefinedMWlist?.nIFTYBANKNSE == null || _preDefinedMWlist!.nIFTYBANKNSE!.isEmpty)) {
              needsFetch = true;
            } else if (wName == "Sensex" && (_preDefinedMWlist?.sENSEXBSE == null || _preDefinedMWlist!.sENSEXBSE!.isEmpty)) {
              needsFetch = true;
            }

            if (needsFetch) {
              await fetchPreDefMWScrip(context);
            }

            if (wName == "Nifty50") {
              _scrips =
                  jsonDecode(jsonEncode(_preDefinedMWlist?.nIFTY50NSE ?? []));
            } else if (wName == "Niftybank") {
              _scrips =
                  jsonDecode(jsonEncode(_preDefinedMWlist?.nIFTYBANKNSE ?? []));
            } else if (wName == "Sensex") {
              _scrips =
                  jsonDecode(jsonEncode(_preDefinedMWlist?.sENSEXBSE ?? []));
            }
          }
        } else {
          // Check if preDefinedMWlist already has data for this watchlist
          bool needsFetch = false;
          if (wName == "Nifty50" && (_preDefinedMWlist?.nIFTY50NSE == null || _preDefinedMWlist!.nIFTY50NSE!.isEmpty)) {
            needsFetch = true;
          } else if (wName == "Niftybank" && (_preDefinedMWlist?.nIFTYBANKNSE == null || _preDefinedMWlist!.nIFTYBANKNSE!.isEmpty)) {
            needsFetch = true;
          } else if (wName == "Sensex" && (_preDefinedMWlist?.sENSEXBSE == null || _preDefinedMWlist!.sENSEXBSE!.isEmpty)) {
            needsFetch = true;
          }

          if (needsFetch) {
            await fetchPreDefMWScrip(context);
          }

          if (wName == "Nifty50") {
            _scrips =
                jsonDecode(jsonEncode(_preDefinedMWlist?.nIFTY50NSE ?? []));
          } else if (wName == "Niftybank") {
            _scrips =
                jsonDecode(jsonEncode(_preDefinedMWlist?.nIFTYBANKNSE ?? []));
          } else if (wName == "Sensex") {
            _scrips =
                jsonDecode(jsonEncode(_preDefinedMWlist?.sENSEXBSE ?? []));
          }
        }
      } else if (wName == "My Stocks") {
        // My Stocks is handled specially through portfolio
        _scrips = [];
      } else if (wName == "My Positions") {
        // My Positions is handled specially through portfolio
        _scrips = [];
      } else {
        // Regular watchlists
        _scrips = wlis ? jsonDecode(_marketWatchScripData[wName]) ?? [] : [];
      }

      // Log the number of symbols for debugging

      // Apply sorting if there's a saved sort preference and if there are scrips to sort
      // if (_scrips.isNotEmpty && _sortByWL.isNotEmpty) {
      //   _applySavedSorting();
      // }

      // Handle portfolio holdings/positions data
      if (wName == "My Stocks") {
        // Portfolio holdings need different subscription handling
        await ref
            .read(portfolioProvider)
            .requestWSHoldings(context: context, isSubscribe: true);
      } else if (wName == "My Positions") {
        // Fetch position book if not already loaded, then subscribe to WS
        final portfolio = ref.read(portfolioProvider);
        if (portfolio.postionBookModel == null || portfolio.postionBookModel!.isEmpty) {
          await portfolio.fetchPositionBook(context, portfolio.isDay);
        }
        await portfolio.requestWSPosition(context: context, isSubscribe: true);
      } else {
        // Standard watchlist - subscribe to the scrips
        if (_scrips.isNotEmpty) {
          await requestMWScrip(context: context, isSubscribe: true);
        } else {
          // If no symbols in watchlist, still ensure we're unsubscribed from previous
          await requestMWScrip(context: context, isSubscribe: false);
        }
      }
    } catch (e) {
    }

    notifyListeners();
  }

// Delete market scrips by watchlist name
  Future<void> deleteWatchList(String walName, BuildContext context) async {
    // Calculate how many user watchlists exist (excluding predefined)
    final userWatchlistCount = _marketWatchlist!.values!
        .where((wl) => !_preDefWL.contains(wl))
        .length;

    // Check if this is the last user watchlist
    if (userWatchlistCount == 1 && !_preDefWL.contains(walName)) {
      if (kIsWeb) {
        ResponsiveSnackBar.showError(context, "Cannot delete the last watchlist");
      } else {
        error(context, "Cannot delete the last watchlist");
      }
      return;
    }

    // Check if this is a pending watchlist (created locally but not yet synced)
    if (_pendingWatchlists.contains(walName)) {
      // Just remove from pending list and local state, no API call needed
      _pendingWatchlists.remove(walName);
      await _savePendingWatchlists();

      // Remove from marketWatchlist
      if (_marketWatchlist != null && _marketWatchlist!.values != null) {
        final updatedValues = List<String>.from(_marketWatchlist!.values!);
        updatedValues.remove(walName);

        _marketWatchlist = MarketWatchlist(
          requestTime: _marketWatchlist!.requestTime,
          stat: _marketWatchlist!.stat,
          values: updatedValues,
          emsg: _marketWatchlist!.emsg,
        );
      }

      // Switch to first watchlist if deleted was active
      if (walName == _wlName && _marketWatchlist!.values!.isNotEmpty) {
        String newActiveWatchlist = _marketWatchlist!.values!.first;
        _wlName = newActiveWatchlist;
        _isPreDefWLs = _preDefWL.contains(newActiveWatchlist) ? "Yes" : "No";
        setCurrentWatchlistPageIndex(0);
        await changeWLScrip(newActiveWatchlist, context);
      }

      if (kIsWeb) {
        ResponsiveSnackBar.showSuccess(context, "Watchlist deleted successfully");
      } else {
        successMessage(context, "Watchlist deleted successfully");
      }
      notifyListeners();
      return;
    }

    // Normal flow for synced watchlists
    String input = "";

    // Get the scrips for this watchlist, even if it's not the active one
    List scripList = [];
    if (_marketWatchScripData.containsKey(walName)) {
      scripList = jsonDecode(_marketWatchScripData[walName]) ?? [];
    }

    // Build the input string for deletion
    for (var element in scripList) {
      input += "${element['exch']}|${element['token']}#";
    }

    try {
      toggleLoadingOn(true);
      _addDeleteScripModel = await api.getAddDeleteSciptoMW(
          isAdd: false, scripToken: input, wlname: walName);

      if (_addDeleteScripModel!.stat!.toUpperCase() == "OK") {
        // Store if deleted watchlist was the active one
        bool wasActiveWatchlist = (walName == _wlName);

        // Clean up cached data for deleted watchlist
        _marketWatchScripData.remove(walName);

        // If the deleted watchlist is the active one, unsubscribe first
        if (wasActiveWatchlist) {
          // Clear scrips immediately to prevent showing deleted watchlist data
          _scrips = [];
          // Unsubscribe from websocket for deleted watchlist scrips
          await requestMWScrip(context: context, isSubscribe: false);
        }

        // Refresh the watchlist data
        await fetchMWList(context, false, true);

        // If we deleted the active watchlist, switch to the first available one
        if (wasActiveWatchlist &&
            _marketWatchlist != null &&
            _marketWatchlist!.values!.isNotEmpty) {
          String newActiveWatchlist = _marketWatchlist!.values!.first;
          _wlName = newActiveWatchlist;
          _isPreDefWLs = _preDefWL.contains(newActiveWatchlist) ? "Yes" : "No";
          setCurrentWatchlistPageIndex(0);
          // Load data for the new active watchlist
          await changeWLScrip(newActiveWatchlist, context);
        }

        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Watchlist deleted successfully");
        } else {
          successMessage(context, "Watchlist deleted successfully");
        }
        // Update UI to reflect changes
        notifyListeners();
      } else if (_addDeleteScripModel!.emsg ==
              "Session Expired :  Invalid Session Key" &&
          _addDeleteScripModel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        if (kIsWeb) {
          ResponsiveSnackBar.showError(context, "Failed to delete watchlist");
        } else {
          error(context, "Failed to delete watchlist");
        }
      }
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
      notifyListeners();
    }
  }

// Add market scrips by watchlist name
  addWatchList(String wlName, BuildContext context) async {
    // Validate watchlist name using centralized validation
    final validationError = validateWatchlistName(wlName);
    if (validationError != null) {
      if (kIsWeb) {
        ResponsiveSnackBar.showError(context, validationError);
      } else {
        error(context, validationError);
      }
      return;
    }

    // Use trimmed name
    wlName = wlName.trim();

    // Store watchlist locally instead of calling API
    // API will be called when user adds the first scrip
    _pendingWatchlists.add(wlName);
    await _savePendingWatchlists(); // Persist to storage

    // Add to the existing marketWatchlist for UI display
    if (_marketWatchlist != null && _marketWatchlist!.values != null) {
      // Filter out predefined watchlists first
      final updatedValues = _marketWatchlist!.values!
          .where((wl) => !_preDefWL.contains(wl))
          .toList();

      // Add the new watchlist
      updatedValues.add(wlName);

      // Sort only user watchlists
      updatedValues.sort((a, b) => a.compareTo(b));

      // If "My Positions" exists, insert at front
      final preDefToAdd = List<String>.from(_preDefWL);
      if (preDefToAdd.contains("My Positions")) {
        preDefToAdd.remove("My Positions");
        updatedValues.insert(0, "My Positions");
      }

      // Add remaining predefined watchlists back at the end
      updatedValues.addAll(preDefToAdd);

      _marketWatchlist = MarketWatchlist(
        requestTime: _marketWatchlist!.requestTime,
        stat: _marketWatchlist!.stat,
        values: updatedValues,
        emsg: _marketWatchlist!.emsg,
      );

    }

    // Set as current watchlist
    _wlName = wlName;
    // IMPORTANT: Mark as custom watchlist (not predefined)
    _isPreDefWLs = "No";

    // Initialize empty scrip list for this watchlist
    _scrips = [];
    _watchListValues = [];

    // Find the index and set as current
    if (_marketWatchlist != null && _marketWatchlist!.values != null) {
      final newWatchlistIndex = _marketWatchlist!.values!.indexOf(wlName);
      if (newWatchlistIndex != -1) {
        setCurrentWatchlistPageIndex(newWatchlistIndex);
      }
      if (kIsWeb) {
        ResponsiveSnackBar.showSuccess(context, "Watchlist created successfully");
      } else {
        successMessage(context, "Watchlist created successfully");
      }
    }

    notifyListeners();
  }

  Future<bool> addDelMarketScrip(
      String wlName,
      String scripTok,
      BuildContext context,
      bool isAdd,
      bool isEdit,
      bool isReOrder,
      bool isOptionStike,
      {bool showSnackBar = true}) async {
    try {
      // Check if this is a pending watchlist (created locally without API call)
      bool wasPending = false;
      if (isAdd && _pendingWatchlists.contains(wlName)) {
        wasPending = true;
        // This is the first scrip being added to a pending watchlist
        // Create the watchlist via API with this scrip
        _addDeleteScripModel = await api.getAddDeleteSciptoMW(
            isAdd: true, scripToken: scripTok, wlname: wlName);

        if (_addDeleteScripModel!.stat!.toUpperCase() == "OK") {
          // Successfully created watchlist with scrip, remove from pending
          _pendingWatchlists.remove(wlName);
          await _savePendingWatchlists(); // Persist the change
          // Refresh the entire watchlist to sync with API
          await fetchMWList(context, false, true);

          // After fetchMWList, update the page index to point to the correct watchlist
          if (_marketWatchlist != null && _marketWatchlist!.values != null) {
            final newIndex = _marketWatchlist!.values!.indexOf(wlName);
            if (newIndex != -1) {
              setCurrentWatchlistPageIndex(newIndex);
              _wlName = wlName; // Ensure current watchlist name is set
            }
          }

          // Fetch the scrip data for the newly created watchlist
          await fetchMWScrip(wlName, context);

          // For pending watchlists, we need to call changeWLScrip here
          // to update the UI immediately after syncing
          await changeWLScrip(wlName, context);

          // Return early since we've handled everything for pending watchlists
          return true;
        }
      } else {
        // Normal flow for existing watchlists
        _addDeleteScripModel = await api.getAddDeleteSciptoMW(
            isAdd: isAdd, scripToken: scripTok, wlname: wlName);
      }

      if (_addDeleteScripModel!.stat!.toUpperCase() == "OK") {
        ConstantName.sessCheck = true;
        if (!isReOrder) {
          // Reset sorting when adding/deleting scrips (but not for reordering)
          if (isAdd) {
            await _resetSortPreference();
          }
          await fetchMWScrip(wlName, context);
          await changeWLScrip(wlName, context);
        } else if (showSnackBar) {
          // Wrap ScaffoldMessenger calls in try-catch to handle disposed widgets
          try {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (kIsWeb) {
              ResponsiveSnackBar.showSuccess(context, "Stocks reordered successfully.");
            } else {
              successMessage(context, "Stocks reordered successfully.");
            }
          } catch (e) {
            if (e.toString().contains("widget was disposed") ||
                e.toString().contains("after the widget was disposed")) {
            }
          }
        }
        if (!isEdit) {
          // Wrap ScaffoldMessenger calls in try-catch to handle disposed widgets
          try {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (kIsWeb) {
              ResponsiveSnackBar.showSuccess(
                  context,
                  isAdd
                      ? 'Stock added to your watchlist "$wlName"'
                      : 'Stock removed from your watchlist "$wlName"');
            } else {
              successMessage(
                  context,
                  isAdd
                      ? 'Stock added to your watchlist "$wlName"'
                      : 'Stock removed from your watchlist "$wlName"');
            }
          } catch (e) {
            if (e.toString().contains("widget was disposed") ||
                e.toString().contains("after the widget was disposed")) {
            }
          }
        }
        if (isEdit && isOptionStike) {
          try {
            Fluttertoast.showToast(
                msg: 'Stock added to your watchlist "$wlName"',
                timeInSecForIosWeb: 2,
                backgroundColor: colors.colorBlack,
                textColor: colors.colorWhite,
                fontSize: 14.0);
          } catch (e) {
          }
        }
        return true;
      } else if (_addDeleteScripModel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        try {
          ref.read(authProvider).ifSessionExpired(context);
        } catch (e) {
        }
      } else if (_addDeleteScripModel!.emsg ==
          "Invalid Input : At least one stock must remain in the Market Watch.") {
        // Backend `emsg` above is left untouched — it's the exact vendor
        // error string we're matching against. User-facing toast below uses
        // friendlier wording per the test-case feedback (TC_17).
        // _delScripQty = 1;
        if (kIsWeb) {
          ResponsiveSnackBar.showError(
              context, "You need at least one stock in your watchlist");
        } else {
          error(context, "You need at least one stock in your watchlist");
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Track old watchlist symbols for proper unsubscription on web
  Set<String> _previousWatchlistSymbols = {};

// websocket Connection Request for Market watch scrip
  requestMWScrip(
      {required bool isSubscribe, required BuildContext context}) async {
    // On web, handle watchlist tab switching via WebSubscriptionManager
    if (kIsWeb) {
      if (!isSubscribe) {
        // When unsubscribing (before watchlist change), save current symbols
        // These will be compared with new symbols when subscribing
        _previousWatchlistSymbols.clear();
        for (var element in _scrips) {
          final exch = element['exch']?.toString() ?? '';
          final token = element['token']?.toString() ?? '';
          if (exch.isNotEmpty && token.isNotEmpty) {
            _previousWatchlistSymbols.add('$exch|$token');
          }
        }
        return;
      }

      // When subscribing on web, use WebSubscriptionManager to handle proper unsubscription
      // of old symbols and subscription of new symbols
      try {
        final newSymbols = <String>{};
        for (var element in _scrips) {
          final exch = element['exch']?.toString() ?? '';
          final token = element['token']?.toString() ?? '';
          if (exch.isNotEmpty && token.isNotEmpty) {
            newSymbols.add('$exch|$token');
          }
        }

        // Also add index tokens
        final indexProvider = ref.read(indexListProvider);
        await indexProvider.requestdefaultIndex();
        final indexToken = indexProvider.indexToken;
        if (indexToken.isNotEmpty) {
          final tokens = indexToken.split('#').where((t) => t.isNotEmpty && t.trim().isNotEmpty);
          newSymbols.addAll(tokens);
        }

        indexProvider.requestTopIndicesToken();
        final topIndicesToken = indexProvider.topIndicesToken;
        if (topIndicesToken.isNotEmpty) {
          final tokens = topIndicesToken.split('#').where((t) => t.isNotEmpty && t.trim().isNotEmpty);
          newSymbols.addAll(tokens);
        }


        // Use WebSubscriptionManager to properly handle the subscription change
        await ref.read(webSubscriptionManagerProvider).updateWatchlistSubscriptions(
          oldSymbols: _previousWatchlistSymbols,
          newSymbols: newSymbols,
          context: context,
        );

        // Clear the previous symbols after processing
        _previousWatchlistSymbols.clear();
        return;
      } catch (e) {
        // Fall through to legacy behavior if something fails
      }
    }

    try {
      toggleLoadingOn(true);
      String input = "";
      _delScripQty = 0;

      // Get index tokens first for market indices
      await ref.read(indexListProvider).requestdefaultIndex();
      if (ref.read(indexListProvider).indexToken.isNotEmpty) {
        input = ref.read(indexListProvider).indexToken;
      }

      // Also add top indices token for dashboard if available
      ref.read(indexListProvider).requestTopIndicesToken();
      final topIndicesToken = ref.read(indexListProvider).topIndicesToken;
      if (topIndicesToken.isNotEmpty) {
        input += topIndicesToken;
      }

      // Save the current scrips count before processing
      final int initialScripsCount = _scrips.length;

      // Special handling for predefined watchlists
      bool isPredefined =
          _wlName == "Nifty50" || _wlName == "Niftybank" || _wlName == "Sensex";

      // Add all scrips from current watchlist to the subscription
      if (_scrips.isNotEmpty) {
        for (var element in _scrips) {
          element['isSelected'] = false;
          input += "${element['exch']}|${element['token']}#";
        }
      } else if (isPredefined && isSubscribe) {
        // If predefined watchlist has no data but we're subscribing, try to use cached data
        if (_marketWatchScripData.containsKey(_wlName)) {
          List cachedData = jsonDecode(_marketWatchScripData[_wlName]) ?? [];
          if (cachedData.isNotEmpty) {
            _scrips = cachedData;
            for (var element in _scrips) {
              element['isSelected'] = false;
              input += "${element['exch']}|${element['token']}#";
            }
          }
        }

        // If still no data, try to use preDefinedMWlist if available
        if (_scrips.isEmpty) {
          // First check if we already have preDefinedMWlist data for this watchlist
          bool hasDataForWatchlist = false;
          if (_wlName == "Nifty50" && (_preDefinedMWlist?.nIFTY50NSE?.isNotEmpty ?? false)) {
            hasDataForWatchlist = true;
          } else if (_wlName == "Niftybank" && (_preDefinedMWlist?.nIFTYBANKNSE?.isNotEmpty ?? false)) {
            hasDataForWatchlist = true;
          } else if (_wlName == "Sensex" && (_preDefinedMWlist?.sENSEXBSE?.isNotEmpty ?? false)) {
            hasDataForWatchlist = true;
          }

          // Only fetch if we don't have data for this watchlist
          if (!hasDataForWatchlist) {
            await fetchPreDefMWScrip(context);
          }

          // Now try to use the loaded data
          if (_wlName == "Nifty50" && _preDefinedMWlist?.nIFTY50NSE != null) {
            _scrips = jsonDecode(jsonEncode(_preDefinedMWlist!.nIFTY50NSE!));
          } else if (_wlName == "Niftybank" &&
              _preDefinedMWlist?.nIFTYBANKNSE != null) {
            _scrips = jsonDecode(jsonEncode(_preDefinedMWlist!.nIFTYBANKNSE!));
          } else if (_wlName == "Sensex" &&
              _preDefinedMWlist?.sENSEXBSE != null) {
            _scrips = jsonDecode(jsonEncode(_preDefinedMWlist!.sENSEXBSE!));
          }

          // Add the newly loaded symbols to the subscription
          if (_scrips.isNotEmpty) {
            for (var element in _scrips) {
              element['isSelected'] = false;
              input += "${element['exch']}|${element['token']}#";
            }
          }
        }
      }

      // Only attempt subscription if we have valid tokens
      if (input.isNotEmpty) {
        await ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? (kIsWeb ? "d" : "t") : "u",
            context: context);

        // For predefined watchlists, ensure data wasn't accidentally cleared during subscription
        if (isPredefined &&
            isSubscribe &&
            initialScripsCount > 0 &&
            _scrips.isEmpty) {

          // Restore data from cache
          if (_marketWatchScripData.containsKey(_wlName)) {
            _scrips = jsonDecode(_marketWatchScripData[_wlName]) ?? [];
          }
        }
      }
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

  // Sort preference management
  getSortByWL(String val) async {
    _sortByWL = val;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("sortByWL", val);
    } catch (e) {
    }
    notifyListeners();
  }

  // Sorting alert list
  filterPendingAlert(String sorting) {
    if (sorting == "ASC") {
      _alertPendingModel!.sort((a, b) => a.tsym!.compareTo(b.tsym!));
    } else if (sorting == "DSC") {
      _alertPendingModel!.sort((a, b) => b.tsym!.compareTo(a.tsym!));
    } else if (sorting == "LTPDSC") {
      _alertPendingModel!.sort((a, b) {
        return double.parse(b.ltp ?? "0.00")
            .compareTo(double.parse(a.ltp ?? "0.00"));
      });
    } else if (sorting == "LTPASC") {
      _alertPendingModel!.sort((a, b) {
        return double.parse(a.ltp ?? "0.00")
            .compareTo(double.parse(b.ltp ?? "0.00"));
      });
    } else if (sorting == "ALERTVALUEDSC") {
      _alertPendingModel!.sort((a, b) {
        return double.parse(b.d ?? "0.00")
            .compareTo(double.parse(a.d ?? "0.00"));
      });
    } else if (sorting == "ALERTVALUEASC") {
      _alertPendingModel!.sort((a, b) {
        return double.parse(a.d ?? "0.00")
            .compareTo(double.parse(b.d ?? "0.00"));
      });
    } else if (sorting == "CHANGEASC") {
      _alertPendingModel!.sort((a, b) {
        final aChange = double.tryParse(a.change ?? '0.0') ?? 0.0;
        final bChange = double.tryParse(b.change ?? '0.0') ?? 0.0;
        return aChange.compareTo(bChange);
      });
    } else if (sorting == "CHANGEDSC") {
      _alertPendingModel!.sort((a, b) {
        final bChange = double.tryParse(b.change ?? '0.0') ?? 0.0;
        final aChange = double.tryParse(a.change ?? '0.0') ?? 0.0;
        return bChange.compareTo(aChange);
      });
    }
    notifyListeners();
  }

  // Sorting market watch scrip by trade symbol
  filterMWScrip(
      {required String sorting,
      required String wlName,
      required BuildContext context}) {

    // If no scrips to sort, exit early
    if (_scrips.isEmpty) {
      return;
    }

    // Store the current sort option immediately in the provider state
    _sortByWL = sorting;

    // Save to persistent storage in the background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString("sortByWL", sorting);
    }).catchError((e) {
    });

    // Log sample data before sorting
    if (_scrips.isNotEmpty) {
    }

    // Make sure we have fresh data before sorting
    syncSocketDataToModel();

    // Create a copy to preserve original objects
    final List<dynamic> tempScrips = List<dynamic>.from(_scrips);

    // Apply sorting based on requested type
    switch (sorting) {
      case "Scrip - Z to A":
        tempScrips.sort((a, b) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return bSymbol.compareTo(aSymbol);
        });
        break;

      case "Scrip - A to Z":
        tempScrips.sort((a, b) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return aSymbol.compareTo(bSymbol);
        });
        break;

      case "Price - Low to High":
        tempScrips.sort((a, b) {
          // Use the helper method for numeric values
          double aPrice = _parseNumericValue(a['ltp']);
          double bPrice = _parseNumericValue(b['ltp']);

          // If values are equal, use symbol as secondary sort
          if (aPrice == bPrice) {
            String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
            String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
            return aSymbol.compareTo(bSymbol);
          }

          return aPrice.compareTo(bPrice);
        });
        break;

      case "Price - High to Low":
        tempScrips.sort((a, b) {
          // Use the helper method for numeric values
          double aPrice = _parseNumericValue(a['ltp']);
          double bPrice = _parseNumericValue(b['ltp']);

          // If values are equal, use symbol as secondary sort
          if (aPrice == bPrice) {
            String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
            String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
            return aSymbol.compareTo(bSymbol);
          }

          return bPrice.compareTo(aPrice);
        });
        break;

      case "Per.Chng - High to Low":
        tempScrips.sort((a, b) {
          // Use the helper method for numeric values
          double aChange = _parseNumericValue(a['perChange']);
          double bChange = _parseNumericValue(b['perChange']);

          // If values are equal, use symbol as secondary sort
          if (aChange == bChange) {
            String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
            String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
            return aSymbol.compareTo(bSymbol);
          }

          return bChange.compareTo(aChange);
        });
        break;

      case "Per.Chng - Low to High":
        tempScrips.sort((a, b) {
          // Use the helper method for numeric values
          double aChange = _parseNumericValue(a['perChange']);
          double bChange = _parseNumericValue(b['perChange']);

          // If values are equal, use symbol as secondary sort
          if (aChange == bChange) {
            String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
            String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
            return aSymbol.compareTo(bSymbol);
          }

          return aChange.compareTo(bChange);
        });
        break;
    }

    // Log sample data after sorting
    if (tempScrips.isNotEmpty) {
    }

    // Update the list with the sorted data
    _scrips = tempScrips;

    // Force UI update
    notifyListeners();

    // Update the backend in the background. Pass an action-specific toast
    // message so the user sees what they actually did (e.g. "Sorted by name
    // (A-Z)") instead of a generic "Stock order was changed" — clearer UX
    // and distinguishes a sort from a drag-drop reorder.
    _updateBackendSortOrderNonBlocking(
      wlName,
      context,
      toastMessage: _sortToastMessage(sorting),
    );
  }

  // Maps a sort key (as stored in _sortByWL) to a human-friendly toast
  // message. Returns the generic "Stock order was changed" for any unknown
  // value (defensive — keeps drag-drop and any other reorder paths working).
  String _sortToastMessage(String sortKey) {
    switch (sortKey) {
      case "Scrip - A to Z":
        return "Sorted by name (A-Z)";
      case "Scrip - Z to A":
        return "Sorted by name (Z-A)";
      case "Price - Low to High":
        return "Sorted by price (Low to High)";
      case "Price - High to Low":
        return "Sorted by price (High to Low)";
      case "Per.Chng - High to Low":
        return "Sorted by % change (High to Low)";
      case "Per.Chng - Low to High":
        return "Sorted by % change (Low to High)";
      default:
        return "Stock order was changed";
    }
  }

  // Non-blocking backend update to avoid UI stutters
  void _updateBackendSortOrderNonBlocking(String wlName, BuildContext context,
      {String toastMessage = "Stock order was changed"}) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _updateBackendSortOrder(wlName, context, toastMessage: toastMessage);
    });
  }

  // Helper method to safely parse numeric values from various formats
  double _parseNumericValue(dynamic value) {
    if (value == null) return 0.0;

    // If value is already a number, return it directly
    if (value is num) return value.toDouble();

    // Convert to string for safe parsing
    String strValue = value.toString().trim();

    // Handle empty strings
    if (strValue.isEmpty) return 0.0;

    // Remove any currency symbols, commas, or other non-numeric characters
    strValue = strValue.replaceAll(RegExp(r'[₹,%]'), '').trim();

    try {
      return double.parse(strValue);
    } catch (e) {
      return 0.0;
    }
  }

  // Helper method to update the backend without blocking UI.
  // Uses the dedicated ReorderMWScrips endpoint — a single atomic call that
  // takes the full ordered list and updates positions on the backend.
  // Replaces the older delete-all + add-all flow that always tripped the
  // "at least 1 stock must remain" rule on the delete step.
  void _updateBackendSortOrder(String wlName, BuildContext context,
      {String toastMessage = "Stock order was changed"}) {
    // Use a longer delay to ensure UI has fully updated before backend operations
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        // Build a single string with all tokens in the current sort order
        final String scripTokens = _scrips
            .map((scrip) => "${scrip['exch']}|${scrip['token']}")
            .join("#");

        if (scripTokens.isEmpty) {
          return;
        }

        await api.getReorderMWScrips(
          wlname: wlName,
          scripToken: "$scripTokens#",
        );

        // Sync the local scrip-data cache with the new order. Without this,
        // any later changeWLScrip / restoreFromCache call (e.g. after a
        // browser tab return triggers the WS reconnect resubscribe chain)
        // would re-hydrate _scrips from the stale cached JSON and silently
        // revert the order.
        _marketWatchScripData[wlName] = jsonEncode(_scrips);

        // Toast wording is set by the caller — sort actions get an
        // action-specific message (e.g. "Sorted by name (A-Z)"), while
        // drag-drop reorder uses the default "Stock order was changed".
        if (context.mounted) {
          try {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (kIsWeb) {
              ResponsiveSnackBar.showSuccess(context, toastMessage);
            } else {
              successMessage(context, toastMessage);
            }
          } catch (_) {
            // Widget may have been disposed during the delay — ignore.
          }
        }
      } catch (e) {
        // Silently handle errors in the background operation
      }
    });
  }

  // Improved sorting logic with reset to ensure clean sort operations
  void _sortScrips(String sorting) {
    // Ensure we have fresh data before sorting
    syncSocketDataToModel();

    // Reset any previous sort flags in data
    for (var scrip in _scrips) {
      scrip.remove('_sortRank');
    }

    // Apply the requested sort
    if (sorting == "Scrip - Z to A") {
      _scrips.sort((a, b) {
        String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
        String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
        return bSymbol.compareTo(aSymbol);
      });
    } else if (sorting == "Scrip - A to Z") {
      _scrips.sort((a, b) {
        String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
        String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
        return aSymbol.compareTo(bSymbol);
      });
    } else if (sorting == "Price - Low to High") {
      // First, normalize the LTP values and add a sort rank
      for (int i = 0; i < _scrips.length; i++) {
        double ltp = _parseTradingDouble(_scrips[i]['ltp']);
        _scrips[i]['_sortRank'] = ltp;
      }

      _scrips.sort((a, b) {
        double aLtp = a['_sortRank'] as double;
        double bLtp = b['_sortRank'] as double;

        // Special handling for zero and negative values
        // Order: negative values, then zeros, then positive values
        if (aLtp < 0 && bLtp >= 0) return -1;
        if (aLtp >= 0 && bLtp < 0) return 1;
        if (aLtp == 0 && bLtp > 0) return -1;
        if (aLtp > 0 && bLtp == 0) return 1;

        // Normal comparison for values in the same category
        int result = aLtp.compareTo(bLtp);

        // If LTPs are equal, use symbol as tiebreaker
        if (result == 0) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return aSymbol.compareTo(bSymbol);
        }
        return result;
      });
    } else if (sorting == "Price - High to Low") {
      // First, normalize the LTP values and add a sort rank
      for (int i = 0; i < _scrips.length; i++) {
        double ltp = _parseTradingDouble(_scrips[i]['ltp']);
        _scrips[i]['_sortRank'] = ltp;
      }

      _scrips.sort((a, b) {
        double aLtp = a['_sortRank'] as double;
        double bLtp = b['_sortRank'] as double;

        // Special handling for zero and negative values
        // Order: positive values, then zeros, then negative values
        if (aLtp > 0 && bLtp <= 0) return -1;
        if (aLtp <= 0 && bLtp > 0) return 1;
        if (aLtp == 0 && bLtp < 0) return -1;
        if (aLtp < 0 && bLtp == 0) return 1;

        // Normal comparison for values in the same category
        int result = bLtp.compareTo(aLtp);

        // If LTPs are equal, use symbol as tiebreaker
        if (result == 0) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return aSymbol.compareTo(bSymbol);
        }
        return result;
      });
    } else if (sorting == "Per.Chng - High to Low") {
      // First, normalize the percentage change values and add a sort rank
      for (int i = 0; i < _scrips.length; i++) {
        double perChange = _parseTradingDouble(_scrips[i]['perChange']);
        _scrips[i]['_sortRank'] = perChange;
      }

      _scrips.sort((a, b) {
        double aChange = a['_sortRank'] as double;
        double bChange = b['_sortRank'] as double;

        // Special handling for zero values
        if (aChange > 0 && bChange <= 0) return -1;
        if (aChange <= 0 && bChange > 0) return 1;
        if (aChange == 0 && bChange < 0) return -1;
        if (aChange < 0 && bChange == 0) return 1;

        // Normal comparison for values in the same category
        int result = bChange.compareTo(aChange);

        // If percentage changes are equal, use symbol as tiebreaker
        if (result == 0) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return aSymbol.compareTo(bSymbol);
        }
        return result;
      });
    } else if (sorting == "Per.Chng - Low to High") {
      // First, normalize the percentage change values and add a sort rank
      for (int i = 0; i < _scrips.length; i++) {
        double perChange = _parseTradingDouble(_scrips[i]['perChange']);
        _scrips[i]['_sortRank'] = perChange;
      }

      _scrips.sort((a, b) {
        double aChange = a['_sortRank'] as double;
        double bChange = b['_sortRank'] as double;

        // Special handling for zero values
        if (aChange < 0 && bChange >= 0) return -1;
        if (aChange >= 0 && bChange < 0) return 1;
        if (aChange == 0 && bChange > 0) return -1;
        if (aChange > 0 && bChange == 0) return 1;

        // Normal comparison for values in the same category
        int result = aChange.compareTo(bChange);

        // If percentage changes are equal, use symbol as tiebreaker
        if (result == 0) {
          String aSymbol = (a['tsym'] ?? "").toString().toUpperCase();
          String bSymbol = (b['tsym'] ?? "").toString().toUpperCase();
          return aSymbol.compareTo(bSymbol);
        }
        return result;
      });
    }

    // Clean up temp sorting data
    for (var scrip in _scrips) {
      scrip.remove('_sortRank');
    }
  }

  // Helper method to parse trading-specific doubles
  double _parseTradingDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    // Handle empty strings
    if (value.toString().trim().isEmpty) return 0.0;

    // Remove any currency symbols or commas
    String cleanValue = value.toString().replaceAll(RegExp(r'[₹,]'), '').trim();

    // Handle percentage signs
    if (cleanValue.endsWith('%')) {
      cleanValue = cleanValue.substring(0, cleanValue.length - 1);
    }

    try {
      // Parse the cleaned value
      return double.parse(cleanValue);
    } catch (e) {
      // For invalid values in trading context, return 0
      return 0.0;
    }
  }

  // Socket data update method to maintain sorting
  void updateSocketData(Map<String, dynamic> socketDatas) {
    if (_scrips.isEmpty) return;

    // Debug: Log when socket data is being updated during option chain operations
    if (_optionChainModel != null) {
      // print("=== SOCKET UPDATE DURING OPTION CHAIN ===");
      // print("Updating socket data with ${socketDatas.length} entries");

      // Check if any option chain tokens are in the update
      int optionTokensUpdated = 0;
      if (_optionChainModel!.optValue != null) {
        for (var option in _optionChainModel!.optValue!) {
          if (socketDatas.containsKey(option.token)) {
            optionTokensUpdated++;
            if (optionTokensUpdated <= 3) {
              // Limit debug output
              final data = socketDatas[option.token];
              // print("  Updated Option: ${option.tsym} - LTP: ${data?['lp']}, Change: ${data?['chng']}");
            }
          }
        }
      }
      // print("Total option tokens updated: $optionTokensUpdated");
      // print("=======================================");
    }

    bool dataUpdated = false;

    // First pass: Update the data in the scrips list
    for (var scrip in _scrips) {
      String token = scrip['token']?.toString() ?? "";
      if (token.isNotEmpty && socketDatas.containsKey(token)) {
        final socketData = socketDatas[token];

        // Update LTP
        if (socketData['lp'] != null && socketData['lp'].toString() != "null") {
          String newValue = socketData['lp'].toString();
          if (scrip['ltp'] != newValue) {
            scrip['ltp'] = newValue;
            dataUpdated = true;
          }
        }

        // Update change
        if (socketData['chng'] != null &&
            socketData['chng'].toString() != "null") {
          String newValue = socketData['chng'].toString();
          if (scrip['change'] != newValue) {
            scrip['change'] = newValue;
            dataUpdated = true;
          }
        }

        // Update percentage change
        if (socketData['pc'] != null && socketData['pc'].toString() != "null") {
          String newValue = socketData['pc'].toString();
          if (scrip['perChange'] != newValue) {
            scrip['perChange'] = newValue;
            dataUpdated = true;
          }
        }

        // Update other relevant fields
        final relevantFields = [
          'h',
          'l',
          'o',
          'c',
          'v',
          'ap',
          'bp1',
          'sp1',
          'tbq',
          'tsq'
        ];

        for (var field in relevantFields) {
          if (socketData[field] != null &&
              socketData[field].toString() != "null") {
            String newValue = socketData[field].toString();
            if (scrip[field] != newValue) {
              scrip[field] = newValue;
              dataUpdated = true;
            }
          }
        }
      }
    }

    // If we have updates and a sort preference, re-apply the sort
    if (dataUpdated && _sortByWL.isNotEmpty) {
      try {
        // Log pre-sort data for debugging
        // if (_scrips.isNotEmpty) {
        //   print(
        //       "Socket update - Pre-sort: ${_scrips[0]['tsym']} LTP: ${_scrips[0]['ltp']} PerChange: ${_scrips[0]['perChange']}");
        // }

        // Create a copy of the list to preserve object references
        final List<dynamic> tempScrips = List<dynamic>.from(_scrips);

        // Apply the sort without having to check the type again
        switch (_sortByWL) {
          case "Scrip - Z to A":
            tempScrips.sort(
                (a, b) => b['tsym'].toString().compareTo(a['tsym'].toString()));
            break;

          case "Scrip - A to Z":
            tempScrips.sort(
                (a, b) => a['tsym'].toString().compareTo(b['tsym'].toString()));
            break;

          case "Price - Low to High":
            tempScrips.sort((a, b) {
              double aPrice = _parseNumericValue(a['ltp']);
              double bPrice = _parseNumericValue(b['ltp']);
              return aPrice.compareTo(bPrice);
            });
            break;

          case "Price - High to Low":
            tempScrips.sort((a, b) {
              double aPrice = _parseNumericValue(a['ltp']);
              double bPrice = _parseNumericValue(b['ltp']);
              return bPrice.compareTo(aPrice);
            });
            break;

          case "Per.Chng - High to Low":
            tempScrips.sort((a, b) {
              double aChange = _parseNumericValue(a['perChange']);
              double bChange = _parseNumericValue(b['perChange']);
              return bChange.compareTo(aChange);
            });
            break;

          case "Per.Chng - Low to High":
            tempScrips.sort((a, b) {
              double aChange = _parseNumericValue(a['perChange']);
              double bChange = _parseNumericValue(b['perChange']);
              return aChange.compareTo(bChange);
            });
            break;
        }

        // Log post-sort data for debugging
        // if (tempScrips.isNotEmpty) {
        //   print(
        //       "Socket update - Post-sort: ${tempScrips[0]['tsym']} LTP: ${tempScrips[0]['ltp']} PerChange: ${tempScrips[0]['perChange']}");
        // }

        // Update the list with the sorted data
        _scrips = tempScrips;
      } catch (e) {
      }
    }

    // Notify listeners to update the UI - only if data actually changed
    // Use post-frame callback to avoid mouse tracker assertion errors
    // ("!_debugDuringDeviceUpdate is not true")
    if (dataUpdated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // Add scrip method with sort reset
  Future<void> addScrip(
      Map<String, dynamic> scrip, String wlName, BuildContext context) async {
    // Add the scrip to the list
    _scrips.add(scrip);

    // Reset sorting when adding new scrips to show natural order
    await _resetSortPreference();
    notifyListeners();
  }

// Assing Del Qty =0
  delQty() {
    _delScripQty = 0;
    notifyListeners();
  }

// Selection for scrip selcetion
  void selectDeleteScrip(int index) {
    if (_scrips[index]['isSelected']) {
      _scrips[index]['isSelected'] = false;
      _delScripQty = _delScripQty - 1;
    } else {
      _scrips[index]['isSelected'] = true;
      _delScripQty = _delScripQty + 1;
    }
    notifyListeners();
  }

  deleteScrip(BuildContext context, String wlName) async {
    String input = "";
    for (var element in _scrips) {
      if (element['isSelected']) {
        input += "${element['exch']}|${element['token']}#";
      }
    }
    await addDelMarketScrip(wlName, input, context, false, false, false, false);

    if (_scrips.isEmpty) {
      Navigator.pop(context);
    }
    if((_addDeleteScripModel!.emsg !=
          "Invalid Input : At least one stock must remain in the Market Watch.")){
      _delScripQty = 0;
    }
    notifyListeners();
  }

  // Market watch scrip re-order
  void reOrderList(
      {required int oldIndex,
      required int newIndex,
      required String wlName,
      required BuildContext context}) async {
    final int oldI = oldIndex;
    int newI = newIndex;
    if (newI > oldI) {
      newI -= 1;
    }

    final element = _scrips.removeAt(oldI);
    _scrips.insert(newI, element);

   
    String addInput = "";
    for (var elements in _scrips) {
      addInput += "${elements['exch']}|${elements['token']}#";
    }
    try {
      await api.getReorderMWScrips(
        wlname: wlName,
        scripToken: addInput,
      );
      // Sync the local scrip-data cache with the new order so a later
      // changeWLScrip/restoreFromCache (e.g. from the WS reconnect chain
      // after a browser tab return) doesn't silently revert the order.
      _marketWatchScripData[wlName] = jsonEncode(_scrips);

      // Restore the success toast that the old delete-then-add flow used
      // to show via addDelMarketScrip's isReOrder branch.
      if (context.mounted) {
        try {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(context, "Stocks reordered successfully.");
          } else {
            successMessage(context, "Stocks reordered successfully.");
          }
        } catch (_) {}
      }
    } catch (_) {
      // Silently swallow — reorder is best-effort; the UI already reflects
      // the new order and the backend remains consistent with the old order.
    }

    // Reset sorting after reordering to maintain natural order
    await _resetSortPreference();
    notifyListeners();
  }

  //////SET ALERT//////

  Future fetchSetAlert(
      String exch,
      String tysm,
      String value,
      String alertTypeVal,
      BuildContext context,
      int index,
      String lp,
      String remark) async {
    try {
      toggleLoadingOn(true);
      _setAlertModel =
          await api.getSetAlert(exch, tysm, value, alertTypeVal, remark);
      // ref.read(orderProvider).changeTabIndex(5, context);

      if (_setAlertModel!.stat! == "OI created") {
        // Fetch updated alert list
        await fetchPendingAlert(context);

        // Update the tab count immediately
        ref.read(orderProvider).tabSize();

        // Display success message
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Alert created successfully");
        } else {
          successMessage(context, "Alert created successfully");
        }

        // Close the alert creation screens
        Navigator.pop(context);
        Navigator.pop(context);
        if(scripsize){
          Navigator.pop(context);
        }

        // Add a small delay to ensure Navigator.pop operations complete before navigation
        Future.delayed(const Duration(milliseconds: 100), () {
          // Navigate to the Alert tab after closing the alert creation screens
          ref.read(indexListProvider).bottomMenu(2, context);
          ref.read(portfolioProvider).changeTabIndex(2);
          ref.read(orderProvider).changeTabIndex(5, context);
        });
      } else if (_setAlertModel!.stat! == "Not_Ok" &&
          _setAlertModel!.emsg == "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
        return _setAlertModel;
      }

      if (_setAlertModel!.stat! != "OI created") {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, "Alert not created");
        } else {
          warningMessage(context, "Alert not created");
        }
      }

      notifyListeners();
      return _setAlertModel;
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future fetchSetAlertWeb(
      String exch,
      String tysm,
      String value,
      String alertTypeVal,
      BuildContext context,
      int index,
      String lp,
      String remark) async {
    try {
      toggleLoadingOn(true);
      _setAlertModel =
          await api.getSetAlert(exch, tysm, value, alertTypeVal, remark);

      if (_setAlertModel!.stat! == "OI created") {
        // Fetch updated alert list
        await fetchPendingAlert(context);

        // Update the tab count immediately
        ref.read(orderProvider).tabSize();

        // Display success message
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Alert created successfully");
        } else {
          successMessage(context, "Alert created successfully");
        }

        // Close the dialog
        Navigator.of(context).pop();

       
        Future.delayed(const Duration(milliseconds: 200), () {
          if (kIsWeb && WebNavigationHelper.isAvailable) {
            // Navigate to Order Book in web panel
            WebNavigationHelper.navigateTo("orderBook");

          
            Future.delayed(const Duration(milliseconds: 300), () {
              ref.read(orderProvider).setSelectedTabSilent(6);
            });
          } else {
            // Fallback for non-web platforms
            ref.read(orderProvider).setSelectedTabSilent(6);
          }
        });
      } else if (_setAlertModel!.stat! == "Not_Ok" &&
          _setAlertModel!.emsg == "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
        return _setAlertModel;
      } else if (_setAlertModel!.stat! != "OI created") {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, "Alert not created");
        } else {
          warningMessage(context, "Alert not created");
        }
      }

      notifyListeners();
      return _setAlertModel;
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future fetchPendingAlert(BuildContext context) async {
    try {
      _alertPendingModel = await api.getPendingAlert();

      if (_alertPendingModel!.isNotEmpty) {
        if (_alertPendingModel![0].stat != "Not_Ok") {
          ConstantName.sessCheck = true;
          // LTP will be updated via WebSocket subscription in pending_alert_card_web.dart
          // No need to call getLTP API here - WebSocket provides real-time updates

          // Apply default sorting (Scrip Name ascending) when alerts are initially loaded
          filterPendingAlert("ASC");
        } else {
          if (_alertPendingModel![0].emsg ==
              "Session Expired :  Invalid Session Key") {
            ref.read(authProvider).ifSessionExpired(context);
          }
          _alertPendingModel = [];
          ConstantName.sessCheck = false;
        }
      }

      notifyListeners();

      // Update the tab count with alert count
      ref.read(orderProvider).tabSize();

      return _alertPendingModel;
    } catch (e) {
    }
  }

  Future<bool> fetchCancelAlert(String alid, BuildContext context) async {
    try {
      // First make the API call to cancel the alert
      _cancelalert = await api.getCancelAlert(alid);
      ConstantName.sessCheck = true;

      if (_cancelalert!.stat == "OI deleted") {
        // Fetch updated alert list
        await fetchPendingAlert(context);

        // Update the tab count immediately
        ref.read(orderProvider).tabSize();

        // Snackbar is shown by the caller (UI) to avoid duplicate messages
        // try {
        //   if (kIsWeb) {
        //     ResponsiveSnackBar.showSuccess(context, "Alert deleted successfully");
        //   } else {
        //     successMessage(context, "Alert deleted successfully");
        //   }
        // } catch (e) {
        //   print("Could not show SnackBar: $e");
        // }

        // Return success status
        notifyListeners();
        return true;
      } else if (_cancelalert!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
        return false;
      }

      notifyListeners();
      return false;
    } catch (e) {
      return false;
    }
  }

  Future fetchmodifyalert(String exch, String tysm, String value,
      String alertTypeVal, String alid, BuildContext context) async {
    try {
      _modifyalertmodel =
          await api.getmodifyalert(exch, tysm, value, alertTypeVal, alid);

      if (_modifyalertmodel!.stat! == "OI replaced") {
        ConstantName.sessCheck = true;

        // Fetch updated alert list
        await fetchPendingAlert(context);

        // Update the tab count immediately
        ref.read(orderProvider).tabSize();
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context, "Alert modified successfully");
        } else {
          successMessage(context, "Alert modified successfully");
        }
      } else if (_modifyalertmodel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }

      notifyListeners();
      return _modifyalertmodel;
    } catch (e) {
    }
  }

///// new code by dd
  Future fetchWatchListRename(
      String oldName, String newName, BuildContext context) async {
    try {
      toggleLoadingOn(true);

      // Check if this is a pending watchlist (created locally but not synced)
      if (_pendingWatchlists.contains(oldName)) {
        // Handle pending watchlist rename locally without API call
        _pendingWatchlists.remove(oldName);
        _pendingWatchlists.add(newName);
        await _savePendingWatchlists();

        // Update cached data key from old name to new name
        if (_marketWatchScripData.containsKey(oldName)) {
          String cachedData = _marketWatchScripData[oldName];
          _marketWatchScripData.remove(oldName);
          _marketWatchScripData[newName] = cachedData;
        }

        // Update current watchlist name if it was the renamed one
        if (_wlName == oldName) {
          _wlName = newName;
        }

        // Update the marketWatchlist values
        if (_marketWatchlist != null && _marketWatchlist!.values != null) {
          final updatedValues = _marketWatchlist!.values!
              .map((wl) => wl == oldName ? newName : wl)
              .toList();

          // Re-sort custom watchlists
          final customWLs = updatedValues.where((wl) => !_preDefWL.contains(wl)).toList();
          customWLs.sort((a, b) => a.compareTo(b));
          // If "My Positions" exists, insert at front
          final preDefForRename = List<String>.from(_preDefWL);
          final List<String> finalValues;
          if (preDefForRename.contains("My Positions")) {
            preDefForRename.remove("My Positions");
            finalValues = ["My Positions", ...customWLs, ...preDefForRename];
          } else {
            finalValues = [...customWLs, ...preDefForRename];
          }

          _marketWatchlist = MarketWatchlist(
            requestTime: _marketWatchlist!.requestTime,
            stat: _marketWatchlist!.stat,
            values: finalValues,
            emsg: _marketWatchlist!.emsg,
          );

          // Update page index to match new sorted position
          if (_wlName == newName) {
            final newIndex = finalValues.indexOf(newName);
            if (newIndex != -1) {
              setCurrentWatchlistPageIndex(newIndex);
            }
          }
        }

        toggleLoadingOn(false);
        // On mobile the rename UI is two nested bottom sheets — this pop
        // dismisses the WatchListRename sheet (the outer sheet has its own
        // pop chain). On web, the caller pops its own dialog before calling
        // us, so popping here would eat a live route on the nested right-
        // panel Navigator and trigger Navigator._debugLocked on unmount.
        if (!kIsWeb) {
          Navigator.pop(context);
        }
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context,
              "Watchlist renamed successfully");
        } else {
          successMessage(context,
              "Watchlist renamed successfully");
        }
        notifyListeners();
        return;
      }

      // Normal flow for synced watchlists
      _watchlistRenameModel = await api.getWatchListRename(oldName, newName);
      if (_watchlistRenameModel!.stat == "Ok") {
        // Update cached data key from old name to new name
        if (_marketWatchScripData.containsKey(oldName)) {
          String cachedData = _marketWatchScripData[oldName];
          _marketWatchScripData.remove(oldName);
          _marketWatchScripData[newName] = cachedData;
        }

        // Update current watchlist name if it was the renamed one
        if (_wlName == oldName) {
          _wlName = newName;
        }

        // Refresh the watchlist data to get updated list from server
        await fetchMWList(context, false);

        // If the renamed watchlist is currently active, reload its data
        if (_wlName == newName) {
          await changeWLScrip(newName, context);
        }

        // See the pending-branch comment above for why these pops are
        // mobile-only. The two pops dismiss the nested rename + watchlist
        // bottom sheets on mobile.
        if (!kIsWeb) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
        if (kIsWeb) {
          ResponsiveSnackBar.showSuccess(context,
              "Watchlist renamed successfully");
        } else {
          successMessage(context,
              "Watchlist renamed successfully");
        }
        notifyListeners();
      } else if (_watchlistRenameModel!.stat == "Not_Ok") {
        if (!kIsWeb) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, "${_watchlistRenameModel!.emsg}");
        } else {
          warningMessage(context, "${_watchlistRenameModel!.emsg}");
        }
      } else if (_watchlistRenameModel!.emsg ==
          "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      }
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }
  ////

  // Clear option chain data to prevent stale UI during symbol switching
  void clearOptionChainData() {
    _optChainCall.clear();
    _optChainPut.clear();
    _optChainCallDown.clear();
    _optChainCallUp.clear();
    _optChainPutDown.clear();
    _optChainPutUp.clear();
    _optionChainModel = null;
    notifyListeners();
  }

  // CRITICAL FIX: Clear old option chain socket data to prevent stale LTP showing
  // BUT preserve socket data for tokens that are still subscribed by other sources (watchlist, etc.)
  Future<void> _clearOldOptionSocketData() async {
    try {
      final wsProvider = ref.read(websocketProvider);
      final Map socketDatas = wsProvider.socketDatas;

      // Get protected symbols from WebSubscriptionManager AND websocket _sentSubscriptions
      // These are tokens that are used by watchlist, depth, holdings, etc.
      final Set<String> protectedTokens = {};
      try {
        // Method 1: Check WebSubscriptionManager's active subscriptions
        final webSubManager = ref.read(webSubscriptionManagerProvider);
        final activeSubscriptions = webSubManager.activeSubscriptions;

        for (var symbol in activeSubscriptions) {
          // Extract token from "NFO|58652" format
          if (symbol.contains('|')) {
            protectedTokens.add(symbol.split('|')[1]);
          }
        }

        // Method 2: Also check _sentSubscriptions in websocket provider
        // This catches tokens that are still subscribed but might not be in master list
        final sentSubs = wsProvider.sentSubscriptions;
        for (var entry in sentSubs) {
          // Format is "d:NFO|58652" - extract just the token
          if (entry.contains('|')) {
            final parts = entry.split('|');
            if (parts.length > 1) {
              protectedTokens.add(parts[1]);
            }
          }
        }

      } catch (e) {
      }

      // Get all current option chain tokens that should be cleared
      final List<String> tokensToRemove = [];
      final List<String> tokensProtected = [];

      if (_optionChainModel?.optValue != null) {
        for (var option in _optionChainModel!.optValue!) {
          if (option.token != null && socketDatas.containsKey(option.token)) {
            // Check if this token is protected (used by other subscriptions)
            if (protectedTokens.contains(option.token)) {
              tokensProtected.add(option.token!);
            } else {
              tokensToRemove.add(option.token!);
            }
          }
        }
      }

      // Remove old option chain tokens from socket data (except protected ones)
      for (String token in tokensToRemove) {
        socketDatas.remove(token);
      }

      // Force update the socket data stream to notify UI components
      if (tokensToRemove.isNotEmpty || tokensProtected.isNotEmpty) {
        if (tokensProtected.isNotEmpty) {
        }
      }
    } catch (e) {
    }
  }

  // Set option chain error state
  void setOptionChainError(String error) {
    // Clear data and set error state
    clearOptionChainData();
    // Could add error state management here if needed
    notifyListeners();
  }


  void updateSelectedTimeframe(String timeframe) {
    _selectedTimeframe = timeframe;
    notifyListeners();
  }

  void updateSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void updateShowTooltip(bool show) {
    _showTooltip = show;
    notifyListeners();
  }

  void updateTouchedIndex(int index) {
    _touchedIndex = index;
    notifyListeners();
  }

  void updateHoveredEventDots(Set<int> dots) {
    _hoveredEventDots = dots;
    notifyListeners();
  }

  void updateSelectedEventDot(int? dot) {
    _selectedEventDot = dot;
    notifyListeners();
  }

  void clearChartInteractionState() {
    _showTooltip = false;
    _touchedIndex = -1;
    _hoveredEventDots.clear();
    _selectedEventDot = null;
    notifyListeners();
  }



  /// Filters stock events (dividend, bonus, split, rights) by matching the given stock token
  /// Returns a map containing matching events across different event types
  ///
  /// Parameters:
  /// - [stockToken]: The token of the stock to filter events for
  ///
  /// Returns a Map with keys: 'dividend', 'bonus', 'split', 'rights'
  /// Each key contains the matching event object or null if not found
  Map<String, dynamic> filterStockEventsByToken(String stockToken) {
    final stockEvents = ref.read(stocksProvide).caeventsModel;
    Map<String, dynamic> filteredEvents = {
      'dividend': null,
      'bonus': null,
      'split': null,
      'rights': null,
    };

    if (stockEvents == null) {
      return filteredEvents;
    }

    // Find dividend
    if (stockEvents.dividend != null) {
      try {
        filteredEvents['dividend'] = stockEvents.dividend!
            .firstWhere((dividend) => dividend.token == stockToken);
      } catch (e) {
        // No matching dividend found
      }
    }

    // Find bonus
    if (stockEvents.bonus != null) {
      try {
        filteredEvents['bonus'] = stockEvents.bonus!
            .firstWhere((bonus) => bonus.token == stockToken);
      } catch (e) {
        // No matching bonus found
      }
    }

    // Find split
    if (stockEvents.split != null) {
      try {
        filteredEvents['split'] = stockEvents.split!
            .firstWhere((split) => split.token == stockToken);
      } catch (e) {
        // No matching split found
      }
    }

    // Find rights
    if (stockEvents.rights != null) {
      try {
        filteredEvents['rights'] = stockEvents.rights!
            .firstWhere((right) => right.token == stockToken);
      } catch (e) {
        // No matching right found
      }
    }

    return filteredEvents;
  }

  /// Returns true if the stock has any corporate action events
  bool hasStockEvents(Map<String,dynamic> events,String stockToken) {
    // final events = filterStockEventsByToken(stockToken);
    return events['dividend'] != null ||
        events['bonus'] != null ||
        events['split'] != null ||
        events['rights'] != null;
  }
}

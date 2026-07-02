import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/global_state_text.dart';

import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/camsres_model.dart';
import '../models/order_book_model/place_order_model.dart';
import '../models/portfolio_model/holdings_model.dart';
import '../models/portfolio_model/mf_holdings_model.dart';
import '../models/portfolio_model/mf_quotes.dart';
import '../models/portfolio_model/position_book_model.dart';
import '../models/portfolio_model/position_convertion_model.dart';

import '../models/portfolio_model/position_group_model.dart';
import '../res/res.dart';
import '../routes/route_names.dart';
import '../sharedWidget/functions.dart';
import '../sharedWidget/snack_bar.dart';
import '../utils/responsive_snackbar.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';

import 'group_pnl_chart_provider.dart';
import 'websocket_provider.dart';
import 'package:mynt_plus/utils/pip_service.dart';

final portfolioProvider =
    ChangeNotifierProvider((ref) => PortfolioProvider(ref));

class PortfolioProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  final FToast _fToast = FToast();
  FToast get fToast => _fToast;
  final Ref ref;
  TabController? portTab;
  final TextEditingController holdingSearchCtrl = TextEditingController();
  final TextEditingController holdingMFSearchCtrl = TextEditingController();
  final TextEditingController positionSearchCtrl = TextEditingController();

  List<HoldingsModel>? _tholdingsModel = [];

  List<HoldingsModel>? _holdingsModel = [];
  List<HoldingsModel>? get holdingsModel => _holdingsModel;

  List<HoldingsModel>? _holdingSearchItem = [];
  List<HoldingsModel>? get holdingSearchItem => _holdingSearchItem;
  List<HoldingsModel> _sealableHoldings = [];
  List<HoldingsModel> get sealableHoldings => _sealableHoldings;
  List<HoldingsModel> _nonSealableHoldings = [];
  List<HoldingsModel> get nonSealableHoldings => _nonSealableHoldings;

  // ---------------------------------------------------------------------------
  // MTF (Margin Trading Facility) holdings — fetched with prd:"F".
  // Kept as a SEPARATE parallel state from the equity (prd:"C") holdings above
  // so the live-shipping Equity tab can never regress from this addition.
  // ---------------------------------------------------------------------------
  List<HoldingsModel>? _tmtfHoldingsModel = [];
  List<HoldingsModel>? _mtfHoldingsModel = [];
  List<HoldingsModel>? get mtfHoldingsModel => _mtfHoldingsModel;
  List<HoldingsModel>? _mtfHoldingSearchItem = [];
  List<HoldingsModel>? get mtfHoldingSearchItem => _mtfHoldingSearchItem;

  List<PositionBookModel>? _tpostionBookModel = [];

  List<PositionBookModel>? _postionBookModel = [];
  List<PositionBookModel>? get postionBookModel => _postionBookModel;

  // Set true whenever the position-book API returned an unexpected/error
  // status or the fetch threw. Reset at the start of every fetchPositionBook
  // call. The manual refresh button reads `lastRefreshSucceeded` after
  // awaiting to decide whether to surface an error toaster.
  bool _positionFetchErrored = false;

  /// True if the last `fetchPositionBook` call finished without an API error
  /// ('success' or 'no data' — both valid). False if the API returned an
  /// unknown status or the call threw.
  bool get lastRefreshSucceeded => !_positionFetchErrored;

  List<PositionBookModel>? _openPosition = [];
  List<PositionBookModel>? get openPosition => _openPosition;
  List<PositionBookModel>? _closedPosion = [];
  List<PositionBookModel>? get closedPosion => _closedPosion;

  List<PositionBookModel> _allPostionList = [];
  List<PositionBookModel> get allPostionList => _allPostionList;

  // List<PositionBookModel> _postionGropList = [];
  // List<PositionBookModel> get postionGropList => _postionGropList;

  List<PositionBookModel> _positionSearchItem = [];
  List<PositionBookModel> get positionSearchItem => _positionSearchItem;
  PositionConvertionModel? _positionConvertionModel;
  PositionConvertionModel? get positionConvertionModel =>
      _positionConvertionModel;

  final String _allPnlPosition = '0.00';
  String get allPnlPosition => _allPnlPosition;

  double _totalPnlHolding = 0.00;
  double get totalPnlHolding => _totalPnlHolding;
  double _totalCurrentVal = 0.00;
  double get totalCurrentVal => _totalCurrentVal;
  double _oneDayChng = 0.00;
  double get oneDayChng => _oneDayChng;
  double _oneDayChngPer = 0.00;
  double get oneDayChngPer => _oneDayChngPer;
  String _totPnlPercHolding = "0.00";
  String get totPnlPercHolding => _totPnlPercHolding;
  String _totInvesHold = "0.00";
  String get totInvesHold => _totInvesHold;

  // MTF holdings summary totals (mirror of the equity totals above).
  double _totalMtfPnl = 0.00;
  double get totalMtfPnl => _totalMtfPnl;
  double _totalMtfCurrentVal = 0.00;
  double get totalMtfCurrentVal => _totalMtfCurrentVal;
  double _mtfOneDayChng = 0.00;
  double get mtfOneDayChng => _mtfOneDayChng;
  double _mtfOneDayChngPer = 0.00;
  double get mtfOneDayChngPer => _mtfOneDayChngPer;
  String _totMtfPnlPerc = "0.00";
  String get totMtfPnlPerc => _totMtfPnlPerc;
  String _totMtfInvest = "0.00";
  String get totMtfInvest => _totMtfInvest;

  int _exitPositionQty = 0;
  int get exitPositionQty => _exitPositionQty;
  bool _isExitAllPosition = false;
  bool get isExitAllPosition => _isExitAllPosition;
  Set<String> _exitSelectedPositions = {};
  Set<String> get exitSelectedPositions => _exitSelectedPositions;

  /// Get selected F&O option positions for strategy builder analysis
  List<PositionBookModel> get selectedFnOPositions {
    if (_openPosition == null) return [];
    return _openPosition!.where((p) =>
      p.isExitSelection == true &&
      p.qty != "0" &&
      (p.exch == 'NFO' || p.exch == 'BFO' || p.exch == 'MCX' || p.exch == 'CDS') &&
      p.option != null &&
      (p.option!.contains('CE') || p.option!.contains('PE'))
    ).toList();
  }

  int _exitHoldingsQty = 0;
  int get exitHoldingsQty => _exitHoldingsQty;
  bool _isExitAllHoldings = false;
  bool get isExitAllHoldings => _isExitAllHoldings;
  PlaceOrderModel? _placeOrderModel;
  PlaceOrderModel? get placeOrderModel => _placeOrderModel;

  String _totBuyAmt = '0.00';
  String get totBuyAmt => _totBuyAmt;
  String _totSellAmt = '0.00';
  String get totSellAmt => _totSellAmt;
  String _netVal = '0.00';
  String get netVal => _netVal;
  bool _isDay = false;
  bool get isDay => _isDay;

  String _totPnL = '0.00';
  String get totPnL => _totPnL;
  String _totMtm = '0.00';
  String get totMtM => _totMtm;

  String _totUnRealMtm = '0.00';
  String get totUnRealMtm => _totUnRealMtm;
  String _totBookedPnL = '0.00';
  String get totBookedPnL => _totBookedPnL;

  bool _isNetPnl = true;
  bool get isNetPnl => _isNetPnl;

  Map<String, dynamic> _allholds = {};
  Map<String, dynamic> get allholds => _allholds;

  Camsmodel? _camsrespons;
  Camsmodel? get camsrespons => _camsrespons;

  String _ldate = "";
  String get ldate => _ldate;

  String _subscr = "";
  String get subscr => _subscr;

  late TabController holdingsTabController;

  PortfolioProvider(this.ref);

  bool _showSearchHold = false;
  bool get showSearchHold => _showSearchHold;

  bool _showSearchPosition = false;
  bool get showSearchPosition => _showSearchPosition;
  bool _showEdis = false;
  bool get showEdis => _showEdis;

  bool _exitAll = false;
  bool get exitAll => _exitAll;
  final List<Tab> _portTabName = [
    const Tab(text: "Holdings"),
    const Tab(text: "Positions"),
    const Tab(text: "Orders"),
    const Tab(text: "Funds")
  ];
  List<Tab> get portTabName => _portTabName;

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  bool _posloader = false;
  bool get posloader => _posloader;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _holdloader = false;
  bool get holdloader => _holdloader;

  bool _isRefreshingHoldings = false;
  bool get isRefreshingHoldings => _isRefreshingHoldings;

  // MTF loader flags (mirror of the equity holdings loaders above).
  bool _mtfHoldLoader = false;
  bool get mtfHoldLoader => _mtfHoldLoader;
  bool _isRefreshingMtf = false;
  bool get isRefreshingMtf => _isRefreshingMtf;

  bool _mfhloader = false;
  bool get mfhloader => _mfhloader;

  bool _tphloader = false;
  bool get tphloader => _tphloader;

  // Navigation locks to prevent duplicate actions
  bool _isFilterNavigating = false;
  bool get isFilterNavigating => _isFilterNavigating;

  void setFilterNavigating(bool value) {
    _isFilterNavigating = value;
    notifyListeners();
  }

// Position Grouping -----------

  Map _groupedBySymbol = {};
  Map get groupedBySymbol => _groupedBySymbol;

  // Map<String, dynamic> _positionGroup = {};
  // Map get positionGroup => _positionGroup;
  List<String> _groupPositionSym = [];
  List<String> get groupPositionSym => _groupPositionSym;
  List _oplists = [];
  List get oplists => _oplists;

  String _posSelection = "All position";

  String get posSelection => _posSelection;

  final List<String> _posGrpNames = ["All position", "Group by symbol"];

  List<String> get posGrpNames => _posGrpNames;

  // Position group filter: 'underlying' (default) groups by symbol only,
  // 'underlying_expiry' groups by symbol + expiry (only affects default
  // F&O groups — equity rows without expDate stay grouped by symbol; custom
  // groups are not affected).
  String _positionGroupFilter = 'underlying';
  String get positionGroupFilter => _positionGroupFilter;

  void setPositionGroupFilter(String value) {
    if (value != 'underlying' && value != 'underlying_expiry') return;
    if (_positionGroupFilter == value) return;
    _positionGroupFilter = value;
    getPositionGroupNames();
    for (var symbol in _groupPositionSym) {
      if (_groupedBySymbol.containsKey(symbol)) {
        final groupData = _groupedBySymbol[symbol]['groupList'];
        final isCustomGrp = _groupedBySymbol[symbol]['isCustomGrp'] ?? false;
        if (groupData != null && groupData.isNotEmpty) {
          positionGroupCal(_isDay, groupData, symbol, isCustomGrp);
        }
      }
    }
    notifyListeners();
  }

  List<GetGroupSymbol> _getPositionGroupSymbol = [];
  List<GetGroupSymbol> get getPositionGroupSymbol => _getPositionGroupSymbol;

  CreateGroupName? _groupName;
  CreateGroupName? get groupName => _groupName;

// change selected portfolio tab name

  clearAllportfolio() {
    _holdingsModel = [];
    _tholdingsModel = [];
    _postionBookModel = [];
    _tpostionBookModel = [];
    _allholds = {};
    _mfHoldingsModel = [];
    _allPostionList = [];
    _openPosition = [];
    _closedPosion = [];
    _holdingSearchItem = [];
    _positionSearchItem = [];
    _subscr = "";
    _mfTotInveest = 0.00;
    _mfTotCurrentVal = 0.00;
    _mfTotalPnl = 0.00;
    _mfTotalPnlPerchng = 0.00;
    _getPositionGroupSymbol = [];

    // Reset any timer or ongoing operations
    cancelTimer();

    notifyListeners();
  }

  changeTabIndex(int index) {
    _selectedTab = index;

    // Animate the TabController to the new index

    // Animate the TabController to the new index if initialized
    portTab?.animateTo(index);

    notifyListeners();
  }

  int _selectedHoldingsTab = 0;
  int get selectedHoldingsTab => _selectedHoldingsTab;

changeHoldingsTabIndex(int index) {
  _selectedHoldingsTab = index;
  
  // Animate the TabController to the new index
  try {
    holdingsTabController.animateTo(index);
  } catch (e) {
  }
  
  notifyListeners();
}

  chngPosSelection(String val) {
    _posSelection = val;
    notifyListeners();
  }

//  Assinging and portfolio name length set

  fetchBrokerDetails(
      BuildContext context, bool isSubscribe, bool consent) async {
    try {
      _tphloader = true;
      var res = await api.getallHolding();
      if (res.equities.isNotEmpty) {
        var one = res.equities;
        one.forEach((key, value) {
          for (var two in value['summary']) {
            _subscr += "${two['exch']}|${two['token']}#";
            two['totinv'] = (double.tryParse(two['lastTradedPrice']) ?? 0.0) *
                (double.tryParse("${two['units']}") ?? 0.0);
          }
        });
        requestallHoldings(isSubscribe: isSubscribe, context: context);
        _allholds = res.equities;
        _ldate = res.syncDatetime;
      } else {
        if (consent) {
          Future.delayed(const Duration(seconds: 2), () {
            if (kIsWeb) {
              ResponsiveSnackBar.showWarning(context, "Unable to fetch data");
            } else {
            warningMessage(context, "Unable to fetch data");
            }
          });
        }
        _allholds = {};
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _tphloader = false;
    }
  }

  Future fetchCamRedirct(BuildContext context) async {
    try {
      toggleLoadingOn(true);
      _camsrespons = await api.getcamsapi();
      Navigator.pushNamed(context, Routes.camsWebView,
          arguments: _camsrespons!.redirectionurl);
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "Fetch API", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  // tabSize(theme) {
  //   _portTabName = [
  //     Tab(
  //         child: Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //           TextWidget.subText(
  //               text:
  //                   "Position${_allPostionList.isNotEmpty ? "s (${_allPostionList.length})" : ""}",
  //               theme: false,
  //               color: selectedTab == 0
  //                   ? theme.isDarkMode
  //                       ? colors.secondaryDark
  //                       : colors.secondaryLight
  //                   : theme.isDarkMode
  //                       ? colors.textSecondaryDark
  //                       : colors.textSecondaryLight,
  //               fw: selectedTab == 0 ? 0 : null)
  //         ])),
  //     Tab(
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           TextWidget.subText(
  //               text:
  //                   "Holding${_holdingsModel!.isNotEmpty ? "s (${_holdingsModel!.length})" : ""}",
  //               theme: false,
  //               color: selectedTab == 1
  //                   ? theme.isDarkMode
  //                       ? colors.secondaryDark
  //                       : colors.secondaryLight
  //                   : theme.isDarkMode
  //                       ? colors.textSecondaryDark
  //                       : colors.textSecondaryLight,
  //               fw: selectedTab == 1 ? 0 : null)
  //         ],
  //       ),
  //     ),
  //     // if (_mfHoldingsModel!.isNotEmpty) ...[
  //     //   if (_mfHoldingsModel![0].stat != "Not_Ok") ...[
  //     Tab(
  //       child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           children: [
  //             TextWidget.subText(
  //                 text: "Orders",
  //                 theme: false,
  //                 color: selectedTab == 2
  //                     ? theme.isDarkMode
  //                         ? colors.secondaryDark
  //                         : colors.secondaryLight
  //                     : theme.isDarkMode
  //                         ? colors.textSecondaryDark
  //                         : colors.textSecondaryLight,
  //                 fw: selectedTab == 2 ? 0 : null)
  //           ]),
  //     ),
  //     Tab(
  //       child: Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           children: [
  //             TextWidget.subText(
  //                 text: "Funds",
  //                 theme: false,
  //                 color: selectedTab == 3
  //                     ? theme.isDarkMode
  //                         ? colors.secondaryDark
  //                         : colors.secondaryLight
  //                     : theme.isDarkMode
  //                         ? colors.textSecondaryDark
  //                         : colors.textSecondaryLight,
  //                 fw: selectedTab == 3 ? 0 : null)
  //           ]),
  //     ),
  //   ];

  //   notifyListeners();
  // }

// Holding search enable & hide

  void disposePortfolioSearch() {
    showHoldSearch(false);
    showPositionSearch(false);
    showHoldMFSearch(false);
    clearHoldSearch();
    clearHoldMFSearch();
    clearPositionSearch();
  }

  showHoldSearch(bool value) {
    _showSearchHold = value;
    if (!_showSearchHold) {
      _holdingSearchItem = [];
    }
    notifyListeners();
  }

//  Position search enable & hide

  showPositionSearch(bool value) {
    _showSearchPosition = value;
    if (!_showSearchPosition) {
      _positionSearchItem = [];
    }
    positionSearchCtrl.clear();
    notifyListeners();
  }

// Holding search text field clear and search list item clear

  clearHoldSearch() {
    holdingSearchCtrl.clear();
    _holdingSearchItem = [];

    notifyListeners();
  }

// Position search text field clear and search list item clear

  clearPositionSearch() {
    positionSearchCtrl.clear();
    _positionSearchItem = [];
    _showSearchPosition = false;

    notifyListeners();
  }

// Show position PNL / MTM value

  chngPositionPnl(bool value) {
    _isNetPnl = value;
    // Recalculate values after changing the PnL/MTM display mode
    positionCal(_isDay);
    notifyListeners();
  }

  positionToggle(bool value, context) {
    clearPositionSearch();
    showPositionSearch(false);
    _isDay = value;

    fetchPositionBook(context, value);
    notifyListeners();
  }

  // MF Holdings

  double _mfTotInveest = 0.00;
  double get mfTotInveest => _mfTotInveest;

  double _mfTotCurrentVal = 0.00;
  double get mfTotCurrentVal => _mfTotCurrentVal;

  double _mfTotalPnl = 0.00;
  double get mfTotalPnl => _mfTotalPnl;

  double _mfTotalPnlPerchng = 0.00;
  double get mfTotalPnlPerchng => _mfTotalPnlPerchng;

  bool _showSearchHoldMF = false;
  bool get showSearchHoldMF => _showSearchHoldMF;

  static List dsgs = [];

  List<MFHoldingsModel>? _mfHoldingsModel = [];
  List<MFHoldingsModel>? get mfHoldingsModel => _mfHoldingsModel;
  List<MFHoldingsModel>? _mfHoldingSearchItem = [];
  List<MFHoldingsModel>? get mfHoldingSearchItem => _mfHoldingSearchItem;

  // Mutual fund Holding search text field clear and search list item clear

  showHoldMFSearch(bool value) {
    _showSearchHoldMF = value;
    if (!_showSearchHoldMF) {
      _mfHoldingSearchItem = [];
    }
    notifyListeners();
  }
// MF Holdings search text field clear and search list item clear

  clearHoldMFSearch() {
    holdingMFSearchCtrl.clear();
    _mfHoldingSearchItem = [];

    notifyListeners();
  }

  MFQuotes? _mfQuotes;
  MFQuotes? get mfQuotes => _mfQuotes;

  // String _totPnlHoldings = "0.00";
  // String get totPnlHoldings => _totPnlHoldings;

  // setPnlHoldings(String val) {
  //   _totPnlHoldings = val;
  // }

// Fetching data from the api and stored in a variable

  Future<void> setPortfolioupdate(String mode, context) async {
    Map<String, dynamic> result;
    if (mode == 'H') {
      result = await api.getHolding();
      if (result['stat'] == 'success') {
        _tholdingsModel = result['data'];
      } else {
        if (result['stat'] == 'no data') {
          _holdingsModel = [];
        }else if(result['emsg'] == "Session Expired :  Invalid Session Key"){
          ref.read(authProvider).ifSessionExpired(context);
        }
        _tholdingsModel = [];
      }
    } else if (mode == 'P') {
      // result = await api.getPositionBook();
      result = await api.mockPositionBookResponse();

      if (result['stat'] == 'success') {
        _tpostionBookModel = result['data'];
      } else {
        if (result['stat'] == 'no data') {
          _postionBookModel = [];
        } else if (result['emsg'] == "Session Expired :  Invalid Session Key") {
          ref.read(authProvider).ifSessionExpired(context);
          _positionFetchErrored = true;
        } else {
          // Real API error (not 'success', not 'no data', not session expired).
          // Mark the flag so the manual refresh caller shows an error toaster.
          _positionFetchErrored = true;
        }
        _tpostionBookModel = [];
      }
    }

    // var result;
    //   if (mode == 'H') {
    //     result = await api.getHolding();
    //   } else if (mode == 'P') {
    //     result = await api.getPositionBook();
    //   }

    // if (result['stat'] == 'no data') {
    //   if (mode == 'H') {
    //     _holdingsModel = [];
    //     _tholdingsModel = [];
    //   } else if (mode == 'P') {
    //     _postionBookModel = [];
    //     _tpostionBookModel = [];
    //   }
    // } else if (result['stat'] == 'success') {
    //   if (mode == 'H') {
    //     _tholdingsModel = result['data'];
    //   } else if (mode == 'P') {
    //     _tpostionBookModel = result['data'];
    //   }
    // } else if (result['stat'] == 'error') {
    //   if (mode == 'H') {
    //     _tholdingsModel = [];
    //   } else if (mode == 'P') {
    //     _tpostionBookModel = [];
    //   }
    // }
    // print("qwqwqw prov alert btm $mode , ${result['stat']}");
  }

  Future fetchHoldings(context, String initail, {bool isRefresh = false}) async {
    final theme = ref.read(themeProvider);
    double invest = 0.0;
    try {
      // Use separate loader states: full-screen loader for initial load, refresh loader for updates
      if (isRefresh) {
        _isRefreshingHoldings = true;
      } else if (_holdingsModel == null || _holdingsModel!.isEmpty) {
        _holdloader = true;
      }
      notifyListeners();

      await setPortfolioupdate('H',context);
      // if (_holdingsModel!.isNotEmpty) {
      //   if (_tholdingsModel!.isNotEmpty) {
      //     _holdingsModel = _tholdingsModel;
      //   }
      // If holdings exist, merge new data with existing
      if (_holdingsModel!.isNotEmpty && _tholdingsModel!.isNotEmpty) {
        // Merge each element instead of complete reset
        for (var newHolding in _tholdingsModel!) {
          final index = _holdingsModel!.indexWhere((oldHolding) =>
              oldHolding.exchTsym![0].token == newHolding.exchTsym![0].token);
          if (index != -1) {
            // Update only changed fields
            _holdingsModel![index].updateFrom(newHolding);
          } else {
            _holdingsModel!.add(newHolding);
          }
        }
      } else {
        _holdloader = true;
        _oneDayChngPer = 0.00;
        _showSearchHold = false;
        _totInvesHold = "0.00";
        _totPnlPercHolding = "0.00";
        _totalPnlHolding = 0.00;
        _totalCurrentVal = 0.00;
        _oneDayChng = 0.00;
        _showEdis = false;
        _sealableHoldings = [];
        _nonSealableHoldings = [];
        _holdingsModel = _tholdingsModel;
      }

      pref.setScrip(true);
      pref.setPrice(true);
      pref.setPerchnage(true);
      pref.setqty(true);
      pref.setInvestby(true);
      // tabSize(theme);
      if (_holdingsModel!.isNotEmpty) {
        if (_holdingsModel![0].stat != "Not_Ok") {
          ConstantName.sessCheck = true;

// Sorting Holdings data Trade symbol wise A to Z

          _holdingsModel!.sort(
              (a, b) => a.exchTsym![0].tsym!.compareTo(b.exchTsym![0].tsym!));
          _sealableHoldings = [];
          _nonSealableHoldings = [];
          for (var element in _holdingsModel!) {
            element.isExitHoldings = false;

// Seperating Trade symbol(symbol,exp date, Option)

            Map spilitSymbol =
                spilitTsym(value: "${element.exchTsym![0].tsym}");

            element.exchTsym![0].symbol = "${spilitSymbol["symbol"]}";
            element.exchTsym![0].expDate = "${spilitSymbol["expDate"]}";
            element.exchTsym![0].option = "${spilitSymbol["option"]}";
            // After e-DIS, the broker mirrors the SAME shares into both the
            // POA and Non-POA fields — settled into dpQty + npoadqty, and T1
            // into btstqty + npoadt1qty. Use max() on each pair so the mirrored
            // qty is counted once (summing would double-count an e-DIS'd holding).
            int qty = (
                    // int.parse("${element.npoadqty ?? 0}") +
                    // int.parse("${element.brkcolqty ?? 0}") +
                    // int.parse("${element.npoadt1qty ?? 0}") +
                    max(int.parse("${element.dpQty ?? 0}"),
                            int.parse("${element.npoadqty ?? 0}")) +
                        int.parse("${element.holdqty ?? 0}") +
                        max<int>(int.parse("${element.btstqty ?? 0}"),
                            int.parse("${element.npoadt1qty ?? 0}"))) -
                int.parse("${element.trdqty ?? 0}");
            element.currentQty = qty;
            // FIX: Update holdQty without wiping existing socket data
            // Previously this replaced all socket data (lp, pc, chng, etc.) with just {'holdQty': ""}
            // causing watchlist symbols with holdings to show 0
           final wsProvider = ref.read(websocketProvider);
            final holdingToken = "${element.exchTsym![0].token}";
            if (!wsProvider.socketDatas.containsKey(holdingToken)) {
              wsProvider.socketDatas[holdingToken] = <String, dynamic>{};
            }
            wsProvider.socketDatas[holdingToken]!['holdQty'] =
                "${element.currentQty}";

            double avgCost = double.parse(
                "${element.upldprc == "0.00" ? element.exchTsym![0].close ?? 0.0 : element.upldprc ?? 0.00}");

            element.avgPrc = "$avgCost";
            element.invested = (qty * avgCost).toStringAsFixed(2);

            invest += double.parse("${element.invested}");
            if (element.npoadqty.toString() != "null" ||
                element.npoadt1qty.toString() != "null") {
              _showEdis = true;
            }

            element.saleableQty = (int.parse("${element.holdqty ?? 0}") +
                    int.parse("${element.dpQty ?? 0}") +
                    int.parse("${element.btstqty ?? 0}")) -
                int.parse("${element.usedqty ?? 0}");
            if (element.sellAmt != null && element.sellAmt != "0.000000") {
              element.rpnl = (double.parse("${element.sellAmt ?? 0.00}") -
                      ((double.parse("${element.trdqty ?? 0.00}")) *
                          (double.parse("${element.avgPrc ?? 0.00}"))))
                  .toStringAsFixed(2);
              // element.rpnl = (double.parse("${element.invested ?? 0.00}") - double.parse("${element.sellAmt ?? 0.00}")).toString();
            }

            if (element.saleableQty != 0) {
              _sealableHoldings.add(element);
            } else {
              _nonSealableHoldings.add(element);
            }
          }

          _totInvesHold = invest.toStringAsFixed(2);

          // Reapply sorting if previously set
          if (_currentHoldingSortOption.isNotEmpty) {
            await filterHoldings(
                sorting: _currentHoldingSortOption, context: context);
          }

          if (initail == "Refresh") {
            await requestWSHoldings(isSubscribe: true, context: context);
            // timerfunc();
          }
        } else {
          if (_holdingsModel![0].emsg ==
                  "Session Expired :  Invalid Session Key" &&
              _holdingsModel![0].stat == "Not_Ok") {
            ref.read(authProvider).ifSessionExpired(context);
          }
          // _holdingsModel = [];
        }
      }
      notifyListeners();
    } catch (e) {
      // print("qwqwqw hold sw catch ${e}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Holdings", "Error": "$e"});
      notifyListeners();
    } finally {
      _holdloader = false;
      _isRefreshingHoldings = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // MTF (Margin Trading Facility) holdings — prd:"F".
  // These methods are a deliberate, isolated mirror of the equity holdings
  // logic above. They operate ONLY on the MTF state so the live Equity tab is
  // unaffected. Row processing is intentionally duplicated (not refactored into
  // a shared helper) to avoid any risk of regressing the equity path.
  // ===========================================================================
  Future fetchMtfHoldings(context, String initail,
      {bool isRefresh = false}) async {
    double invest = 0.0;
    try {
      if (isRefresh) {
        _isRefreshingMtf = true;
      } else if (_mtfHoldingsModel == null || _mtfHoldingsModel!.isEmpty) {
        _mtfHoldLoader = true;
      }
      notifyListeners();

      // Fetch holdings under the MTF product (prd:"F").
      final result = await api.getHolding(prd: "F");
      if (result['stat'] == 'success') {
        _tmtfHoldingsModel = result['data'];
      } else {
        if (result['stat'] == 'no data') {
          _mtfHoldingsModel = [];
        } else if (result['emsg'] == "Session Expired :  Invalid Session Key") {
          ref.read(authProvider).ifSessionExpired(context);
        }
        _tmtfHoldingsModel = [];
      }

      // Merge fresh data into existing rows (preserve socket-updated values),
      // mirroring the equity merge.
      if (_mtfHoldingsModel!.isNotEmpty && _tmtfHoldingsModel!.isNotEmpty) {
        for (var newHolding in _tmtfHoldingsModel!) {
          final index = _mtfHoldingsModel!.indexWhere((oldHolding) =>
              oldHolding.exchTsym![0].token == newHolding.exchTsym![0].token);
          if (index != -1) {
            _mtfHoldingsModel![index].updateFrom(newHolding);
          } else {
            _mtfHoldingsModel!.add(newHolding);
          }
        }
      } else {
        _totMtfInvest = "0.00";
        _totMtfPnlPerc = "0.00";
        _totalMtfPnl = 0.00;
        _totalMtfCurrentVal = 0.00;
        _mtfOneDayChng = 0.00;
        _mtfOneDayChngPer = 0.00;
        _mtfHoldingsModel = _tmtfHoldingsModel;
      }

      if (_mtfHoldingsModel!.isNotEmpty &&
          _mtfHoldingsModel![0].stat != "Not_Ok") {
        // Sort A→Z by trading symbol (same as equity).
        _mtfHoldingsModel!.sort(
            (a, b) => a.exchTsym![0].tsym!.compareTo(b.exchTsym![0].tsym!));

        for (var element in _mtfHoldingsModel!) {
          element.isExitHoldings = false;

          Map spilitSymbol = spilitTsym(value: "${element.exchTsym![0].tsym}");
          element.exchTsym![0].symbol = "${spilitSymbol["symbol"]}";
          element.exchTsym![0].expDate = "${spilitSymbol["expDate"]}";
          element.exchTsym![0].option = "${spilitSymbol["option"]}";

          int qty = (max(int.parse("${element.dpQty ?? 0}"),
                          int.parse("${element.npoadqty ?? 0}")) +
                      int.parse("${element.holdqty ?? 0}") +
                      max<int>(int.parse("${element.btstqty ?? 0}"),
                          int.parse("${element.npoadt1qty ?? 0}"))) -
                  int.parse("${element.trdqty ?? 0}");
          element.currentQty = qty;

          double avgCost = double.parse(
              "${element.upldprc == "0.00" ? element.exchTsym![0].close ?? 0.0 : element.upldprc ?? 0.00}");
          element.avgPrc = "$avgCost";
          element.invested = (qty * avgCost).toStringAsFixed(2);
          invest += double.parse("${element.invested}");

          element.saleableQty = (int.parse("${element.holdqty ?? 0}") +
                  int.parse("${element.dpQty ?? 0}") +
                  int.parse("${element.btstqty ?? 0}")) -
              int.parse("${element.usedqty ?? 0}");
          if (element.sellAmt != null && element.sellAmt != "0.000000") {
            element.rpnl = (double.parse("${element.sellAmt ?? 0.00}") -
                    ((double.parse("${element.trdqty ?? 0.00}")) *
                        (double.parse("${element.avgPrc ?? 0.00}"))))
                .toStringAsFixed(2);
          }
        }

        _totMtfInvest = invest.toStringAsFixed(2);

        if (initail == "Refresh") {
          await requestWSMtfHoldings(isSubscribe: true, context: context);
        }
      } else if (_mtfHoldingsModel!.isNotEmpty &&
          _mtfHoldingsModel![0].emsg ==
              "Session Expired :  Invalid Session Key" &&
          _mtfHoldingsModel![0].stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }

      // Seed row values + totals from the live socket cache for first paint.
      seedMtfHoldingsFromCache();
      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API MTF Holdings", "Error": "$e"});
      notifyListeners();
    } finally {
      _mtfHoldLoader = false;
      _isRefreshingMtf = false;
      notifyListeners();
    }
  }

  // WebSocket subscription request for MTF holdings scrips (mirror of
  // requestWSHoldings but built from the MTF list).
  requestWSMtfHoldings(
      {required bool isSubscribe, required BuildContext context}) {
    if (kIsWeb && !isSubscribe) return;
    try {
      String input = "";
      if (_mtfHoldingsModel != null &&
          _mtfHoldingsModel!.isNotEmpty &&
          _mtfHoldingsModel![0].stat != "Not_Ok") {
        for (var i = 0; i < _mtfHoldingsModel!.length; i++) {
          input +=
              "${_mtfHoldingsModel![i].exchTsym![0].exch}|${_mtfHoldingsModel![i].exchTsym![0].token}#";
        }
      }
      if (input.isNotEmpty) {
        ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? (kIsWeb ? "d" : "t") : "u",
            context: context);
      }
    } catch (e) {}
  }

  // Seed MTF rows + totals from the cached socket data (used right after a
  // fetch so the first paint shows live LTP / current value / P&L).
  void seedMtfHoldingsFromCache() {
    if (_mtfHoldingsModel == null || _mtfHoldingsModel!.isEmpty) return;
    try {
      final socketDatas = ref.read(websocketProvider).socketDatas;
      for (final holding in _mtfHoldingsModel!) {
        final token = holding.exchTsym?.isNotEmpty == true
            ? holding.exchTsym![0].token
            : null;
        if (token == null) continue;
        final cached = socketDatas[token];
        if (cached is Map<String, dynamic>) {
          updateMtfHoldingValues(token, cached);
        }
      }
    } catch (e) {}
    mtfPnlHoldCal();
  }

  // Per-tick update for an MTF row (mirror of updateHoldingValues). Driven by
  // the holdings screen's own socket-stream listener so the shared WebSocket
  // provider stays untouched.
  void updateMtfHoldingValues(String token, Map<String, dynamic> socketData) {
    if (_mtfHoldingsModel == null) return;

    var index = -1;
    for (int i = 0; i < _mtfHoldingsModel!.length; i++) {
      if (_mtfHoldingsModel![i].exchTsym![0].token == token) {
        index = i;
        break;
      }
    }
    if (index == -1) return;

    var holding = _mtfHoldingsModel![index];
    bool hasUpdates = false;

    final newLp = socketData['lp']?.toString();
    final newPc = socketData['pc']?.toString();
    final newChng = socketData['chng']?.toString();
    final newClose = socketData['c']?.toString();

    if (_isValidValue(newLp)) {
      holding.exchTsym![0].lp = newLp;
      hasUpdates = true;
    }
    if (_isValidValue(newPc)) {
      holding.exchTsym![0].perChange = newPc;
      hasUpdates = true;
    }
    if (_isValidValue(newChng)) {
      holding.exchTsym![0].change = newChng;
      hasUpdates = true;
    }
    if (_isValidValue(newClose)) {
      holding.exchTsym![0].close = newClose;
      hasUpdates = true;
    }

    if (hasUpdates) {
      _updateMtfDerivedValues(holding);
    }
  }

  // Mirror of _updateDerivedValues, scoped to a single MTF row. Totals are
  // recomputed separately via mtfPnlHoldCal (called by the screen listener).
  void _updateMtfDerivedValues(HoldingsModel holding) {
    final qty = holding.currentQty ?? 0;
    if (qty < 0) return;

    final lpDouble = double.tryParse(holding.exchTsym![0].lp ?? '0.0') ?? 0.0;
    if (lpDouble <= 0) return;

    holding.currentValue = (qty * lpDouble).toStringAsFixed(2);

    final closeVal =
        double.tryParse(holding.exchTsym![0].close ?? "0.00") ?? 0.0;
    final avgCost = double.tryParse(holding.upldprc == "0.00"
            ? (closeVal > 0
                ? closeVal.toString()
                : holding.exchTsym![0].close ?? '0.0')
            : holding.upldprc ?? '0.00') ??
        0.0;
    if (avgCost <= 0) return;

    holding.invested = (qty * avgCost).toStringAsFixed(2);
    final investedValue = double.tryParse(holding.invested ?? '0.00') ?? 0.00;

    final currentValue = double.tryParse(holding.currentValue ?? "0.00") ?? 0.0;
    holding.exchTsym![0].profitNloss = ((currentValue - investedValue) +
            double.tryParse(holding.rpnl ?? '0.0')!)
        .toStringAsFixed(2);

    if (investedValue > 0.0 || double.tryParse(holding.sellAmt ?? '0.0')! > 0) {
      final profitValue =
          double.tryParse(holding.exchTsym![0].profitNloss ?? "0.00") ?? 0.0;
      holding.exchTsym![0].pNlChng = ((profitValue /
                  (investedValue +
                      (double.tryParse(holding.sellAmt ?? '0.0')!))) *
              100)
          .toStringAsFixed(2);
    }

    if (closeVal > 0) {
      holding.exchTsym![0].oneDayChg =
          ((lpDouble - closeVal) * qty).toStringAsFixed(2);
    }
  }

  // Recompute MTF headline totals (mirror of pnlHoldCal, synchronous since the
  // MTF list is small).
  void mtfPnlHoldCal() {
    if (_mtfHoldingsModel == null || _mtfHoldingsModel!.isEmpty) return;

    double totalPnl = 0.0;
    double dayChange = 0.0;
    double invest = 0.0;
    double currentVal = 0.0;

    for (final holding in _mtfHoldingsModel!) {
      if (holding.exchTsym == null || holding.exchTsym!.isEmpty) continue;
      final profitNlossStr = holding.exchTsym![0].profitNloss;
      final profitNloss = profitNlossStr != null
          ? (double.tryParse(profitNlossStr) ?? 0.0)
          : (double.tryParse(holding.rpnl ?? '0.0') ?? 0.0);
      final oneDayChg =
          double.tryParse(holding.exchTsym![0].oneDayChg ?? '0.0') ?? 0.0;
      final invested = double.tryParse(holding.invested ?? '0.0') ?? 0.0;
      final currentValue =
          double.tryParse(holding.currentValue ?? '0.0') ?? 0.0;

      totalPnl += profitNloss;
      dayChange += oneDayChg;
      invest += invested;
      currentVal += currentValue;
    }

    _totalMtfPnl = totalPnl;
    _mtfOneDayChng = dayChange;
    _totalMtfCurrentVal = currentVal;
    _totMtfInvest = invest.toStringAsFixed(2);
    _mtfOneDayChngPer = currentVal > 0 ? (dayChange / currentVal) * 100 : 0.0;
    _totMtfPnlPerc =
        invest > 0 ? ((totalPnl / invest) * 100).toStringAsFixed(2) : '0.00';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future fetchPositionBook(BuildContext context, bool isDay, {bool isRefresh = false}) async {
    // Reset flag at the start of every fetch so lastRefreshSucceeded
    // reflects THIS call's outcome, not a previous one.
    _positionFetchErrored = false;
    try {
      // Use separate loader states: full-screen loader for initial load, refresh loader for updates
      if (isRefresh) {
        _isRefreshing = true;
      } else if (_postionBookModel == null || _postionBookModel!.isEmpty) {
        _posloader = true;
      }
      notifyListeners();

      await setPortfolioupdate('P',context);
      // [POS_DIAG] Capture what the API actually returned vs what we had before.
      debugPrint('🔍 [POS_DIAG] fetchPositionBook — isDay=$isDay, old _postionBookModel.length=${_postionBookModel?.length ?? 0}, new _tpostionBookModel.length=${_tpostionBookModel?.length ?? 0}');
      if (_postionBookModel!.isNotEmpty) {
        if (_tpostionBookModel!.isNotEmpty) {
          _postionBookModel = _tpostionBookModel;
        } else {
          // [POS_DIAG] API returned empty but we had data — stale-data path.
          debugPrint('🔍 [POS_DIAG] ⚠️ STALE PATH — _tpostionBookModel is empty but _postionBookModel has ${_postionBookModel!.length} items. Old data kept.');
        }
      } else {
        _posloader = true;
        _allPostionList = [];
        _totPnL = "0.00";
        _totMtm = "0.00";
        _exitAll = false;
        _totBookedPnL = "0.00";
        _totUnRealMtm = '0.00';
        _posSelection = "All position";
        _postionBookModel = _tpostionBookModel;
        // Push zeroed P&L to PiP (no positions)
        if (PipService.isOpen) {
          PipService.updatePipValues(_totPnL, _totMtm);
        }
      }

      pref.setPosScrip(true);
      pref.setPosPrice(true);
      pref.setPosPerchnage(true);
      pref.setPosqty(true);
      pref.setPostion(false); // Default to show 0 qty positions at bottom
      if (_postionBookModel!.isNotEmpty) {
        if (_postionBookModel![0].stat != "Not_Ok") {
          for (var i = 0; i < _postionBookModel!.length; i++) {
            var element = _postionBookModel?[i];
            int tempqty = (int.parse(element!.daybuyqty.toString()) +
                        int.parse(element.cfbuyqty.toString())) <
                    (int.parse(element.daysellqty.toString()) +
                        int.parse(element.cfsellqty.toString()))
                ? int.parse(element.daybuyqty.toString())
                : int.parse(element.daysellqty.toString());
            tempqty =
                (tempqty * double.parse(element.prcftr.toString())).toInt();
            double tempavg = int.parse(element.netqty.toString()) > 0
                ? double.parse(element.daysellavgprc.toString()) -
                    double.parse(element.netupldprc.toString())
                : double.parse(element.netupldprc.toString()) -
                    double.parse(element.daybuyavgprc.toString());

            _postionBookModel?[i].temppnl =
                "${double.parse(tempavg.toString()) * int.parse(tempqty.toString())}";
          }

          ConstantName.sessCheck = true;
          _isDay = isDay;

          // Patch positions where the broker returned lp=0 using the last-good LTP
          // from the WebSocket cache. Happens when the API is called right after an
          // order fills — the broker's position aggregator lags the latest tick.
          // Without this, UI shows 0 P&L until the next df update or manual refresh.
          _patchStaleLtpsFromSocketCache();

          await splitPositionBook(isDay);
          // [POS_DIAG] After split: see how many ended up in each bucket.
          debugPrint('🔍 [POS_DIAG] splitPositionBook done — isDay=$isDay, openPosition=${_openPosition?.length ?? 0}, closedPosion=${_closedPosion?.length ?? 0}, allPostionList=${_allPostionList.length}');

          // Reapply sorting if previously set
          if (_currentPositionSortOption.isNotEmpty) {
            await sortPositions(sorting: _currentPositionSortOption);
          }

          await requestWSPosition(context: context, isSubscribe: true);

          // Fetch saved custom groups in background — doesn't block main flow.
          // Merges custom group data with live positions after fetch completes.
          _refreshCustomGroups();
        } else {
          // [POS_DIAG] API returned stat=Not_Ok — positions cleared.
          debugPrint('🔍 [POS_DIAG] ⚠️ stat=Not_Ok — emsg=${_postionBookModel![0].emsg}, clearing _openPosition');
          if (_postionBookModel![0].emsg ==
                  "Session Expired :  Invalid Session Key" &&
              _postionBookModel![0].stat == "Not_Ok") {
            ref.read(authProvider).ifSessionExpired(context);
          }
          _openPosition = [];
          // _postionBookModel = [];
        }
      }
      notifyListeners();
      return _postionBookModel;
    } catch (e) {
      // [POS_DIAG] Exception thrown during fetchPositionBook — positions may be stale.
      debugPrint('🔍 [POS_DIAG] ❌ fetchPositionBook CATCH — error: $e');
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Position Book", "Error": "$e"});
      // Exception during fetch counts as a refresh failure so
      // lastRefreshSucceeded reports false to the caller.
      _positionFetchErrored = true;
      notifyListeners();
    } finally {
      _posloader = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

// Fetching data from the api and stored in a variable

  Future fetchMFHoldings(context) async {
    final theme = ref.read(themeProvider);
    try {
      _mfhloader = true;
      // _mfHoldingsModel = [];
      _mfHoldingsModel = await api.getMFHolding();
      _mfTotInveest = 0.00;
      _mfTotCurrentVal = 0.00;
      _mfTotalPnl = 0.00;
      _mfTotalPnlPerchng = 0.00;
      pref.setMfScrip(true);
      pref.setMfPrice(true);
      pref.setMfPerchnage(true);
      pref.setMfqty(true);
      pref.setMfInvestby(true);
      // tabSize(theme);
      if (_mfHoldingsModel!.isNotEmpty) {
        if (_mfHoldingsModel![0].stat != "Not_Ok") {
          ConstantName.sessCheck = true;

// PNL Calculation

          for (var element in _mfHoldingsModel!) {
            element.invested = (double.parse("${element.uploadPrc ?? 0.00}") *
                    double.parse("${element.holdqty ?? 0.00}"))
                .toStringAsFixed(2);
            _mfTotInveest += double.parse("${element.invested ?? 0.00}");

            if (element.exchTsym![0].nav == null) {
              _mfQuotes = await api.getMFQutoes("${element.exchTsym![0].exch}",
                  "${element.exchTsym![0].token}");

              if (_mfQuotes!.emsg ==
                      "Session Expired :  Invalid Session Key" &&
                  _mfQuotes!.stat == "Not_Ok") {
                ref.read(authProvider).ifSessionExpired(context);
                return;
              }

              element.exchTsym![0].nav =
                  double.parse("${_mfQuotes!.nav ?? 0.00}").toStringAsFixed(2);
            }
            element.currentVal =
                (double.parse("${element.exchTsym![0].nav ?? 0.00}") *
                        double.parse("${element.holdqty ?? 0.00}"))
                    .toStringAsFixed(2);

            _mfTotCurrentVal += double.parse("${element.currentVal ?? 0.00}");

            element.exchTsym![0].pnl =
                (double.parse("${element.currentVal ?? 0.00}") -
                        double.parse("${element.invested ?? 0.00}"))
                    .toStringAsFixed(2);
            _mfTotalPnl += double.parse("${element.exchTsym![0].pnl ?? 0.00}");

            element.exchTsym![0].pnlPerChng =
                ((double.parse("${element.exchTsym![0].pnl ?? 0.00}") /
                            double.parse("${element.invested ?? 0.00}")) *
                        100)
                    .toStringAsFixed(2);
          }

          _mfTotalPnlPerchng = ((_mfTotalPnl / _mfTotInveest) * 100);
          _mfHoldingsModel!.sort(
              (a, b) => a.exchTsym![0].tsym!.compareTo(b.exchTsym![0].tsym!));
        } else {
          if (_mfHoldingsModel![0].emsg ==
                  "Session Expired :  Invalid Session Key" &&
              _mfHoldingsModel![0].stat == "Not_Ok") {
            ref.read(authProvider).ifSessionExpired(context);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API MF Holdings", "Error": "$e"});
      notifyListeners();
    } finally {
      _mfhloader = false;
    }
  }

  setTotPnlHoldings(double val) {
    _totalPnlHolding = val;
  }

  setOneDayChng(double val) {
    _oneDayChng = val;
  }

  // setTotPnlPercHolding(String val) {
  //   _totPnlPercHolding = val;
  // }

  setTotInvHoldings(double val) {
    _totInvesHold = val.toStringAsFixed(2);
  }

  setTotCurrentVal(double val) {
    _totalCurrentVal = val;
    _totPnlPercHolding = _totInvesHold == "0.00"
        ? "0.00"
        : ((double.parse("$_totalPnlHolding") / double.parse(_totInvesHold)) *
                100)
            .toStringAsFixed(2);
  }

  setOneDayChngPer() {
    _oneDayChngPer = ((_oneDayChng / _totalCurrentVal) * 100);
  }

  Timer? _timer;
  cancelTimer() {
    times = false;
    if (_timer != null) {
      _timer!.cancel();
    }
  }

  bool times = false;

  void timerfunc() {
    if (!times) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) {
        times = true;
        pnlHoldCal();
      });
    }
  }

  pnlHoldCal() {
    // Early return if no holdings
    if (holdingsModel == null || holdingsModel!.isEmpty) return;

    // Use local variables for performance and minimize string conversions
    double totalPnl = 0.0;
    double dayChange = 0.0;
    double invest = 0.0;
    double currentVal = 0.0;

    // Process holdings in batches to reduce UI blocking
    const int batchSize = 10;
    final int totalHoldings = holdingsModel!.length;
    int processedCount = 0;

    void processBatch(int startIndex) {
      final int endIndex = (startIndex + batchSize) < totalHoldings
          ? startIndex + batchSize
          : totalHoldings;

      for (int i = startIndex; i < endIndex; i++) {
        final holding = holdingsModel![i];

        // Per-row profitNloss is set by _updateDerivedValues as
        // (currentValue - invested) + rpnl, so it already includes the
        // realized component. Falling back to rpnl only when profitNloss
        // hasn't been written yet (pre-first-WS-tick window) keeps sold
        // rows from briefly contributing 0 to the aggregate.
        final profitNlossStr = holding.exchTsym![0].profitNloss;
        final profitNloss = profitNlossStr != null
            ? (double.tryParse(profitNlossStr) ?? 0.0)
            : (double.tryParse(holding.rpnl ?? '0.0') ?? 0.0);
        final oneDayChg =
            double.tryParse(holding.exchTsym![0].oneDayChg ?? '0.0') ?? 0.0;
        final invested = double.tryParse(holding.invested ?? '0.0') ?? 0.0;
        final currentValue =
            double.tryParse(holding.currentValue ?? '0.0') ?? 0.0;

        // Accumulate totals
        totalPnl += profitNloss;
        dayChange += oneDayChg;
        invest += invested;
        currentVal += currentValue;
      }

      processedCount = endIndex;

      // If there are more holdings to process, schedule next batch
      if (processedCount < totalHoldings) {
        Future.microtask(() => processBatch(processedCount));
      } else {
        // All batches processed, update class variables
        _totalPnlHolding = totalPnl;
        _oneDayChng = dayChange;
        _totalCurrentVal = currentVal;
        _totInvesHold = invest.toStringAsFixed(2);

        // Calculate percentages
        _oneDayChngPer = currentVal > 0 ? (dayChange / currentVal) * 100 : 0.0;
        _totPnlPercHolding = invest > 0
            ? ((totalPnl / invest) * 100).toStringAsFixed(2)
            : '0.00';
        // Use post-frame callback to avoid mouse tracker assertion errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    }

    // Start processing in batches
    processBatch(0);
  }

  // Implement correct MTM and PnL calculations
  positionCal(bool isDay) {
    double totalMtm = 0.0;
    double totalPnl = 0.0;
    double unRealMtm = 0.0;
    double bookPnl = 0.0;

    for (var position in _allPostionList) {
      final lp = double.tryParse(position.lp ?? "0.00") ?? 0.0;
      final prcFtr = double.tryParse(position.prcftr ?? "1.0") ?? 1.0;
      final mult = double.tryParse(position.mult ?? "1.0") ?? 1.0;
      final lotSize = double.tryParse(position.ls ?? "1.0") ?? 1.0;
      final netQty = int.tryParse(position.netqty ?? "0") ?? 0;

      final dayBuyQty = int.tryParse(position.daybuyqty ?? "0") ?? 0;
      final daySellQty = int.tryParse(position.daysellqty ?? "0") ?? 0;
      final cfBuyQty = int.tryParse(position.cfbuyqty ?? "0") ?? 0;
      final cfSellQty = int.tryParse(position.cfsellqty ?? "0") ?? 0;

      final dayBuyAmt = double.tryParse(position.daybuyamt ?? "0.00") ?? 0.0;
      final daySellAmt = double.tryParse(position.daysellamt ?? "0.00") ?? 0.0;
      final upldPrc = double.tryParse(position.upldprc ?? "0.00") ?? 0.0;
      final netAvgPrc = double.tryParse(position.netavgprc ?? "0.00") ?? 0.0;
      final netUpldPrc = double.tryParse(position.netupldprc ?? "0.00") ?? 0.0;
      final rpnl = double.tryParse(position.rpnl ?? "0.00") ?? 0.0;

      // Net Buy/Sell Qty
      final netBuyQty = dayBuyQty + cfBuyQty;
      final netSellQty = daySellQty + cfSellQty;

      // --- Assign qty and avgPrc as per isDay ---
      int qty = 0;
      double avgPrc = 0.0;

      if (isDay) {
        // qty logic for day
        if (position.exch == "MCX") {
          qty = ((dayBuyQty - daySellQty) / lotSize).toInt();
        } else {
          qty = dayBuyQty - daySellQty;
        }
        position.qty = qty.toString();

        // avgPrc logic for day
        position.avgPrc = (netQty == 0 ? "0.00" : position.dayavgprc ?? "0.00");
        avgPrc = double.tryParse(position.avgPrc ?? "0.00") ?? 0.0;
      } else {
        // qty logic for net
        qty = netQty;
        position.qty = qty.toString();

        // avgPrc logic for net
        if (qty == 0) {
          position.avgPrc = "0.00";
        } else {
          // If netupldprc != 0, use that, else netavgprc
          position.avgPrc = (netUpldPrc != 0.0)
              ? netUpldPrc.toStringAsFixed(2)
              : netAvgPrc.toStringAsFixed(2);
        }
        avgPrc = double.tryParse(position.avgPrc ?? "0.00") ?? 0.0;
      }

      // ActualBuyAvgPrice (for BookedPNL calculation)
      double actualBuyAvgPrice = 0.0;
      if (netBuyQty != 0) {
        actualBuyAvgPrice =
            ((dayBuyAmt / mult) + (upldPrc * prcFtr * cfBuyQty)) / netBuyQty;
      }

      // ActualSellAvgPrice (for BookedPNL calculation)
      double actualSellAvgPrice = 0.0;
      if (netSellQty != 0) {
        actualSellAvgPrice =
            ((daySellAmt / mult) + (upldPrc * prcFtr * cfSellQty)) / netSellQty;
      }

      // ActualBookedPNL
      double actualBookedPnl = 0.0;
      if (netQty > 0) {
        actualBookedPnl =
            (actualSellAvgPrice - actualBuyAvgPrice) * netSellQty * mult;
      } else {
        actualBookedPnl =
            (actualSellAvgPrice - actualBuyAvgPrice) * netBuyQty * mult;
      }

      // For MTM, avgprc = netavgprc
      double actualUnrealizedMtm = netQty * prcFtr * mult * (lp - netAvgPrc);

      // For PnL, avgprc = netupldprc if not 0 else netavgprc
      double avgPrcForUnrealized = netUpldPrc != 0.0 ? netUpldPrc : netAvgPrc;
      double actualUnrealizedPnl =
          netQty * prcFtr * mult * (lp - avgPrcForUnrealized);

      // MTM = rpnl + ActualUnrealizedMtoM
      double mtm = rpnl + actualUnrealizedMtm;

      // PnL = ActualBookedPNL + ActualUnrealizedMtoM
      double pnl = actualBookedPnl + actualUnrealizedPnl;

      // Assign back to position
      position.mTm = mtm.toStringAsFixed(2);
      position.profitNloss = pnl.toStringAsFixed(2);

      // Totals
      totalMtm += mtm;
      totalPnl += pnl;
      unRealMtm += actualUnrealizedPnl;
      bookPnl += actualBookedPnl;
    }

    _totMtm = totalMtm.toStringAsFixed(2);
    _totPnL = totalPnl.toStringAsFixed(2);
    _totUnRealMtm = unRealMtm.toStringAsFixed(2);
    _totBookedPnL = bookPnl.toStringAsFixed(2);
    // Push live P&L to PiP window if open
    if (PipService.isOpen) {
      final positions = PipService.buildPositionItems(
        groupedBySymbol: _groupedBySymbol,
        groupPositionSym: _groupPositionSym,
      );
      PipService.updatePipValues(_totPnL, _totMtm, positions: positions);
    }
    // Use post-frame callback to avoid mouse tracker assertion errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // websocket Connection Request for Position scrip
  requestWSPosition(
      {required bool isSubscribe, required BuildContext context}) {
    // On web, WebSubscriptionManager handles all subscriptions
    // Skip unsubscribe here to avoid conflicts with multi-panel layout
    if (kIsWeb && !isSubscribe) return;

    try {
      String input = "";

      if (_postionBookModel != null) {
        if (_postionBookModel!.isNotEmpty &&
            _postionBookModel![0].stat != "Not_Ok") {
          for (var element in _postionBookModel!) {
            input += "${element.exch}|${element.token}#";
          }
        }
      }
      if (input.isNotEmpty) {
        // ConstantName.lastSubscribe = input;
        ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? (kIsWeb ? "d" : "t") : "u",
            context: context);
      }
    } catch (e) {}

    // notifyListeners();
  }

// websocket Connection Request for Holdings scrip
  requestWSHoldings(
      {required bool isSubscribe, required BuildContext context}) {
    // On web, WebSubscriptionManager handles all subscriptions
    // Skip unsubscribe here to avoid conflicts with multi-panel layout
    if (kIsWeb && !isSubscribe) return;

    try {
      String input = "";
      if (_holdingsModel != null) {
        if (_holdingsModel!.isNotEmpty) {
          if (_holdingsModel![0].stat != "Not_Ok") {
            for (var i = 0; i < _holdingsModel!.length; i++) {
              input +=
                  "${_holdingsModel![i].exchTsym![0].exch}|${_holdingsModel![i].exchTsym![0].token}#";
            }
          }
        }
      }
      if (input.isNotEmpty) {
        // ConstantName.lastSubscribe = input;
        ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? (kIsWeb ? "d" : "t") : "u",
            context: context);
      }
    } catch (e) {}
  }

  requestallHoldings(
      {required bool isSubscribe, required BuildContext context}) {
    try {
      if (_subscr.isNotEmpty) {
        ref.read(websocketProvider).establishConnection(
            channelInput: _subscr, task: kIsWeb ? 'd' : 't', context: context);
      }
    } catch (e) {}
  }

  exitGroupedPosition(BuildContext context, List positionData) async {
    if (positionData.isNotEmpty) {
      for (var element in positionData) {
        if (element['qty'].toString() != "0") {
          if (((element['s_prdt_ali'] == "MIS" ||
                  element['s_prdt_ali'] == "CNC") ||
              element['s_prdt_ali'] == "NRML")) {
            PlaceOrderInput placeOrderInput = PlaceOrderInput(
                amo: "",
                blprc: '',
                bpprc: '',
                dscqty: "",
                exch: "${element['exch']}",
                prc: "0",
                prctype: "MKT",
                prd: "${element['prd']}",
                qty: element['qty'].toString().replaceAll("-", ""),
                ret: "DAY",
                trailprc: '',
                trantype: int.parse(element['qty'] ?? "0") < 0 ? 'B' : 'S',
                trgprc: "",
                tsym: "${element['tsym']}",
                mktProt: '',
                channel: defaultTargetPlatform == TargetPlatform.android
                    ? '${ref.read(authProvider).deviceInfo["brand"]}'
                    : "${ref.read(authProvider).deviceInfo["model"]}");
            _placeOrderModel = await api.getPlaceOrder(
                placeOrderInput, ref.read(orderProvider).ip);

            if (_placeOrderModel!.emsg ==
                    "Session Expired :  Invalid Session Key" &&
                _placeOrderModel!.stat == "Not_Ok") {
              ref.read(authProvider).ifSessionExpired(context);
              return;
            }

            if (_placeOrderModel!.stat!.toLowerCase() != "ok") {
              break;
            }
          }
        }
      }
      await fetchPositionBook(context, _isDay);
    }
  }
// Sort Holding data (LTP,Symbol,Change,Per Change)

  filterHoldings(
      {required String sorting, required BuildContext context}) async {
    // Store the current sort option
    _currentHoldingSortOption = sorting;

    if (sorting == "ASC") {
      _holdingsModel!
          .sort((a, b) => a.exchTsym![0].tsym!.compareTo(b.exchTsym![0].tsym!));
    } else if (sorting == "DSC") {
      _holdingsModel!
          .sort((a, b) => b.exchTsym![0].tsym!.compareTo(a.exchTsym![0].tsym!));
    } else if (sorting == "LTPDSC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(
                b.exchTsym![0].lp == null || b.exchTsym![0].lp == "null"
                    ? "0.00"
                    : "${b.exchTsym![0].lp}")
            .compareTo(double.parse(
                a.exchTsym![0].lp == null || a.exchTsym![0].lp == "null"
                    ? "0.00"
                    : "${a.exchTsym![0].lp}"));
      });
    } else if (sorting == "LTPASC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(
                a.exchTsym![0].lp == null || a.exchTsym![0].lp == "null"
                    ? "0.00"
                    : "${a.exchTsym![0].lp}")
            .compareTo(double.parse(
                b.exchTsym![0].lp == null || b.exchTsym![0].lp == "null"
                    ? "0.00"
                    : "${b.exchTsym![0].lp}"));
      });
    } else if (sorting == "QTYDSC") {
      _holdingsModel!.sort((a, b) {
        return int.parse(b.currentQty == null || b.currentQty == "null"
                ? "0.00"
                : "${b.currentQty}")
            .compareTo(int.parse(a.currentQty == null || a.currentQty == "null"
                ? "0.00"
                : "${a.currentQty}"));
      });
    } else if (sorting == "QTYASC") {
      _holdingsModel!.sort((a, b) {
        return int.parse(a.currentQty == null || a.currentQty == "null"
                ? "0.00"
                : "${a.currentQty}")
            .compareTo(int.parse(b.currentQty == null || b.currentQty == "null"
                ? "0.00"
                : "${b.currentQty}"));
      });
    } else if (sorting == "PCDESC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(b.exchTsym![0].perChange == null ||
                    b.exchTsym![0].perChange == "null"
                ? "0.00"
                : "${b.exchTsym![0].perChange}")
            .compareTo(double.parse(a.exchTsym![0].perChange == null ||
                    a.exchTsym![0].perChange == "null"
                ? "0.00"
                : "${a.exchTsym![0].perChange}"));
      });
    } else if (sorting == "PCASC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(a.exchTsym![0].perChange == null ||
                    a.exchTsym![0].perChange == "null"
                ? "0.00"
                : "${a.exchTsym![0].perChange}")
            .compareTo(double.parse(b.exchTsym![0].perChange == null ||
                    b.exchTsym![0].perChange == "null"
                ? "0.00"
                : "${b.exchTsym![0].perChange}"));
      });
    } else if (sorting == "LTPPCDESC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(b.exchTsym![0].pNlChng == null ||
                    b.exchTsym![0].pNlChng == "null"
                ? "0.00"
                : "${b.exchTsym![0].pNlChng}")
            .compareTo(double.parse(a.exchTsym![0].pNlChng == null ||
                    a.exchTsym![0].pNlChng == "null"
                ? "0.00"
                : "${a.exchTsym![0].pNlChng}"));
      });
    } else if (sorting == "LTPPCASC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(a.exchTsym![0].pNlChng == null ||
                    a.exchTsym![0].pNlChng == "null"
                ? "0.00"
                : "${a.exchTsym![0].pNlChng}")
            .compareTo(double.parse(b.exchTsym![0].pNlChng == null ||
                    b.exchTsym![0].pNlChng == "null"
                ? "0.00"
                : "${b.exchTsym![0].pNlChng}"));
      });
    } else if (sorting == "INVDESC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(b.invested == null || b.invested == "null"
                ? "0.00"
                : "${b.invested}")
            .compareTo(double.parse(a.invested == null || a.invested == "null"
                ? "0.00"
                : "${a.invested}"));
      });
    } else if (sorting == "INVASC") {
      _holdingsModel!.sort((a, b) {
        return double.parse(a.invested == null || a.invested == "null"
                ? "0.00"
                : "${a.invested}")
            .compareTo(double.parse(b.invested == null || b.invested == "null"
                ? "0.00"
                : "${b.invested}"));
      });
    }

    notifyListeners();
  }
// Sort MF Holding data (LTP,Symbol,Change,Per Change)

  filterMfHoldings(
      {required String sorting, required BuildContext context}) async {
    if (sorting == "ASC") {
      _mfHoldingsModel!.sort(
          (a, b) => a.exchTsym![0].cname!.compareTo(b.exchTsym![0].cname!));
    } else if (sorting == "DSC") {
      _mfHoldingsModel!.sort(
          (a, b) => b.exchTsym![0].cname!.compareTo(a.exchTsym![0].cname!));
    } else if (sorting == "LTPDSC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(
                b.exchTsym![0].nav == null || b.exchTsym![0].nav == "null"
                    ? "0.00"
                    : "${b.exchTsym![0].nav}")
            .compareTo(double.parse(
                a.exchTsym![0].nav == null || a.exchTsym![0].nav == "null"
                    ? "0.00"
                    : "${a.exchTsym![0].nav}"));
      });
    } else if (sorting == "LTPASC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(
                a.exchTsym![0].nav == null || a.exchTsym![0].nav == "null"
                    ? "0.00"
                    : "${a.exchTsym![0].nav}")
            .compareTo(double.parse(
                b.exchTsym![0].nav == null || b.exchTsym![0].nav == "null"
                    ? "0.00"
                    : "${b.exchTsym![0].nav}"));
      });
    } else if (sorting == "QTYDSC") {
      _mfHoldingsModel!.sort((a, b) {
        return int.parse(b.holdqty == null || b.holdqty == "null"
                ? "0.00"
                : "${b.holdqty}")
            .compareTo(int.parse(a.holdqty == null || a.holdqty == "null"
                ? "0.00"
                : "${a.holdqty}"));
      });
    } else if (sorting == "QTYASC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(a.holdqty == null || a.holdqty == "null"
                ? "0.00"
                : "${a.holdqty}")
            .compareTo(double.parse(b.holdqty == null || b.holdqty == "null"
                ? "0.00"
                : "${b.holdqty}"));
      });
    } else if (sorting == "PCDESC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(b.exchTsym![0].pnlPerChng == null ||
                    b.exchTsym![0].pnlPerChng == "null"
                ? "0.00"
                : "${b.exchTsym![0].pnlPerChng}")
            .compareTo(double.parse(a.exchTsym![0].pnlPerChng == null ||
                    a.exchTsym![0].pnlPerChng == "null"
                ? "0.00"
                : "${a.exchTsym![0].pnlPerChng}"));
      });
    } else if (sorting == "PCASC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(a.exchTsym![0].pnlPerChng == null ||
                    a.exchTsym![0].pnlPerChng == "null"
                ? "0.00"
                : "${a.exchTsym![0].pnlPerChng}")
            .compareTo(double.parse(b.exchTsym![0].pnlPerChng == null ||
                    b.exchTsym![0].pnlPerChng == "null"
                ? "0.00"
                : "${b.exchTsym![0].pnlPerChng}"));
      });
    } else if (sorting == "INVDESC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(b.invested == null || b.invested == "null"
                ? "0.00"
                : "${b.invested}")
            .compareTo(double.parse(a.invested == null || a.invested == "null"
                ? "0.00"
                : "${a.invested}"));
      });
    } else if (sorting == "INVASC") {
      _mfHoldingsModel!.sort((a, b) {
        return double.parse(a.invested == null || a.invested == "null"
                ? "0.00"
                : "${a.invested}")
            .compareTo(double.parse(b.invested == null || b.invested == "null"
                ? "0.00"
                : "${b.invested}"));
      });
    }

    notifyListeners();
  }

// Sort position data (LTP,Symbol,Change,Per Change)
  sortPositions({required String sorting}) async {
    // Store the current sort option
    _currentPositionSortOption = sorting;

    if (sorting == "ASC") {
      _allPostionList.sort((a, b) => a.tsym!.compareTo(b.tsym!));
    } else if (sorting == "DSC") {
      _allPostionList.sort((a, b) => b.tsym!.compareTo(a.tsym!));
    } else if (sorting == "LTPDSC") {
      _allPostionList.sort((a, b) {
        return double.parse(b.lp == null || b.lp == "null" ? "0.00" : "${b.lp}")
            .compareTo(double.parse(
                a.lp == null || a.lp == "null" ? "0.00" : "${a.lp}"));
      });
    } else if (sorting == "LTPASC") {
      _allPostionList.sort((a, b) {
        return double.parse(a.lp == null || a.lp == "null" ? "0.00" : "${a.lp}")
            .compareTo(double.parse(
                b.lp == null || b.lp == "null" ? "0.00" : "${b.lp}"));
      });
    } else if (sorting == "QTYDSC") {
      _allPostionList.sort((a, b) {
        return int.parse(b.qty == null || b.qty == "null" ? "0" : "${b.qty}")
            .compareTo(
                int.parse(a.qty == null || a.qty == "null" ? "0" : "${a.qty}"));
      });
    } else if (sorting == "QTYASC") {
      _allPostionList.sort((a, b) {
        return int.parse(a.qty == null || a.qty == "null" ? "0" : "${a.qty}")
            .compareTo(int.parse(
                b.qty == null || b.qty == "null" ? "0.00" : "${b.qty}"));
      });
    } else if (sorting == "PCDESC") {
      _allPostionList.sort((a, b) {
        return double.parse(b.perChange == null || b.perChange == "null"
                ? "0.00"
                : "${b.perChange}")
            .compareTo(double.parse(a.perChange == null || a.perChange == "null"
                ? "0.00"
                : "${a.perChange}"));
      });
    } else if (sorting == "PCASC") {
      _allPostionList.sort((a, b) {
        return double.parse(a.perChange == null || a.perChange == "null"
                ? "0.00"
                : "${a.perChange}")
            .compareTo(double.parse(b.perChange == null || b.perChange == "null"
                ? "0.00"
                : "${b.perChange}"));
      });
    } else if (sorting == "Close") {
      _allPostionList.sort((a, b) {
        return int.parse("${a.netqty}").compareTo(int.parse("${b.netqty}"));
      });
    } else if (sorting == "Open") {
      // Show 0 quantity positions (closed) at the top
      _allPostionList.sort((a, b) {
        int aQty = int.parse("${a.netqty}");
        int bQty = int.parse("${b.netqty}");

        // If both are closed (zero), maintain original order
        if (aQty == 0 && bQty == 0) return 0;
        // If both are open (non-zero), maintain original order
        if (aQty != 0 && bQty != 0) return 0;
        // If a is closed (zero), move it to top
        if (aQty == 0) return -1;
        // If b is closed (zero), move it to top
        if (bQty == 0) return 1;
        // Fallback to quantity comparison
        return aQty.compareTo(bQty);
      });
    } else if (sorting == "OpenDSC") {
      // Show 0 quantity positions (closed) at the bottom
      _allPostionList.sort((a, b) {
        int aQty = int.parse("${a.netqty}");
        int bQty = int.parse("${b.netqty}");

        // If both are closed (zero), maintain original order
        if (aQty == 0 && bQty == 0) return 0;
        // If both are open (non-zero), maintain original order
        if (aQty != 0 && bQty != 0) return 0;
        // If a is closed (zero), move it to bottom
        if (aQty == 0) return 1;
        // If b is closed (zero), move it to bottom
        if (bQty == 0) return -1;
        // Fallback to quantity comparison
        return aQty.compareTo(bQty);
      });
    }

    notifyListeners();
  }

  exitPosition(BuildContext context, bool exitAll) async {
    // Set loading state to true at the beginning
    // if (exitAll) {
    //   _isExitingAll = true;
    //   notifyListeners();
    // }

    try {
      for (var element in _allPostionList) {
        if (element.qty != "0") {
          if (((element.sPrdtAli == "MIS" || element.sPrdtAli == "CNC") ||
              element.sPrdtAli == "NRML")) {
            if (exitAll) {
              PlaceOrderInput placeOrderInput = PlaceOrderInput(
                  amo: "",
                  blprc: '',
                  bpprc: '',
                  dscqty: "",
                  exch: "${element.exch}",
                  prc: "0",
                  prctype: "MKT",
                  prd: "${element.prd}",
                  qty: element.qty!.replaceAll("-", ""),
                  ret: "DAY",
                  trailprc: '',
                  trantype: int.parse(element.qty!) < 0 ? 'B' : 'S',
                  trgprc: "",
                  tsym: "${element.tsym}",
                  mktProt: '',
                  channel: defaultTargetPlatform == TargetPlatform.android
                      ? '${ref.read(authProvider).deviceInfo["brand"]}'
                      : "${ref.read(authProvider).deviceInfo["model"]}",
                      frzqty: ((int.parse(element.frzqty.toString()) /
                              int.parse(element.ls.toString()))
                          .floor() *
                      int.parse(element.ls.toString())));
               await fetchExitPosition(context, placeOrderInput, true, true);
                      
              // _placeOrderModel = await api.getPlaceOrder(
              //     placeOrderInput, ref.read(orderProvider).ip);

              

              if (_placeOrderModel!.emsg ==
                      "Session Expired :  Invalid Session Key" &&
                  _placeOrderModel!.stat == "Not_Ok") {
                ref.read(authProvider).ifSessionExpired(context);
                return;
              }

                  if (_placeOrderModel!.stat! == "Ok") {
                    successMessage(context, "Position exited successfully.");
                  }

              if (_placeOrderModel!.stat!.toLowerCase() != "ok") {
                break;
              }
            } else if (element.isExitSelection == true) {
              PlaceOrderInput placeOrderInput = PlaceOrderInput(
                  amo: "",
                  blprc: '',
                  bpprc: '',
                  dscqty: "",
                  exch: "${element.exch}",
                  prc: "0",
                  prctype: "MKT",
                  prd: "${element.prd}",
                  qty: element.qty!.replaceAll("-", ""),
                  ret: "DAY",
                  trailprc: '',
                  trantype: int.parse(element.qty!) < 0 ? 'B' : 'S',
                  trgprc: "",
                  tsym: "${element.tsym}",
                  mktProt: '',
                  channel: defaultTargetPlatform == TargetPlatform.android
                      ? '${ref.read(authProvider).deviceInfo["brand"]}'
                      : "${ref.read(authProvider).deviceInfo["model"]}",
                  frzqty: ((int.parse(element.frzqty.toString()) /
                              int.parse(element.ls.toString()))
                          .floor() *
                      int.parse(element.ls.toString())));
              await fetchExitPosition(context, placeOrderInput, true, true);
            }
          }
        }
      }
    } finally {
      _exitPositionQty = 0;
      // Reset loading state when done (whether successful or not)
      // if (exitAll) {
      //   _isExitingAll = false;
      //   notifyListeners();
      // }
    }

    // ref.read(indexListProvider).bottomMenu(2);
    // Navigator.pop(context);
  }

  exitAllHoldings(BuildContext context) async {
    for (var element in _sealableHoldings) {
      // Only exit holdings that are selected
      if (element.isExitHoldings!) {
        PlaceOrderInput placeOrderInput = PlaceOrderInput(
            amo: "",
            blprc: '',
            bpprc: '',
            dscqty: "",
            exch: "${element.exchTsym![0].exch}",
            prc: "0",
            prctype: "MKT",
            prd: "${element.prd}",
            qty: "${element.saleableQty}",
            ret: "DAY",
            trailprc: '',
            trantype: 'S',
            trgprc: "",
            tsym: "${element.exchTsym![0].tsym}",
            mktProt: '',
            channel: defaultTargetPlatform == TargetPlatform.android
                ? '${ref.read(authProvider).deviceInfo["brand"]}'
                : "${ref.read(authProvider).deviceInfo["model"]}",
            frzqty: 0);
        await fetchExitPosition(context, placeOrderInput, false, false);
      }
    }
  }

// Holding search by Trade symbol
  holdingSearch(String value, BuildContext context) {
    if (value.length > 0) {
      _holdingSearchItem = [];
      _holdingSearchItem = _holdingsModel!
          .where((element) => element.exchTsym![0].tsym!
              .toUpperCase()
              .contains(value.toUpperCase()))
          .toList();
    } else {
      _holdingSearchItem = [];
    }
    notifyListeners();
  }

// MF Holding search by Trade symbol
  mfHoldingSearch(String value, BuildContext context) {
    if (value.length > 0) {
      _mfHoldingSearchItem = [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _mfHoldingSearchItem = _mfHoldingsModel!
          .where((element) => element.exchTsym![0].tsym!
              .toUpperCase()
              .contains(value.toUpperCase()))
          .toList();
      if (_mfHoldingSearchItem!.isEmpty) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(context, 'No Data Found');
        } else {
        warningMessage(context, 'No Data Found');
        }
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } else {
      _mfHoldingSearchItem = [];
    }
    notifyListeners();
  }

// Fetching data from the api and stored in a variable
  positionSearch(String value, BuildContext context) {
    if (value.length > 0) {
      // _showSearchPosition = true;
      _positionSearchItem = [];
      _positionSearchItem = _allPostionList
          .where((element) =>
              element.tsym!.toLowerCase().contains(value.toLowerCase()) ||
              (element.symbol?.toLowerCase().contains(value.toLowerCase()) ??
                  false))
          .toList();
    } else {
      // _showSearchPosition = false;
      _positionSearchItem = [];
    }
    notifyListeners();
  }

// Fetching data from the api and stored in a variable
  Future fetchPosGroupSymbol(String name, bool isCreateGrp) async {
    try {
      _getPositionGroupSymbol = await api.getGroupPosition();

      _exitAll = false;

      if (isCreateGrp) {
        _posSelection = "Group by symbol";
      }

      getPositionGroupNames();

      // Recalculate P&L for all groups after grouping
      for (var symbol in _groupPositionSym) {
        if (_groupedBySymbol.containsKey(symbol)) {
          final groupData = _groupedBySymbol[symbol]['groupList'];
          final isCustomGrp = _groupedBySymbol[symbol]['isCustomGrp'] ?? false;
          if (groupData != null && groupData.isNotEmpty) {
            positionGroupCal(_isDay, groupData, symbol, isCustomGrp);
          }
        }
      }
    } catch (_) {}
    finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Refresh custom groups in the background without blocking the main flow.
  /// Fetches saved groups from API, syncs their positions with the live
  /// position book, removes stale positions from both local state AND
  /// the server (via deletePositionGrpSym API), and recalculates P&L.
  void _refreshCustomGroups() async {
    try {
      _getPositionGroupSymbol = await api.getGroupPosition();

      // Sync custom group positions with live data from _allPostionList.
      // Positions that no longer exist are removed from the server too.
      for (var group in _getPositionGroupSymbol) {
        if (group.posdata == null || group.posdata!.isEmpty) continue;

        final groupName = group.posname ?? '';
        final syncedPositions = <PositionBookModel>[];
        final staleSymbols = <String>[];

        for (var savedPos in group.posdata!) {
          // Find matching live position by token + prd
          final livePos =
              _allPostionList.cast<PositionBookModel?>().firstWhere(
                    (p) => p?.token == savedPos.token && p?.prd == savedPos.prd,
                    orElse: () => null,
                  );
          if (livePos != null) {
            syncedPositions.add(livePos);
          } else if (savedPos.tsym != null && groupName.isNotEmpty) {
            // Position no longer exists — queue for server cleanup
            staleSymbols.add(savedPos.tsym!);
          }
        }

        group.posdata = syncedPositions;

        // Remove stale positions from server in background (fire-and-forget)
        for (var tsym in staleSymbols) {
          api.deletePositionGrpSym(groupName, tsym).ignore();
        }
      }

      // Rebuild groups with synced data
      getPositionGroupNames();

      // Recalculate P&L for all groups
      for (var symbol in _groupPositionSym) {
        if (_groupedBySymbol.containsKey(symbol)) {
          final groupData = _groupedBySymbol[symbol]['groupList'];
          final isCustomGrp =
              _groupedBySymbol[symbol]['isCustomGrp'] ?? false;
          if (groupData != null && groupData.isNotEmpty) {
            positionGroupCal(_isDay, groupData, symbol, isCustomGrp);
          }
        }
      }
    } catch (_) {}
  }

// Fetching data from the api and stored in a variable
  Future fetchGroupName(String name, BuildContext c, bool isCreateGrp) async {
    try {

      // _posloader = true;
      _groupName = await api.createGroupName(name);


      if (_groupName!.status == "Data inserted") {
        //  ref.read(indexListProvider).bottomMenu(1);
        await fetchPosGroupSymbol(name, isCreateGrp);
        successMessage(c, "Group '$name' created successfully");
        // Navigator.pop is already called in create_group_web.dart before this method
      } else {
        // Handle error cases
        final status = _groupName!.status ?? "Unknown error";
        if (status.toLowerCase().contains("already exists") ||
            status.toLowerCase().contains("duplicate")) {
          warningMessage(c, "Group name '$name' already exists");
        } else {
          error(c, status);
        }
      }
    } catch (e, stackTrace) {
    } finally {
      // _posloader = false;
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchAddGroupSymbol(String name, BuildContext c, Map data) async {
    try {
      _groupName = await api.addGroupNameSymbol(name, data);

      if (_groupName!.status == "symbol added") {
        await fetchPosGroupSymbol(name, true);
        successMessage(c, "Symbol added to group '$name' successfully");
        // Navigator.pop(c);
      } else {
        final status = _groupName!.status ?? "Unknown error";
        error(c, "$status to group '$name'");
      }
    } catch (e) {}
  }

// Fetching data from the api and stored in a variable
  Future fetchDeleteGroupName(String name, BuildContext c) async {
    try {
      // _posloader = true;
      _groupName = await api.deletePositionGrpName(name);

      if (_groupName!.status == "Data deleted") {
        await fetchPosGroupSymbol(name, true);
        successMessage(c, "Group '$name' deleted successfully");
        // Navigator.pop(c);
      } else {
        final status = _groupName!.status ?? "Unknown error";
        error(c, status);
      }
    } finally {
      // _posloader = false;
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchDeleteGroupSymbol(
      String name, BuildContext c, String tsym) async {
    try {
      _groupName = await api.deletePositionGrpSym(name, tsym);

      if (_groupName!.status == "symbol removed") {
        await fetchPosGroupSymbol(name, false);
        successMessage(c, "Symbol '$tsym' removed from group '$name'");
        // Navigator.pop(c);
      } else {
        final status = _groupName!.status ?? "Unknown error";
        error(c, status);
      }
    } catch (e) {}
  }

  // Optimized for fast updates from websocket
  void updateHoldingValues(String token, Map<String, dynamic> socketData) {
    // Early return if no token or data
    if (token == null || socketData == null || _holdingsModel == null) return;

    // Use indexWhere with efficient stopping
    var index = -1;
    for (int i = 0; i < _holdingsModel!.length; i++) {
      if (_holdingsModel![i].exchTsym![0].token == token) {
        index = i;
        break;
      }
    }

    if (index == -1) return; // Not found, nothing to update

    var holding = _holdingsModel![index];
    bool hasUpdates = false;

    // Get new values from socket data
    final newLp = socketData['lp']?.toString();
    final newPc = socketData['pc']?.toString();
    final newChng = socketData['chng']?.toString();
    final newClose = socketData['c']?.toString();

    // Only update if valid values are received
    if (_isValidValue(newLp)) {
      holding.exchTsym![0].lp = newLp;
      hasUpdates = true;
    }

    if (_isValidValue(newPc)) {
      holding.exchTsym![0].perChange = newPc;
      hasUpdates = true;
    }

    if (_isValidValue(newChng)) {
      holding.exchTsym![0].change = newChng;
      hasUpdates = true;
    }

    if (_isValidValue(newClose)) {
      holding.exchTsym![0].close = newClose;
      hasUpdates = true;
    }

    // Only recalculate if we've actually updated any values
    if (hasUpdates) {
      _updateDerivedValues(holding);
    }
  }

  // Helper method to check if a value is valid
  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  // Helper method to update derived values
  void _updateDerivedValues(HoldingsModel holding) {
    final qty = holding.currentQty ?? 0;
    final usedqty = int.parse(holding.usedqty ?? "0");
    if (qty < 0) return; // Nothing to calculate for zero quantity

    final lpDouble = double.tryParse(holding.exchTsym![0].lp ?? '0.0') ?? 0.0;
    if (lpDouble <= 0) return; // Can't calculate with invalid price

    // Update current value
    holding.currentValue = (qty * lpDouble).toStringAsFixed(2);

    // Get average cost with fallback to closing price
    final closeVal =
        double.tryParse(holding.exchTsym![0].close ?? "0.00") ?? 0.0;
    final avgCost = double.tryParse(holding.upldprc == "0.00"
            ? (closeVal > 0
                ? closeVal.toString()
                : holding.exchTsym![0].close ?? '0.0')
            : holding.upldprc ?? '0.00') ??
        0.0;

    if (avgCost <= 0) return; // Can't calculate with invalid cost

    holding.invested = (qty * avgCost).toStringAsFixed(2);
    final investedValue = double.tryParse(holding.invested ?? '0.00') ?? 0.00;

    // Calculate profit/loss
    final currentValue = double.tryParse(holding.currentValue ?? "0.00") ?? 0.0;
    holding.exchTsym![0].profitNloss = ((currentValue - investedValue) +
            double.tryParse(holding.rpnl ?? '0.0')!)
        .toStringAsFixed(2);

    // Calculate percentage change if invested amount exists
    if (investedValue > 0.0 || double.tryParse(holding.sellAmt ?? '0.0')! > 0) {
      final profitValue =
          double.tryParse(holding.exchTsym![0].profitNloss ?? "0.00") ?? 0.0;
      holding.exchTsym![0].pNlChng = ((profitValue /
                  (investedValue +
                      (double.tryParse(holding.sellAmt ?? '0.0')!)
                      )) *
              100)
          .toStringAsFixed(2);
    }

    // Calculate one day change if close value is valid
  if (closeVal > 0) {
      holding.exchTsym![0].oneDayChg =
          ((lpDouble - closeVal) * qty).toStringAsFixed(2);
    }

    // Update totals
    updateHoldingStat();
  }

  updateHoldingStat() {
    _totalCurrentVal = 0.0;
    for (var holdingJson in holdingsModel!) {
      _totalCurrentVal += double.parse("${holdingJson.currentValue ?? 0.0}");
    }
  }

  /// Patch positions whose lp came back as 0 / null / empty from the API using
  /// the last-good LTP cached by the WebSocket provider.
  ///
  /// Why: when an order fills, the broker's position-book endpoint may return
  /// lp=0 for a few seconds because its aggregator lags the latest market tick.
  /// Meanwhile _socketDatas has the real last-traded price from the live feed.
  /// Without this patch, the user sees 0 P&L until the next df update or a
  /// manual refresh.
  void _patchStaleLtpsFromSocketCache() {
    if (_postionBookModel == null || _postionBookModel!.isEmpty) return;

    try {
      final socketDatas = ref.read(websocketProvider).socketDatas;
      if (socketDatas.isEmpty) return;

      int patched = 0;
      for (final position in _postionBookModel!) {
        final token = position.token;
        if (token == null || token.isEmpty) continue;

        // Only patch when the API-returned lp is missing or zero
        final apiLp = position.lp;
        final apiLpNum = double.tryParse(apiLp ?? '') ?? 0.0;
        if (apiLpNum != 0.0) continue;

        final cached = socketDatas[token];
        if (cached is! Map) continue;
        final cachedLp = cached['lp']?.toString();
        if (cachedLp == null || cachedLp.isEmpty) continue;

        final cachedLpNum = double.tryParse(cachedLp) ?? 0.0;
        if (cachedLpNum == 0.0) continue;

        position.lp = cachedLp;
        patched++;
      }

      if (patched > 0) {
        debugPrint('🔍 [POS_DIAG] Patched $patched position(s) with cached WebSocket LTP');
      }
    } catch (e) {
      debugPrint('🔍 [POS_DIAG] _patchStaleLtpsFromSocketCache error: $e');
    }
  }

  // Optimized for fast updates from websocket - Updates position values when price changes
  // This enables ticker to show real-time P&L regardless of which screen is active
  void updatePositionValues(String token, Map<String, dynamic> socketData) {
    // Early return if no token or data
    if (token.isEmpty || socketData.isEmpty || _postionBookModel == null) return;

    // Find the position by token
    var positionIndex = -1;
    for (int i = 0; i < _postionBookModel!.length; i++) {
      if (_postionBookModel![i].token == token) {
        positionIndex = i;
        break;
      }
    }

    if (positionIndex == -1) return; // Not found, nothing to update

    var position = _postionBookModel![positionIndex];
    bool hasUpdates = false;

    // Get new values from socket data
    final newLp = socketData['lp']?.toString();

    // Only update if valid lp value is received
    if (newLp != null && newLp != "null" && newLp != "0" && newLp != "0.0" && newLp != "0.00") {
      final oldLp = position.lp;
      if (oldLp != newLp) {
        position.lp = newLp;
        hasUpdates = true;
      }
    }

    // Only recalculate if we've actually updated any values
    if (hasUpdates) {
      _updatePositionDerivedValues(position);

      // Also update in _allPostionList if it exists
      for (int i = 0; i < _allPostionList.length; i++) {
        if (_allPostionList[i].token == token) {
          _allPostionList[i].lp = position.lp;
          _allPostionList[i].mTm = position.mTm;
          _allPostionList[i].profitNloss = position.profitNloss;
          break;
        }
      }

      // Always update group P&L for ticker header (regardless of selection mode)
      // The ticker displays grouped positions and needs real-time P&L updates
      if (position.symbol != null) {
        _updateGroupPnlForSymbol(position.symbol!);
      }

      // Recalculate totals
      _recalculateTotalPnl();

      // Update chart provider if chart dialog is open
      try {
        final chartProv = ref.read(groupPnlChartProvider);
        if (chartProv.isOpen && newLp != null) {
          chartProv.onTickUpdate(
            token: token,
            ltp: newLp,
            isDay: _isDay,
            isNetPnl: _isNetPnl,
          );
        }
      } catch (_) {}
    }
  }

  // Helper method to update derived values for a single position
  void _updatePositionDerivedValues(PositionBookModel position) {
    final lp = double.tryParse(position.lp ?? "0.00") ?? 0.0;
    final prcFtr = double.tryParse(position.prcftr ?? "1.0") ?? 1.0;
    final mult = double.tryParse(position.mult ?? "1.0") ?? 1.0;
    final netQty = int.tryParse(position.netqty ?? "0") ?? 0;

    final dayBuyQty = int.tryParse(position.daybuyqty ?? "0") ?? 0;
    final daySellQty = int.tryParse(position.daysellqty ?? "0") ?? 0;
    final cfBuyQty = int.tryParse(position.cfbuyqty ?? "0") ?? 0;
    final cfSellQty = int.tryParse(position.cfsellqty ?? "0") ?? 0;

    final dayBuyAmt = double.tryParse(position.daybuyamt ?? "0.00") ?? 0.0;
    final daySellAmt = double.tryParse(position.daysellamt ?? "0.00") ?? 0.0;
    final upldPrc = double.tryParse(position.upldprc ?? "0.00") ?? 0.0;
    final netAvgPrc = double.tryParse(position.netavgprc ?? "0.00") ?? 0.0;
    final netUpldPrc = double.tryParse(position.netupldprc ?? "0.00") ?? 0.0;
    final rpnl = double.tryParse(position.rpnl ?? "0.00") ?? 0.0;

    // Net Buy/Sell Qty
    final netBuyQty = dayBuyQty + cfBuyQty;
    final netSellQty = daySellQty + cfSellQty;

    // Calculate ActualBuyAvgPrice (for BookedPNL calculation)
    double actualBuyAvgPrice = 0.0;
    if (netBuyQty != 0) {
      actualBuyAvgPrice =
          ((dayBuyAmt / mult) + (upldPrc * prcFtr * cfBuyQty)) / netBuyQty;
    }

    // Calculate ActualSellAvgPrice (for BookedPNL calculation)
    double actualSellAvgPrice = 0.0;
    if (netSellQty != 0) {
      actualSellAvgPrice =
          ((daySellAmt / mult) + (upldPrc * prcFtr * cfSellQty)) / netSellQty;
    }

    // Calculate ActualBookedPNL
    double actualBookedPnl = 0.0;
    if (netQty > 0) {
      actualBookedPnl =
          (actualSellAvgPrice - actualBuyAvgPrice) * netSellQty * mult;
    } else {
      actualBookedPnl =
          (actualSellAvgPrice - actualBuyAvgPrice) * netBuyQty * mult;
    }

    // For MTM, avgprc = netavgprc
    double actualUnrealizedMtm = netQty * prcFtr * mult * (lp - netAvgPrc);

    // For PnL, avgprc = netupldprc if not 0 else netavgprc
    double avgPrcForUnrealized = netUpldPrc != 0.0 ? netUpldPrc : netAvgPrc;
    double actualUnrealizedPnl =
        netQty * prcFtr * mult * (lp - avgPrcForUnrealized);

    // MTM = rpnl + ActualUnrealizedMtoM
    double mtm = rpnl + actualUnrealizedMtm;

    // PnL = ActualBookedPNL + ActualUnrealizedPnL
    double pnl = actualBookedPnl + actualUnrealizedPnl;

    // Assign back to position
    position.mTm = mtm.toStringAsFixed(2);
    position.profitNloss = pnl.toStringAsFixed(2);
  }

  // Helper method to update group P&L for a specific symbol
  void _updateGroupPnlForSymbol(String symbol) {
    if (!_groupedBySymbol.containsKey(symbol)) return;

    final groupData = _groupedBySymbol[symbol]['groupList'];
    final isCustomGrp = _groupedBySymbol[symbol]['isCustomGrp'] ?? false;

    if (groupData != null && groupData.isNotEmpty) {
      // Sync live position data from _allPostionList to group data (group data is JSON copy, not reference)
      for (var groupPosition in groupData) {
        final groupToken = groupPosition['token']?.toString();
        final groupPrd = groupPosition['prd']?.toString();
        if (groupToken != null) {
          // Find the corresponding position in _allPostionList to get updated values
          for (var pos in _allPostionList) {
            if (pos.token == groupToken && (groupPrd == null || pos.prd == groupPrd)) {
              // Sync all live fields - qty, netqty, buy/sell data, lp, P&L
              groupPosition['lp'] = pos.lp;
              groupPosition['qty'] = pos.qty;
              groupPosition['netqty'] = pos.netqty;
              groupPosition['daybuyqty'] = pos.daybuyqty;
              groupPosition['daysellqty'] = pos.daysellqty;
              groupPosition['daybuyamt'] = pos.daybuyamt;
              groupPosition['daysellamt'] = pos.daysellamt;
              groupPosition['daybuyavgprc'] = pos.daybuyavgprc;
              groupPosition['daysellavgprc'] = pos.daysellavgprc;
              groupPosition['cfbuyqty'] = pos.cfbuyqty;
              groupPosition['cfsellqty'] = pos.cfsellqty;
              groupPosition['cfbuyamt'] = pos.cfbuyamt;
              groupPosition['cfsellamt'] = pos.cfsellamt;
              groupPosition['cfbuyavgprc'] = pos.cfbuyavgprc;
              groupPosition['cfsellavgprc'] = pos.cfsellavgprc;
              groupPosition['rpnl'] = pos.rpnl;
              groupPosition['urmtom'] = pos.urmtom;
              groupPosition['netavgprc'] = pos.netavgprc;
              groupPosition['avgPrc'] = pos.avgPrc;
              groupPosition['totbuyamt'] = pos.totbuyamt;
              groupPosition['totsellamt'] = pos.totsellamt;
              groupPosition['totbuyavgprc'] = pos.totbuyavgprc;
              groupPosition['totsellavgprc'] = pos.totsellavgprc;
              break;
            }
          }
        }
      }
      positionGroupCal(_isDay, groupData, symbol, isCustomGrp);
    }
  }

  // Helper method to recalculate total P&L from all positions
  void _recalculateTotalPnl() {
    if (_posSelection == "Group by symbol") {
      _updateTotalGroupValues();
    } else {
      // Recalculate from _allPostionList
      double totalPnl = 0.0;
      double totalMtm = 0.0;
      double unRealMtm = 0.0;
      double bookPnl = 0.0;

      for (var position in _allPostionList) {
        totalPnl += double.tryParse(position.profitNloss ?? "0.00") ?? 0.0;
        totalMtm += double.tryParse(position.mTm ?? "0.00") ?? 0.0;

        // Recalculate unrealized PnL and booked PnL per position
        final lp = double.tryParse(position.lp ?? "0.00") ?? 0.0;
        final prcFtr = double.tryParse(position.prcftr ?? "1.0") ?? 1.0;
        final mult = double.tryParse(position.mult ?? "1.0") ?? 1.0;
        final netQty = int.tryParse(position.netqty ?? "0") ?? 0;
        final netUpldPrc =
            double.tryParse(position.netupldprc ?? "0.00") ?? 0.0;
        final netAvgPrc =
            double.tryParse(position.netavgprc ?? "0.00") ?? 0.0;
        final upldPrc = double.tryParse(position.upldprc ?? "0.00") ?? 0.0;

        final dayBuyQty = int.tryParse(position.daybuyqty ?? "0") ?? 0;
        final daySellQty = int.tryParse(position.daysellqty ?? "0") ?? 0;
        final cfBuyQty = int.tryParse(position.cfbuyqty ?? "0") ?? 0;
        final cfSellQty = int.tryParse(position.cfsellqty ?? "0") ?? 0;
        final dayBuyAmt =
            double.tryParse(position.daybuyamt ?? "0.00") ?? 0.0;
        final daySellAmt =
            double.tryParse(position.daysellamt ?? "0.00") ?? 0.0;

        final netBuyQty = dayBuyQty + cfBuyQty;
        final netSellQty = daySellQty + cfSellQty;

        // Unrealized PnL: netQty * prcFtr * mult * (lp - avgPrc)
        final avgPrcForUnrealized =
            netUpldPrc != 0.0 ? netUpldPrc : netAvgPrc;
        unRealMtm += netQty * prcFtr * mult * (lp - avgPrcForUnrealized);

        // Booked PnL
        double actualBuyAvgPrice = 0.0;
        if (netBuyQty != 0) {
          actualBuyAvgPrice =
              ((dayBuyAmt / mult) + (upldPrc * prcFtr * cfBuyQty)) /
                  netBuyQty;
        }
        double actualSellAvgPrice = 0.0;
        if (netSellQty != 0) {
          actualSellAvgPrice =
              ((daySellAmt / mult) + (upldPrc * prcFtr * cfSellQty)) /
                  netSellQty;
        }
        if (netQty > 0) {
          bookPnl +=
              (actualSellAvgPrice - actualBuyAvgPrice) * netSellQty * mult;
        } else {
          bookPnl +=
              (actualSellAvgPrice - actualBuyAvgPrice) * netBuyQty * mult;
        }
      }

      _totPnL = totalPnl.toStringAsFixed(2);
      _totMtm = totalMtm.toStringAsFixed(2);
      _totUnRealMtm = unRealMtm.toStringAsFixed(2);
      _totBookedPnL = bookPnl.toStringAsFixed(2);
    }
    // Push live P&L to PiP window if open
    if (PipService.isOpen) {
      final positions = PipService.buildPositionItems(
        groupedBySymbol: _groupedBySymbol,
        groupPositionSym: _groupPositionSym,
      );
      PipService.updatePipValues(_totPnL, _totMtm, positions: positions);
    }
    // Use post-frame callback to avoid mouse tracker assertion errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Cache expiry duration: 12 hours in milliseconds
  static const int _oplistCacheExpiryMs = 12 * 60 * 60 * 1000;

  Future fetchOplist(context) async {
    try {
      // Check if cached data exists and is not expired
      final cachedData = pref.oplistCache;
      final cachedTimestamp = pref.oplistCacheTimestamp;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (cachedData != null &&
          cachedData.isNotEmpty &&
          cachedTimestamp != null &&
          (currentTime - cachedTimestamp) < _oplistCacheExpiryMs) {
        // Use cached data
        _oplists = jsonDecode(cachedData) as List;
        notifyListeners();
        return;
      }

      // Cache expired or doesn't exist, fetch from API
      List oplist = await api.getOptionlist();
      _oplists = oplist;

      // Store in cache with current timestamp
      await pref.setOplistCache(jsonEncode(oplist));
      await pref.setOplistCacheTimestamp(currentTime);

      notifyListeners();
    } catch (e) {
      // If API fails, try to use cached data regardless of expiry
      final cachedData = pref.oplistCache;
      if (cachedData != null && cachedData.isNotEmpty && _oplists.isEmpty) {
        _oplists = jsonDecode(cachedData) as List;
      }
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API OPlist", "Error": "$e"});
      notifyListeners();
    }
  }

  splitPositionBook(bool isDay) async {
    final theme = ref.read(themeProvider);
    if (_postionBookModel!.isNotEmpty) {
      _closedPosion = [];
      double totBuyAmts = 0.00;
      double totSellAmts = 0.00;
      _allPostionList = [];
      _totPnL = "0.00";
      _totMtm = "0.00";
      _exitAll = false;
      _totBookedPnL = "0.00";
      _totUnRealMtm = '0.00';
      _openPosition = [];
      // Reset selection state when position data is refreshed
      _exitPositionQty = 0;
      _isExitAllPosition = false;

      for (var element in _postionBookModel!) {
        element.isExitSelection = false;

        if (element.netqty == "0") {
          _closedPosion!.add(element);
          _closedPosion!.sort((a, b) => a.tsym!.compareTo(b.tsym!));
        } else {
          _openPosition!.add(element);
          _openPosition!.sort((a, b) => a.tsym!.compareTo(b.tsym!));
        }

        totBuyAmts += double.parse(element.totbuyamt ?? "0.00");
        totSellAmts += double.parse(element.totsellamt ?? "0.00");
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
      }

      _totBuyAmt = totBuyAmts.toStringAsFixed(2);
      _totSellAmt = totSellAmts.toStringAsFixed(2);

      _netVal = (double.parse(_totBuyAmt) - double.parse(_totSellAmt))
          .toStringAsFixed(2);

      _exitAll = false;
      if (isDay) {
        int check = 0;
        int skippedCount = 0;
        for (var element in _openPosition!) {
          if (element.daybuyqty != "0" || element.daysellqty != "0") {
            check = check + 1;
            _allPostionList.add(element);

            if (check >= 2) {
              _exitAll = true;
            }
          } else {
            skippedCount++;
            // [POS_DIAG] This open position is being DROPPED from allPostionList in Day mode.
            debugPrint('🔍 [POS_DIAG] ⚠️ isDay SKIP — tsym=${element.tsym}, netqty=${element.netqty}, daybuyqty=${element.daybuyqty}, daysellqty=${element.daysellqty}');
          }
        }
        if (skippedCount > 0) {
          debugPrint('🔍 [POS_DIAG] ⚠️ isDay=true dropped $skippedCount open positions from allPostionList');
        }
      } else {
        int check = 0;
        for (var element in _openPosition!) {
          check = check + 1;
          _allPostionList.add(element);
        }
        if (check >= 2) {
          _exitAll = true;
        }
      }

      for (var element in _closedPosion!) {
        if (isDay) {
          if (element.daybuyqty != "0" || element.daysellqty != "0") {
            _allPostionList.add(element);
          }
        } else {
          _allPostionList.add(element);
        }
      }

      await positionCal(isDay);
      getPositionGroupNames();

      // Recalculate P&L for all groups after grouping
      for (var symbol in _groupPositionSym) {
        if (_groupedBySymbol.containsKey(symbol)) {
          final groupData = _groupedBySymbol[symbol]['groupList'];
          final isCustomGrp = _groupedBySymbol[symbol]['isCustomGrp'] ?? false;
          if (groupData != null && groupData.isNotEmpty) {
            positionGroupCal(isDay, groupData, symbol, isCustomGrp);
          }
        }
      }
      // tabSize(theme);

      // Use post-frame callback to avoid mouse tracker assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  getPositionGroupNames() {
    try {
      _groupedBySymbol = {};
      for (var element in _allPostionList) {
        final expDate = element.expDate?.toString() ?? '';
        final hasExpiry = expDate.isNotEmpty && expDate != '-';
        final groupKey =
            (_positionGroupFilter == 'underlying_expiry' && hasExpiry)
                ? "${element.symbol} $expDate"
                : "${element.symbol}";
        if (_groupedBySymbol.containsKey(groupKey)) {
          _groupedBySymbol[groupKey]["groupList"]
              .add(jsonDecode(jsonEncode(element)));
        } else {
          _groupedBySymbol.addAll({
            groupKey: {
              "isCustomGrp": false,
              "totMtm": "0.00",
              "totPnl": "0.00",
              "groupList": [jsonDecode(jsonEncode(element))]
            }
          });
        }
      }

      for (var element in _getPositionGroupSymbol) {
        // Skip if posname is null or empty
        if (element.posname == null || element.posname!.isEmpty) {
          continue;
        }

        List<dynamic> groupListData = [];

        if (element.posdata != null && element.posdata!.isNotEmpty) {
          // Convert each PositionBookModel to a Map, then sync with live position data
          for (var pos in element.posdata!) {
            final posMap = jsonDecode(jsonEncode(pos)) as Map<String, dynamic>;
            final posToken = posMap['token']?.toString() ?? '';
            final posPrd = posMap['prd']?.toString() ?? '';

            // Find matching live position from _allPostionList by token + prd
            // This ensures custom group shows current qty/netqty/P&L, not stale saved data
            PositionBookModel? livePos;
            for (var lp in _allPostionList) {
              if (lp.token == posToken && lp.prd == posPrd) {
                livePos = lp;
                break;
              }
            }

            if (livePos != null) {
              // Replace with live position data (has current qty, netqty, P&L, etc.)
              final liveMap = jsonDecode(jsonEncode(livePos)) as Map<String, dynamic>;
              groupListData.add(liveMap);
            } else {
              // No matching live position found - use saved data as fallback
              groupListData.add(posMap);
            }
          }
        }

        if (_groupedBySymbol.containsKey(element.posname)) {
          // Add all items from groupListData to existing groupList
          final existingGroupList = _groupedBySymbol['${element.posname}']["groupList"] as List;
          existingGroupList.addAll(groupListData);
        } else {
          // Create new group entry
          _groupedBySymbol.addAll({
            "${element.posname}": {
              "isCustomGrp": true,
              "totMtm": "0.00",
              "totPnl": "0.00",
              "totUnRealMtm": "0.00",
              "totBookedPnL": "0.00",
              "groupList": groupListData  // Always a List, even if empty
            }
          });
        }
      }

      _groupPositionSym = [];

      if (_groupedBySymbol.keys.isNotEmpty) {
        for (var element in _groupedBySymbol.keys) {
          _groupPositionSym.add(element);
        }
      }
    } catch (e) {
    }

    notifyListeners();
  }

  Future fetchExitPosition(
      BuildContext context,
      PlaceOrderInput placeOrderInput,
      bool isPosition,
      bool multipleexit) async {
    try {
      int qty = int.parse(placeOrderInput.qty);
      int frzqty = int.parse(placeOrderInput.frzqty.toString());

      if (qty > frzqty) {
        int fullOrders = qty ~/ frzqty;
        int remainingQty = qty % frzqty;

        for (int i = 0; i < fullOrders; i++) {
          placeOrderInput.qty = frzqty.toString();
          _placeOrderModel = await api.getPlaceOrder(
              placeOrderInput, ref.read(orderProvider).ip);
        }

        if (remainingQty > 0) {
          placeOrderInput.qty = remainingQty.toString();
          _placeOrderModel = await api.getPlaceOrder(
              placeOrderInput, ref.read(orderProvider).ip);
        }
      } else {
        _placeOrderModel = await api.getPlaceOrder(
            placeOrderInput, ref.read(orderProvider).ip);
      }

      if (_placeOrderModel!.stat == "Ok") {
        ConstantName.sessCheck = true;
        if (isPosition) {
          await fetchPositionBook(context, _isDay);
          successMessage(context, "Position exited successfully.");
        } else {
          await fetchHoldings(context, "Refresh");
        }
        if (!multipleexit) {
          Navigator.pop(context);
        }
      } else {
        if (_placeOrderModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _placeOrderModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        } else {
          successMessage(context, "${_placeOrderModel!.emsg}");
        }
      }

      return _placeOrderModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Place Order", "Error": "$e"});
      notifyListeners();
    }
  }

  // Methods for exit holdings selection
  void selectExitAllHoldings(bool value) {
    _isExitAllHoldings = value;

    // Update selection status for all holdings
    for (var holding in _sealableHoldings) {
      holding.isExitHoldings = value;
    }

    // Update exit quantity count
    _exitHoldingsQty = value
        ? _sealableHoldings.fold(0, (sum, h) => sum + (h.saleableQty ?? 0))
        : 0;

    notifyListeners();
  }

  void selectExitHoldings(int index) {
    if (index < _sealableHoldings.length) {
      // Toggle selection for a specific holding
      _sealableHoldings[index].isExitHoldings =
          !_sealableHoldings[index].isExitHoldings!;

      // Recalculate total selected quantity
      _exitHoldingsQty = 0;
      bool allSelected = true;

      for (var holding in _sealableHoldings) {
        if (holding.isExitHoldings!) {
          _exitHoldingsQty += holding.saleableQty ?? 0;
        } else {
          allSelected = false;
        }
      }

      // Update "Select All" state based on individual selections
      _isExitAllHoldings = allSelected && _sealableHoldings.isNotEmpty;

      notifyListeners();
    }
  }

  // Helper method to generate unique key for position
  String _getPositionKey(PositionBookModel position) {
    return "${position.token}_${position.tsym}_${position.exch}_${position.actid}";
  }

  // Helper method to check if position is selected for exit
  bool isPositionSelected(PositionBookModel position) {
    return _exitSelectedPositions.contains(_getPositionKey(position));
  }

  // Helper method to check if position is in a group
  // Checks token AND prd (product type) to differentiate NRML vs MIS positions
  bool isPositionInGroup(PositionBookModel position, String groupName) {
    for (var group in _getPositionGroupSymbol) {
      if (group.posname == groupName && group.posdata != null) {
        for (var pos in group.posdata!) {
          if (pos.token == position.token && pos.prd == position.prd) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Methods for exit positions selection
  void selectExitAllPosition(bool value) {
    _isExitAllPosition = value;

    // Update selection status for all positions
    if (_openPosition != null) {
        for (var position in _openPosition!) {
        position.isExitSelection = value;
          }

      // Update exit quantity count
      _exitPositionQty =
          value ? _openPosition!.where((p) => p.qty != "0").length : 0;
    }

    notifyListeners();
  }

  void selectExitPosition(int index) {
    if (_openPosition != null && index < _openPosition!.length) {
      // Toggle selection for specific position
      _openPosition![index].isExitSelection =
          !_openPosition![index].isExitSelection!;

      // Recalculate total selected positions
      _exitPositionQty = 0;
      bool allSelected = true;

      for (var position in _openPosition!) {
        if (position.isExitSelection! && position.qty != "0") {
            _exitPositionQty++;
        }

        if (!position.isExitSelection! && position.qty != "0") {
            allSelected = false;
        }
      }

      // Update "Select All" state based on individual selections
      _isExitAllPosition =
          allSelected && _openPosition!.where((p) => p.qty != "0").isNotEmpty;

      notifyListeners();
    }
  }

  // Reset exit position selection state
  void resetExitPositionSelection() {
    _exitPositionQty = 0;
    _isExitAllPosition = false;
    _exitSelectedPositions.clear();

    notifyListeners();
  }
  
   // Helper to get product display name from code
  String _getProductDisplayName(String? code) {
    switch (code) {
      case 'I':
        return 'MIS';
      case 'C':
        return 'CNC';
      case 'M':
        return 'NRML';
      default:
        return code ?? '';
    }
  }

  // Position conversion
  Future<void> fetchPositionConverstion(
      PositionConvertionInput input, BuildContext context) async {

    // Get display names for toast message
    final fromProduct = _getProductDisplayName(input.prevprd);
    final toProduct = _getProductDisplayName(input.prd);

    try {
      toggleLoadingOn(true);

      _positionConvertionModel = await api.getPositionConvertion(input);


      if (_positionConvertionModel!.stat == "Ok") {
        // Refresh position book after conversion
        await fetchPositionBook(context, _isDay);

        if (context.mounted) {
        Navigator.pop(context);

          // Show success message with from/to product details
          final successMsg = "Position converted from $fromProduct to $toProduct";
          if (kIsWeb) {
            ResponsiveSnackBar.showSuccess(context, successMsg);
      } else {
            successMessage(context, successMsg);
          }
        }
      } else {

        if (_positionConvertionModel!.emsg ==
                "Session Expired :  Invalid Session Key" &&
            _positionConvertionModel!.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
          return;
        }

        if (context.mounted) {
        Navigator.pop(context);
          // Show error message from API
          final errorMsg = _positionConvertionModel!.emsg ?? "Conversion failed";
          if (kIsWeb) {
            ResponsiveSnackBar.showWarning(context, errorMsg);
          } else {
            warningMessage(context, errorMsg);
      }
        }
      }
    } catch (e, stackTrace) {

      ref
          .read(indexListProvider)
          .logError
          .add({"type": "Position Conversion", "Error": "$e"});

      if (context.mounted) {
        if (kIsWeb) {
          ResponsiveSnackBar.showWarning(
              context, "Failed to convert position: $e");
        } else {
      warningMessage(context, "Failed to convert position: $e");
        }
      }
    } finally {
      toggleLoadingOn(false);
    }
  }

  positionGroupCal(
      bool isDay, List groupData, String groupName, bool iscusGrop) {
    if (groupData.isEmpty) return;

    double totalProfitNloss = 0.0;
    double totalMtm = 0.0;
    double totalUnRealMtm = 0.0;
    double totalBookedPnL = 0.0;
    bool hasExitPositions = false;

    for (var position in groupData) {
      // Get common values used in calculations
      final lastPrice = double.tryParse(position["lp"] ?? "0.00") ?? 0.0;
      final prcFtr = double.tryParse(position["prcftr"] ?? "1.0") ?? 1.0;
      final mult = double.tryParse(position["mult"] ?? "1.0") ?? 1.0;
      final lotSize = double.tryParse(position["ls"] ?? "1.0") ?? 1.0;
      final netQty = int.tryParse(position["netqty"] ?? "0") ?? 0;

      // Parse buy/sell quantities
      final dayBuyQty = int.tryParse(position["daybuyqty"] ?? "0") ?? 0;
      final daySellQty = int.tryParse(position["daysellqty"] ?? "0") ?? 0;
      final cfBuyQty = int.tryParse(position["cfbuyqty"] ?? "0") ?? 0;
      final cfSellQty = int.tryParse(position["cfsellqty"] ?? "0") ?? 0;

      // Calculate net buy and sell quantities
      final netBuyQty = dayBuyQty + cfBuyQty;
      final netSellQty = daySellQty + cfSellQty;

      // Parse prices and amounts
      final netAvgPrc = double.tryParse(position["netavgprc"] ?? "0.00") ?? 0.0;
      final netUpldPrc = double.tryParse(position["netupldprc"] ?? "0.00") ?? 0.0;
      final upldPrc = double.tryParse(position["upldprc"] ?? "0.00") ?? 0.0;
      final dayBuyAmt = double.tryParse(position["daybuyamt"] ?? "0.00") ?? 0.0;
      final daySellAmt =
          double.tryParse(position["daysellamt"] ?? "0.00") ?? 0.0;
      final rpnl = double.tryParse(position["rpnl"] ?? "0.00") ?? 0.0;
      final exch = position["exch"]?.toString() ?? "";

      if (isDay) {
        // DAY POSITION GROUP CALCULATION (matching positionCal logic)
        // qty logic for day (with MCX special handling)
        int qty = 0;
        if (exch == "MCX") {
          qty = ((dayBuyQty - daySellQty) / lotSize).toInt();
        } else {
          qty = dayBuyQty - daySellQty;
        }
        position["qty"] = qty.toString();

        // avgPrc logic for day
        position["avgPrc"] = (netQty == 0 ? "0.00" : position["dayavgprc"] ?? "0.00");
        final avgPrc = double.tryParse(position["avgPrc"] ?? "0.00") ?? 0.0;

        // Calculate ActualBuyAvgPrice (for BookedPNL calculation)
        double actualBuyAvgPrice = 0.0;
        if (netBuyQty != 0) {
          actualBuyAvgPrice =
              ((dayBuyAmt / mult) + (upldPrc * prcFtr * cfBuyQty)) / netBuyQty;
        }

        // Calculate ActualSellAvgPrice (for BookedPNL calculation)
        double actualSellAvgPrice = 0.0;
        if (netSellQty != 0) {
          actualSellAvgPrice =
              ((daySellAmt / mult) + (upldPrc * prcFtr * cfSellQty)) / netSellQty;
        }

        // Calculate ActualBookedPNL
        double actualBookedPnl = 0.0;
        if (netQty > 0) {
          actualBookedPnl =
              (actualSellAvgPrice - actualBuyAvgPrice) * netSellQty * mult;
        } else {
          actualBookedPnl =
              (actualSellAvgPrice - actualBuyAvgPrice) * netBuyQty * mult;
        }

        // For MTM, avgprc = netavgprc
        double actualUnrealizedMtm = netQty * prcFtr * mult * (lastPrice - netAvgPrc);

        // For PnL, avgprc = netupldprc if not 0 else netavgprc
        double avgPrcForUnrealized = netUpldPrc != 0.0 ? netUpldPrc : netAvgPrc;
        double actualUnrealizedPnl =
            netQty * prcFtr * mult * (lastPrice - avgPrcForUnrealized);

        // MTM = rpnl + ActualUnrealizedMtoM
        double mtm = rpnl + actualUnrealizedMtm;

        // PnL = ActualBookedPNL + ActualUnrealizedMtoM
        double pnl = actualBookedPnl + actualUnrealizedPnl;

        // Assign back to position
        position["mTm"] = mtm.toStringAsFixed(2);
        position["profitNloss"] = pnl.toStringAsFixed(2);

        // Totals
        totalMtm += mtm;
        totalProfitNloss += pnl;
        totalUnRealMtm += actualUnrealizedPnl;
        totalBookedPnL += actualBookedPnl;

        if (qty != 0) {
          hasExitPositions = true;
        }
      } else {
        // NET POSITION GROUP CALCULATION (matching positionCal logic)
        // qty logic for net
        final qty = netQty;
        position["qty"] = qty.toString();

        // avgPrc logic for net (matching positionCal exactly)
        if (qty == 0) {
          position["avgPrc"] = "0.00";
        } else {
          // If netupldprc != 0, use that, else netavgprc
          position["avgPrc"] = (netUpldPrc != 0.0)
              ? netUpldPrc.toStringAsFixed(2)
              : netAvgPrc.toStringAsFixed(2);
        }
        final avgPrc = double.tryParse(position["avgPrc"] ?? "0.00") ?? 0.0;

        double actualBuyAvgPrice = 0.0;
      if (netBuyQty != 0) {
        actualBuyAvgPrice =
            ((dayBuyAmt / mult) + (upldPrc * prcFtr * cfBuyQty)) / netBuyQty;
      }

      // Calculate ActualSellAvgPrice (for BookedPNL calculation)
      double actualSellAvgPrice = 0.0;
      if (netSellQty != 0) {
        actualSellAvgPrice =
            ((daySellAmt / mult) + (upldPrc * prcFtr * cfSellQty)) / netSellQty;
      }

      // Calculate ActualBookedPNL
      double actualBookedPnl = 0.0;
      if (netQty > 0) {
        actualBookedPnl =
            (actualSellAvgPrice - actualBuyAvgPrice) * netSellQty * mult;
      } else {
        actualBookedPnl =
            (actualSellAvgPrice - actualBuyAvgPrice) * netBuyQty * mult;
      }

      // For MTM, avgprc = netavgprc
      double actualUnrealizedMtm = netQty * prcFtr * mult * (lastPrice - netAvgPrc);

      // For PnL, avgprc = netupldprc if not 0 else netavgprc
      double avgPrcForUnrealized = netUpldPrc != 0.0 ? netUpldPrc : netAvgPrc;
      double actualUnrealizedPnl =
          netQty * prcFtr * mult * (lastPrice - avgPrcForUnrealized);

      // MTM = rpnl + ActualUnrealizedMtoM
      double mtm = rpnl + actualUnrealizedMtm;

      // PnL = ActualBookedPNL + ActualUnrealizedPnL
      double pnl = actualBookedPnl + actualUnrealizedPnl;

      // Assign back to position
      position["mTm"] = mtm.toStringAsFixed(2);
      position["profitNloss"] = pnl.toStringAsFixed(2);

      // Totals
      totalMtm += mtm;
      totalProfitNloss += pnl;
      totalUnRealMtm += actualUnrealizedPnl;
      totalBookedPnL += actualBookedPnl;

      if (netQty != 0) {
        hasExitPositions = true;
      }
    }
  }

    // Update group summary
    _groupedBySymbol[groupName]['totPnl'] = totalProfitNloss.toStringAsFixed(2);
    _groupedBySymbol[groupName]['totMtm'] = totalMtm.toStringAsFixed(2);
    _groupedBySymbol[groupName]['totUnRealMtm'] = totalUnRealMtm.toStringAsFixed(2);
    _groupedBySymbol[groupName]['totBookedPnL'] = totalBookedPnL.toStringAsFixed(2);
    _groupedBySymbol[groupName]['isexit'] = "$hasExitPositions";

    // Update total P&L and MTM only when in "Group by symbol" mode
    // This recalculates totals after creating/modifying groups
    if (_posSelection == "Group by symbol") {
      _updateTotalGroupValues();
    }
  }

  // Helper method to update total group values
  void _updateTotalGroupValues() {
    double totalPnl = 0.0;
    double totalMtm = 0.0;
    double totalUnRealMtm = 0.0;
    double totalBookedPnL = 0.0;

    for (var symbol in _groupPositionSym) {
      if (_groupedBySymbol[symbol]["isCustomGrp"] == false) {
        totalPnl +=
            double.tryParse(_groupedBySymbol[symbol]['totPnl'] ?? "0.00") ??
                0.0;
        totalMtm +=
            double.tryParse(_groupedBySymbol[symbol]['totMtm'] ?? "0.00") ??
                0.0;
        totalUnRealMtm +=
            double.tryParse(_groupedBySymbol[symbol]['totUnRealMtm'] ?? "0.00") ??
                0.0;
        totalBookedPnL +=
            double.tryParse(_groupedBySymbol[symbol]['totBookedPnL'] ?? "0.00") ??
                0.0;
      }
    }

    _totMtm = totalMtm.toStringAsFixed(2);
    _totPnL = totalPnl.toStringAsFixed(2);
    _totUnRealMtm = totalUnRealMtm.toStringAsFixed(2);
    _totBookedPnL = totalBookedPnL.toStringAsFixed(2);
    // Push live P&L to PiP window if open
    if (PipService.isOpen) {
      final positions = PipService.buildPositionItems(
        groupedBySymbol: _groupedBySymbol,
        groupPositionSym: _groupPositionSym,
      );
      PipService.updatePipValues(_totPnL, _totMtm, positions: positions);
    }

    // debugPrint("DEBUG _updateTotalGroupValues -> totMtm:$_totMtm, totPnL:$_totPnL, totUnRealMtm:$_totUnRealMtm, totBookedPnL:$_totBookedPnL");
    notifyListeners();
  }

  // Method for custom group position selection
  Future<void> cusGrpSelectPosition(List groupList) async {
    try {
      if (groupList.isNotEmpty) {
        // Mark which positions are already in the group
        for (var element in _allPostionList) {
          element.isAlreadyGroup = false;

          for (var grpElement in groupList) {
            if (element.token == grpElement['token'] &&
                element.prd == grpElement['prd']) {
              element.isAlreadyGroup = true;
              break;
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
    }
  }

  // Add this near the other state variables
  final bool _isExitingAll = false;
  bool get isExitingAll => _isExitingAll;

  // Add this near the other state variables
  String _currentPositionSortOption =
      "OpenDSC"; // Default to show 0 qty positions at bottom
  String get currentPositionSortOption => _currentPositionSortOption;

  // Add this near the other state variables and _currentHoldingSortOption
  String _currentHoldingSortOption = "ASC";
  String get currentHoldingSortOption => _currentHoldingSortOption;
}

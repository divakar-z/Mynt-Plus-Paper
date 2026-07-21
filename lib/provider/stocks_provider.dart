import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import '../api/core/api_export.dart';
import '../locator/locator.dart';
import 'package:intl/intl.dart';
import '../locator/preference.dart';
import '../models/explore_model/ca_events_model.dart';
import '../models/explore_model/stocks_model/corporate_action_model.dart';
import '../models/explore_model/stocks_model/get_ad_indices.dart';
import '../models/explore_model/stocks_model/sctor_thematic_model.dart';
import '../models/explore_model/stocks_model/sector_thematric_detail_model.dart';
import '../models/explore_model/stocks_model/stock_monitor_model.dart';
import '../models/indices/global_indices_model.dart';
import '../models/news_model.dart';
import '../models/explore_model/stocks_model/action_trade_model.dart';
import '../models/explore_model/stocks_model/toplist_stocks.dart';
import '../models/marketwatch_model/search_scrip_model.dart';
import '../models/span_calc_model.dart';
import '../models/marketwatch_model/get_quotes.dart';
// duplicate imports removed
import '../models/strategy_model.dart';
import '../routes/route_names.dart';
import 'bonds_provider.dart';
import 'core/default_change_notifier.dart';
import 'iop_provider.dart';

final stocksProvide = ChangeNotifierProvider((ref) => StocksProvider(ref));

class StocksProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final prefs = locator<Preferences>();

  final Ref ref;

  NewsModel? _newsModel;
  NewsModel? get newsModel => _newsModel;
  List<GlobalIndicesModel>? _globalIndicesModel;
  List<GlobalIndicesModel>? get globalIndicesModel => _globalIndicesModel;
  List<ActionTradeModel>? _actionTrademodel;
  List<ActionTradeModel>? get actionTrademodel => _actionTrademodel;

  // Search scrip related variables
  List<ScripValue> _searchResults = [];
  List<ScripValue> get searchResults => _searchResults;
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  String? _searchError;
  String? get searchError => _searchError;

  TopListStocks? _topListStocks;
  TopListStocks? get topListStocks => _topListStocks;
  List<TopGainers> _topGainers = [];
  List<TopGainers> _topLosers = [];
  List<TopGainers> _byValue = [];
  List<TopGainers> _byVolume = [];
  List<TopGainers> _topStockData = [];
  bool _isTradeActionLoaded = false;
  List<TopGainers> get topGainers => _topGainers;
  List<TopGainers> get topLosers => _topLosers;
  List<TopGainers> get byValue => _byValue;
  List<TopGainers> get byVolume => _byVolume;
  List<TopGainers> get topStockData => _topStockData;
  bool get isTradeActionLoaded => _isTradeActionLoaded;

  List<StockMoniterModel> _stockMonitor = [];
  List<StockMoniterModel> get stockMonitor => _stockMonitor;
  String _tradeData = "Top gainer";
  String get tradeData => _tradeData;
  StocksProvider(this.ref);

  List<String> tradeActType = ["Equity", "F&O"];

  String _selctedTradeAct = "Equity";
  String _selctedEventAct = "dividend";

  bool _moreFunRatio = false;
  bool get moreFunRatio => _moreFunRatio;

  final List<String> _eveType = [
    "Announcement",
    "Bonus",
    "Divedend",
    "Rights",
    "Split"
  ];

  String _slectSMSym = "Nifty 50";
  String get slectSMSym => _slectSMSym;
  String _slectSMFilter = "Volume & Price Up";
  String get slectSMFilter => _slectSMFilter;

  String _slectBaskt = "NIFTY50";
  String get slectBaskt => _slectBaskt;
  String _slectFilterCont = "VolUpPriceUp";
  String get slectFilterCont => _slectFilterCont;

  chngSMSym(String val) {
    _slectSMSym = val;

    for (var element in _stockMonitorSym) {
      if (_slectSMSym == "${element['symbol']}") {
        _slectBaskt = "${element["bskt"]}";

        fetchStockMonitor("NSE", _slectBaskt, _slectFilterCont);
      }
    }
    notifyListeners();
  }

  chngSMFilter(String val, String val1) {
    _slectSMFilter = val;
    _slectFilterCont = val1;
    fetchStockMonitor("NSE", _slectBaskt, _slectFilterCont);
    notifyListeners();
  }

  final List _stockMonitorSym = [
    {"symbol": "All", "bskt": "A"},
    {"symbol": "Nifty 50", "bskt": "NIFTY50"},
    {"symbol": "Nifty 500", "bskt": "NIFTY500"},
    {"symbol": "Nifty MIDCAP 50", "bskt": "NIFTYMCAP50"},
    {"symbol": "Nifty SMALCAP 50", "bskt": "NIFTYSMCAP50"}
  ];

  List get stockMonitorSym => _stockMonitorSym;

  final List _stockMonitorFilter = [
    {"filterType": "Volume & Price Up", "cont": "VolUpPriceUp"},
    {"filterType": "Volume & Price Down", "cont": "VolUpPriceDown"},
    {"filterType": "Open High", "cont": "OpenHigh"},
    {"filterType": "Open Low", "cont": "OpenLow"},
    {"filterType": "High Break", "cont": "HighBreak"},
    {"filterType": "Low Break", "cont": "LowBreak"}
  ];

  List get stockMonitorFilter => _stockMonitorFilter;

  List<String> get eveType => _eveType;
  String _selectedEvent = "Announcement";
  String get selectedevent => _selectedEvent;

  List<SectorThemeaticModel> _sectorsData = [];

  List<SectorThemeaticModel> _thematicData = [];

  List<SectorThemeaticModel> _strategicData = [];

  List<SectorThemeaticModel> _niftyData = [];

  List<SectorThemeaticModel> get sectorsData => _sectorsData;

  List<SectorThemeaticModel> get thematicDat => _thematicData;

  List<SectorThemeaticModel> get strategicData => _strategicData;

  List<SectorThemeaticModel> get niftyData => _niftyData;

  CorporateActionModel? _corporateActionModel;
  CorporateActionModel? get corporateActionModel => _corporateActionModel;

  CAevents? _caeventsModel;
  CAevents? get caeventsModel => _caeventsModel;

  List<SectorThematicDetailModel> _indicesData = [];
  List<SectorThematicDetailModel> get indicesData => _indicesData;

  GetAdIndicesModel? _getAdIndicesModel;
  GetAdIndicesModel? get getAdIndicesModel => _getAdIndicesModel;

  final TextEditingController _searchController = TextEditingController();
  TextEditingController get searchController => _searchController;


  dashboardsearchclear() {
    _searchController.clear();
    notifyListeners();
  }

  searchdashboard(String value, BuildContext context, {int? tabIndex}) {
    // Use provided tabIndex or fall back to current exploreIndex
    _searchController.text = value;
    int currentTabIndex = tabIndex ?? _exploreIndex;
    
    if (value.isNotEmpty && currentTabIndex >= 0 && currentTabIndex < _exploreTabName.length) {
      switch (_exploreTabName[currentTabIndex].text) {
        case "Stocks":
          // Add stock search logic here if needed
          // For now, we can implement stock search or navigate to stock search screen
          // Navigator.pushNamed(context, Routes.stockSearchScreen);
          break;

        case "Mutual Fund":
          Navigator.pushNamed(context, Routes.mfsearchscreen);
          break;

        case "IPO":
          // Update IPO search used by Upcoming and My Bids
          ref.read(ipoProvide).setIpoSearchQuery(value);
          // Maintain existing common search behavior
          ref.read(ipoProvide).searchCommonIpo(value, context);
          break;

        case "Bond":
          // Update Bonds search used by My Bids orderbook filtering
          ref.read(bondsProvider).setBondsSearchQuery(value);
          ref.read(bondsProvider).searchCommonBonds(value, context);
          break;
      }
    }
    notifyListeners();
  }

  clearsearchlist(BuildContext context) {
    ref.read(ipoProvide).clearCommonIpoSearch();
    ref.read(bondsProvider).clearCommonBondsSearch();
    notifyListeners();
  }

  // Method to sync TabBar index with provider's exploreIndex
  syncTabIndex(int tabIndex) {
    if (tabIndex >= 0 && tabIndex < _exploreTabName.length) {
      _exploreIndex = tabIndex;
      notifyListeners();
      _exploreName = _exploreNames[tabIndex];
      notifyListeners();
    }
  }


  showMoreFunRatio() {
    _moreFunRatio = !_moreFunRatio;
    notifyListeners();
  }

  chngEvent(String val) {
    _selectedEvent = val;
    notifyListeners();
  }

  late TabController exploreTab;
  final List<Tab> _exploreTabName = [
    const Tab(text: "Stocks"),
    const Tab(text: "Mutual Fund"),
    const Tab(text: "IPO"),
    const Tab(text: "Bond"),
  ];
  List<Tab> get exploreTabName => _exploreTabName;

  final List<String> _finacialType = ["Income", "Balance sheet", "Cashflow"];

  List<String> get finacialType => _finacialType;

  String _selctedFinType = "Income";

  String get selctedFinType => _selctedFinType;

  final List<String> _exploreNames = ["Stock", "Mutual Fund", "IPOs", "Bonds"];

  List<String> get exploreNames => _exploreNames;

  String _exploreName = "Stock";

  String get exploreName => _exploreName;
  int _exploreIndex = 0;
  PageController controller = PageController(initialPage: 0);
  int get exploreIndex => _exploreIndex;

  chngExpName(String val, int ind) {
    _exploreName = val;
    _exploreIndex = ind;
    controller = PageController(initialPage: ind);
    notifyListeners();
  }

  String get selctedTradeAct => _selctedTradeAct;
  String get selctedEventAct => _selctedEventAct;

  chngTradeAct(String val) async {
    if (val == "init") {
      _selctedTradeAct = "Equity";
      await fetchTradeAction("NSE", "NSEALL", "topG_L", "topG_L");
      await fetchTradeAction("NSE", "NSEALL", "mostActive", "mostActive");
    } else {
      _selctedTradeAct = val;

      if (val == "Equity") {
        await fetchTradeAction("NSE", "NSEALL", "topG_L", "topG_L");
        await fetchTradeAction("NSE", "NSEALL", "mostActive", "mostActive");
      } else {
        await fetchTradeAction("NFO", "NFOALL", "topG_L", "topG_L");
        await fetchTradeAction("NFO", "NFOALL", "mostActive", "mostActive");
      }
      notifyListeners();
    }
  }

  chngEventAct(String val) async {
    _selctedEventAct = val.toLowerCase();
    notifyListeners();
  }

  List<double> getCustomItemsHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (tradeActType.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<double> getSMCustomItemsHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_stockMonitorSym.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<DropdownMenuItem<String>> addSMDivider() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _stockMonitorSym) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item["symbol"].toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    item["symbol"].toString(),
                    style: dysInter(
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xff000000),
                            fontSize: 13)),
                  ))),
          //If it's last item, we will not add Divider after it.
          if (item != _stockMonitorSym.last)
            const DropdownMenuItem<String>(
              enabled: false,
              child: Divider(),
            ),
        ],
      );
    }
    return menuItems;
  }

  List<DropdownMenuItem<String>> addDividersAfterExpDates() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in tradeActType) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item.toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    item.toString(),
                    style: dysInter(
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xff000000),
                            fontSize: 13)),
                  ))),
          //If it's last item, we will not add Divider after it.
          if (item != tradeActType.last)
            const DropdownMenuItem<String>(
              enabled: false,
              child: Divider(),
            ),
        ],
      );
    }
    return menuItems;
  }

  List<double> getSMCustItemsHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (tradeActType.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<DropdownMenuItem<String>> addSMividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in tradeActType) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item.toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    item.toString(),
                    style: dysInter(
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xff000000),
                            fontSize: 13)),
                  ))),
          //If it's last item, we will not add Divider after it.
          if (item != tradeActType.last)
            const DropdownMenuItem<String>(
              enabled: false,
              child: Divider(),
            ),
        ],
      );
    }
    return menuItems;
  }

  Future getNews() async {
    try {
      final DateTime now = DateTime.now();
      final DateFormat formatter = DateFormat('dd-MM-yyyy');
      final String formatted = formatter.format(now);

      _newsModel = await api.fetchNews(formatted);
      notifyListeners(); // Add this to notify listeners about the state change

      return _newsModel;
    } catch (e) {
      // Fluttertoast.showToast(
      //     msg: "$e",
      //     backgroundColor: Colors.red,
      //     textColor: Colors.white,
      //     fontSize: 14.0);
      rethrow;
    }
  }

 
  Future getGlobalIndices() async {
    try {
      _globalIndicesModel = await api.fetchGlobalIndices();
      return _globalIndicesModel;
    } catch (e) {
      Fluttertoast.showToast(
          msg: "$e",
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 14.0);
      rethrow;
    }
  }

  Future fetchTradeAction(
      String exch, String bskt, String crt, String isMostAct) async {
    try {
      _topListStocks = await api.getTradeAction(exch, bskt, crt);

      if (_topListStocks!.stat == "Ok") {
        if (isMostAct == "mostActive") {
          _byValue = _topListStocks!.byValue ?? [];
          _byVolume = _topListStocks!.byVolume ?? [];
        } else {
          _topGainers = _topListStocks!.topGainers ?? [];
          _topLosers = _topListStocks!.topLosers ?? [];
        }
      }
      _isTradeActionLoaded = true;
      notifyListeners();
    } catch (e) {
      _isTradeActionLoaded = true;
      notifyListeners();
    }
  }

  //Future getActionTrade() async {
  //   try {
  //     _actionTrademodel = await api.fetchTradeAction();
  //     return _actionTrademodel;
  //   } catch (e) {
  //     print(e);

  //     rethrow;
  //   }
  // }

  chngTradeAction(String val) {
    if (val == 'init') {
      _tradeData = "Top gainers";
      _topStockData = _topGainers;
    } else {
      _tradeData = val;
      if (val == "Top gainers") {
        _topStockData = _topGainers;
      } else if (val == "Top losers") {
        _topStockData = _topLosers;
      } else if (val == "Vol. breakout") {
        _topStockData = _byVolume;
      } else {
        _topStockData = _byValue;
      }
      notifyListeners();
    }
  }

  chngfinancilaType(String val) {
    _selctedFinType = val;
    notifyListeners();
  }

  defaultSectorThemematicData() {
    _sectorsData = [
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY FINANCIAL SERVICES",
          secCount: "",
          name: "Financial Services",
          ltp: "",
          token: "26037",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY OIL AND GAS INDEX",
          secCount: "",
          name: "Oil & Gas",
          ltp: "",
          token: "26071",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY BANK",
          secCount: "",
          name: "Bank",
          ltp: "",
          token: "26009",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY IT",
          secCount: "",
          name: "IT",
          ltp: "",
          token: "26008",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY FMCG",
          secCount: "",
          name: "FMCG",
          ltp: "",
          token: "26021",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
    ];

    _thematicData = [
      SectorThemeaticModel(
          chng: "",
          secName: "Nifty India Manufacturing",
          secCount: "",
          name: "Manufacturing",
          ltp: "",
          token: "26080",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY INFRASTRUCTURE",
          secCount: "",
          name: "InfraStructure",
          ltp: "",
          token: "26019",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "NIFTY INDIA CONSUMPTION",
          secCount: "",
          name: "Consumption",
          ltp: "",
          token: "26036",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "Nifty Mobility",
          secCount: "",
          name: "Mobility",
          ltp: "",
          token: "26008",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: ""),
      SectorThemeaticModel(
          chng: "",
          secName: "Nifty India Digital",
          secCount: "",
          name: "Digital",
          ltp: "",
          token: "26077",
          perChng: "",
          poistive: "",
          nutral: "",
          marketCap: "",
          close: "")
    ];
    fetchIndicesAdvdec();
    notifyListeners();
  }

  fetchIndicesAdvdec() async {
    try {
      final response = await api.getadindicesAdvdec("");

      Map res = jsonDecode(response.body);
      List ltpArgs = [];
      for (var element in res.keys) {
        for (var sector in _sectorsData) {
          if (element.toString() == sector.secName.toString()) {
            sector.negative = "${res["$element"]["Negative"]}";
            sector.poistive = "${res["$element"]["Positive"]}";
            sector.nutral = "${res["$element"]["Neutral"]}";
            sector.marketCap = "${res["$element"]["marketCap"]}";
            sector.token = "${res["$element"]["token"]}";

            sector.secCount = (int.parse(sector.poistive ?? "0") +
                    int.parse(sector.nutral ?? "0") +
                    int.parse(sector.negative ?? "0"))
                .toString();
            ltpArgs.add({"exch": "NSE", "token": "${sector.token}"});

            // print("${sector.secCount}");
          }
        }
      }

      for (var element in res.keys) {
        for (var sector in _thematicData) {
          if (element.toString() == sector.secName.toString()) {
            sector.negative = "${res["$element"]["Negative"]}";
            sector.poistive = "${res["$element"]["Positive"]}";
            sector.nutral = "${res["$element"]["Neutral"]}";
            sector.marketCap = "${res["$element"]["marketCap"]}";
            sector.token = "${res["$element"]["token"]}";

            sector.secCount = (int.parse(sector.poistive ?? "0") +
                    int.parse(sector.nutral ?? "0") +
                    int.parse(sector.negative ?? "0"))
                .toString();
            ltpArgs.add({"exch": "NSE", "token": "${sector.token}"});

            // print("${sector.secCount}");
          }
        }
      }

      final ltpDatas = await api.getLTP(ltpArgs);

      Map ltpData = jsonDecode(ltpDatas.body);

      for (var element in _sectorsData) {
        if (element.token.toString() ==
            "${ltpData["data"]["${element.token}"]['token']}") {
          element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

          element.close = "${ltpData["data"]["${element.token}"]["close"]}";

          element.perChng = "${ltpData["data"]["${element.token}"]["change"]}";

          element.chng = (double.parse(
                      "${element.ltp == "0" ? element.close : element.ltp}") -
                  double.parse("${element.close}"))
              .toStringAsFixed(2);
        }
      }

      for (var element in _thematicData) {
        if (element.token.toString() ==
            "${ltpData["data"]["${element.token}"]['token']}") {
          element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

          element.close = "${ltpData["data"]["${element.token}"]["close"]}";

          element.perChng = "${ltpData["data"]["${element.token}"]["change"]}";

          element.chng = (double.parse(
                      "${element.ltp == "0" ? element.close : element.ltp}") -
                  double.parse("${element.close}"))
              .toStringAsFixed(2);
        }
      }

// _tradeActionKeys.add(jsonEncode(res.keys) );
//    for (var i = 0; i < res.length; i++) {

//     print("${res[i]}");
// //    for (var element in _sectorsData) {
// //   if (res[element]) {

//    }

// }
//  }
    } catch (e) {
    }
  }

  Future fetchCorporateAction() async {
    try {
      _corporateActionModel = await api.getCorporateAction();

      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchCAevents() async {
    try {
      _caeventsModel = await api.getCAeventsdata();
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchAdindices(String name) async {
    try {
      _indicesData = await api.getadindices(name);

      for (var element in _indicesData) {
        element.perChng = (double.parse(element.ltp ?? "0.00") -
                double.parse(element.close ?? "0.0"))
            .toStringAsFixed(2);
      }
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchALLAdindices() async {
    try {
      _getAdIndicesModel = await api.getAllAdindices();

      final response = await api.getadindicesAdvdec("");

      Map res = jsonDecode(response.body);

      _sectorsData = [];

      List ltpArgs = [];
      for (var element in _getAdIndicesModel!.sectoralIndices!) {
        if (res.containsKey(element)) {
          _sectorsData.add(SectorThemeaticModel(
              secName: element,
              name: "",
              secCount: (int.parse("${res[element]["Positive"]}") +
                      int.parse("${res[element]["Neutral"]}") +
                      int.parse("${res[element]["Negative"]}"))
                  .toString(),
              ltp: "",
              chng: "",
              perChng: "",
              negative: "${res[element]["Negative"]}",
              poistive: "${res[element]["Positive"]}",
              close: "",
              token: "${res[element]["token"]}",
              nutral: "${res[element]["Neutral"]}",
              marketCap: "${res[element]["marketCap"]}"));
        }

        if (res[element]["token"] != "") {
          ltpArgs.add({"exch": "NSE", "token": "${res[element]["token"]}"});
        }

        // print("${sector.secCount}");
      }
      _thematicData = [];

      for (var element in _getAdIndicesModel!.thematicIndices!) {
        if (res.containsKey(element)) {
          _thematicData.add(SectorThemeaticModel(
              secName: element,
              name: "",
              secCount: (int.parse("${res[element]["Positive"]}") +
                      int.parse("${res[element]["Neutral"]}") +
                      int.parse("${res[element]["Negative"]}"))
                  .toString(),
              ltp: "",
              chng: "",
              perChng: "",
              negative: "${res[element]["Negative"]}",
              poistive: "${res[element]["Positive"]}",
              close: "",
              token: "${res[element]["token"]}",
              nutral: "${res[element]["Neutral"]}",
              marketCap: "${res[element]["marketCap"]}"));
        }

        if (res[element]["token"] != "") {
          ltpArgs.add({"exch": "NSE", "token": "${res[element]["token"]}"});
        }

        // print("${sector.secCount}");
      }

      _strategicData = [];

      for (var element in _getAdIndicesModel!.strategyIndices!) {
        if (res.containsKey(element)) {
          _strategicData.add(SectorThemeaticModel(
              secName: element,
              name: "",
              secCount: (int.parse("${res[element]["Positive"]}") +
                      int.parse("${res[element]["Neutral"]}") +
                      int.parse("${res[element]["Negative"]}"))
                  .toString(),
              ltp: "",
              chng: "",
              perChng: "",
              negative: "${res[element]["Negative"]}",
              poistive: "${res[element]["Positive"]}",
              close: "",
              token: "${res[element]["token"]}",
              nutral: "${res[element]["Neutral"]}",
              marketCap: "${res[element]["marketCap"]}"));
        }
        if (res[element]["token"] != "") {
          ltpArgs.add({"exch": "NSE", "token": "${res[element]["token"]}"});
        }
        // print("${sector.secCount}");
      }

      _niftyData = [];

      for (var element in _getAdIndicesModel!.niftyIndices!) {
        if (res.containsKey(element)) {
          _niftyData.add(SectorThemeaticModel(
              secName: element,
              name: "",
              secCount: (int.parse("${res[element]["Positive"]}") +
                      int.parse("${res[element]["Neutral"]}") +
                      int.parse("${res[element]["Negative"]}"))
                  .toString(),
              ltp: "",
              chng: "",
              perChng: "",
              negative: "${res[element]["Negative"]}",
              poistive: "${res[element]["Positive"]}",
              close: "",
              token: "${res[element]["token"]}",
              nutral: "${res[element]["Neutral"]}",
              marketCap: "${res[element]["marketCap"]}"));
        }
        if (res[element]["token"] != "") {
          ltpArgs.add({"exch": "NSE", "token": "${res[element]["token"]}"});
        }
        // print("${sector.secCount}");
      }

      final ltpDatas = await api.getLTP(ltpArgs);

      Map ltpData = jsonDecode(ltpDatas.body);

      for (var element in _sectorsData) {
        if (element.token!.isNotEmpty) {
          if (element.token.toString() ==
              "${ltpData["data"]["${element.token}"]['token']}") {
            element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

            element.close = "${ltpData["data"]["${element.token}"]["close"]}";

            element.perChng =
                "${ltpData["data"]["${element.token}"]["change"]}";

            element.chng = (double.parse(
                        "${element.ltp == "0" ? element.close : element.ltp}") -
                    double.parse("${element.close}"))
                .toStringAsFixed(2);
          }
        }
      }

      for (var element in _thematicData) {
        if (element.token!.isNotEmpty) {
          if (element.token.toString() ==
              "${ltpData["data"]["${element.token}"]['token']}") {
            element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

            element.close = "${ltpData["data"]["${element.token}"]["close"]}";

            element.perChng =
                "${ltpData["data"]["${element.token}"]["change"]}";

            element.chng = (double.parse(
                        "${element.ltp == "0" ? element.close : element.ltp}") -
                    double.parse("${element.close}"))
                .toStringAsFixed(2);
          }
        }
      }

      for (var element in _strategicData) {
        if (element.token!.isNotEmpty) {
          if (element.token.toString() ==
              "${ltpData["data"]["${element.token}"]['token']}") {
            element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

            element.close = "${ltpData["data"]["${element.token}"]["close"]}";

            element.perChng =
                "${ltpData["data"]["${element.token}"]["change"]}";

            element.chng = (double.parse(
                        "${element.ltp == "0" ? element.close : element.ltp}") -
                    double.parse("${element.close}"))
                .toStringAsFixed(2);
          }
        }
      }
      for (var element in _niftyData) {
        if (element.token!.isNotEmpty) {
          if (element.token.toString() ==
              "${ltpData["data"]["${element.token}"]['token']}") {
            element.ltp = "${ltpData["data"]["${element.token}"]["lp"]}";

            element.close = "${ltpData["data"]["${element.token}"]["close"]}";

            element.perChng =
                "${ltpData["data"]["${element.token}"]["change"]}";

            element.chng = (double.parse(
                        "${element.ltp == "0" ? element.close : element.ltp}") -
                    double.parse("${element.close}"))
                .toStringAsFixed(2);
          }
        }
      }

      notifyListeners();
    } catch (e) {
    }
  }

  requestWSTradeaction(
      {required bool isSubscribe, required BuildContext context}) {
    // On web, WebSubscriptionManager handles all subscriptions
    // Skip unsubscribe here to avoid conflicts with multi-panel layout
    if (kIsWeb && !isSubscribe) return;

    try {
      String input = "";
      if (_topStockData.isNotEmpty) {
        input =
            _topStockData.map((e) => "${e.exch}|${e.token}").toSet().join("#");
      }

      if (input.isNotEmpty) {
        // ConstantName.lastSubscribe = input;
        ref.read(websocketProvider).establishConnection(
            channelInput: input,
            task: isSubscribe ? (kIsWeb ? "d" : "t") : "u",
            context: context);
      }
    } catch (e) {}

    notifyListeners();
  }

  fetchStockMonitor(String exch, String bskt, String cont) async {
    try {
      _stockMonitor = await api.getStockMonitor(exch, bskt, cont);
      // List ltpArgs=[];
      if (_stockMonitor.isNotEmpty) {
        if (_stockMonitor[0].stat == "Not_Ok") {
          _stockMonitor = [];
        }

// for (var element in _stockMonitor) {
//    ltpArgs.add({"exch": "NSE", "token": "${element.token}"});
// }
      }
      notifyListeners();
    } catch (e) {
    }
  }

  // Search scrip methods
  Future<void> searchScrip(String searchText, {List<String> filters = const ["NFO", "BFO"]}) async {
    if (searchText.length < 2) {
      _searchResults.clear();
      _searchError = null;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final result = await api.searchScrip(searchText, filters: filters);
      
      if (result.stat == "Ok") {
        _searchResults = result.values ?? [];
        _searchError = null;
      } else {
        _searchResults = [];
        _searchError = "No results found";
      }
    } catch (e) {
      _searchResults = [];
      // _searchError = e.toString();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearchResults() {
    _searchResults.clear();
    _searchError = null;
    notifyListeners();
  }

  // SpanCalc state
  SpanCalcResponse? _spanCalcResponse;
  SpanCalcResponse? get spanCalcResponse => _spanCalcResponse;
  bool _isCalculatingSpan = false;
  bool get isCalculatingSpan => _isCalculatingSpan;
  
Future<SpanCalcResponse?> calculateSpanForSelection({
    required ScripValue scrip,
    required int quantity,
    required String transactionType, // 'B' or 'S'
  }) async {
    _isCalculatingSpan = true;
    notifyListeners();
    try {
      final GetQuotes quote = await api.getScripQuote(scrip.token ?? '', scrip.exch ?? '');

      final signedQty = (transactionType == 'S' ? -quantity : quantity).toString();
      final position = SpanCalcPositionItem(
        prd: 'M',
        exch: scrip.exch ?? '',
        tsym: scrip.tsym ?? '',
        symname: quote.symname ?? '',
        instname: quote.instname ?? '',
        exd: quote.exd ?? '',
        netqty: signedQty,
        optt: quote.optt ?? '',
        strprc: quote.strprc ?? '',
      );

      final response = await calculateSpanForPositions([position]);
      return response;
    } catch (e) {
      return null;
    } finally {
      _isCalculatingSpan = false;
      notifyListeners();
    }
  }

  Future<SpanCalcPositionItem?> buildSpanPosition({
    required ScripValue scrip,
    required int quantity,
    required String transactionType, // 'B' or 'S'
  }) async {
    try {
      final GetQuotes quote = await api.getScripQuote(scrip.token ?? '', scrip.exch ?? '');
      final signedQty = (transactionType == 'S' ? -quantity : quantity).toString();

      return SpanCalcPositionItem(
        prd: 'M',
        exch: scrip.exch ?? '',
        tsym: scrip.tsym ?? '',
        symname: quote.symname ?? (scrip.symbol ?? ''),
        instname: quote.instname ?? (scrip.instname ?? ''),
        exd: quote.exd ?? (scrip.expDate ?? ''),
        netqty: signedQty,
        optt: quote.optt ?? (scrip.optt ?? ''),
        // Match web: if strprc is null/empty, omit it
        strprc: (quote.strprc ?? '').toString(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<SpanCalcResponse?> calculateSpanForPositions(
    List<SpanCalcPositionItem> positions, {
    String? actid,
  }) async {
    if (positions.isEmpty) return null;
    try {
      _isCalculatingSpan = true;
      notifyListeners();
      // final resolvedActId = (actid != null && actid.isNotEmpty)
      //     ? actid
      //     : ((prefs.clientId ?? '').isNotEmpty ? prefs.clientId! : 'DEMOIT');
      final response = await api.spanCalc(actid: 'DEMOIT', positions: positions);
      _spanCalcResponse = response;
      return response;
    } catch (e) {
      _spanCalcResponse = null;
      return null;
    } finally {
      _isCalculatingSpan = false;
      notifyListeners();
    }
  }

  // Margin Calculator Portfolio State
  final List<MarginCalculatorPortfolioItem> _marginCalculatorPortfolio = [];
  MarginCalculatorData _marginCalculatorCombinedMargin = MarginCalculatorData();
  double _marginCalculatorBenefits = 0.0;
  double _marginCalculatorBenefitPercentage = 0.0;
  bool _isMarginBreakdownExpanded = false;

  // Getters for margin calculator
  List<MarginCalculatorPortfolioItem> get marginCalculatorPortfolio => _marginCalculatorPortfolio;
  MarginCalculatorData get marginCalculatorCombinedMargin => _marginCalculatorCombinedMargin;
  double get marginCalculatorBenefits => _marginCalculatorBenefits;
  double get marginCalculatorBenefitPercentage => _marginCalculatorBenefitPercentage;
  bool get isMarginBreakdownExpanded => _isMarginBreakdownExpanded;

  // Methods for margin calculator
  void addMarginCalculatorContract(MarginCalculatorPortfolioItem item) {
    _marginCalculatorPortfolio.add(item);
    notifyListeners();
  }

  void removeMarginCalculatorContract(int index) {
    if (index >= 0 && index < _marginCalculatorPortfolio.length) {
      _marginCalculatorPortfolio.removeAt(index);
      notifyListeners();
    }
  }

  void clearMarginCalculatorPortfolio() {
    _marginCalculatorPortfolio.clear();
    _marginCalculatorCombinedMargin = MarginCalculatorData();
    _marginCalculatorBenefits = 0.0;
    _marginCalculatorBenefitPercentage = 0.0;
    notifyListeners();
  }

  void updateMarginCalculatorCombinedData({
    required MarginCalculatorData combinedMargin,
    required double benefits,
    required double benefitPercentage,
  }) {
    _marginCalculatorCombinedMargin = combinedMargin;
    _marginCalculatorBenefits = benefits;
    _marginCalculatorBenefitPercentage = benefitPercentage;
    notifyListeners();
  }

  void toggleMarginBreakdownExpansion() {
    _isMarginBreakdownExpanded = !_isMarginBreakdownExpanded;
    notifyListeners();
  }

  // Check if contract already exists
  bool marginCalculatorContractExists(String token, String exch) {
    return _marginCalculatorPortfolio.any((item) =>
        item.scrip.token == token && item.scrip.exch == exch);
  }

  String _strategyType = 'Intraday';
  TimeOfDay _entryTime = const TimeOfDay(hour: 9, minute: 35);
  TimeOfDay _exitTime = const TimeOfDay(hour: 15, minute: 15);
  
  // Instrument Settings
  String _selectedIndex = 'BANKNIFTY';
  String _selectedUnderlying = 'Cash';
  String _selectedSquareOff = 'Partial';
  
  // Leg Builder
  final List<StrategyLeg> _legs = [];
  bool _isLegBuilderCollapsed = false;
  String _selectedSegment = 'Options';
  String _totalQty = '1';
  String _selectedPosition = 'Buy';
  String _selectedOptionType = 'Call';
  String _selectedExpiry = 'Weekly';
  String _selectedStrikeCriteria = 'Strike Type';
  String _selectedStrikeType = 'ATM';
  String _currentStrike = '56900';
  
  // Target and StopLoss
  String _targetPoints = '0';
  String _stopLossPoints = '0';
  
  // Loading and Error states
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _overallTarget = false;
  bool _overallStoploss = false;

  TextEditingController targetPointsController = TextEditingController();
  TextEditingController stopLossPointsController = TextEditingController();
  TextEditingController totalQtyController = TextEditingController();

  // Getters
  String get strategyType => _strategyType;
  TimeOfDay get entryTime => _entryTime;
  TimeOfDay get exitTime => _exitTime;
  String get selectedIndex => _selectedIndex;
  String get selectedUnderlying => _selectedUnderlying;
  String get selectedSquareOff => _selectedSquareOff;
  List<StrategyLeg> get legs => _legs;
  bool get isLegBuilderCollapsed => _isLegBuilderCollapsed;
  String get selectedSegment => _selectedSegment;
  String get totalQty => _totalQty;
  String get selectedPosition => _selectedPosition;
  String get selectedOptionType => _selectedOptionType;
  String get selectedExpiry => _selectedExpiry;
  String get selectedStrikeCriteria => _selectedStrikeCriteria;
  String get selectedStrikeType => _selectedStrikeType;
  String get currentStrike => _currentStrike;
  String get targetPoints => _targetPoints;
  String get stopLossPoints => _stopLossPoints;
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get overallTarget => _overallTarget;
  bool get overallStoploss => _overallStoploss;



  void toggleOverallTarget() {
    _overallTarget = !_overallTarget;
    notifyListeners();
  }
  
  void toggleOverallStoploss() {
    _overallStoploss = !_overallStoploss;
    notifyListeners();
  }

  // Setters
  void setStrategyType(String type) {
    _strategyType = type;
    notifyListeners();
  }

  void setEntryTime(TimeOfDay time) {
    _entryTime = time;
    notifyListeners();
  }

  void setExitTime(TimeOfDay time) {
    _exitTime = time;
    notifyListeners();
  }

  void setSelectedIndex(String index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setSelectedUnderlying(String underlying) {
    _selectedUnderlying = underlying;
    notifyListeners();
  }

  void setSelectedSquareOff(String squareOff) {
    _selectedSquareOff = squareOff;
    notifyListeners();
  }

  void toggleLegBuilderCollapsed() {
    _isLegBuilderCollapsed = !_isLegBuilderCollapsed;
    notifyListeners();
  }

  void setSelectedSegment(String segment) {
    _selectedSegment = segment;
    notifyListeners();
  }

  void setTotalQty(String qty) {
    _totalQty = qty;
    notifyListeners();
  }

  void setSelectedPosition(String position) {
    _selectedPosition = position;
    notifyListeners();
  }

  void setSelectedOptionType(String optionType) {
    _selectedOptionType = optionType;
    notifyListeners();
  }

  void setSelectedExpiry(String expiry) {
    _selectedExpiry = expiry;
    notifyListeners();
  }

  void setSelectedStrikeCriteria(String criteria) {
    _selectedStrikeCriteria = criteria;
    notifyListeners();
  }

  void setSelectedStrikeType(String strikeType) {
    _selectedStrikeType = strikeType;
    _updateStrikePrice();
    notifyListeners();
  }

  void setTargetPoints(points) {
    _targetPoints = points;
    notifyListeners();
  }

  void setStopLossPoints(points) {
    _stopLossPoints = points;
    notifyListeners();
  }

  void _updateStrikePrice() async {
    try {
      final strikes = await api.getStrikePrice(_selectedIndex, _selectedExpiry);
      _currentStrike = strikes[_selectedStrikeType] ?? '56900';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update strike price';
      notifyListeners();
    }
  }

  void addLeg() {
    final leg = StrategyLeg(
      strike: _currentStrike,
      expiry: '28-AUG-2025', // This should be dynamic based on selection
      optionType: _selectedOptionType == 'Call' ? 'CE' : 'PE',
      quantity: (_totalQty).toString(), // Assuming 25 quantity per lot
      action: _selectedPosition == 'Buy' ? 'B' : 'S',
      prctype: 'MKT',
    );
    
    _legs.add(leg);
    notifyListeners();
  }

  void removeLeg(int index) {
    if (index < _legs.length) {
      _legs.removeAt(index);
      notifyListeners();
    }
  }

  Future<bool> createStrategy() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final request = StrategyRequest(
        uid: 'ZP00285', 
        email: 'user@example.com',
        statname: '$_selectedIndex ${_strategyType.toLowerCase()} Strategy',
        exch: 'NFO',
        product: 'OPTIONS',
        symbol: _selectedIndex,
        idxtoken: _selectedIndex == 'BANKNIFTY' ? '26009' : '26000',
        idxexch: 'NSE',
        statlegs: _legs,
        target: Target(type: 'POINTS', value: _targetPoints),
        stoploss: StopLoss(
          type: _stopLossPoints != null ? 'POINTS' : null,
          value: _stopLossPoints,
        ),
        starttime: '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}:00',
        endtime: '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}:00',
        executionOn: _strategyType == 'Intraday' 
            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
            : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        broker: 'ZEBU',
        datetime: DateTime.now().toIso8601String(),
      );
      final response = await api.createStrategy(request);

      
      if (response.success) {
        _successMessage = response.message;
        _legs.clear(); // Clear legs after successful creation
      } else {
        _errorMessage = response.message;
      }
      
      _isLoading = false;
      notifyListeners();
      return response.success;
    } catch (e) {
      _errorMessage = 'Failed to create strategy: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  StrategyList? _getStrategyList;
  StrategyList? get getStrategyList => _getStrategyList;

  Future<void> getstrategyList() async {
    try {
      final response = await api.getStrategyList();
      _getStrategyList = response;
      notifyListeners();
    } catch (e) {
    }

    // return ;
  }

  String _deployMessage = "";
  String get deployMessage => _deployMessage;

  Future<void> deployStrategy(String strategyId) async {
    try {
      final response = await api.deployStrategy(strategyId);
      _deployMessage = response;
      if(response == "Strategy deployed successfully"){
        _deployMessage = "Strategy deployed successfully";
      }else{
        _deployMessage = "Strategy deployment failed";
      }
      notifyListeners();
    } catch (e) {
    }
  }

  void clearStrategyList() {
    _getStrategyList = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  
  
}



// Margin Calculator Data Models
class MarginCalculatorPortfolioItem {
  final ScripValue scrip;
  final String symbol;
  final String exchange;
  final int quantity;
  final String transactionType;
  final double spanMargin;
  final double exposureMargin;
  final double totalMargin;

  MarginCalculatorPortfolioItem({
    required this.scrip,
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.transactionType,
    required this.spanMargin,
    required this.exposureMargin,
    required this.totalMargin,
  });
}

class MarginCalculatorData {
  final double span;
  final double exposure;
  final double total;

  MarginCalculatorData({
    this.span = 0.0,
    this.exposure = 0.0,
    this.total = 0.0,
  });
}
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:intl/intl.dart';
import 'package:mynt_plus/models/mf_model/all_category_new_model.dart';
import 'package:mynt_plus/models/mf_model/all_mf_holdings_model.dart';
import 'package:mynt_plus/models/mf_model/allcatlistviewmodel.dart';
import 'package:mynt_plus/models/mf_model/mf_bestnewapi_list_model.dart';
import 'package:mynt_plus/models/mf_model/mf_hold_singlepage_model.dart';
import 'package:mynt_plus/models/mf_model/mf_demat_holding_model.dart';
import 'package:mynt_plus/models/mf_model/mf_holding_new_model.dart';
import 'package:mynt_plus/models/mf_model/mf_holding_new_model.dart' as mfh;
import 'package:mynt_plus/models/mf_model/mf_order_det_model.dart';
import 'package:mynt_plus/models/mf_model/mf_sip_cancel_mess_model.dart';
import 'package:mynt_plus/models/mf_model/mf_sip_reject_reason.dart';
import 'package:mynt_plus/models/mf_model/mf_sip_single_page_provider.dart';
import 'package:mynt_plus/models/mf_model/pause_sip_model.dart';
import 'package:mynt_plus/models/mf_model/sip_mf_list_model.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
// import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/mf_model/best_mf_list_model.dart';
import '../models/mf_model/best_mf_model.dart';
import '../models/mf_model/mandate_detail_model.dart';
import '../models/mf_model/mf_all_payment_model.dart';
import '../models/mf_model/mf_bank_detail_model.dart';
import '../models/mf_model/mf_category_list_model.dart';
import '../models/mf_model/mf_categorytype_model.dart';
import '../models/mf_model/mf_create_mandate.dart';
import '../models/mf_model/mf_etf_category_model.dart';
import '../models/mf_model/mf_factsheet_data_model.dart';
import '../models/mf_model/mf_factsheet_graph.dart';
import '../models/mf_model/mf_lumpsum_order.dart';
import '../models/mf_model/mf_nav_graph_model.dart';
import '../models/mf_model/mf_nfo_model.dart';
import '../models/mf_model/mf_orderbook_lumpsum_model.dart';
import '../models/mf_model/mf_scheme_peers_model.dart';
// import '../models/mf_model/mf_search_model.dart';
import '../models/mf_model/mf_sip_model.dart';
import '../models/mf_model/mf_upi_payment_check.dart';
import '../models/mf_model/mf_watch_list.dart';
import '../models/mf_model/mf_x_sip_order_responces.dart';
import '../models/mf_model/mf_xsip_cancle_resone_res.dart';
import '../models/mf_model/mutual_fundmodel.dart';
import '../models/mf_model/redemption_model.dart';
import '../models/mf_model/top_schemes_model.dart';
import '../models/mf_model/upi_respose_model.dart';
import '../models/mf_model/x_sip_cancel_order_model.dart';
import '../res/global_state_text.dart';
import '../res/res.dart';
// import '../routes/route_names.dart';
import '../routes/route_names.dart';
import '../screens/Mobile/profile_screen/fund_screen/upi_id_screens/upi_id_payment_fail_or_success.dart';
import '../sharedWidget/custom_drag_handler.dart';
import '../sharedWidget/functions.dart';
import '../sharedWidget/snack_bar.dart';
import 'core/default_change_notifier.dart';

final mfProvider = ChangeNotifierProvider((ref) => MFProvider(ref));

class MFProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();

  final Ref ref;
  MFProvider(this.ref);

  MFFactSheetDataModel? _factSheetDataModel;
  MFFactSheetDataModel? get factSheetDataModel => _factSheetDataModel;
  MFSchemePeers? _schemePeers;
  MFSchemePeers? get schemePeers => _schemePeers;
  MFFactSheetGraph? _sheetGraph;
  MFFactSheetGraph? get sheetGraph => _sheetGraph;
  MFNavGraph? _navGraph;
  MFNavGraph? get navGraph => _navGraph;

  VerifyUPIModel? _verifyUPIModel;
  VerifyUPIModel? get verifyUPIModel => _verifyUPIModel;

  MfPlaceOrderResponces? _mfPlaceOrderResponces;
  MfPlaceOrderResponces? get mfPlaceOrderResponces => _mfPlaceOrderResponces;

  void setMfPlaceOrderFromSip(String orderId, String orderVal) {
    _mfPlaceOrderResponces = MfPlaceOrderResponces(
      orderId: orderId,
      orderVal: orderVal,
      stat: 'Ok',
    );
    notifyListeners();
  }

  BestMFModel? _bestMFModel;
  BestMFModel? get bestMFModel => _bestMFModel;

  BestmfNewlist? _newbestmodel;
  BestmfNewlist? get newbestmodel => _newbestmodel;

  MFCategoryList? _mfCategoryList;
  MFCategoryList? get mfCategoryList => _mfCategoryList;

  BestMFListModel? _bestMFList;
  BestMFListModel? get bestMFList => _bestMFList;

  TaxSaving? _bestMFListnew;
  TaxSaving? get bestMFListnew => _bestMFListnew;

  MFCategoryType? _mfCategoryTypes;
  MFCategoryType? get mfCategoryTypes => _mfCategoryTypes;

  Sip_list_data? _mfsiporderlist;
  Sip_list_data? get mfsiporderlist => _mfsiporderlist;

  AllMfModel? _allMfHoldings;
  AllMfModel? get allMfHoldings => _allMfHoldings;

  bool _showAllMfHoldings = false;
  bool get showAllMfHoldings => _showAllMfHoldings;

  // Search results for MF orders
  List<dynamic>? _mfOrderSearch = [];
  List<dynamic>? get mfOrderSearch => _mfOrderSearch;

  // Search results for SIP orders
  List<dynamic>? _mfSipSearch = [];
  List<dynamic>? get mfSipSearch => _mfSipSearch;

  void setMfOrderSearch(List<dynamic>? searchResult) {
    _mfOrderSearch = searchResult;
    notifyListeners();
  }

  void setMfSipSearch(List<dynamic>? searchResult) {
    _mfSipSearch = searchResult;
    notifyListeners();
  }

  void clearMfSearch() {
    _mfOrderSearch = [];
    _mfSipSearch = [];
    notifyListeners();
  }

  void mfOrderBookSearch(String value) {
    if (value.isNotEmpty) {
      if (_mfLumpSumOrderbook?.data != null) {
        _mfOrderSearch = _mfLumpSumOrderbook!.data!
            .where((element) =>
                (element.name?.toUpperCase().contains(value.toUpperCase()) ??
                    false) ||
                (element.orderId?.toUpperCase().contains(value.toUpperCase()) ??
                    false))
            .toList();
      }
    } else {
      _mfOrderSearch = [];
    }
    notifyListeners();
  }

  Sip_list_data? _mfnotlivesiporderlist;
  Sip_list_data? get mfnotlivesiporderlist => _mfnotlivesiporderlist;

  Sip_single_page? _mfsinglepageres;
  Sip_single_page? get mfsinglepageres => _mfsinglepageres;

  mf_order_sig_det? _mforderdet;
  mf_order_sig_det? get mforderdet => _mforderdet;

  mf_holding_sig_det? _mfholdsingepage;
  mf_holding_sig_det? get mfholdsingepage => _mfholdsingepage;

  mf_sip_reject_res? _mfsiprejreason;
  mf_sip_reject_res? get mfsiprejreason => _mfsiprejreason;

  mf_holdoing_new? _mfholdingnew;
  mf_holdoing_new? get mfholdingnew => _mfholdingnew;

  // "Mutual Fund Beta" holdings (demat_holdings endpoint) — separate from the
  // live MF holdings above so the existing tab is untouched.
  MfDematHolding? _mfDematHolding;
  MfDematHolding? get mfDematHolding => _mfDematHolding;

  bool _dematHoldLoad = false;
  bool get dematHoldLoad => _dematHoldLoad;

  bool _mforderloader = false;
  bool get mforderloader => _mforderloader;

  MutualFundModel? _mutualFundModel;
  MutualFundModel? get mutualFundModel => _mutualFundModel;

  MfSIPModel? _mfSIPModel;
  MfSIPModel? get mfSIPModel => _mfSIPModel;
  MandateDetailModel? _mandateDetailModel;
  MandateDetailModel? get mandateDetailModel => _mandateDetailModel;

  UpiIdOrderResponse? _upiApiresponse;
  UpiIdOrderResponse? get upiApiresponse => _upiApiresponse;

  List<MandateDetails>? _mandateData = [];
  List<MandateDetails>? get mandateData => _mandateData;

  bool _mandateDataLoaded = false;
  bool get mandateDataLoaded => _mandateDataLoaded;

  final List<MutualFundList> _mutualFundList = [];
  List<MutualFundList>? get mutualFundList => _mutualFundList;

  List _paymentMethod = [];

  List get paymentMethod => _paymentMethod;
  // NFODataModel? _mfNFOList;
  // NFODataModel? get mfNFOList => _mfNFOList;

  MutualFundModel? _mfNFOList;
  MutualFundModel? get mfNFOList => _mfNFOList;

  List<MutualFundList>? _mutualFundtopsearch = [];
  List<MutualFundList>? get mutualFundtopsearch => _mutualFundtopsearch;

  List<MutualFundList>? _mutualFundcommonsearch;
  List<MutualFundList>? get mutualFundcommonsearch => _mutualFundcommonsearch;

  List<MutualFundList>? _mutualFundsearchdata = [];
  List<MutualFundList>? get mutualFundsearchdata => _mutualFundsearchdata;

  // Current MF Holdings sort option tracking
  String _currentMFSortOption = "";
  String get currentMFSortOption => _currentMFSortOption;

  List<TopSchemesModelData>? _topSchemesdata = [];
  List<TopSchemesModelData>? get topSchemesdata => _topSchemesdata;

  List<MutualFundList>? _mfWatchlist = [];
  List<MutualFundList>? get mfWatchlist => _mfWatchlist;

  final List<Xsip> _mfsiplistview = [];
  List<Xsip>? get mfsiplistview => _mfsiplistview;

  List<MutualFundList>? _topmutualfund = [];
  List<MutualFundList>? get topmutualfund => _topmutualfund;

  final List<MutualFundList> _equityMf = [];
  List<MutualFundList>? get equityMf => _equityMf;
  final List<MutualFundList> _hybridMf = [];
  List<MutualFundList>? get hybridMf => _hybridMf;
  final List<MutualFundList> _debutMf = [];
  List<MutualFundList>? get debutMf => _debutMf;
  final List<MutualFundList> _otherMf = [];
  List<MutualFundList>? get otherMf => _otherMf;
  final List<MutualFundList> _solutionOMf = [];
  List<MutualFundList>? get solutionOMf => _solutionOMf;

  final List<MutualFundList> _filteredMf = [];
  List<MutualFundList>? get filteredMf => _filteredMf;

  final List<MFCategory> _mfCategorys = [];
  List<MFCategory> get mfCategorys => _mfCategorys;

  final List<String> _subCat = [];
  List<String>? get subCat => _subCat;

  final List<String> _uniqueList = [];
  List<String>? get uniqueList => _uniqueList;

  final List<String> _amc = [];
  List<String>? get amc => _amc;

  final List<String> _amcfilter = [];
  List<String>? get amcfilter => _amcfilter;

  final List<double> _schmemin = [];
  List<double>? get schmemin => _schmemin;

  final List<int> _schmeminfilter = [];
  List<int>? get schmeminfilter => _schmeminfilter;

  final List<String> _aum = [];
  List<String>? get aum => _aum;

  final bool _isFiltered = false;
  bool? get isFiltered => _isFiltered;

  bool? _singleloader = false;
  bool? get singleloader => _singleloader;

  final bool _timer = false;
  bool? get timer => _timer;

  String _selechip = "";
  String get selctedchip => _selechip;

  String _droupreason = "";
  String get droupreason => _droupreason;

  String _orderseltab = "";
  String get orderseltab => _orderseltab;

  bool? _bestmfloader = false;
  bool? get bestmfloader => _bestmfloader;

  bool _fundDetailLoader = false;
  bool get fundDetailLoader => _fundDetailLoader;

  void setFundDetailLoader(bool value) {
    _fundDetailLoader = value;
    notifyListeners();
  }

  bool _categoryDataLoader = false;
  bool get categoryDataLoader => _categoryDataLoader;

  void setCategoryDataLoader(bool value) {
    _categoryDataLoader = value;
    notifyListeners();
  }

  bool? _watchbatchval = false;
  bool? get watchbatchval => _watchbatchval;

  bool? _triggerfromMF = false;
  bool? get triggerfromMF => _triggerfromMF;

  setterformftrigger(bool name) {
    _triggerfromMF = name;
    notifyListeners();
  }

  bool? _holdstatload = false;
  bool? get holdstatload => _holdstatload;

  RangeValues _currentRangeValues = const RangeValues(0, 11);
  RangeValues get currentRangeValues => _currentRangeValues;

  TextEditingController invAmt = TextEditingController();
  TextEditingController upiId = TextEditingController();
  TextEditingController installmentAmt = TextEditingController();
  TextEditingController redemptionQty = TextEditingController();
  TextEditingController redemptionAmount = TextEditingController();
  TextEditingController rejectsip = TextEditingController();
  TextEditingController pausesip = TextEditingController();

  String? invAmtError = "",
      upiError = "",
      installmentAmtError = "",
      invDurationError = "",
      redemptionError = "",
      redemptionOrderError = "";

  RedemptionModel? _redemptionData;
  RedemptionModel? get redemptionData => _redemptionData;

  int? _activeTab = 0;
  int? get activeTab => _activeTab;

  int _mfPortfolioInitialTab = 0;
  int get mfPortfolioInitialTab => _mfPortfolioInitialTab;
  void setMfPortfolioInitialTab(int tab) {
    _mfPortfolioInitialTab = tab;
  }

  Timer? _autoPopTimer;
  Timer? get autoPopTimer => _autoPopTimer;

  Timer? _threeSecondTimer;

  Timer? get threeSecondTimer => _threeSecondTimer;

  String _namechange = "";
  String get namechange => _namechange;

  String _orderpagetitle = "";
  String get orderpagetitle => _orderpagetitle;

  orderpagetite(String name) {
    _orderpagetitle = name;
    notifyListeners();
  }

  orderrejectupdate(String name) {
    _droupreason = name;
    // print("djfj${_droupreason}");
    notifyListeners();
  }

  cleartext() {
    _droupreason = "";
  }

  changename(String name) {
    _namechange = name;
    notifyListeners();
  }

  loaderfun() {
    _bestmfloader = true;
    // print("ttttttttttt");
    notifyListeners();
  }

  loaderfunfalse() {
    _bestmfloader = false;
    // print("ttttttttttt");
    notifyListeners();
  }

  mfApicallinit(BuildContext ctx, int tab) async {
    // loaderfun();
    mfExTabchange(tab);
    fetchsiprejreasn();
    // await fetchnewMFBestList();
    // await fetchBestMF();
    // Navigator.pushNamed(ctx, Routes.mfmainscreen);
    // await fetchsiprejreasin();
    // Old MF holdings API is being decommissioned — demat holdings replace it.
    // await fetchmfholdingnew();
    await fetchmfdematholding();

    await fetchMfOrderbook(ctx);
    // await fetchmfallcatnew();
    await ref.read(portfolioProvider).fetchMFHoldings(ctx);
    // await fetchMFCategoryType();
    // await fetchmfNFO(context);
    await fetchMFWatchlist("", "", ctx, true, "");
    await fetchmfsiplist();
    // await fetchBestMF();
    // await ref.read(portfolioProvider).fetchMFHoldings(context);
    // await fetchMFCategoryType();
    // // await fetchmfNFO(context);
    // await fetchMFWatchlist("", "", context, true, "");
    // Navigator.pushNamed(context, Routes.mfmainscreen);
    // launch(
    //     "https://mynt.zebuetrade.com/mutualfund?sUserId=${pref.clientId}&sAccountId=${pref.clientId}&sToken=${funds.fundHstoken!.hstk}");
  }

  mfExTabchange(int tab) {
    _activeTab = tab;
    notifyListeners();
  }

  changetitle(String title) {
    _selechip = title;
    notifyListeners();
  }

  orderchangetitle(String title) {
    _orderseltab = title;
    notifyListeners();
  }

  updateRange(RangeValues values, String start, String end) {
    _currentRangeValues = values;
    // print("object  $start $end");

    notifyListeners();
  }

  void recdemevalu() {
    redemptionQty.text = _holssinglelist![0].avgQty!;
  }

  /// Sets the single-holding list directly from a caller-supplied item.
  /// Used by the Mutual Fund Beta tab, which already has its own holding object
  /// (with scheme code) rather than one looked up from [mfholdingnew].
  void setHoldSingleListItem(dynamic item) {
    _holssinglelist = [item];
    notifyListeners();
  }

  String _paymentName = "UPI";

  String get paymentName => _paymentName;
  BankDetailsModel? _bankDetailsModel;
  UPIDetailsModel? _upiDetailsModel;
  UPIDetailsModel? get upiDetailsModel => _upiDetailsModel;
  BankDetailsModel? get bankDetailsModel => _bankDetailsModel;

  String _sipDuration = "";

  bool _isInitalPay = false;
  bool get isInitalPay => _isInitalPay;

  bool _investloader = false;
  bool get investloader => _investloader;

  String? _loadingMessage;
  String? get loadingMessage => _loadingMessage;

  String _accNum = "";

  String get accNum => _accNum;

  String _ifsc = "";

  String get ifsc => _ifsc;

  String _bankname = "";

  String get bankname => _bankname;

  List<BankData>? _bankData = [];
  List<BankData>? get bankData => _bankData;

  int get startValue => _schmeminfilter[_currentRangeValues.start.round()];
  int get endValue => _schmeminfilter[_currentRangeValues.end.round()];

  final List<String> _aumfilter = [];
  List<String>? get aumfilter => _aumfilter;

  String _mfCategory = "Top Mutual Funds";
  String get mfCategory => _mfCategory;

  final String _bestmfselected = "";
  String get bestmfselected => _bestmfselected;

  final String _redemtionres = "";
  String get redemtionres => _redemtionres;

  MFWatchlistModel? _mfWatchlistModel;
  MFWatchlistModel? get mfWatchlistModel => _mfWatchlistModel;

  MFOrderBookModel? _mfLumpSumOrderbook;
  MFOrderBookModel? get mflumpsumorderbook => _mfLumpSumOrderbook;

  mf_catge_newlist? _mfallcatnewlist;
  mf_catge_newlist? get mfallcatnewlist => _mfallcatnewlist;

  final_list_model? _mfcatlistview;
  final_list_model? get mfcatlistview => _mfcatlistview;

  MfCreateMandateModel? _createMandateModel;
  MfCreateMandateModel? get createMandateModel => _createMandateModel;

  XsipOrderResponces? _xsipOrderResponces;
  XsipOrderResponces? get xsipOrderResponces => _xsipOrderResponces;

  XsipOrderCancleResone? _xsipOrderCancleResone;
  XsipOrderCancleResone? get xsipOrderCancleResone => _xsipOrderCancleResone;

  UPIPaymentStatusCheck? _statusCheckUpi;
  UPIPaymentStatusCheck? get statusCheckUpi => _statusCheckUpi;

  XsipOrderCancleResponces? _xsipOrderCancleResponces;
  XsipOrderCancleResponces? get xsipOrderCancleResponces =>
      _xsipOrderCancleResponces;

  mf_sip_cancel_message? _mfsipcancelmess;
  mf_sip_cancel_message? get mfsipcancelmess => _mfsipcancelmess;

  pause_spi_res? _mfsippause;
  pause_spi_res? get mfsippause => _mfsippause;

  AllPaymentMfModel? _allPaymentMfModel;
  AllPaymentMfModel? get allPaymentMfModel => _allPaymentMfModel;

  final List<MutualFundList> _bestmfFilter = [];
  List<MutualFundList>? get bestmfFilter => _bestmfFilter;

  List<Fund>? _catnewlist = [];
  List<Fund>? get catnewlist => _catnewlist;

  List? _holssinglelist = [];
  List? get holssinglelist => _holssinglelist;

  // List<MutualFundList>? _bestmfList = [];
  // List<MutualFundList>? get bestmfList => _bestmfList;
  bool? _isportfolio = false;
  bool? get isportfolio => _isportfolio;

  setPortfolioIs(bool value) {
    _isportfolio = value;
    notifyListeners();
  }

  setInitialPay(bool value) {
    _isInitalPay = value;
    notifyListeners();
  }

  setLoadingMessage(String? message) {
    _loadingMessage = message;
    notifyListeners();
  }

  setInvestLoader(bool value) {
    _investloader = value;
    notifyListeners();
  }

  final List _bestMFListStatic = [
    {
      "funds": "46 funds",
      "image": "assets/explore/loan.svg",
      "subtitle": "Build wealth and save taxes",
      "title": "Save taxes"
    },
    {
      "funds": "90 funds",
      "image": "assets/explore/transactions.svg",
      "subtitle": "Stable income and growth",
      "title": "Equity + Debt"
    },
    {
      "funds": "56 funds",
      "image": "assets/explore/goldcoin.svg",
      "subtitle": "Hybrid of active and passive",
      "title": "Smart beta"
    },
    {
      "funds": "120 funds",
      "image": "assets/explore/globe.svg",
      "subtitle": "Diversify your portfolio globally",
      "title": "International funds"
    }
  ];

  List get bestMFListStatic => _bestMFListStatic;

  final List _bestMFListStaticnew = [
    {
      "funds": "46 funds",
      "image": "assets/explore/loan.svg",
      "subtitle": "Build wealth and save taxes",
      "title": "Tax Saving",
      "titlekey": "taxSaving"
    },
    {
      "funds": "90 funds",
      "image": "assets/explore/growthnew.svg",
      "subtitle": "Maximize returns with high growth",
      "title": "High Growth Equity",
      "titlekey": "highGrowthEquity"
    },
    {
      "funds": "56 funds",
      "image": "assets/explore/goldcoin.svg",
      "subtitle": "Stable income and growth",
      "title": "Stable Debt",
      "titlekey": "stableDebt"
    },
    {
      "funds": "120 funds",
      "image": "assets/explore/transactions.svg",
      "subtitle": "Focused investments in key sectors",
      "title": "Sectoral Thematic",
      "titlekey": "sectoralThematic"
    },
    {
      "funds": "56 funds",
      "image": "assets/explore/globe.svg",
      "subtitle": "Diversify your portfolio globally",
      "title": "International  Exposure",
      "titlekey": "internationalExposure"
    },
    {
      "funds": "120 funds",
      "image": "assets/explore/balancehybrid.svg",
      "subtitle": "Stability and growth combined",
      "title": "Balanced Hybrid",
      "titlekey": "balancedHybrid"
    }
  ];

  List get bestMFListStaticnew => _bestMFListStaticnew;
  // List get bestmfnewlist => _bestMFListnew;

  final List _mFCategoryTypesStatic = [
    {
      "dataIcon": 'assets/explore/equity.png',
      "description":
          "Invest primarily in stocks. High risk, high return potential.",
      "title": "Equity",
      "sub": []
    },
    {
      "dataIcon": 'assets/explore/coins.png',
      "description":
          "Invest in bonds and fixed-income securities. Lower risk, stable returns.",
      "title": "Income",
      "sub": []
    },
    {
      "dataIcon": 'assets/explore/gold.png',
      "description":
          "Invest in gold and related securities. Hedge against inflation.",
      "title": "Gold",
      "sub": []
    },
    {
      "dataIcon": 'assets/explore/hybrid.png',
      "description": "Mix of equity and debt to balance risk and return.",
      "title": "Hybrid",
      "sub": []
    },
    {
      "dataIcon": 'assets/explore/solution.png',
      "description":
          "Financial goals include retirement planning, funding a child's education, and etc.",
      "title": "Solution",
      "sub": []
    },
  ];

  List get mFCategoryTypesStatic => _mFCategoryTypesStatic;

  final List _mfrejectsiplist = [
    {"id": "01", "reason_name": "Non availability of Funds"},
    {"id": "02", "reason_name": "Scheme not performing"},
    {"id": "03", "reason_name": "Service issue"},
    {"id": "04", "reason_name": "Load Revised"},
    {"id": "05", "reason_name": "Wish to invest in other schemes"},
    {"id": "06", "reason_name": "Change in Fund Manager"},
    {"id": "07", "reason_name": "Goal Achieved"},
    {"id": "08", "reason_name": "Not comfortable with market volatility"},
    {"id": "09", "reason_name": "Will be restarting SIP after few months"},
    {"id": "10", "reason_name": "Modifications in bank/mandate/date etc"},
    {"id": "11", "reason_name": "I have decided to invest elsewhere"},
    {"id": "12", "reason_name": "This is not the right time to invest"},
    {"id": "13", "reason_name": "Others (pls specify the reason)"}
  ];

  List? get mfrejectsiplist => _mfrejectsiplist;

  // makefalse(String isn) {
  //   int index = _topmutualfund!.indexWhere((element) => element.iSIN == isn);
  //   if (index != -1) {
  //     _topmutualfund![index].isAdd = false;
  //   } else {
  //     print("Value not found");
  //   }

  //   if(_isFiltered!){
  //     for (var watchListMf in _mfWatchlist!) {
  //         _filteredMf!.where((m) => m.iSIN == watchListMf.iSIN).forEach((m) => m.isAdd = true);
  //       }
  //   }

  //   notifyListeners();
  // }

  //  maketrue(String isn) {
  //   int index = _topmutualfund!.indexWhere((element) => element.iSIN == isn);
  //   if (index != -1) {
  //     _topmutualfund![index].isAdd = true;
  //   } else {
  //     print("Value not found");
  //   }

  //   notifyListeners();
  // }

  // updateFilteredMF(range){

  //   _filteredMf = _mutualFundList!
  //     .where((content) {
  //       return _subcatselected.contains(content.sCHEMESUBCATEGORY);}).toList();
  //   if(_amcselected.isNotEmpty){
  //   _filteredMf = _subcatselected.isEmpty ? _mutualFundList!
  //     .where((content) {return _amcselected.contains(content.aMCCode!.toLowerCase().replaceAll('mf', '').replaceAll('_', ' '));}).toList() : _filteredMf!
  //     .where((content) {return _amcselected.contains(content.aMCCode!.toLowerCase().replaceAll('mf', '').replaceAll('_', ' '));}).toList();
  //   }
  //   if(range != false){
  //    _filteredMf = _subcatselected.isEmpty && _amcselected.isEmpty ? _mutualFundList!
  //     .where((content) {double value = double.parse(content.minimumPurchaseAmount!);
  //   return value >= startValue && value <= endValue;}).toList() : _filteredMf!
  //     .where((content) {double value = double.parse(content.minimumPurchaseAmount!);
  //   return value >= startValue && value <= endValue;}).toList();
  //   }
  //   _isFiltered = true;
  //     if(_subcatselected.isEmpty & _amcselected.isEmpty & !range){
  //       _isFiltered = false;
  //     }
  //     for (var watchListMf in _mfWatchlist!) {
  //         _filteredMf!.where((m) => m.iSIN == watchListMf.iSIN).forEach((m) => m.isAdd = true);
  //       }
  //   notifyListeners();
  // }

  // bestmfEmpty(String val) {
  //   _bestmfselected = val;
  //   notifyListeners();
  // }

  // filterItem(String title) {
  //   _bestmfselected = title;
  //   _bestmfFilter = _bestmfList!.where((item) {
  //     bool isT = item.schemeName!.contains("GROWTH");
  //     if (isT) {
  //       if (title == "Save taxes") {
  //         return item.sCHEMECATEGORY!.toUpperCase().contains("EQUITY") &&
  //             item.sCHEMESUBCATEGORY!.toUpperCase().contains("ELSS");
  //       } else if (title == "Low-cost index funds") {
  //         return item.sCHEMECATEGORY!.toUpperCase().contains("OTHER") &&
  //             item.sCHEMESUBCATEGORY!.toUpperCase().contains("INDEX FUNDS") &&
  //             double.parse(item.minimumPurchaseAmount.toString()).toInt() <
  //                 5000;
  //       } else if (title == "Smart beta") {
  //         return item.sCHEMECATEGORY!.toUpperCase().contains("OTHER") &&
  //             item.sCHEMESUBCATEGORY!.toUpperCase().contains("INDEX FUNDS") &&
  //             item.schemeType!.toUpperCase().contains("EQUITY") &&
  //             double.parse(item.minimumPurchaseAmount.toString()).toInt() <
  //                 5000;
  //       } else if (title == "Equity + Debt") {
  //         return item.sCHEMECATEGORY!.toUpperCase().contains("HYBRID") &&
  //             (item.sCHEMESUBCATEGORY!.contains(
  //                     "Dynamic Asset Allocation or Balanced Advantage") ||
  //                 item.sCHEMESUBCATEGORY!.contains("Balanced Hybrid Fund"));
  //       } else if (title == "Alternatives to bank FDs") {
  //         return item.sCHEMECATEGORY!.toUpperCase().contains('DEBT') &&
  //             item.sCHEMESUBCATEGORY!.toUpperCase().contains('LIQUID');
  //       }
  //     }

  //     return false;
  //   }).toList();

  //   notifyListeners();
  // }

  List _mfReturnsGridview = [];

  List get mfReturnsGridview => _mfReturnsGridview;

  final bool _mfPlaceorderload = true;
  bool? get mfPlaceorderload => _mfPlaceorderload;

  String _comYear = "10 Years";
  String get comYear => _comYear;

  final List _compYears = [
    {"yearName": "10 Years", "year": "10Year"},
    {"yearName": "5 Years", "year": "5Year"},
    {"yearName": "3 Years", "year": "3Year"},
    {"yearName": "2 Years", "year": "2Year"},
    {"yearName": "1 Year", "year": "1Year"}
  ];

  List get comYears => _compYears;

  //  MF SIP

  // TextEditingController instalmentAmt = TextEditingController();
  final TextEditingController mfsearchcontroller = TextEditingController();

  // MF Holdings Search Variables
  final TextEditingController mfHoldingSearchController =
      TextEditingController();
  bool _showMfHoldingSearch = false;
  bool get showMfHoldingSearch => _showMfHoldingSearch;
  List<dynamic>? _mfHoldingSearchItems = [];
  List<dynamic>? get mfHoldingSearchItems => _mfHoldingSearchItems;

  TextEditingController invDuration = TextEditingController();
  String _freqName = "";
  String _dates = "1";
  int _sipMonth = DateTime.now().month;
  int get sipMonth => _sipMonth;
  String get freqName => _freqName;
  final String _sipreason = "";
  String get sipreason => _sipreason;

  String get dates => _dates;

  String _xsipvalue = "";
  String get xsipvalue => _xsipvalue;

  /// Get the pause flag from MONTHLY entry instead of first entry
  String? get monthlyPauseFlag {
    if (_mfSIPModel?.data == null || _mfSIPModel!.data!.isEmpty) return null;

    // Find MONTHLY entry
    for (var element in _mfSIPModel!.data!) {
      if (element.sIPFREQUENCY == "MONTHLY") {
        return element.pAUSEFLAG;
      }
    }

    // Fallback to first entry if no MONTHLY found
    return _mfSIPModel!.data![0].pAUSEFLAG;
  }

  String _xsipcaseno = "";
  String get xsipcaseno => _xsipcaseno;

  List<String> _dateList = [];
  List<String> get dateList => _dateList;
  String _insAmt = "0.00";
  String get insAmt => _insAmt;

  List mfOrderTpyes = ["One-time", "SIP"]; //["Lumpsum"];
  String _mfOrderTpye = "One-time";
  String get mfOrderTpye => _mfOrderTpye;

  List mfOrderbookfilters = ["All", "Lumpsum", "X-SIP", "Redeem"];
  String _mfOrderbookfilter = "All";
  String get mfOrderbookfilter => _mfOrderbookfilter;

  String _mandateId = "";
  String get mandateId => _mandateId;

  String _mandateStatus = "";
  String get mandateStatus => _mandateStatus;

  final List<String> _subcatselected = [];
  List<String> get subcatselected => _subcatselected;

  final List<String> _amcselected = [];
  List<String> get amcselected => _amcselected;

  final String _aumselected = "";
  String get aumselected => _aumselected;

  final bool _mfloader = false;
  bool? get mfloader => _mfloader;

  bool _showSearch = false;
  bool get showSearch => _showSearch;

  int _shoew = 10;
  int get shoew => _shoew;

  final int _minpurchase = 0;
  int get minpurchase => _minpurchase;

  final int _bestshoew = 10;
  int get bestshoew => _bestshoew;

  // selectedSubCat(String value) {
  //   // _subcatselected = value;
  //   if (_subcatselected.contains(value)) {
  //     _subcatselected.remove(value); // Deselect the item
  //   } else {
  //     _subcatselected.add(value); // Select the item
  //   }
  //   print("value $_subcatselected");
  //   notifyListeners();
  // }

  // selectedminamt(int value) {
  //   _minpurchase = value;
  //   print("value $_minpurchase");
  //   notifyListeners();
  // }

  // selectedamc(String value) {
  //   // _amcselected = value;
  //   if (_amcselected.contains(value)) {
  //     _amcselected.remove(value); // Deselect the item
  //   } else {
  //     _amcselected.add(value); // Select the item
  //   }
  //   print("value $_amcselected");
  //   notifyListeners();
  // }

  // bestshowmore(int value) {
  //   _bestmfFilter!.length > _bestshoew
  //       ? _bestshoew += value
  //       : _bestshoew += (_bestmfFilter!.length - _bestshoew);
  //   notifyListeners();
  // }

  // showmore(int value) {
  //   _topmutualfund!.length > _shoew
  //       ? _shoew += value
  //       : _shoew += (_topmutualfund!.length - _shoew);
  //   // print(
  //   //     " overall length ${_mutualFundList!.length} object ${_mutualFundList!.length > _shoew ? _shoew : _shoew += (_mutualFundList!.length - _shoew)}");
  //   notifyListeners();
  // }

  showOpenSearch(bool value) {
    _showSearch = value;
    if (!_showSearch) {
      _mutualFundtopsearch = [];
      mfsearchcontroller.clear();
    }
    notifyListeners();
  }

  chngPayName(String val) {
    if (val == "NET BANKING") {
      upiError = "";
    } else {
      final RegExp upiRegex =
          RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$', caseSensitive: false);
      if (upiId.text.isEmpty) {
        upiError = "Please enter UPI ID";
      } else if (!upiRegex.hasMatch(upiId.text)) {
        upiError = "Please enter valid UPI ID";
      } else {
        upiError = "";
      }
    }
    _paymentName = val;
    notifyListeners();
  }

  commonsearch() {
    _mutualFundsearchdata = [];
    mfsearchcontroller.clear();

    notifyListeners();
  }

  clearopenoreder() {
    mfsearchcontroller.clear();
    _mutualFundtopsearch = [];
    _mutualFundsearchdata!.clear();
    notifyListeners();
  }

  // bestmfSearch(String value, BuildContext context) {
  //   if (value.length > 1) {
  //     _mutualFundtopsearch = [];
  //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //     _mutualFundtopsearch = _bestmfFilter!.where((element) {
  //       final symbol = element.schemeName!.toUpperCase();
  //       // final companyname = element.companyName!.toUpperCase();
  //       // final status = element.reponseStatus!.toUpperCase();
  //       // final investedvalue = element.bidDetail![0].amount!.toUpperCase();
  //       return
  //           //companyname.contains(value.toUpperCase()) ||
  //           //     status.contains(value.toUpperCase()) ||
  //           //     investedvalue.contains(value.toUpperCase()) ||
  //           symbol.contains(value.toUpperCase());
  //     }).toList();
  //     if (_bestmfFilter!.isEmpty) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(warningMessage(context, 'No Data Found'));
  //     } else {
  //       ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //     }
  //   } else {
  //     _mutualFundtopsearch = [];
  //   }
  //   notifyListeners();
  // }

  // mfSearch(String value, BuildContext context) {
  //   if (value.length > 1) {
  //     _mutualFundtopsearch = [];
  //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //     _mutualFundtopsearch = _mutualFundList!.where((element) {
  //       final symbol = element.schemeName!.toUpperCase();
  //       // final companyname = element.companyName!.toUpperCase();
  //       // final status = element.reponseStatus!.toUpperCase();
  //       // final investedvalue = element.bidDetail![0].amount!.toUpperCase();
  //       return
  //           //companyname.contains(value.toUpperCase()) ||
  //           //     status.contains(value.toUpperCase()) ||
  //           //     investedvalue.contains(value.toUpperCase()) ||
  //           symbol.contains(value.toUpperCase());
  //     }).toList();
  //     if (_mutualFundtopsearch!.isEmpty) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(warningMessage(context, 'No Data Found'));
  //     } else {
  //       ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //     }
  //   } else {
  //     _mutualFundtopsearch = [];
  //   }
  //   notifyListeners();
  // }
  invertfun(String isin, String schemeCode, BuildContext context) async {
    _singleloader = true;
    await fetchMFSipData(isin, schemeCode);
    await fetchMFMandateDetail();
    // fetchBankDetail();
    await fetchUpiDetail('', context);
    resetmfordervalidation();
    // await chngMandate(mandateId);
    _singleloader = false;
  }

  chngMandate(String val) {
    _mandateId = val;
    if (val != "Lumpsum") {
      var indx = _mandateData!.indexWhere((f) => f.mandateId == val);
      _mandateStatus = _mandateData![indx].status!;
      // print("${_mandateData![indx].mandateId}, ${_mandateData![indx].status}");
    }
    invAmtError = "";
    installmentAmtError = "";
    invDurationError = "";
    upiError = "";
    notifyListeners();
  }

  chngOrderType(String val) {
    _mfOrderTpye = val;
    notifyListeners();
  }

  resetmfordervalidation() {
    invAmtError = "";
    upiError = "";
    installmentAmtError = "";
    invDurationError = "";
  }

  chngComYear(String year, String yearName, String isin) async {
    _comYear = yearName;
    await fetchSchemePeer(isin, year);
    notifyListeners();
  }

  chngOrderFilter(String val) {
    _mfOrderbookfilter = val;

    notifyListeners();
  }

  chngFrequency(String val) {
    _freqName = val;
    if (_mfSIPModel!.data!.isNotEmpty) {
      for (var element in _mfSIPModel!.data!) {
        if (element.sIPFREQUENCY == _freqName) {
          if (_freqName == "DAILY") {
            _dateList = [];
          } else {
            _dateList = element.sIPDATES!.replaceAll("\"", "").split(',');
          }
          invDuration.text = "${element.sIPMAXIMUMINSTALLMENTNUMBERS}";
          _sipDuration = "${element.sIPMINIMUMINSTALLMENTNUMBERS}";
          // _insAmt = "${element.sIPMINIMUMINSTALLMENTNUMBERS ?? 0.00}";
        }
      }
    }
    notifyListeners();
  }

  chngxsip(
    String val,
  ) {
    _xsipvalue = val;
    _xsipcaseno = _xsipOrderCancleResone!.data!
        .firstWhere((reason) => reason.reasonName == val)
        .id
        .toString();
    // print("object ${_xsipcaseno}");
    notifyListeners();
  }

  chngMFCategory(String val) {
    _mfCategory = val;
    if (_mfCategory == "Equity Funds") {
      _topmutualfund = _equityMf;
      _shoew = 0;
    } else if (_mfCategory == "Debt Funds") {
      _topmutualfund = _debutMf;
      _shoew = 0;
    } else if (_mfCategory == "Hybrid Funds") {
      _topmutualfund = _hybridMf;
      _shoew = 0;
    } else if (_mfCategory == "Solution Oriented Funds") {
      _topmutualfund = _solutionOMf;
      _shoew = 0;
    } else if (_mfCategory == "Top Mutual Funds") {
      _topmutualfund = _mutualFundModel!.mutualFundList;
      _shoew = 0;
    } else if (val == "out") {
      _topmutualfund = _mutualFundModel!.mutualFundList;
      _shoew = 10;
    } else {
      _shoew = 0;
      _topmutualfund = _otherMf;
    }

    for (var watchListMf in _mfWatchlist!) {
      for (var masterMf in _mutualFundList) {
        if (watchListMf.iSIN == masterMf.iSIN) {
          masterMf.isAdd = true;
        }
      }
    }
    _mutualFundList.sort((a, b) {
      return double.parse(b.aUM.toString() == "null" || b.aUM!.isEmpty
              ? "0.00"
              : b.aUM.toString())
          .compareTo(double.parse(a.aUM.toString() == "null" || a.aUM!.isEmpty
              ? "0.00"
              : a.aUM.toString()));
    });

    notifyListeners();
  }

  clearMfSearchResult() {
    _mutualFundsearchdata = [];
    notifyListeners();
  }

  // MF Holdings Search Methods
  void setMfHoldingSearch(bool show) {
    _showMfHoldingSearch = show;
    if (!show) {
      mfHoldingSearchController.clear();
      _mfHoldingSearchItems = [];
    }
    notifyListeners();
  }

  void mfHoldingSearch(String value, BuildContext context) {
    if (value.isNotEmpty) {
      _showMfHoldingSearch = true;
      _mfHoldingSearchItems = [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Search in the holdings data
      if (_mfholdingnew?.data != null) {
        _mfHoldingSearchItems = _mfholdingnew!.data!
            .where((element) =>
                (element.name?.toUpperCase().contains(value.toUpperCase()) ??
                    false) ||
                (element.iSIN?.toUpperCase().contains(value.toUpperCase()) ??
                    false))
            .toList();
      }
    } else {
      _showMfHoldingSearch = false;
      // When search text is empty, show all items (don't filter)
      _mfHoldingSearchItems = _mfholdingnew?.data ?? [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    notifyListeners();
  }

  void clearMfHoldingSearch() {
    _mfHoldingSearchItems = [];
    mfHoldingSearchController.clear();
    _showMfHoldingSearch = false;
    notifyListeners();
  }

  Future fetchmfCommonsearch(String value, BuildContext context) async {
    try {
      var mutualFundsearch = await api.getSearchMf(value);
      _mutualFundsearchdata = mutualFundsearch.data ?? [];
      for (var masterMf in _mfWatchlist!) {
        _mutualFundsearchdata!
            .where((m) => m.iSIN == masterMf.iSIN)
            .forEach((m) => m.isAdd = true);
      }
      var search = "";
      for (var i = 0; i < _mutualFundsearchdata!.length; i++) {
        search = "${_mutualFundsearchdata![i].schemeName}";
      }
      notifyListeners();
      // print("object ${search}");
    } catch (e) {
      // print("SEARCH ERROR :: $e");
    }
  }

  Future fetchmfNFO(BuildContext context) async {
    try {
      _investloader = true;
      _mfNFOList = await api.getNFOData();
      // print("NFO list ${_mfNFOList!.nfoList}");
      notifyListeners();
    } catch (e) {
      // print("NFO ERROR :: $e");
    } finally {
      _investloader = false;
    }
  }

  Future fetchsiprejreasn() async {
    try {
      // _investloader = true;
      _mfsiprejreason = await api.getsiprejreason();
      // print("sip reject list${_mfsiprejreason?.toJson()}");
      notifyListeners();
    } catch (e) {
      // print("NFO sippp error :: $e");
    } finally {
      // _investloader = false;
    }
  }

  Future fetchTopSchemes() async {
    try {
      _investloader = true;

      var topSchemesdata = await api.getTopSchemes();
      if (topSchemesdata.msg != "") {
        _topSchemesdata = topSchemesdata.data;
        // log("TopSchemesModel ${_topSchemesdata![0]}");
      }
    } catch (e) {
      // print("top schemes error $e");
    } finally {
      _investloader = false;

      notifyListeners();
    }
  }

  MfEtfCategoryModel? _etfCategorydata;
  MfEtfCategoryModel? get etfCategorydata => _etfCategorydata;

  Future fetchEtfCategory() async {
    try {
      _investloader = true;
      var etfCategorydata = await api.getetfcategory();
      _etfCategorydata = etfCategorydata;
      // print("ETF Category ==>${_etfCategorydata}");
      notifyListeners();
    } catch (e) {
    } finally {
      _investloader = false;
    }
  }

  // Future fetchMasterMF() async {
  //   try {
  //     _mfloader = true;
  //     _topmutualfund = [];
  //     _equityMf = [];
  //     _debutMf = [];
  //     _hybridMf = [];
  //     _solutionOMf = [];
  //     _otherMf = [];
  //     _mutualFundList = [];
  //     _mfCategorys = [];
  //     _mutualFundModel ??= await api.getMasterMF();
  //     _bestMFModel ?? await fetchBestMF();
  //     // await fetchBestMF();
  //     _mfCategory = "Top Mutual Funds";
  //     if (_mutualFundModel!.stat == "Ok") {
  //       for (var element in _mutualFundModel!.mutualFundList!) {
  //         if (element.sCHEMECATEGORY == "Equity Scheme ") {
  //           _equityMf!.add(element);
  //         } else if (element.sCHEMECATEGORY == "Debt Scheme ") {
  //           _debutMf!.add(element);
  //         } else if (element.sCHEMECATEGORY == "Hybrid Scheme ") {
  //           _hybridMf!.add(element);
  //         } else if (element.sCHEMECATEGORY == "Solution Oriented Scheme ") {
  //           _solutionOMf!.add(element);
  //         } else {
  //           _otherMf!.add(element);
  //         }
  //       }
  //       _mutualFundList = _mutualFundModel!.mutualFundList;
  //       _topmutualfund = _mutualFundModel!.mutualFundList;
  //       _bestmfList = _mutualFundModel!.mutualFundList;

  //       for (var element in _bestmfList!) {
  //         _subCat?.add(element.sCHEMESUBCATEGORY.toString());
  //         _amc?.add(element.aMCCode.toString());
  //         _schmemin!
  //             .add(double.parse(element.minimumPurchaseAmount.toString()));
  //         _aum!.add(element.aUM.toString());
  //       }
  //       for (var watchListMf in _mfWatchlist!) {
  //         for (var masterMf in _mutualFundList!) {
  //           if (watchListMf.iSIN == masterMf.iSIN) {
  //             masterMf.isAdd = true;
  //           }
  //         }
  //       }
  //       _uniqueList = _subCat!
  //           .where((item) => item.trim().isNotEmpty)
  //           .toSet()
  //           .toList()
  //         ..sort();

  //       _amcfilter = _amc!
  //           .map((fund) =>
  //               fund.toLowerCase().replaceAll('mf', '').replaceAll('_', ' '))
  //           .toSet()
  //           .toList();

  //       _schmeminfilter =
  //           _schmemin!.map((item) => item.toInt()).toSet().toList()..sort();
  //       _aumfilter = _aum!.map((item) => item).toSet().toList()..sort();

  //       print("object $_schmeminfilter");
  //       _topmutualfund!.sort((a, b) {
  //         return double.parse(b.aUM.toString() == "null" || b.aUM!.isEmpty
  //                 ? "0.00"
  //                 : b.aUM.toString())
  //             .compareTo(double.parse(
  //                 a.aUM.toString() == "null" || a.aUM!.isEmpty
  //                     ? "0.00"
  //                     : a.aUM.toString()));
  //       });
  //     }
  //     _mfCategorys.add(MFCategory(
  //         name: "Top Mutual Funds",
  //         length: "${_topmutualfund!.length > 100 ? 100 : null} Funds"));

  //     _mfCategorys.add(MFCategory(
  //         name: "Equity Funds", length: "${_equityMf!.length} Funds"));

  //     _mfCategorys.add(
  //         MFCategory(name: "Debt Funds", length: "${_debutMf!.length} Funds"));

  //     _mfCategorys.add(MFCategory(
  //         name: "Hybrid Funds", length: "${_hybridMf!.length} Funds"));

  //     _mfCategorys.add(MFCategory(
  //         name: "Solution Oriented Funds",
  //         length: "${_solutionOMf!.length} Funds"));

  //     _mfCategorys.add(
  //         MFCategory(name: "Other Funds", length: "${_otherMf!.length} Funds"));

  //     notifyListeners();
  //   } catch (e) {
  //     debugPrint("$e");
  //   } finally {
  //     _mfloader = false;
  //   }
  // }

  Future fetchBestMF() async {
    try {
      _bestMFModel = await api.getBestMF();
      if (_bestMFModel!.stat == "Ok") {
        for (var watchListMf in _bestMFModel!.bestMFList!) {
          _bestMFListStatic
              .where((m) => m['title'] == watchListMf.title)
              .forEach((m) => m['funds'] = watchListMf.counts);
        }
      }
      // print("{{{{{{{{{{}}}}}}}}}}${_bestMFModel}");
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchMFBestList(String type) async {
    try {
      _bestmfloader = true;
      _bestMFList = await api.getMFBestListData(type);
      if (_bestMFList != null) {
        _bestMFList!.bestMFList!.sort((a, b) {
          // print("${a.aUM} ${b.aUM}");
          return double.parse(b.aUM == '' ? "0.00" : b.aUM!)
              .compareTo(double.parse(a.aUM == '' ? "0.00" : a.aUM!));
        }); // Sor
      }
      // print("_bestMFList $_mfCategoryList");
      for (var m in _bestMFList!.bestMFList!) {
        m.isAdd =
            _mfWatchlist!.any((watchListMf) => watchListMf.iSIN == m.iSIN);
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  Future<void> fetchnewMFBestList() async {
    // print("tryoutcalll");

    try {
      _bestmfloader = true;
      // print("@@@tryyinnn");

      _newbestmodel = await api.getnewMFBestListData();

      // for (var watchListMf in _newbestmodel!.basketsLength!) {
      //   _bestMFListStaticnew
      //       .where((m) => m['title'] == watchListMf.title)
      //       .forEach((m) => m['funds'] = watchListMf.count);
      // }

      // print("--------------mfbest ${_newbestmodel}");
      // print(_newbestmodel);

      notifyListeners();
    } catch (e, stackTrace) {
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  Future<void> fetchmfsiplist() async {
    try {
      _bestmfloader = true;
      notifyListeners();

      _mfsiporderlist = await api.getSiplist('');
      // print("sipppppres${_mfsiporderlist?.toJson()}");
      notifyListeners();
    } catch (e, stackTrace) {
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  Future<void> fetchmfsipnotlivelist() async {
    try {
      _bestmfloader = true;
      notifyListeners();
      _mfnotlivesiporderlist = await api.getSiplist('notlive');
      // print("sipppppres${_mfsiporderlist?.toJson()}");
      notifyListeners();
    } catch (e, stackTrace) {
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  Future<void> fetchmfsipsinglepage(String value) async {
    try {
      _bestmfloader = true;
      _mfsinglepageres = await api.getSipsinglepage(value);
      // print("themffffff//${value}");
      // print("nwewwwww${_mfsinglepageres?.invList.toString()}");

      notifyListeners();
    } catch (e, stackTrace) {
      _bestmfloader = false;
      notifyListeners();

      // print("apii errror");
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  Future<void> fetchorderdetails(
    String orderid,
    //  String bs, String type,
    //     String status, String sipno, String remarks
  ) async {
    try {
      _bestmfloader = true;

      // print("1111${value},${type},${bs},${status},${sipno},${remarks}");
      // print("nwewwwww${_mforderdet.toString()}");

      // String orderStatus = checkOrderRemarks(remarks);
      // print(
      //     "payload${value},${type},${bs},${status},${sipno},${orderStatus == 'usercancel' ? "" : orderStatus}");

      _mforderdet = await api.getsingleortderapi(orderid);
      // print("11111@@${orderStatus}");
      return notifyListeners();
    } catch (e, stackTrace) {
      _bestmfloader = false;
      // print("apii errror");
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  String checkOrderRemarks(String orderremarks) {
    if (orderremarks.contains("HAS BEEN REGISTERED")) {
      return "REGISTERED";
    } else if (orderremarks.contains("CANCELLED SUCCESSFULLY")) {
      return "CANCELLED";
    } else {
      return "usercancel";
    }
  }

  Future<void> fetchmfholdsinglelist(String value) async {
    try {
      _bestmfloader = true;
      _mfholdsingepage = await api.getholdsinglepage(value);
      // print("themffffff${value}");
      // print("nwewwwww${_mfholdsingepage.toString()}");

      notifyListeners();
    } catch (e, stackTrace) {
      _bestmfloader = false;
      // print("apii errror");
    } finally {
      _bestmfloader = false;
      notifyListeners();
    }
  }

  // RETIRED: the backing endpoint is being decommissioned. No live code
  // calls this any more — mfholdingnew data is now adapted from the demat
  // response inside fetchmfdematholding(). Kept for reference only.
  Future<void> fetchmfholdingnew() async {
    try {
      _holdstatload = true;
      notifyListeners();
      _mfholdingnew = await api.getmfholdnewapi();
      // print("themffffff${value}");

      // print("holdinglist${_mfholdingnew?.toJson()}");

      // notifyListeners();
    } catch (e, stackTrace) {
      _holdstatload = false;
      // print("apii errror");
    } finally {
      _holdstatload = false;
      notifyListeners();
    }
  }

  Future<void> fetchmfdematholding() async {
    try {
      _dematHoldLoad = true;
      _holdstatload = true;
      notifyListeners();
      _mfDematHolding = await api.getmfdemathldapi();
      // The old MF holdings endpoint is being decommissioned. The MF section
      // screens (holdings list, search, single page, redeem) still read the
      // mfholdingnew shape, so mirror the demat response into it here —
      // display and order/redeem flows keep working unchanged while ALL
      // network traffic goes to the demat endpoint only.
      _mfholdingnew = _dematToMfHoldingNew(_mfDematHolding);
    } catch (e) {
      _dematHoldLoad = false;
      _holdstatload = false;
    } finally {
      _dematHoldLoad = false;
      _holdstatload = false;
      notifyListeners();
    }
  }

  /// Adapts the demat holdings response into the legacy mfholdingnew shape.
  ///
  /// Field mapping: SCRIP_NAME -> name, total_units -> avg_qty,
  /// Scheme_Code -> sCHEMECODE (backend now sends it, so redemption order
  /// placement works), Minimum_Redemption_Qty -> minRedemptionQty (parsed
  /// whenever the response carries it). Folio number has no demat
  /// equivalent and stays null — the redemption API takes only scheme code
  /// and quantity, so nothing downstream needs it.
  mf_holdoing_new? _dematToMfHoldingNew(MfDematHolding? demat) {
    if (demat == null) return null;
    final rows = <mfh.Data>[];
    for (final d in demat.data ?? <MfDematHoldingData>[]) {
      final row = mfh.Data(
        name: d.scripName,
        iSIN: d.iSIN,
        avgQty: d.totalUnits,
        avgNav: d.avgNav,
        curNav: d.curNav,
        investedValue: d.investedValue,
        currentValue: d.currentValue,
        profitLoss: d.profitLoss,
        changeprofitLoss: d.changeprofitLoss,
      );
      row.sCHEMECODE = d.schemeCode;
      row.minRedemptionQty = d.minimumRedemptionQty;
      row.minimumPurchaseAmount = d.minimumPurchaseAmount;
      row.purchaseAllowed = d.purchaseAllowed;
      row.redemptionAllowed = d.redemptionAllowed;
      rows.add(row);
    }

    // Prefer the API summary; compute totals from rows when the demat
    // response omits its summary block.
    mfh.Summary summary;
    if (demat.summary != null) {
      summary = mfh.Summary(
        invested: demat.summary!.invested,
        currentValue: demat.summary!.currentValue,
        absReturnValue: demat.summary!.absReturnValue,
        absReturnPercent: demat.summary!.absReturnPercent,
      );
    } else {
      double invested = 0;
      double current = 0;
      for (final r in rows) {
        invested += double.tryParse(r.investedValue ?? '0') ?? 0;
        current += double.tryParse(r.currentValue ?? '0') ?? 0;
      }
      final pnl = current - invested;
      summary = mfh.Summary(
        invested: invested.toStringAsFixed(2),
        currentValue: current.toStringAsFixed(2),
        absReturnValue: pnl.toStringAsFixed(2),
        absReturnPercent:
            (invested != 0 ? (pnl / invested) * 100 : 0).toStringAsFixed(2),
      );
    }

    return mf_holdoing_new(data: rows, summary: summary, stat: demat.stat);
  }

  void fetchmfholdsingpage(String isin, {bool isAllMf = false}) async {
    // print("qqqq|${isin}---");

    // Clear previous data
    _holssinglelist = [];
    notifyListeners();

    if (isAllMf) {
      // Search in All MF holdings
      for (var item in _allMfHoldings?.data ?? []) {
        if (isin == item.iSIN) {
          // Ensure item is not null before adding it to the list
          _holssinglelist = item != null ? [item] : [];
          break; // Found the item, no need to continue
        }
      }
    } else {
      // Search in My MF holdings
      for (var item in _mfholdingnew?.data ?? []) {
        if (isin == item.iSIN) {
          // Ensure item is not null before adding it to the list
          _holssinglelist = item != null ? [item] : [];
          break; // Found the item, no need to continue
        }
      }
    }

    notifyListeners();
  }

  // Future fetchMFCategoryList(String type, String subtype) async {
  //   try {
  //     _bestmfloader = true;
  //     _mfCategoryList = await api.getMFCategoryList(type, subtype);
  //     if (_mfCategoryList != null) {
  //       _mfCategoryList!.data!.sort((a, b) {
  //         // print("${a.aUM} ${b.aUM}");
  //         return double.parse(b.aUM == '' ? "0.00" : b.aUM!)
  //             .compareTo(double.parse(a.aUM == '' ? "0.00" : a.aUM!));
  //       }); // Sor
  //     }
  //     // print("_mfCategoryList $_mfCategoryList");
  //     // if (_bestMFModel!.stat == "Ok") {
  //     //   for (var watchListMf in _bestMFModel!.bestMFList!) {
  //     //     _bestMFListStatic
  //     //         .where((m) => m['title'] == watchListMf.title)
  //     //         .forEach((m) => m['funds'] = watchListMf.counts);
  //     //   }
  //     for (var masterMf in _mfWatchlist!) {
  //       _mfCategoryList!.data!
  //           .where((m) => m.iSIN == masterMf.iSIN)
  //           .forEach((m) => m.isAdd = true);
  //     }
  //     // }
  //     notifyListeners();
  //   } catch (e) {
  //     _bestmfloader = false;
  //     debugPrint("$e");
  //   } finally {
  //     _bestmfloader = false;
  //     notifyListeners();
  //   }
  // }

  // Future fetchMFCategoryType() async {
  //   _mfCategoryTypes = await api.getMFCategoryTypes();
  //   print("_mfCategoryTypes ${_mfCategoryTypes!.data![0]}");
  //   for (var watchListMf in _mfCategoryTypes!.data!) {
  //     _mFCategoryTypesStatic
  //         .where((m) => m['title'] == watchListMf.type)
  //         .forEach((m) => m['sub'] = watchListMf.sub);
  //   }
  //   print("_mfCategoryTypes $_mFCategoryTypesStatic");
  //   notifyListeners();
  // }

  Future fetchFactSheet(String isin) async {
    try {
      _fundDetailLoader = true;
      notifyListeners();
      Map trailingReturns = {};
      _mfReturnsGridview = [];
      _comYear = "10 Years";
      var stopwatch = Stopwatch()..start();
      _factSheetDataModel = await api.getMFFactSheetData(isin);
      _fundDetailLoader = false;
      stopwatch.stop(); // Stop timer

      log('Time taken 1: ${stopwatch.elapsedMilliseconds} ms');
      stopwatch = Stopwatch()..start();
      if (_factSheetDataModel!.stat == "Ok") {
        trailingReturns =
            _factSheetDataModel!.data!.benchmarkTrailingReturn!.toJson();

        _mfReturnsGridview.add({
          "duration": "3MonthBenchMarkReturn",
          "durName": "3 Month",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d3Month != "null"
                  ? _factSheetDataModel!.data!.d3Month!
                  : "0.00")
              .toStringAsFixed(2)
        });
        _mfReturnsGridview.add({
          "duration": "6MonthBenchMarkReturn",
          "durName": "6 Month",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d6Month != "null"
                  ? _factSheetDataModel!.data!.d6Month!
                  : "0.00")
              .toStringAsFixed(2)
        });
        _mfReturnsGridview.add({
          "duration": "1YearBenchMarkReturn",
          "durName": "1 Year",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d1Year != "null"
                  ? _factSheetDataModel!.data!.d1Year!
                  : "0.00")
              .toStringAsFixed(2)
        });
        _mfReturnsGridview.add({
          "duration": "3YearBenchMarkReturn",
          "durName": "3 Year",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d3Year != "null"
                  ? _factSheetDataModel!.data!.d3Year!
                  : "0.00")
              .toStringAsFixed(2)
        });
        _mfReturnsGridview.add({
          "duration": "5YearBenchMarkReturn",
          "durName": "5 Year",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d5Year != "null"
                  ? _factSheetDataModel!.data!.d5Year!
                  : "0.00")
              .toStringAsFixed(2)
        });
        _mfReturnsGridview.add({
          "duration": "10YearBenchMarkReturn",
          "durName": "10 Year",
          "return": "",
          "value": double.parse(_factSheetDataModel!.data!.d10Year != "null"
                  ? _factSheetDataModel!.data!.d10Year!
                  : "0.00")
              .toStringAsFixed(2)
        });

        for (var element in _mfReturnsGridview) {
          for (var returns in trailingReturns.entries) {
            if (element['duration'] == returns.key) {
              element['return'] =
                  double.parse(returns.value ?? "0.00").toStringAsFixed(2);
            }
          }
        }
        List splitOverview =
            _factSheetDataModel!.data!.overview!.split("The portfolio");

        if (splitOverview.length > 1) {
          factSheetDataModel!.data!.overview1 = splitOverview[0];
          factSheetDataModel!.data!.overview2 =
              "The portfolio${splitOverview[1]}";
        } else {
          // Fallback if "The portfolio" is not found
          factSheetDataModel!.data!.overview1 =
              _factSheetDataModel!.data!.overview!;
          factSheetDataModel!.data!.overview2 = "";
        }
      }
      stopwatch.stop(); // Stop timer

      // log('Time taken 2: ${stopwatch.elapsedMilliseconds} ms');
      // stopwatch = Stopwatch()..start();
      // await fetchFactSheetGraph(isin);
      // stopwatch.stop(); // Stop timer

      // log('Time taken 3: ${stopwatch.elapsedMilliseconds} ms');
      // stopwatch = Stopwatch()..start();
      // await fetchSchemePeer(isin, "10Year");
      // stopwatch.stop(); // Stop timer

      log('Time taken 4: ${stopwatch.elapsedMilliseconds} ms');
      stopwatch = Stopwatch()..start();
      _navGraph = await api.getMFNavGraph(isin);
      stopwatch.stop(); // Stop timer

      log('Time taken 5: ${stopwatch.elapsedMilliseconds} ms');

      if (_navGraph!.stat == "Ok") {
      }

      notifyListeners();
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
      _fundDetailLoader = false;
      notifyListeners();
    }
  }

  Future fetchSchemePeer(String isin, String comYear) async {
    try {
      _schemePeers = await api.getMFSchemePeer(isin, comYear);

      if (_schemePeers!.stat == "Ok") {
        for (var element in _schemePeers!.topSchemes!) {
          if (comYear == "10Year") {
            element.yearPer = "${element.d10Year}";
            element.yearName = "10Yr";
          } else if (comYear == "5Year") {
            element.yearPer = "${element.d5Year}";
            element.yearName = "5Yr";
          } else if (comYear == "3Year") {
            element.yearPer = "${element.d3Year}";
            element.yearName = "3Yr";
          } else if (comYear == "2Year") {
            element.yearPer = "${element.d2Year}";
            element.yearName = "2Yr";
          } else {
            element.yearPer = "${element.d1Year}";
            element.yearName = "1Yr";
          }
        }
      }
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchFactSheetGraph(String isin) async {
    try {
      _sheetGraph = await api.getMFFactSheetGraph(isin);

      if (_sheetGraph!.stat == "Ok") {}
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchcommonsearchWadd(
      String isin, String isAdd, BuildContext context, bool bool) async {
    try {
      _mfWatchlist = [];
      _mfWatchlistModel = await api.getMFWatchlistsearch(isin, isAdd);
      if (_mfWatchlistModel!.stat == "Ok") {
        _mfWatchlist = _mfWatchlistModel!.scripts ?? [];
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        //log("SSSSSSSSSSSSS ${_mfWatchlistModel!.msg.toString()}");
        if (isAdd == "add") {
          successMessage(context, "Stock was Added to Mutual fund watchlist");
        } else if (isAdd == "delete") {
          successMessage(
              context, "Stock was Removed from Mutual fund watchlist");
        }

        // if (bool) {
        //   _mutualFundList = _mfWatchlist;
        // }

        // First, reset all isAdd to false
        for (var m in _mutualFundList) {
          m.isAdd = false;
        }
        _mutualFundsearchdata?.forEach((m) => m.isAdd = false);

        // Then, set isAdd to true only for items in the watchlist
        for (var watchListMf in _mfWatchlist!) {
          _mutualFundList
              .where((m) => m.iSIN == watchListMf.iSIN)
              .forEach((m) => m.isAdd = true);
          _mutualFundsearchdata!
              .where((m) => m.iSIN == watchListMf.iSIN)
              .forEach((m) => m.isAdd = true);
        }
      } else {
        _mfWatchlist = [];
        if (_mfWatchlistModel!.msg == "script exists") {
          successMessage(context, "${_mfWatchlistModel!.msg}");
        }
      }
      notifyListeners();
    } catch (e) {
    } finally {
      notifyListeners();
    }
  }

  Future fetchMFWatchlist(String isin, String isAdd, BuildContext context,
      bool bool, String val) async {
    try {
      // _mfWatchlist = [];
      toggleLoadingOn(true);

      _mfWatchlistModel = await api.getMFWatchlist(isin, isAdd);
      if (_mfWatchlistModel!.stat == "Ok") {
        _mfWatchlist = _mfWatchlistModel!.scripts ?? [];
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        //log("SSSSSSSSSSSSS ${_mfWatchlistModel!.msg.toString()}");
        if (isAdd == "add") {
          successMessage(context, "MF was Added to Mutual fund watchlist");
        } else if (isAdd == "delete") {
          successMessage(context, "MF was Removed from Mutual fund watchlist");
        }

        // if (bool) {
        //   print("object $bool");
        //   _mutualFundList = _mfWatchlist;
        // }

        // for (var watchListMf in _mfWatchlist!) {
        //   print("object 1");
        //   for (var masterMf in _mutualFundList!) {
        //     print("object 2");
        //     if (watchListMf.iSIN == masterMf.iSIN) {
        //       print("object 3");
        //       masterMf.isAdd = true;
        //     }
        //   }
        // }
        if (_mfWatchlist!.isNotEmpty) {
          for (var m in _mutualFundList) {
            m.isAdd =
                _mfWatchlist!.any((watchListMf) => watchListMf.iSIN == m.iSIN);
          }
          if (_bestMFList != null) {
            for (var m in _bestMFList!.bestMFList!) {
              m.isAdd = _mfWatchlist!
                  .any((watchListMf) => watchListMf.iSIN == m.iSIN);
            }
          }
          if (_mutualFundtopsearch != null) {
            for (var m in _mutualFundtopsearch!) {
              m.isAdd = _mfWatchlist!
                  .any((watchListMf) => watchListMf.iSIN == m.iSIN);
            }
          }
          if (_mfCategoryList!.data != null) {
            for (var m in _mfCategoryList!.data!) {
              m.isAdd = _mfWatchlist!
                  .any((watchListMf) => watchListMf.iSIN == m.iSIN);
            }
          }
        }

        // else {
        //   for (var m in _mutualFundList!) {
        //     m.isAdd = false;
        //   }

        //   for (var m in _bestMFList!.bestMFList!) {
        //     m.isAdd = false;
        //   }
        //   for (var m in _mutualFundtopsearch!) {
        //     m.isAdd = false;
        //   }

        //   for (var m in mfCategoryList!.data!) {
        //     m.isAdd = false;
        //   }
        // }
      } else {
        // _mfWatchlist = [];
        if (_mfWatchlistModel!.msg == "script exists") {
          successMessage(context, "${_mfWatchlistModel!.msg}");
        }
      }
      notifyListeners();
    } catch (e) {
      toggleLoadingOn(false);
    } finally {
      toggleLoadingOn(false);
      _bestmfloader = false;

      notifyListeners();
    }
  }

  Future fetchMFSipData(String isin, String schemeCode) async {
    try {
      _investloader = true;

      _dateList = [];
      _mfSIPModel = await api.getMFSip(isin, schemeCode);
      if (_mfSIPModel!.stat == "Ok") {
        if (_mfSIPModel!.data!.isNotEmpty) {
          // Debug print all available frequencies
          for (int i = 0; i < _mfSIPModel!.data!.length; i++) {
          }

          // Find the index where frequency is MONTHLY
          int monthlyIndex = -1;
          for (int i = 0; i < _mfSIPModel!.data!.length; i++) {
            if (_mfSIPModel!.data![i].sIPFREQUENCY == "MONTHLY") {
              monthlyIndex = i;
              break;
            }
          }

          // Use MONTHLY index if found, otherwise fallback to first index
          int indexToUse = monthlyIndex != -1 ? monthlyIndex : 0;


          _freqName = "${_mfSIPModel!.data![indexToUse].sIPFREQUENCY}";

          installmentAmt.text =
              "${_mfSIPModel!.data![indexToUse].sIPMINIMUMINSTALLMENTAMOUNT}";
          invDuration.text =
              "${_mfSIPModel!.data![indexToUse].sIPMAXIMUMINSTALLMENTNUMBERS}";
          _sipDuration =
              "${_mfSIPModel!.data![indexToUse].sIPMINIMUMINSTALLMENTNUMBERS}";

          if (_freqName == "MONTHLY" || _freqName == "QUARTERLY") {
            _dateList = _mfSIPModel!.data![indexToUse].sIPDATES!
                .replaceAll("\"", "")
                .split(',');

            _dates = _dateList[0];
          } else {
            _dates = _dateList[0];
          }

          // Ensure the selected date is at least 2 working days from today
          final now = DateTime.now();
          final todayDate = DateTime(now.year, now.month, now.day);
          // Calculate minimum allowed date (2 working days from today, skipping weekends)
          int addedDays = 0;
          DateTime minAllowedDate = todayDate;
          while (addedDays < 2) {
            minAllowedDate = minAllowedDate.add(const Duration(days: 1));
            if (minAllowedDate.weekday != DateTime.saturday &&
                minAllowedDate.weekday != DateTime.sunday) {
              addedDays++;
            }
          }
          final selectedDay = int.tryParse(_dates) ?? 1;
          final selectedDayDate = DateTime(now.year, _sipMonth, selectedDay);
          // Date must be after 2 full working days and not a weekend
          final isSelectedPast = !selectedDayDate.isAfter(minAllowedDate);
          final isSelectedWeekend = selectedDayDate.weekday == DateTime.saturday ||
              selectedDayDate.weekday == DateTime.sunday;
          if (isSelectedPast || isSelectedWeekend) {
            // Find the first available date from dateList that meets the minimum and is not a weekend
            String? firstAvailable;
            for (var d in _dateList) {
              final day = int.tryParse(d.trim());
              if (day != null) {
                final dayDate = DateTime(now.year, _sipMonth, day);
                final isDayWeekend = dayDate.weekday == DateTime.saturday ||
                    dayDate.weekday == DateTime.sunday;
                if (dayDate.isAfter(minAllowedDate) && !isDayWeekend) {
                  firstAvailable = d.trim();
                  break;
                }
              }
            }
            // If no available date in current month, move to next month
            if (firstAvailable == null && _dateList.isNotEmpty) {
              _sipMonth = now.month + 1 > 12 ? 1 : now.month + 1;
              firstAvailable = _dateList[0].trim();
            }
            if (firstAvailable != null) {
              _dates = firstAvailable;
            }
          }

          // Set full start/end date based on resolved _dates and _sipMonth
          final resolvedDay = int.tryParse(_dates) ?? 1;
          final resolvedYear = _sipMonth < now.month ? now.year + 1 : now.year;
          _startDate = "$resolvedDay/$_sipMonth/$resolvedYear";
          _endsDate = DateTime(resolvedYear + 30, _sipMonth, resolvedDay - 1);
          _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";

          _insAmt =
              "${_mfSIPModel!.data![indexToUse].sIPMINIMUMINSTALLMENTAMOUNT ?? 0.00}";
        }
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _investloader = false;

      notifyListeners();
    }
  }

  String _inpauseerror = "";
  get inpauseerror => _inpauseerror;

  clearPauseError() {
    _inpauseerror = "";
    pausesip.text = "";
    notifyListeners();
  }

  void installmentDuration(String value, BuildContext context) {
    pausesip.text = value;
    try {
      final sipModel = _mfSIPModel?.data?.first;
      final orderList = _mfsiporderlist?.data?.first;

      if (sipModel == null || orderList == null) return;

      if (value.isEmpty) {
        _inpauseerror = "No of installments is Required";
        notifyListeners();
        return;
      }
      final parsedValue = double.tryParse(value);
      if (parsedValue == null) {
        _inpauseerror = "Please enter a valid number";
        notifyListeners();
        return;
      }

      // Check frequency match first
      final minInstallments =
          double.parse(sipModel.pAUSEMINIMUMINSTALLMENTS ?? "0") ?? 0;
      final maxInstallments =
          double.parse(sipModel.pAUSEMAXIMUMINSTALLMENTS ?? "0") ?? 0;

      // Check if entered value is within range
      if (double.parse(value) >= minInstallments &&
          double.parse(value) <= maxInstallments) {
        _inpauseerror = "";
        notifyListeners();
      } else {
        _inpauseerror = "Please provide a valid number within the range";
        notifyListeners();
      }
    } catch (e) {
    }
  }

  Future fetchMFMandateDetail() async {
    try {
      _investloader = true;
      _mandateDataLoaded = false;
      _mandateData = [];
      _mandateDetailModel = await api.getMandateDetail();

      if (_mandateDetailModel!.stat == "Ok") {
        _mandateData = _mandateDetailModel!.data!.mandateDetails ?? [];

        // Pick first approved mandate, fallback to first one
        final approvedMandate = _mandateData!.cast<dynamic>().firstWhere(
          (m) => m.status == "APPROVED",
          orElse: () => null,
        );
        final defaultMandate = approvedMandate ?? _mandateData![0];
        _mandateId = defaultMandate.mandateId!;
        _mandateStatus = defaultMandate.status!;
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _investloader = false;
      _mandateDataLoaded = true;
      notifyListeners();
    }
  }

  Future fetchMfPlaceorder(MfPlaceOrderInput placeorderinput,
      BuildContext context, String upiId) async {
    try {
      // _mfPlaceOrderResponces = await api.getLumpSumOrder(placeorderinput);
      // if (_mfPlaceOrderResponces?.stat == "Ok" &&
      //     _mfPlaceOrderResponces?.orderNumber != null) {
      fetchAllPayment(
          context,
          "${_mfPlaceOrderResponces?.orderNumber}",
          placeorderinput.amount,
          accNum,
          ifsc,
          bankname,
          paymentName == "UPI" ? "UPI" : "NET BANKING",
          "",
          "",
          upiId,
          placeorderinput.schemecode);

      // } else {
      //   ref.read(fundProvider).paymentName == "UPI"
      //       ? ScaffoldMessenger.of(context).showSnackBar(successMessage(
      //           context, '${_mfPlaceOrderResponces!.responseMessage}'))
      //       : null;
      // }
    } catch (e) {
      log("Failed to Place MF order :: ${e.toString()}");
      notifyListeners();
    }
  }

  Future fetchMfOrderbook(BuildContext context) async {
    try {
      _mforderloader = true;
      notifyListeners();
      _mfLumpSumOrderbook = await api.getorderbook();
      // if (_mfLumpSumOrderbook != null) {
      //   _mfLumpSumOrderbook!.data!.sort((a, b) {
      //     final DateFormat dateFormat = DateFormat("dd/MM/yyyy");
      //     DateTime dateA = dateFormat.parse(a.date.toString());
      //     DateTime dateB = dateFormat.parse(b.date.toString());
      //     return dateB.compareTo(dateA);
      //   }); // Sor
      // }
    } catch (e) {
      log("Failed to fetchMfOrderbook :: ${e.toString()}");
      notifyListeners();
    } finally {
      _mforderloader = false;
      notifyListeners();
    }
  }

  Future cancelredumorder(BuildContext context, orderno) async {
    try {
      // _mforderloader = true;
      toggleLoadingOn(true);
      try {
        toggleLoadingOn(true);
        _mfLumpSumOrderbook = await api.redemptioncancelapi(orderno);
        // print("@@@1111111111111111$_mfLumpSumOrderbook");
        await fetchMfOrderbook(context);

        Navigator.pop(context);

        warningMessage(context, "Your Request to Cancel Order  is confirmed");
        // if (_createMandateModel?.mandate == null) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //       warningMessage(context, "${_createMandateModel!.error}"));
        // }
        //else {
        //   fetchMFMandateDetail();
        //   ScaffoldMessenger.of(context).showSnackBar(
        //       successMessage(context, "${_createMandateModel!.resp}"));
        // }
      } catch (e) {
        toggleLoadingOn(false);
        Navigator.pop(context);
        warningMessage(context, "Something Went Wrong");
        log("Failed to Create Mandate :: ${e.toString()}");
        notifyListeners();
      }
    } catch (e) {
      toggleLoadingOn(false);
      Navigator.pop(context);
      warningMessage(context, "Something Went Wrong");
      log("Failed to fetchMfOrderbook :: ${e.toString()}");
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
      // _mforderloader = false;
      notifyListeners();
    }
  }

  Future cancelsiporder(BuildContext context, orderno, scode) async {
    if (droupreason != "") {
      toggleLoadingOn(true);
      try {
        _mfsipcancelmess = await api.cancelsipapi(
            orderno, droupreason, rejectsip.text, scode);

        toggleLoadingOn(false);

        if (_mfsipcancelmess?.stat == "Not_Ok") {
          Navigator.pop(context);
          warningMessage(context, "${_mfsipcancelmess?.bSERemarks}");
        } else if (_mfsipcancelmess?.stat == "Ok") {
          Navigator.pop(context, true);
          successMessage(
              context, "SIP successfully ${_mfsipcancelmess?.status?.toLowerCase()}");
        } else {
          Navigator.pop(context);
        }
        fetchmfsiplist();
      } catch (e) {
        toggleLoadingOn(false);
        Navigator.pop(context);
        warningMessage(context, "Something Went Wrong");
        log("Failed to cancel SIP :: ${e.toString()}");
      } finally {
        toggleLoadingOn(false);
        notifyListeners();
      }
    } else {
      warningMessage(context, "SIP Reject Reason Is Required*");
    }
    rejectsip.text = "";
    pausesip.text = "";
    cleartext();
  }

  Future pausesiporder(
      BuildContext context, orderno, freqty, nxtdate, scode) async {
    if (pausesip.text != "") {
      toggleLoadingOn(true);
      try {
        _mfsippause = await api.pausesipapi(
            orderno, pausesip.text, freqty, nxtdate, scode);

        toggleLoadingOn(false);

        if (_mfsippause?.stat == "Not_Ok") {
          Navigator.pop(context);
          warningMessage(context, "${_mfsippause?.bseRemarks}");
        } else if (_mfsippause?.stat == "Ok") {
          Navigator.pop(context, true);
          successMessage(context, "SIP ${_mfsippause?.status?.toLowerCase()} successfully");
        } else {
          Navigator.pop(context);
        }
        fetchmfsiplist();
      } catch (e) {
        toggleLoadingOn(false);
        Navigator.pop(context);
        warningMessage(context, "Something Went Wrong");
        log("Failed to pause SIP :: ${e.toString()}");
      } finally {
        toggleLoadingOn(false);
        notifyListeners();
      }
    } else {
      _inpauseerror = "No of installments is Required";
      notifyListeners();
    }
    rejectsip.text = "";
    pausesip.text = "";
    cleartext();
  }

  Future<void> fetchmfallcatnew() async {
    _categoryDataLoader = true;
    notifyListeners();
    try {
      // Fetch data from API
      _mfallcatnewlist = await api.mfallcatnewapi();
      // print("object@@${newres?.toJson()}");

      // print("valuesss${_mfallcatnewlist!.data![0].values![0].name}");
      // print("#######${_mfallcatnewlist?.toJson()}");

      // Clear existing sub-categories before populating to prevent duplicates
      for (var category in _mFCategoryTypesStatic) {
        category['sub'].clear();
      }

      for (var i = 0; i < _mfallcatnewlist!.data![0].values!.length; i++) {
        _mFCategoryTypesStatic[0]['sub']
            .add(_mfallcatnewlist!.data![0].values![i].name);
      }

      for (var i = 0; i < _mfallcatnewlist!.data![1].values!.length; i++) {
        _mFCategoryTypesStatic[1]['sub']
            .add(_mfallcatnewlist!.data![1].values![i].name);
      }

      for (var i = 0; i < _mfallcatnewlist!.data![2].values!.length; i++) {
        _mFCategoryTypesStatic[2]['sub']
            .add(_mfallcatnewlist!.data![2].values![i].name);
      }

      for (var i = 0; i < _mfallcatnewlist!.data![3].values!.length; i++) {
        _mFCategoryTypesStatic[3]['sub']
            .add(_mfallcatnewlist!.data![3].values![i].name);
      }

      for (var i = 0; i < _mfallcatnewlist!.data![5].values!.length; i++) {
        _mFCategoryTypesStatic[4]['sub']
            .add(_mfallcatnewlist!.data![5].values![i].name);
      }

      _categoryDataLoader = false;
      // print("Transformed Data: ");
    } catch (e) {
      log("Failed to fetch data: ${e.toString()}");
      _categoryDataLoader = false;
      notifyListeners();
    } finally {
      _categoryDataLoader = false;
      notifyListeners();
    }
  }

  fetchcatdatanew(String tit, String chi) {
    // print("qqqq|${tit}----${chi}");

    // Define mapping of title to index dynamically
    Map<String, int> categoryIndex = {
      'Equity': 0,
      'Income': 1,
      'Gold': 2,
      'Hybrid': 3,
      'Solution': 5
    };

    // Check if the category exists in the map
    if (!categoryIndex.containsKey(tit)) {
      // print("Invalid category or missing data.");
      return;
    }

    int index = categoryIndex[tit]!; // Get the correct index

    // Null safety checks
    if (_mfallcatnewlist?.data == null ||
        _mfallcatnewlist!.data!.length <= index) {
      // print("otherr or null data");
      return;
    }

    // Iterate through values and find matching `chi`
    for (var item in _mfallcatnewlist!.data![index].values ?? []) {
      // print("nameee ${item.name}");

      if (chi == item.name) {
        // print("statisfyyy ${item.values}");

        // Assign values safely
        _catnewlist = List<Fund>.from(item.values ?? []);

        // Notify listeners AFTER updating _catnewlist
        notifyListeners();
        return;
      }
    }

    // print("No matching data found.");
  }

// void fetchmatchisan(String isin) {
//   final watchlistIsins = _mfWatchlist!.map((item) => item.iSIN).toSet();

//   if (_factSheetDataModel!.data!. == isin) {

//     _factSheetDataModel!.data!.isAdd = watchlistIsins.contains(isin);
//   }
// }
  void fetchmatchisan(String isin) {
    bool isMatch = _mfWatchlist!.any((watchListMf) => watchListMf.iSIN == isin);

//  if(isMatch == true)
    _watchbatchval = isMatch;
    // print("Updated isAdd to: ${_watchbatchval}");
    notifyListeners();
  }

  Future fetchVerifyUpi(
    BuildContext context,
    String upiId,
    MfPlaceOrderInput input,
  ) async {
    try {
      toggleLoadingOn(true);
      if (upiId != "") {
        _verifyUPIModel = await api.getVerifyUpi(upiId, "123456");
        if (_verifyUPIModel!.data!.verifiedVPAStatus1 == "Available" ||
            _verifyUPIModel!.data!.verifiedVPAStatus2 == "Available") {
          fetchMfPlaceorder(input, context, upiId);
        } else {
          warningMessage(context, 'Invalid UPI ID');
        }
      } else {
        fetchMfPlaceorder(input, context, upiId);
      }

      //log("HDFC BANK $_upiIdValidationModel");
    } catch (e) {
      // log("Failed to fetch bank Data:: ${e.toString()}");

      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  void checknetbankingstatus(BuildContext context) {
    // Cancel existing timers before starting new ones (optional safety)
    _autoPopTimer?.cancel();
    _threeSecondTimer?.cancel();

    // Start 3-second repeating timer
    _threeSecondTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      getpaymentstatus(_mfPlaceOrderResponces!.orderId, context);
    });

    // Start 1-minute auto pop timer
    // _autoPopTimer = Timer(const Duration(minutes: 1), () {
    //   _threeSecondTimer?.cancel(); // Stop the repeating timer
    //   if (Navigator.of(context).canPop()) {
    //     Navigator.of(context).pop(); // Auto pop after 1 minute
    //     _triggerfromMF = false;
    //   }
    // });
  }

  void cancelPaymentTransaction() {
    // Cancel timers
    _autoPopTimer?.cancel();
    _threeSecondTimer?.cancel();
    _triggerfromMF = false;
    ispaymentcalled = false;
    notifyListeners();
  }

  Future upipaymenttrigger(
      BuildContext context, id, val, upiid, ordertype) async {
    try {
      _investloader = true;
      _loadingMessage = "Processing payment...";
      notifyListeners();

      _upiApiresponse = await api.apiPushUpiTrigger(id, val, upiid, ordertype);
      if (_upiApiresponse?.stat != "Not Ok") {
        if (_upiApiresponse?.stat == "Ok") {
          _loadingMessage = "Initiated";
          _triggerfromMF = true;
          notifyListeners();
        }
      } else {
        // Navigator.pop(context);

        // if (_upiApiresponse!.data!.responsestring!.contains('Could not validate payment create request due to')) {
        // showModalBottomSheet(
        //     context: context,
        //     shape: const RoundedRectangleBorder(
        //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        //     ),
        //     isScrollControlled: true,
        //     builder: (context) {
        //       return Wrap(
        //         children: [
        //           const SizedBox(
        //             height: 24,
        //           ),
        //           Container(
        //             padding: const EdgeInsets.symmetric(horizontal: 16),
        //             decoration: BoxDecoration(
        //                 borderRadius: BorderRadius.circular(16),
        //                 color: colors.colorWhite,
        //                 boxShadow: const [
        //                   BoxShadow(
        //                       color: Color(0xff999999),
        //                       blurRadius: 4.0,
        //                       offset: Offset(2.0, 0.0))
        //                 ]),
        //             child: Column(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               mainAxisSize: MainAxisSize.min,
        //               children: [
        //                 Container(
        //                   alignment: Alignment.center,
        //                   child: Column(
        //                     children: [
        //                       const CustomDragHandler(),
        //                       Icon(
        //                         Icons.cancel_rounded,
        //                         //
        //                         color: colors.kColorRedButton,
        //                         size: 70,
        //                       ),
        //                       const SizedBox(
        //                         height: 16,
        //                       ),
        //                       TextWidget.subText(
        //                         text: "UPI ID not liked with bank",
        //                         theme: false,
        //                         color: colors.textPrimaryLight,
        //                       ),
        //                       const SizedBox(
        //                         height: 5,
        //                       ),
        //                       TextWidget.paraText(
        //                         text: "Payment trigger fail",
        //                         theme: false,
        //                         color: colors.textSecondaryLight,
        //                       ),
        //                       const SizedBox(
        //                         height: 10,
        //                       ),
        //                       // TextWidget.custmText(
        //                       //     text: "",
        //                       //     theme: false,
        //                       //     color:  colors.colorBlack,
        //                       //     fs: 40),
        //                       const SizedBox(
        //                         height: 10,
        //                       ),
        //                       // TextWidget.paraText(
        //                       //   text: "${widget.upiData?["datetime"]}",
        //                       //   theme: false,
        //                       //   color: colors.textSecondaryLight,
        //                       // ),
        //                     ],
        //                   ),
        //                 ),
        //                 Padding(
        //                   padding: const EdgeInsets.symmetric(horizontal: 8),
        //                   child: SizedBox(
        //                     width: MediaQuery.of(context).size.width,
        //                     child: ElevatedButton(
        //                         style: ElevatedButton.styleFrom(
        //                           elevation: 0,
        //                           minimumSize: const Size(0, 40),
        //                           backgroundColor: colors.primaryLight,
        //                           shape: RoundedRectangleBorder(
        //                             borderRadius: BorderRadius.circular(5),
        //                           ),
        //                         ),
        //                         onPressed: () {
        //                           // Clear the amount text field
        //                           Navigator.pop(context);
        //                           FocusScope.of(context).unfocus();
        //                         },
        //                         child: TextWidget.subText(
        //                             text: 'Done',
        //                             theme: false,
        //                             color: colors.colorWhite,
        //                             fw: 2)),
        //                   ),
        //                 ),
        //                 const SizedBox(
        //                   height: 20,
        //                 ),
        //               ],
        //             ),
        //           ),
        //         ],
        //       );
        //     });
        // }else{
        //        ScaffoldMessenger.of(context)
        //       .showSnackBar(warningMessage(context, _upiApiresponse!.data!.responsestring!));
        // // }
        ispaymentcalled = false;
        // Navigator.pop(context);

        // if (_upiApiresponse!.data!.responsestring!.contains('Could not validate payment create request due to')) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     warningMessage(context, 'UPI ID not liked with bank'),
        //   );
        //   Navigator.pop(context); // Only pop when the condition is true
        // }else if(_upiApiresponse != null && _upiApiresponse!.data != null && _upiApiresponse!.data!.responsestring != null){
        //     ScaffoldMessenger.of(context).showSnackBar(
        //     warningMessage(context, '${_upiApiresponse!.data!.responsestring}'),
        //   );
        //   Navigator.pop(context); // Only po
        // }else{
        //     ScaffoldMessenger.of(context).showSnackBar(
        //     warningMessage(context, 'Something error try again later'),
        //   );
        //   Navigator.pop(context); // Only po
        // }
        notifyListeners();
      }
      _investloader = false;
      _loadingMessage = null;
      notifyListeners();

      // Navigator.pop(context);

      // ScaffoldMessenger.of(context).showSnackBar(
      //     warningMessage(context, "${_upiApiresponse?.data?.responsestring}"));
      // notifyListeners();
    } catch (e) {
      Navigator.pop(context);
      warningMessage(context, "Something Went Wrong");
      notifyListeners();
    } finally {
      _investloader = false;
      _loadingMessage = null;
      notifyListeners();
    }
  }

  Future placeordermftemp(BuildContext context, String upiId,
      MfPlaceOrderInput input, String scode, double amt, [bool isAdditional = false]) async {
    _investloader = true;
    _loadingMessage = "Processing order...";
    notifyListeners();

    try {
      _mfPlaceOrderResponces = await api.getLumpSumOrder(scode, amt, isAdditional);

      if (_mfPlaceOrderResponces?.stat == "Ok") {
        setLoadingMessage("Order Initiated");

        // Add a small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 1000));

        _investloader = false;
        _loadingMessage = null;
        notifyListeners();

        // Show success message
        // ScaffoldMessenger.of(context).showSnackBar(
        //     successMessage(context, "Order initiated successfully"));
      } else {
        _investloader = false;
        _loadingMessage = null;
        notifyListeners();
        // Show the backend error (emsg) in a toast; fall back to remarks /
        // response_message so the regular MF tab's existing messages still work.
        final res = _mfPlaceOrderResponces;
        final candidates = [res?.emsg, res?.remarks, res?.responseMessage];
        final errMsg = candidates.firstWhere(
          (m) => m != null && m.isNotEmpty && m != 'null',
          orElse: () => 'Unable to place the order.',
        )!;
        warningMessage(
            context, "$errMsg\nPlease contact our support team.");
      }
      //     // showModalBottomSheet(
      //     //     context: context,
      //     //     shape: const RoundedRectangleBorder(
      //     //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      //     //     ),
      //     //     isScrollControlled: true,
      //     //     builder: (context) {
      //     //       return Padding(
      //     //         padding: EdgeInsets.only(
      //     //             top: 22.0, bottom: 16.0, left: 16.0, right: 16.0),
      //     //         child: Wrap(
      //     //           children: [
      //     //             Center(
      //     //               child: Column(
      //     //                 mainAxisSize: MainAxisSize.min,
      //     //                 children: [
      //     //                   const Icon(Icons.check_circle,
      //     //                       color: Colors.green, size: 48),
      //     //                   const SizedBox(height: 12),
      //     //                   const Text(
      //     //                     "Payment URL link sent to your registered Mail ID ",
      //     //                     style: TextStyle(
      //     //                         fontSize: 18, fontWeight: FontWeight.bold),
      //     //                   ),
      //     //                   const SizedBox(height: 20),

      //     //                   Text("or"),
      //     //                   const SizedBox(height: 20),
      //     //                   Container(
      //     //                     width: double.infinity, // 👈 Full width
      //     //                     child: ElevatedButton(
      //     //                       onPressed: () async {
      //     //                         final Uri url = Uri.parse(val['url']);
      //     //                         if (!await launchUrl(url,
      //     //                             mode: LaunchMode.externalApplication)) {
      //     //                           print("Could not launch URL");
      //     //                         }
      //     //                       },
      //     //                       style: ElevatedButton.styleFrom(
      //     //                         elevation: 0,
      //     //                         backgroundColor: colors.primaryLight,
      //     //                         shape: RoundedRectangleBorder(
      //     //                           borderRadius: BorderRadius.circular(5),
      //     //                         ),
      //     //                       ),
      //     //                       child: const Text(
      //     //                         "Click here to pay",
      //     //                         style: TextStyle(
      //     //                           color: Color.fromARGB(255, 246, 246, 246),
      //     //                           fontSize: 12,
      //     //                           fontWeight: FontWeight.normal,
      //     //                         ),
      //     //                       ),
      //     //                     ),
      //     //                   ),
      //     //                   // InkWell(
      //     //                   //   onTap: () async{

      //     //                   //   },
      //     //                   //   child: Padding(
      //     //                   //     padding: const EdgeInsets.symmetric(horizontal: 14.0),
      //     //                   //     child: Text(
      //     //                   //       "${val['url']}",
      //     //                   //       style:const  TextStyle(
      //     //                   //         color: Color(0xFF0037B7),
      //     //                   //           fontSize: 12, fontWeight: FontWeight.normal ),
      //     //                   //     ),
      //     //                   //   ),
      //     //                   // ),
      //     //                   const SizedBox(height: 8),
      //     //                 ],
      //     //               ),
      //     //             ),
      //     //           ],
      //     //         ),
      //     //       );
      //     //     });
      //   }
      // } else {
      //   _investloader = false;
      //   notifyListeners();
      // }
      _investloader = false;

      notifyListeners();

      // if (_createMandateModel?.mandate == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //       warningMessage(context, "${_createMandateModel!.error}"));
      // } else {
      //   fetchMFMandateDetail();
      //   ScaffoldMessenger.of(context).showSnackBar(
      //       successMessage(context, "${_createMandateModel!.resp}"));
      // }
      // print(
      //     "object ${_createMandateModel!.error} ${_createMandateModel!.url1} ::${_createMandateModel!.mandate}");
    } catch (e) {
      warningMessage(context, "Error$e");

      _investloader = false;
      _loadingMessage = null;
      notifyListeners();
      log("Failed to place order :: ${e.toString()}");
    }
  }

  Future fetchCreateMandate(BuildContext context, String amount,
      String startDate, String endDate) async {
    try {
      _createMandateModel =
          await api.getCreateMandate(amount, startDate, endDate);

      if (_createMandateModel?.mandate == null) {
        warningMessage(context, "${_createMandateModel!.emsg}");
      } else {
        fetchMFMandateDetail();
        successMessage(context, "${_createMandateModel!.msg}");
      }
      // print(
      //     "object ${_createMandateModel!.error} ${_createMandateModel!.url1} ::${_createMandateModel!.mandate}");
    } catch (e) {
      log("Failed to Create Mandate :: ${e.toString()}");
      notifyListeners();
    }
  }

  Future fetchXsipPlaceOrder(
      BuildContext context,
      String schemecode,
      String startDate,
      String freqtype,
      String amt,
      String noofinstallment,
      String enddate,
      String mandateId, [bool isAdditional = false, bool firstInstallment = false]) async {
    try {
      // Debug print before API call

      _investloader = true;
      notifyListeners();

      _xsipOrderResponces = await api.getXsipPurchase(schemecode, startDate,
          freqtype, amt, noofinstallment, endDate, mandateId, isAdditional, firstInstallment);

      // Debug print after API call

      if (_xsipOrderResponces?.stat == 'Ok') {
        notifyListeners();

        // Add a small delay to show the success message
        await Future.delayed(const Duration(milliseconds: 1000));

        successMessage(context, "${_xsipOrderResponces!.remarks}");
        _investloader = false;

        // fetchAllPayment(
        //     context,
        //     "${_mfPlaceOrderResponces?.orderNumber}",
        //     amt,
        //     accNum,
        //     ifsc,
        //     bankname,
        //     paymentName == "UPI" ? "UPI" : "NET BANKING",
        //     "",
        //     "",
        //     upiId.text,
        //     schemecode);
        notifyListeners();
      } else {
        // toggleLoadingOn(false);
        _loadingMessage = null;
        warningMessage(context, "${_xsipOrderResponces!.remarks}");
        _investloader = false;

        notifyListeners();
      }
      fetchmfsiplist();
      fetchMfOrderbook(context);
    } catch (e) {
      _investloader = false;
      toggleLoadingOn(false);
      _loadingMessage = null;
      notifyListeners();
    } finally {
      _investloader = false;
      toggleLoadingOn(false);
      _loadingMessage = null;
      notifyListeners();
    }
  }

  Future fetchXsipcancelResone() async {
    try {
      _xsipOrderCancleResone = await api.getXsipCancleResone();
      _xsipvalue = "${_xsipOrderCancleResone!.data![0].reasonName}";
      _xsipcaseno = "${_xsipOrderCancleResone!.data![0].id}";
      // print("object ${_xsipOrderCancleResone?.data![0].id}");
      notifyListeners();
    } catch (e) {
    }
  }

  Future getpaymentstatus(orderid, BuildContext context) async {
    try {
      _statusCheckUpi = await api.getstatuspaymentcheck(orderid);

      if ((_statusCheckUpi != null) &&
          (_statusCheckUpi!.status == 'PAYMENT REJECTED' ||
              _statusCheckUpi!.status == 'PAYMENT COMPLETED')) {
        setterformftrigger(false);
        if (context.mounted) {
          // Navigator.pop(context);
          // showModalBottomSheet(
          //         shape: const RoundedRectangleBorder(
          //             borderRadius:
          //                 BorderRadius.vertical(top: Radius.circular(16))),
          //         backgroundColor: Colors.transparent,
          //         isDismissible: false,
          //         enableDrag: false,
          //         showDragHandle: false,
          //         useSafeArea: false,
          //         isScrollControlled: true,
          //         context: context,
          //         builder: (BuildContext context) {
          //           return PopScope(
          //               canPop: false,
          //               onPopInvokedWithResult: (didPop, result) async {
          //                 if (didPop) return;
          //               },
          //               child: Container(
          //                   child: const UpiIdSucessorFaliureScreen()));
          //         })
          //     .whenComplete(()
          //     {

          // })
        }
      }
      // print("object ${_xsipOrderCancleResone?.data![0].id}");
      notifyListeners();
    } catch (e) {
    }
  }

  Future fetchXsipcancel(BuildContext context, String xsipregno,
      String internalrefno, String caseno, String remarks) async {
    try {
      _xsipOrderCancleResponces =
          await api.getxsipCancle(xsipregno, internalrefno, caseno, remarks);

      if (_xsipOrderCancleResponces?.stat == "Not Ok") {
        Navigator.pop(context);
        warningMessage(context, "${_xsipOrderCancleResponces!.emsg}");
      }
      notifyListeners();
    } catch (e) {
    }
  }

  // Future fetchAllPayment(
  //     BuildContext context,
  //     String orderNumber,
  //     String totalAmt,
  //     String accno,
  //     String ifsc,
  //     String bankname,
  //     String paymentMethod,
  //     String internalrefno,
  //     String mandateId,
  //     String upi) async {
  //   try {
  //     _allPaymentMfModel = await api.getmfallpayment(orderNumber, totalAmt,
  //         accno, ifsc, bankname, paymentMethod, internalrefno, mandateId, upi);
  //     if (_allPaymentMfModel?.stat == "Not Ok") {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           warningMessage(context, "${_allPaymentMfModel!.emsg}"));
  //     } else if(_allPaymentMfModel?.stat == "Ok") {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           successMessage(context, "${_allPaymentMfModel!.msg}"));
  //           Navigator.pushNamed(
  //                     context,
  //                     Routes.mf,
  //                   );
  //     }
  //     else if(_allPaymentMfModel?.type == "NET BANKING"){
  //       launch("https://v3.mynt.in/mf${_allPaymentMfModel!.file}");
  //     }

  //     notifyListeners();
  //   } catch (e) {
  //     debugPrint("ALL MF ERROR $e");
  //   }
  // }

  Future fetchAllPayment(
      BuildContext context,
      String orderNumber,
      String totalAmt,
      String accno,
      String ifsc,
      String bankname,
      String paymentMethod,
      String internalrefno,
      String mandateId,
      String upi,
      String schemeCode) async {
    _allPaymentMfModel = await api.getmfallpayment(
        orderNumber,
        totalAmt,
        accno,
        ifsc,
        bankname,
        paymentMethod,
        internalrefno,
        mandateId,
        upi,
        schemeCode);
    if (_allPaymentMfModel?.stat == "Not Ok") {
      warningMessage(context, "${_allPaymentMfModel!.response_message}");
      Navigator.pop(context);
    } else if (_allPaymentMfModel?.stat == "Ok" &&
        _allPaymentMfModel?.type == "NET BANKING") {
      Navigator.pop(context);
      launch("https://v3.mynt.in/mf${_allPaymentMfModel!.file}");
    } else if (_allPaymentMfModel?.stat == "Ok") {
      if (_allPaymentMfModel?.type == "UPI") {
        successMessage(context, "${_allPaymentMfModel!.msg}");
        // print("${_allPaymentMfModel!.payment_msg} Payment message");
        Navigator.pop(context);
      } else {
        successMessage(context, "${_allPaymentMfModel!.msg}");
        // print("${_allPaymentMfModel!.payment_msg} Payment message 2");
        // print("+++++${_allPaymentMfModel?.toJson()}");
        Navigator.pop(context);
      }
    }
    togglefundLoadingOn(false);
    fetchMfOrderbook(context);
  }

  List<DropdownMenuItem<String>> addFrqDividers() {
    List<DropdownMenuItem<String>> menuItems = [];
    if (_mfSIPModel != null) {
      for (var item in _mfSIPModel!.data!) {
        menuItems.addAll([
          DropdownMenuItem<String>(
              value: item.sIPFREQUENCY.toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                      "${item.sIPFREQUENCY![0]}${item.sIPFREQUENCY!.substring(1).toLowerCase()}",
                      style: textStyle(const Color(0xff000000), 13, 0)))),
          if (item != _mfSIPModel!.data!.last)
            const DropdownMenuItem<String>(enabled: false, child: Divider())
        ]);
      }
    }

    return menuItems;
  }

  List<double> frqCustHeight() {
    List<double> itemsHeights = [];
    if (_mfSIPModel?.data != null) {
      for (var i = 0; i < (_mfSIPModel!.data!.length * 2) - 1; i++) {
        if (i.isEven) {
          itemsHeights.add(40);
        }
        if (i.isOdd) {
          itemsHeights.add(4);
        }
      }
    }
    return itemsHeights;
  }

  List<DropdownMenuItem<String>> addDateDividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _dateList) {
      menuItems.addAll([
        DropdownMenuItem<String>(
            value: item.toString(),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(item.toString(),
                    style: textStyle(const Color(0xff000000), 13, 0)))),
        if (item != _dateList.last)
          const DropdownMenuItem<String>(enabled: false, child: Divider())
      ]);
    }
    return menuItems;
  }

  List<double> dateCustHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_dateList.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<DropdownMenuItem<String>> xsipDividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _xsipOrderCancleResone!.data!) {
      menuItems.addAll([
        DropdownMenuItem<String>(
            value: item.reasonName.toString(),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(item.reasonName!,
                    style: textStyle(const Color(0xff000000), 13, 0)))),
        if (item != _xsipOrderCancleResone!.data!.last)
          const DropdownMenuItem<String>(enabled: false, child: Divider())
      ]);
    }
    return menuItems;
  }

  List<double> xsipCustHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_xsipOrderCancleResone!.data!.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  DateTime _curDate = DateTime.now();
  DateTime get curDate => _curDate;

  DateTime? _endsDate;
  DateTime? get endsDate => _endsDate;
  DateTime? _pickedStartDate;
  DateTime? get pickedStartDate => _pickedStartDate;

  String _startDate = "";
  String get startDate => _startDate;
  String _endDate = "";
  String get endDate => _endDate;

  getCurrentDate() {
    _curDate = DateTime.now();
    _pickedStartDate = null;

    _startDate = "${_curDate.day}/${_curDate.month}/${_curDate.year}";
    _endsDate = DateTime(_curDate.year + 30, _curDate.month, _curDate.day - 1);
    _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
    notifyListeners();
  }

  changeStartDate(date) {
    _dates = date;
    notifyListeners();
  }

  changeInstallmentDate(int day, int month, int year) {
    _dates = day.toString();
    _sipMonth = month;
    _startDate = "$day/$month/$year";
    _endsDate = DateTime(year + 30, month, day - 1);
    _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
    notifyListeners();
  }

  datePickerStart(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        currentDate: _pickedStartDate ?? _curDate,
        context: context,
        initialDate: _pickedStartDate ?? _curDate,
        firstDate: _curDate,
        lastDate: DateTime(_curDate.year + 200));
    if (picked != null) {
      _pickedStartDate = picked;
      _startDate =
          "${_pickedStartDate!.day}/${_pickedStartDate!.month}/${_pickedStartDate!.year}";
      _endsDate = DateTime(_pickedStartDate!.year + 30, _pickedStartDate!.month,
          _pickedStartDate!.day - 1);
      _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
    }
    notifyListeners();
  }

  setEndDate(DateTime date) {
    _endsDate = date;
    _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
    notifyListeners();
  }

  datePickerEnd(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        currentDate: _endsDate,
        initialDate: _endsDate,
        firstDate:
            DateTime(_curDate.year, _curDate.month + 2, _curDate.day - 1),
        lastDate: DateTime(_curDate.year + 200));
    if (picked != null) {
      _endsDate = picked;
      _endDate = "${_endsDate!.day}/${_endsDate!.month}/${_endsDate!.year}";
    }
    notifyListeners();
  }

  List<DropdownMenuItem<String>> mandateDividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _mandateData!) {
      menuItems.addAll([
        DropdownMenuItem<String>(
            value: item.mandateId.toString(),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text("${item.mandateId}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle(colors.colorBlack, 14, 0)),
                                const SizedBox(
                                  width: 10,
                                ),
                                item.status == "REJECTED"
                                    ? SvgPicture.asset(assets.cancelledIcon)
                                    : item.status == "APPROVED"
                                        ? SvgPicture.asset(assets.completedIcon)
                                        : SvgPicture.asset(assets.warningIcon)
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text("Reg date: ${item.regnDate}",
                                style: textStyle(colors.colorGrey, 12, 0))
                          ]),
                      Text("${double.parse(item.amount!).ceil()}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle(colors.colorBlack, 14, 0))
                    ]))),
        if (item != _mandateData!.last)
          const DropdownMenuItem<String>(enabled: false, child: Divider())
      ]);
    }
    return menuItems;
  }

  List<double> mandateHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_mandateData!.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(50);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  chngBankAcc(String val) {
    _accNum = val;
    _ifsc = _bankDetailsModel!.data!
        .firstWhere((reason) => reason.bankAcNo == val)
        .iFSCCode
        .toString();
    _bankname = _bankDetailsModel!.data!
        .firstWhere((reason) => reason.bankAcNo == val)
        .bankName
        .toString();
    notifyListeners();
  }

  List<DropdownMenuItem<String>> addBankDividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _bankData!) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item.bankAcNo.toString(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${item.bankName} - ****${item.bankAcNo!.substring(8)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle(colors.colorBlack, 14, 0)),
                    const SizedBox(height: 2),
                    // Text("*******${item.bankAcNo!.substring(8)}",
                    //     style:
                    //         textStyle(colors.colorGrey, 12, FontWeight.w500)),
                  ],
                ),
              )),
          //If it's last item, we will not add Divider after it.
          if (item != _bankData!.last)
            const DropdownMenuItem<String>(
              enabled: false,
              child: Divider(),
            ),
        ],
      );
    }
    return menuItems;
  }

  // set Dropdown item height
  List<double> getBankCustItemsHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_bankData!.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(50);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  // Fetching data from the api and stored in a variable
  Future fetchUpiDetail(val, BuildContext context) async {
    if (val == 'repop') {
      Navigator.pop(context);
    }

    try {
      _investloader = true;
      _paymentMethod = [];
      _upiDetailsModel = await api.getUPI();
      _paymentMethod.add("UPI");
      _paymentMethod.add("NET BANKING");
      if (_upiDetailsModel!.stat == "Ok") {
        upiId.text = _upiDetailsModel!.data![0].upiId.toString();
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _investloader = false;

      notifyListeners();
    }
  }

  // Fetching data from the api and stored in a variable
  Future fetchBankDetail() async {
    upiId.text = "";
    try {
      _investloader = true;

      _bankDetailsModel = await api.getBankDetail();
      _bankData = [];
      if (_bankDetailsModel!.stat == "Ok") {
        _paymentMethod.add("NET BANKING");
        _bankData = _bankDetailsModel!.data ?? [];
        if (_bankData!.isNotEmpty) {
          _accNum = "${_bankData![0].bankAcNo}";
          _ifsc = "${bankData![0].iFSCCode}";
          _bankname = "${bankData![0].bankName}";
        }
      }

      if (_upiDetailsModel!.stat == "Ok" || _bankDetailsModel!.stat == "Ok") {
        _paymentName = _paymentMethod[0];

        if (_paymentName == "UPI") {
          upiId.text = "${_upiDetailsModel!.data![0].upiId}";
        }
      }
      notifyListeners();
    } catch (e) {
    } finally {
      _investloader = false;

      notifyListeners();
    }
  }

  List<DropdownMenuItem<String>> addDividers() {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var item in _paymentMethod) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item.toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    item.toString(),
                    style: textStyle(const Color(0xff000000), 13, 0),
                  ))),
          //If it's last item, we will not add Divider after it.
          if (item != _paymentMethod.last)
            const DropdownMenuItem<String>(
              enabled: false,
              child: Divider(),
            ),
        ],
      );
    }
    return menuItems;
  }

  List<double> getCustItemsHeight() {
    List<double> itemsHeights = [];
    for (var i = 0; i < (_paymentMethod.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  bool ispaymentcalled = false;
  bool get isPaymentCalled => ispaymentcalled;

  IsPaymentCalled(bool value) {
    ispaymentcalled = value;
    notifyListeners();
  }

  bool isValidUpiId(dynamic mfData, String val, {String schemeType = "Growth"}) {
    final RegExp upiRegex =
        RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$', caseSensitive: false);

    // For reinitiate from portfolio, only validate UPI — no min/max needed
    if (val == 'reinitiatefromportfolio') {
      if (upiId.text.isEmpty) {
        upiError = "Please enter UPI ID";
      } else if (!upiRegex.hasMatch(upiId.text)) {
        upiError = "Please enter valid UPI ID";
      } else {
        upiError = "";
      }
      notifyListeners();
      return upiError?.isEmpty ?? true;
    }

    // Resolve min/max based on selected scheme type
    String? resolvedMin;
    String? resolvedMax;
    if (schemeType == "Divided Payout") {
      resolvedMin = mfData.iDCWMinimumPurchaseAmount ?? mfData.minimumPurchaseAmount;
      resolvedMax = mfData.iDCWMaximumPurchaseAmount ?? mfData.maximumPurchaseAmount;
    } else if (schemeType == "Divided Reinvest") {
      resolvedMin = mfData.reinvMinimumPurchaseAmount ?? mfData.minimumPurchaseAmount;
      resolvedMax = mfData.reinvMaximumPurchaseAmount ?? mfData.maximumPurchaseAmount;
    } else {
      resolvedMin = mfData.minimumPurchaseAmount;
      resolvedMax = mfData.maximumPurchaseAmount;
    }

    // The demat holdings response may not carry the purchase limits the old
    // MF holdings API sent. A missing or unparseable bound must SKIP that
    // check — the previous `double.parse(resolvedMin!)` null-assert crashed
    // the payment button silently when the limit was absent.
    final double? minAmt = double.tryParse(resolvedMin ?? '');
    final double? maxAmt = double.tryParse(resolvedMax ?? '');

    {
      if (mfOrderTpye == "One-time") {
        if (invAmt.text.isEmpty) {
          invAmtError = "Please enter Investment amount";
        } else if (minAmt != null && double.parse(invAmt.text) < minAmt) {
          invAmtError =
              "Investment amount should not be less than ${minAmt.toStringAsFixed(2)}";
        } else if (maxAmt != null &&
                   maxAmt > 0 &&
                   double.parse(invAmt.text) > maxAmt) {
          invAmtError =
              "Investment amount should not be more than ${maxAmt.toStringAsFixed(2)}";
        } else {
          invAmtError = "";
        }
      } else {
        if (invAmt.text.isEmpty) {
          invAmtError = "Please enter Investment amount";
        } else if (minAmt != null &&
            double.parse(invAmt.text) < minAmt &&
            isInitalPay) {
          invAmtError =
              "Investment amount should not be less than ${minAmt.toStringAsFixed(2)}";
        } else if (maxAmt != null &&
                   maxAmt > 0 &&
                   double.parse(invAmt.text) > maxAmt) {
          invAmtError =
              "Investment amount should not be more than ${maxAmt.toStringAsFixed(2)}";
        } else {
          invAmtError = "";
        }

        if (installmentAmt.text.isEmpty) {
          installmentAmtError = "Please enter Installment amount";
        } else if (minAmt != null &&
            double.parse(installmentAmt.text) < minAmt) {
          installmentAmtError =
              "Installment amount should not be less than ${minAmt.toStringAsFixed(2)}";
        } else if (maxAmt != null &&
                   maxAmt > 0 &&
                   double.parse(installmentAmt.text) > maxAmt) {
          installmentAmtError =
              "Installment amount should not be more than ${maxAmt.toStringAsFixed(2)}";
        } else {
          installmentAmtError = "";
        }
      }

      if (upiId.text.isEmpty) {
        upiError = "Please enter UPI ID";
      } else if (!upiRegex.hasMatch(upiId.text)) {
        upiError = "Please enter valid UPI ID";
      } else {
        upiError = "";
      }

      if (invDuration.text.isEmpty) {
        invDurationError = "Please enter Investment duration";
      } else if (double.parse(invDuration.text) < double.parse(_sipDuration)) {
        invDurationError =
            "Installment Duration should not be less than $_sipDuration";
      } else {
        invDurationError = "";
      }
      notifyListeners();
    }
    // print("Change made");

    // print("mfOrderTpye${mfOrderTpye}");

    return invAmtError == "" &&
        upiError == "" &&
        installmentAmtError == "" &&
        invDurationError == "";
  }

  bool checkRedemption(
      String? redQty, String? minRedQty, String? holdQty, String? nav) {
    redemptionError = "";
    redemptionOrderError = "";

    if (redQty == null || redQty.trim().isEmpty) {
      redemptionError = "Please enter Redemption Qty";
    } else {
      try {
        double red = double.parse(redQty);
        double hold = double.tryParse(holdQty ?? "") ?? 0;
        double min = double.tryParse(minRedQty ?? "") ?? 0;
        double navVal = double.tryParse(nav ?? "") ?? 0;

        if (red > hold) {
          redemptionError = "Redemption Qty should not exceed $holdQty";
        } else if (red < min) {
          redemptionError = "Redemption Qty should not be less than $minRedQty";
        } else if (red == 0) {
          redemptionError = "Redemption Qty should not be 0";
        } else {
          redemptionAmount.text = (red * navVal).toStringAsFixed(4);
          redemptionError = "";
          redemptionOrderError = "";
        }
      } catch (e) {
        redemptionError = "Invalid number format";
      }
    }

    notifyListeners();
    return redemptionError == "";
  }

  mfRedemption(BuildContext context, String scheme, String qty) async {
    // print("remmfujnnn");
    // print("scheme ${scheme}");
    // print("qtyqty ${qty}");
    try {
      toggleLoadingOn(true);

      _redemptionData = await api.getMFRedemption(scheme, qty);
      if (_redemptionData!.stat == "Ok") {
        fetchMfOrderbook(context);
        successMessage(context, "${_redemptionData!.remarks}");
        Navigator.pop(context);
      } else {
        redemptionOrderError = _redemptionData!.emsg;
      }
    }
    // notifyListeners();
    catch (e) {
      toggleLoadingOn(false);
    } finally {
      toggleLoadingOn(false);
      _bestmfloader = false;

      notifyListeners();
    }
  }

  // MF Holdings Filter Method
  void filterMFHoldings(
      {required String sorting, required BuildContext context}) {
    if (_mfholdingnew?.data == null) return;

    // Track current sort option
    _currentMFSortOption = sorting;

    if (sorting == "NAMEASC") {
      _mfholdingnew!.data!
          .sort((a, b) => (a.name ?? "").compareTo(b.name ?? ""));
    } else if (sorting == "NAMEDSC") {
      _mfholdingnew!.data!
          .sort((a, b) => (b.name ?? "").compareTo(a.name ?? ""));
    } else if (sorting == "NAVASC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aNav = double.tryParse(a.curNav ?? "0.00") ?? 0.0;
        double bNav = double.tryParse(b.curNav ?? "0.00") ?? 0.0;
        return aNav.compareTo(bNav);
      });
    } else if (sorting == "NAVDSC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aNav = double.tryParse(a.curNav ?? "0.00") ?? 0.0;
        double bNav = double.tryParse(b.curNav ?? "0.00") ?? 0.0;
        return bNav.compareTo(aNav);
      });
    } else if (sorting == "UNITASC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aQty = double.tryParse(a.avgQty ?? "0.00") ?? 0.0;
        double bQty = double.tryParse(b.avgQty ?? "0.00") ?? 0.0;
        return aQty.compareTo(bQty);
      });
    } else if (sorting == "UNITDSC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aQty = double.tryParse(a.avgQty ?? "0.00") ?? 0.0;
        double bQty = double.tryParse(b.avgQty ?? "0.00") ?? 0.0;
        return bQty.compareTo(aQty);
      });
    } else if (sorting == "RETURNPERCASC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aChange = double.tryParse(a.changeprofitLoss ?? "0.00") ?? 0.0;
        double bChange = double.tryParse(b.changeprofitLoss ?? "0.00") ?? 0.0;
        return aChange.compareTo(bChange);
      });
    } else if (sorting == "RETURNPERCDSC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aChange = double.tryParse(a.changeprofitLoss ?? "0.00") ?? 0.0;
        double bChange = double.tryParse(b.changeprofitLoss ?? "0.00") ?? 0.0;
        return bChange.compareTo(aChange);
      });
    } else if (sorting == "INVESTEDASC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aInvested = double.tryParse(a.investedValue ?? "0.00") ?? 0.0;
        double bInvested = double.tryParse(b.investedValue ?? "0.00") ?? 0.0;
        return aInvested.compareTo(bInvested);
      });
    } else if (sorting == "INVESTEDDSC") {
      _mfholdingnew!.data!.sort((a, b) {
        double aInvested = double.tryParse(a.investedValue ?? "0.00") ?? 0.0;
        double bInvested = double.tryParse(b.investedValue ?? "0.00") ?? 0.0;
        return bInvested.compareTo(aInvested);
      });
    }

    notifyListeners();
  }
}

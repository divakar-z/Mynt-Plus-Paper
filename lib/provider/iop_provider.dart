// ignore_for_file: use_build_context_synchronously\
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/models/ipo_model/ipo_details_model.dart';
import 'package:mynt_plus/models/ipo_model/ipo_pre_close_model.dart';
import 'package:mynt_plus/models/ipo_model/ipo_upcoming_model.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/provider/stocks_provider.dart';
import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/ipo_model/ipo_db_model.dart';
import '../models/ipo_model/ipo_mainstream_model.dart';
import '../models/ipo_model/ipo_order_book_model.dart';
import '../models/ipo_model/ipo_order_res_model.dart';
import '../models/ipo_model/ipo_performance_model.dart';
import '../models/ipo_model/ipo_place_order_model.dart';
import '../models/ipo_model/ipo_single_page_model.dart';
import '../models/ipo_model/ipo_sme_model.dart';
import '../models/mf_model/mf_bank_detail_model.dart';
import '../res/res.dart';
import '../sharedWidget/snack_bar.dart';
import 'core/default_change_notifier.dart';
import 'package:intl/intl.dart';

final ipoProvide = ChangeNotifierProvider((ref) => IPOProvider(ref));

class IPOProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();

  late TabController ipoTab;

  // final String ipoImageUrl=api.apiLinks.dashBoardURL;

  final TextEditingController quantity = TextEditingController();
  final TextEditingController bidprice = TextEditingController();

  bool _ipoOrderLoading = false;
  bool get ipoOrderLoading => _ipoOrderLoading;
  void toggleIpoOrderLoading(bool on) {
    _ipoOrderLoading = on;
    notifyListeners();
  }

  bool _isSMEPlaceOrderBtnActive = false;
  bool get isSMEPlaceOrderBtnActive => _isSMEPlaceOrderBtnActive;

  set setisSMEPlaceOrderBtnActiveValue(bool value) {
    _isSMEPlaceOrderBtnActive = value;
  }

  int _smePlaceOrderRequiredMaxPrice = 0;
  int get smePlaceOrderRequiredMaxPrice => _smePlaceOrderRequiredMaxPrice;

  set setsmePlaceOrderRequiredMaxPrice(List<IpoDetails> addIpo) {
    _smePlaceOrderRequiredMaxPrice =
        addIpo.map((map) => map.requriedprice).reduce((a, b) => a > b ? a : b);
  }

  bool _isMainIPOPlaceOrderBtnActive = false;
  bool get isMainIPOPlaceOrderBtnActive => _isMainIPOPlaceOrderBtnActive;

  set setisMainIPOPlaceOrderBtnActiveValue(bool value) {
    _isMainIPOPlaceOrderBtnActive = value;
  }

  int _mainIPOPlaceOrderRequiredMaxPrice = 0;
  int get mainIPOPlaceOrderRequiredMaxPrice =>
      _mainIPOPlaceOrderRequiredMaxPrice;

  set setMainIPOPlaceOrderRequiredMaxPrice(List<IpoDetails> addIpo) {
    _mainIPOPlaceOrderRequiredMaxPrice =
        addIpo.map((map) => map.requriedprice).reduce((a, b) => a > b ? a : b);
  }

  final List customIpoCategoryListOrder = [
    "Individual",
    "HNI",
    "Employee",
    "Shareholder",
    "Policyholder"
  ];

  bool _isActiveMainStream = true;
  bool get isActiveMainStream => _isActiveMainStream;

  bool _isActiveSME = true;
  bool get isActiveSME => _isActiveSME;

  final Ref ref;

  void activeMainStreamBtn(bool val) {
    _isActiveMainStream = val;
    // log("$_isActiveMainStream");
    notifyListeners();
  }

  void activeSMEBtn(bool val) {
    _isActiveSME = val;
    // log("$_isActiveSME");
    notifyListeners();
  }

  IPOProvider(this.ref);

  // List<IPOOrderBookModel>? _orderBookModel;
  // List<IPOOrderBookModel>? get orderBookModel => _orderBookModel;

  final TextEditingController viewupiid = TextEditingController();
  final TextEditingController performancesearchcontroller =
      TextEditingController();
  final TextEditingController openOrderController = TextEditingController();
  final TextEditingController ipocommonsearchcontroller =
      TextEditingController();
  late TabController tabCtrl;
  late TabController ipoScreenTab;
  late TabController ipoOrderBookScreenTab;

  final tablistitems = [
    {
      "title": "Open",
      "index": 0,
    },
    {
      "title": "Upcoming",
      "index": 1,
    },
    {
      "title": "My Bids",
      "index": 2,
    }
  ];

  VerifyUPIModel? _upiIdValidationModel;
  VerifyUPIModel? get upiIdValidationModel => _upiIdValidationModel;

  SmeIpoModel? _smeIpoModel;
  SmeIpoModel? get smeIpoModel => _smeIpoModel;

  DashbordIposIPOS? _dashboardIpoModel;
  DashbordIposIPOS? get dashboardIpoModel => _dashboardIpoModel;

  MainStreamIpoModel? _mainStreamIpoModel;
  MainStreamIpoModel? get mainStreamIpoModel => _mainStreamIpoModel;

  IpoPerformanceModel? _ipoPerformanceModel;
  IpoPerformanceModel? get ipoPerformanceModel => _ipoPerformanceModel;

  IpoPreCloseModel? _ipoPreClose;
  IpoPreCloseModel? get ipoPreClose => _ipoPreClose;

  List<IpoScrip>? _performancesearch = [];
  List<IpoScrip>? get performancesearch => _performancesearch;

  final List<IpoScrip> _filterperformance = [];
  List<IpoScrip>? get filterperformance => _filterperformance;

  IpoOrderResponcesModel? _ipoOrderResponcesModel;
  IpoOrderResponcesModel? get ipoOrderResponcesModel => _ipoOrderResponcesModel;

  IpoOrderBookModel? _iposubcategory;
  IpoOrderBookModel? get iposubcategory => _iposubcategory;

  List<IpoOrderBookModel>? _ipoOrderBookModel;
  List<IpoOrderBookModel>? get ipoOrderBookModel => _ipoOrderBookModel;

  List<IpoOrderBookModel>? _iposearch = [];
  List<IpoOrderBookModel>? get iposearch => _iposearch;

  List _ipoCommonSearchList = [];
  List get ipoCommonSearchList => _ipoCommonSearchList;

  List _ipoCommonSearchAllIpos = [];

  List<IpoOrderBookModel>? _openorder = [];
  List<IpoOrderBookModel>? get openorder => _openorder;

  List<IpoOrderBookModel>? _closeorder = [];
  List<IpoOrderBookModel>? get closeorder => _closeorder;

  List<dynamic> _mainsme = [];
  List<dynamic> get mainsme => _mainsme;

  final List<MainIPO> _main = [];
  List<MainIPO>? get main => _main;

  final List<SMEIPO> _sme = [];
  List<SMEIPO>? get sme => _sme;

  String ipoCategoryvalue = "";
  String get ipoCategorys => ipoCategoryvalue;

  bool _upivalid = false;
  bool get upivalid => _upivalid;

  String _upierror = "";
  String get upierror => _upierror;

  mergemainsme() {
    _mainsme = [];
    _ipoCommonSearchAllIpos = [];
    try {
      _mainsme.addAll(_mainStreamIpoModel!.mainIPO ?? []);
      _mainsme.addAll(_smeIpoModel!.sMEIPO ?? []);

      _ipoCommonSearchAllIpos.addAll(_mainStreamIpoModel!.mainIPO ?? []);
      _ipoCommonSearchAllIpos.addAll(_smeIpoModel!.sMEIPO ?? []);
      _ipoCommonSearchAllIpos.addAll(_ipoPerformanceModel!.data ?? []);
      _ipoCommonSearchAllIpos.addAll(_ipoPreClose?.msg ?? []);

      for (int i = 0; i < _mainsme.length; i++) {
        if (_mainsme[i] is MainIPO) {
          _mainsme[i].key = "MAIN";

          // print(
          //     "MAIN IPO : ${_mainsme[i].biddingStartDate} ${_mainsme[i].name} ${_mainsme[i].key}");
        } else if (_mainsme[i] is SMEIPO) {
          _mainsme[i].key = "SME";
          // print(
          //     "SME IPO : ${_mainsme[i].biddingStartDate} ${_mainsme[i].name} ${_mainsme[i].key}");
        }
      }
      // print("ODDDDD :: ${_mainsme[0].biddingStartDate} ${_mainsme[0].key}");

      _mainsme.sort((a, b) {
        final DateFormat dateFormat = DateFormat("dd-MM-yyyy");
        DateTime dateA = dateFormat.parse(a.biddingStartDate.toString());
        DateTime dateB = dateFormat.parse(b.biddingStartDate.toString());
        return dateA.compareTo(dateB);
      });

      return _mainsme = mainsme;
      //return _mainsme;
    } catch (e) {
    }
  }

  IpoSinglePage? _ipoSinglePage;
  IpoSinglePage? get iposinglepage => _ipoSinglePage;

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  // Method to set selected tab index
  void setSelectedTab(int index) {
    if (index >= 0 && index < tablistitems.length) {
      _selectedTab = index;
      notifyListeners();
    }
  }

  void resetTabToDefault() {
    _selectedTab = 0;
    notifyListeners();
  }

  String timemessage = "";
  String get timeMessage => timemessage;

  double _maxUPIAmt = 0.00;
  double get maxUPIAmt => _maxUPIAmt;

  bool _showSearch = false;
  bool get showSearch => _showSearch;

  final String _numbers = "";
  String? get numbers => _numbers;

  String? _maxValue = "";
  String? get maxValue => _maxValue;

  List<String> _stringList = [];
  List<String> get stringList => _stringList;

  final List<Tab> _ipoScreenTabName = [
    const Tab(text: "Explore IPOs"),
    const Tab(text: "Order Book"),
  ];
  List<Tab> get ipoScreenTabName => _ipoScreenTabName;

  final List<Tab> _orderBookTabName = [];
  List<Tab> get orderBookTabName => _orderBookTabName;

  bool _displayload = true;
  bool get displayload => _displayload;

  bool _myBidsload = true;
  bool get myBidsload => _myBidsload;

  final List _inIPOTabNameBtns = [
    {"btnName": "Live / Pre Open", "imgPath": assets.liveorpre},
    {"btnName": "Closed", "imgPath": assets.closed},
    {"btnName": "Listed", "imgPath": assets.listed}
  ];
  List get inIPOTabNameBtns => _inIPOTabNameBtns;

  String _inIPOTabNameAct = "Live / Pre Open";
  String get inIPOTabNameAct => _inIPOTabNameAct;

  chngDephBtn(val) {
    _inIPOTabNameAct = val;
    notifyListeners();
  }

  // tabSize() {
  //   _orderTabName = [
  //     Tab(text: "Current & Upcoming"),
  //     Tab(text: "Listed IPO’s")
  //   ];

  //   notifyListeners();
  // }

  showOpenSearch(bool value) {
    _showSearch = value;
    if (!_showSearch) {
      _ipoOrderBookModel = [];
    }
    notifyListeners();
  }

  clearopenoreder() {
    openOrderController.clear();
    _iposearch = [];
    notifyListeners();
  }

  clearPerformanceSearch() {
    performancesearchcontroller.clear();
    _performancesearch = [];
    notifyListeners();
  }

// Common search for IPOs

  showCommonIpoSearch(bool value) {
    _showSearch = value;
    if (!_showSearch) {
      _ipoCommonSearchList = [];
    }
    notifyListeners();
  }

  clearCommonIpoSearch() {
    // ipocommonsearchcontroller.clear();
    ref.read(stocksProvide).searchController.clear();
    _ipoCommonSearchList = [];
    notifyListeners();
  }

  // Set common IPO search query to drive filtering in Upcoming and My Bids screens
  void setIpoSearchQuery(String value) {
    ipocommonsearchcontroller.text = value;
    notifyListeners();
  }

  dynamic getIpoDetails(String searchCompany) {
    dynamic returnData;
    if (searchCompany.length > 1) {
      returnData = _ipoCommonSearchAllIpos
          .where((element) => element.companyName != ""
              ? element.companyName!
                  .toUpperCase()
                  .contains(searchCompany.toUpperCase())
              : element.name!
                  .toUpperCase()
                  .contains(searchCompany.toUpperCase()))
          .toList();
    }
    return returnData;
    // notifyListeners();
  }

  searchCommonIpo(String value, BuildContext context) {
    if (value.length > 1) {
      _ipoCommonSearchList = [];
      // ScaffoldMessenger.of(context).hideCurrentSnackBar();

      _ipoCommonSearchList = _ipoCommonSearchAllIpos
          .where((element) => element.companyName != ""
              ? element.companyName!.toUpperCase().contains(value.toUpperCase())
              : element.name!.toUpperCase().contains(value.toUpperCase()))
          .toList();

      // print("_ipoCommonSearchList :: ${inspect(_ipoCommonSearchList)}");
      // if (_ipoCommonSearchList.isEmpty) {
      //   ScaffoldMessenger.of(context)
      //       .showSnackBar(warningMessage(context, 'No Data Found'));
      // } else {
      //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // }
    } else {
      _ipoCommonSearchList = [];
    }
    notifyListeners();
  }

  openOrderSearch(String value, BuildContext context) {
    if (value.length > 1) {
      _iposearch = [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _iposearch = _openorder!.where((element) {
        final symbol = element.symbol!.toUpperCase();
        final companyname = element.companyName!.toUpperCase();
        final status = element.reponseStatus!.toUpperCase();
        final investedvalue = element.bidDetail![0].amount!.toUpperCase();
        return companyname.contains(value.toUpperCase()) ||
            status.contains(value.toUpperCase()) ||
            investedvalue.contains(value.toUpperCase()) ||
            symbol.contains(value.toUpperCase());
      }).toList();
      if (_iposearch!.isEmpty) {
        warningMessage(context, 'No Data Found');
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } else {
      _iposearch = [];
    }
    notifyListeners();
  }

  searchperformance(String value, BuildContext context) {
    if (value.length > 1) {
      _performancesearch = [];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _performancesearch = _ipoPerformanceModel!.data!
          .where((element) =>
              element.companyName!.toUpperCase().contains(value.toUpperCase()))
          .toList();
      if (_performancesearch!.isEmpty) {
        warningMessage(context, 'No Data Found');
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } else {
      _performancesearch = [];
    }
    notifyListeners();
  }

  smedatesort(List<SMEIPO> data) {
    try {
      data.sort((a, b) {
        final DateFormat dateFormat = DateFormat("MMMM d, yyyy");
        DateTime dateA = dateFormat.parse(a.biddingStartDate.toString());
        DateTime dateB = dateFormat.parse(b.biddingStartDate.toString());
        return dateB.compareTo(dateA);
      }); // Sort by date
    } catch (e) {}
  }

  sortIPOListByDate(List<IpoScrip> data) {
    try {
      data.sort((a, b) {
        final DateFormat dateFormat = DateFormat("MMMM d, yyyy");
        DateTime dateA = dateFormat.parse(a.listedDate.toString());
        DateTime dateB = dateFormat.parse(b.listedDate.toString());
        return dateB.compareTo(dateA);
      }); // Sort by date
    } catch (e) {}
  }

  changeTabIndex(
    int index,
  ) {
    _selectedTab = index;
    notifyListeners();
  }

  changeIpoIndex(int index, BuildContext context) {
    _selectedTab = index;
    notifyListeners();
  }

  validateCurrentTime() {
    String message = "";
    final now = DateTime.now();
    final int currentMinutes = now.hour * 60 + now.minute;
    const int startMinutes = 10 * 60; // 10:00 AM
    const int endMinutes = 17 * 60; // 5:00 PM

    if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
      message = "Time";
    } else {
      message =
          "IPO window is open from 10:00 AM till 05:00 PM on trading days.";
    }
    timemessage = message;

    notifyListeners();
  }

  smecutoffprice(IpoDetails addIpo, SMEIPO smeipo) {
    addIpo.biderrortext = "";
    addIpo.isChecked = !addIpo.isChecked;
    addIpo.isChecked == true
        ? addIpo.bidpricecontroller.text =
            ("${double.parse(smeipo.maxPrice!).toInt()}")
        : addIpo.bidpricecontroller.text =
            "${double.parse(smeipo.minPrice!).toInt()}";
    addIpo.isChecked == true
        ? addIpo.qualityController.text.isEmpty
            ? addIpo.qualityController.text = ""
            : addIpo.requriedprice = double.parse(smeipo.maxPrice!).toInt() *
                (int.parse(addIpo.qualityController.text))
        : addIpo.qualityController.text.isEmpty
            ? addIpo.qualityController.text = ""
            : addIpo.requriedprice = double.parse(smeipo.minPrice!).toInt() *
                (int.parse(addIpo.qualityController.text));
    if (addIpo.qualityController.text.isNotEmpty) {
      if (addIpo.requriedprice > _maxUPIAmt) {
        addIpo.qualityerrortext =
            "Maximum investment upto ₹${_maxUPIAmt.toInt()} only ";
        setisSMEPlaceOrderBtnActiveValue = false;
      } else {
        addIpo.qualityerrortext = "";
      }
    }
    notifyListeners();
  }

  smebidpriceOnChange(
      String value, IpoDetails addIpo, bool ischecked, SMEIPO smeipo) {
    final bidPrice = (double.tryParse(value) ?? 0).toInt();
    final qty = (double.tryParse(addIpo.qualityController.text) ?? 0).round();
    value.isEmpty
        ? addIpo.requriedprice = 0
        : addIpo.requriedprice = (bidPrice * qty).toInt();
    if (value.isEmpty || value == "0") {
      addIpo.biderrortext =
          value.isEmpty ? "* Value is required" : "Value cannot be 0";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (bidPrice > double.parse(smeipo.maxPrice.toString()).toInt() ||
        bidPrice < double.parse(smeipo.minPrice.toString()).toInt()) {
      addIpo.biderrortext =
          "Your bid price ranges between ₹${double.parse(smeipo.minPrice!).toInt()}-₹${double.parse(smeipo.maxPrice!).toInt()}";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.biderrortext = "";
    }

    if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
    } else {
      if (addIpo.qualityerrortext.contains("Maximum investment")) {
        addIpo.qualityerrortext = "";
      }
    }
    notifyListeners();
  }

  smequantityOnchange(String value, IpoDetails addIpo, SMEIPO smeipo,
      bool ischecked, double maxUPIAmt, String selectedChip) {
    final qty = (double.tryParse(value) ?? 0).round();
    final bidPrice = (double.tryParse(addIpo.bidpricecontroller.text) ?? 0).toInt();
    value.isEmpty
        ? addIpo.requriedprice = 0
        : addIpo.requriedprice = addIpo.isChecked
            ? double.parse(smeipo.maxPrice!).toInt() * qty
            : bidPrice * qty;
    if (value.isEmpty || value == "0") {
      addIpo.qualityerrortext =
          value.isEmpty ? "* Value is required" : "Value cannot be 0";
      addIpo.requriedprice = 0;
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (qty < int.parse(smeipo.minBidQuantity.toString())) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${smeipo.minBidQuantity.toString()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (addIpo.lotsize > 0 && qty % addIpo.lotsize != 0) {
      addIpo.qualityerrortext =
          "Quantity must be in multiples of ${addIpo.lotsize}";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }
    notifyListeners();
  }

  smequantityminusfunction(IpoDetails addIpo, bool ischecked, SMEIPO smeipo,
      double maxUPIAmt, String selectedChip) {
    if (addIpo.qualityController.text.isNotEmpty) {
      final minQty = int.parse(smeipo.minBidQuantity.toString());
      final currentQty = int.parse(addIpo.qualityController.text);
      int newQty;
      if (addIpo.lotsize > 0 && currentQty % addIpo.lotsize != 0) {
        newQty = ((currentQty / addIpo.lotsize).floor()) * addIpo.lotsize;
      } else {
        newQty = currentQty - addIpo.lotsize;
      }
      if (newQty < minQty) newQty = minQty;
      addIpo.qualityController.text = newQty.toString();

      addIpo.isChecked == true
          ? addIpo.requriedprice = double.parse(smeipo.maxPrice!).toInt() *
              (int.parse(addIpo.qualityController.text))
          : addIpo.requriedprice =
              double.parse(addIpo.bidpricecontroller.text).toInt() *
                  (int.parse(addIpo.qualityController.text));
    }
    if (addIpo.qualityController.text.isEmpty ||
        addIpo.qualityController.text == "0") {
      addIpo.qualityerrortext = addIpo.qualityController.text.isEmpty
          ? "* Value is required"
          : "Value cannot be 0";
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      // setisMainIPOPlaceOrderBtnActiveValue = false;
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if ((int.parse(addIpo.qualityController.text)) <
        int.parse(smeipo.minBidQuantity.toString()).toInt()) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${smeipo.minBidQuantity.toString()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }
    notifyListeners();
  }

  smequalityplusefunction(IpoDetails addIpo, bool ischecked, SMEIPO smeipo,
      double maxUPIAmt, String selectedChip) {
    if (addIpo.qualityController.text.isNotEmpty) {
      final currentQty = int.parse(addIpo.qualityController.text);
      int newQty;
      if (addIpo.lotsize > 0 && currentQty % addIpo.lotsize != 0) {
        newQty = ((currentQty / addIpo.lotsize).ceil()) * addIpo.lotsize;
      } else {
        newQty = currentQty + addIpo.lotsize;
      }
      addIpo.qualityController.text = newQty.toString();
      addIpo.isChecked == true
          ? addIpo.requriedprice = double.parse(smeipo.maxPrice!).toInt() *
              (int.parse(addIpo.qualityController.text))
          : addIpo.requriedprice =
              double.parse(addIpo.bidpricecontroller.text).toInt() *
                  (int.parse(addIpo.qualityController.text));
    }
    if (addIpo.qualityController.text.isEmpty ||
        addIpo.qualityController.text == "0") {
      addIpo.qualityerrortext = addIpo.qualityController.text.isEmpty
          ? "* Value is required"
          : "Value cannot be 0";
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      // setisMainIPOPlaceOrderBtnActiveValue = false;
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if ((int.parse(addIpo.qualityController.text)) <
        int.parse(smeipo.minBidQuantity.toString()).toInt()) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${smeipo.minBidQuantity.toString()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
      setisSMEPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }
    notifyListeners();
  }

  checkForErrorsInSMEPlaceOrder(List<IpoDetails> addIpo) {
    bool status = false;
    for (final item in addIpo) {
      if (item.qualityerrortext.isEmpty && item.biderrortext.isEmpty) {
        status = true;
      } else {
        status = false;
        break;
      }
    }
    return status;
  }

  ipoOrdervalidation(
      IpoDetails addIpo,
      double maxUPIAmt,
      bool ischecked,
      FundProvider upiid,
      BuildContext context,
      Function(FundProvider upiid) ipoplaceorder) {
    if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
      ischecked = false;
    } else if (addIpo.bidpricecontroller.text.isEmpty) {
      warningMessage(context, "*Bid Price Value is required");
      ischecked = false;
    } else if (upiid.viewupiid.text.isEmpty) {
      ischecked = false;
      warningMessage(context, '* UPI ID cannot be empty');
    } else if (!RegExp(r'^[\w.-]+@[\w]+$').hasMatch(upiid.viewupiid.text)) {
      ischecked = false;
      warningMessage(context, 'Invalid UPI ID format');
    } else {
      ipoplaceorder(upiid);
    }
    notifyListeners();
  }

  categoryOnChange(List<IpoDetails> addIpo, double maxUPIAmt, bool ischecked,
      String selectedChip) {
    for (IpoDetails singleIpo in addIpo) {
      if (singleIpo.requriedprice > maxUPIAmt) {
        singleIpo.qualityerrortext =
            "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} ";
        setisMainIPOPlaceOrderBtnActiveValue = false;
        setisSMEPlaceOrderBtnActiveValue = false;
      } else if (selectedChip == "HNI" && singleIpo.requriedprice < 200000) {
        singleIpo.qualityerrortext =
            "Minimum investment for HNI is above ₹200000";
        setisMainIPOPlaceOrderBtnActiveValue = false;
        setisSMEPlaceOrderBtnActiveValue = false;
      } else if (((int.parse(singleIpo.qualityController.text)) <
          singleIpo.lotsize)) {
        singleIpo.qualityerrortext = "Provide bid with valid Quantity";
        setisMainIPOPlaceOrderBtnActiveValue = false;
        setisSMEPlaceOrderBtnActiveValue = false;
      } else {
        singleIpo.qualityerrortext = "";
        setisMainIPOPlaceOrderBtnActiveValue = false;
        setisSMEPlaceOrderBtnActiveValue = false;
      }
      notifyListeners();
    }
  }

  // onChangeCheckmainIPOBids(List<IpoDetails> addIpo,IPOProvider ipo,String selectedChip,MainIPO mainstream){
  //   for (var singleIpo in addIpo){
  //     if (singleIpo.qualityController.text.isEmpty ||
  //       singleIpo.qualityController.text == "0") {
  //     singleIpo.qualityerrortext = singleIpo.qualityController.text.isEmpty
  //         ? "* Value is required"
  //         : "Value cannot be 0";
  //   }else if ((int.parse(singleIpo.bidpricecontroller.text)) >
  //           double.parse(mainstream.maxPrice.toString()).toInt() ||
  //       (int.parse(singleIpo.bidpricecontroller.text)) <
  //           double.parse(mainstream.minPrice.toString()).toInt()) {
  //     singleIpo.biderrortext =
  //         "Your bid price ranges between ₹${double.parse(mainstream.minPrice!).toInt()}-₹${double.parse(mainstream.maxPrice!).toInt()}";
  //     setisMainIPOPlaceOrderBtnActiveValue = false;
  //   }
  //   else if (singleIpo.requriedprice > ipo.maxUPIAmt) {
  //     singleIpo.qualityerrortext =
  //         "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ";
  //     setisMainIPOPlaceOrderBtnActiveValue = false;
  //   } else if (selectedChip=="HNI" && singleIpo.requriedprice < 200000) {
  //     singleIpo.qualityerrortext =
  //         "Minimum investment for HNI is ₹200000 ";
  //     setisMainIPOPlaceOrderBtnActiveValue = false;
  //   }else {
  //     singleIpo.qualityerrortext = "";
  //   }

  //   if ((int.parse(singleIpo.qualityController.text)) <
  //       int.parse(mainstream.minBidQuantity.toString()).toInt()) {
  //     singleIpo.qualityerrortext =
  //         "Minimum Bid quantity is ${mainstream.minBidQuantity.toString()} only ";
  //     setisMainIPOPlaceOrderBtnActiveValue = false;
  //   }

  //   }
  //   notifyListeners();
  // }

  qualityplusefunction(IpoDetails addIpo, bool ischecked, IPOProvider ipo,
      MainIPO mainstream, String selectedChip) {
    if (addIpo.qualityController.text.isNotEmpty) {
      final currentQty = int.parse(addIpo.qualityController.text);
      int newQty;
      if (addIpo.lotsize > 0 && currentQty % addIpo.lotsize != 0) {
        newQty = ((currentQty / addIpo.lotsize).ceil()) * addIpo.lotsize;
      } else {
        newQty = currentQty + addIpo.lotsize;
      }
      addIpo.qualityController.text = newQty.toString();
      addIpo.isChecked == true
          ? addIpo.requriedprice = double.parse(mainstream.maxPrice!).toInt() *
              (int.parse(addIpo.qualityController.text))
          : addIpo.requriedprice =
              double.parse(addIpo.bidpricecontroller.text).toInt() *
                  (int.parse(addIpo.qualityController.text));
    }
    if (addIpo.qualityController.text.isEmpty ||
        addIpo.qualityController.text == "0") {
      addIpo.qualityerrortext = addIpo.qualityController.text.isEmpty
          ? "* Value is required"
          : "Value cannot be 0";
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
      // setisSMEPlaceOrderBtnActiveValue = false;
    } else if ((int.parse(addIpo.qualityController.text)) <
        int.parse(mainstream.minBidQuantity.toString()).toInt()) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${mainstream.minBidQuantity.toString()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > ipo.maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }

    notifyListeners();
  }

  quantityminusfunction(IpoDetails addIpo, bool ischecked, IPOProvider ipo,
      MainIPO mainstream, String selectedChip) {
    if (addIpo.qualityController.text.isNotEmpty) {
      final minQty = int.parse(mainstream.minBidQuantity.toString());
      int newQty;
      if ((int.parse(addIpo.qualityController.text) % addIpo.lotsize) == 0) {
        newQty = int.parse(addIpo.qualityController.text) - addIpo.lotsize;
      } else {
        newQty = ((int.parse(addIpo.qualityController.text) / addIpo.lotsize)
                    .floor()) *
                addIpo.lotsize;
      }
      if (newQty < minQty) newQty = minQty;
      addIpo.qualityController.text = newQty.toString();
      addIpo.isChecked == true
          ? addIpo.requriedprice = double.parse(mainstream.maxPrice!).toInt() *
              (int.parse(addIpo.qualityController.text))
          : addIpo.requriedprice =
              double.parse(addIpo.bidpricecontroller.text).toInt() *
                  (int.parse(addIpo.qualityController.text));
    }
    if (addIpo.qualityController.text.isEmpty ||
        addIpo.qualityController.text == "0") {
      addIpo.qualityerrortext = addIpo.qualityController.text.isEmpty
          ? "* Value is required"
          : "Value cannot be 0";
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
      // setisSMEPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > ipo.maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if ((int.parse(addIpo.qualityController.text)) <
        int.parse(mainstream.minBidQuantity.toString()).toInt()) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${mainstream.minBidQuantity.toString()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }
    notifyListeners();
  }

  quantityOnchange(IpoDetails addIpo, bool ischecked, IPOProvider ipo,
      String value, MainIPO mainstream, String selectedChip) {
    final qty = (double.tryParse(value) ?? 0).round();
    final bidPrice = (double.tryParse(addIpo.bidpricecontroller.text) ?? 0).toInt();
    value.isEmpty
        ? addIpo.requriedprice = 0
        : addIpo.requriedprice = addIpo.isChecked
            ? double.parse(mainstream.maxPrice!).toInt() * qty
            : bidPrice * qty;
    if (value.isEmpty || value == "0") {
      addIpo.qualityerrortext =
          value.isEmpty ? "* Value is required" : "Value cannot be 0";
      addIpo.requriedprice = 0;
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (selectedChip == "HNI" && addIpo.requriedprice < 200000) {
      addIpo.qualityerrortext = "Minimum investment for HNI is above ₹200000 ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (addIpo.requriedprice > ipo.maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(ipo.maxUPIAmt.toString()).toInt()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (qty < int.parse(mainstream.minBidQuantity.toString())) {
      addIpo.qualityerrortext =
          "Minimum Bid quantity is ${mainstream.minBidQuantity.toString()} only ";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (addIpo.lotsize > 0 && qty % addIpo.lotsize != 0) {
      addIpo.qualityerrortext =
          "Quantity must be in multiples of ${addIpo.lotsize}";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.qualityerrortext = "";
    }
    notifyListeners();
  }

  bidpricefunction(
      IpoDetails addIpo, MainIPO mainstream, String value, bool ischecked) {
    final bidPrice = (double.tryParse(value) ?? 0).toInt();
    final qty = (double.tryParse(addIpo.qualityController.text) ?? 0).round();
    value.isEmpty
        ? addIpo.requriedprice = 0
        : addIpo.requriedprice = (bidPrice * qty).toInt();
    if (value.isEmpty || value == "0") {
      addIpo.biderrortext =
          value.isEmpty ? "* Value is required" : "Value cannot be 0";
      addIpo.requriedprice = 0;
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else if (bidPrice > double.parse(mainstream.maxPrice.toString()).toInt() ||
        bidPrice < double.parse(mainstream.minPrice.toString()).toInt()) {
      addIpo.biderrortext =
          "Your bid price ranges between ₹${double.parse(mainstream.minPrice!).toInt()}-₹${double.parse(mainstream.maxPrice!).toInt()}";
      setisMainIPOPlaceOrderBtnActiveValue = false;
    } else {
      addIpo.biderrortext = "";
    }

    if (addIpo.requriedprice > maxUPIAmt) {
      addIpo.qualityerrortext =
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ";
    } else {
      if (addIpo.qualityerrortext.contains("Maximum investment")) {
        addIpo.qualityerrortext = "";
      }
    }
    notifyListeners();
  }

  cutoffprice(IpoDetails addIpo, MainIPO mainstream) {
    addIpo.biderrortext = "";
    addIpo.isChecked = !addIpo.isChecked;
    addIpo.isChecked == true
        ? addIpo.bidpricecontroller.text =
            ("${double.parse(mainstream.maxPrice!).toInt()}")
        : addIpo.bidpricecontroller.text =
            "${double.parse(mainstream.minPrice!).toInt()}";
    addIpo.isChecked == true
        ? addIpo.qualityController.text.isEmpty
            ? addIpo.qualityController.text = ""
            : addIpo.requriedprice =
                double.parse(mainstream.maxPrice!).toInt() *
                    (int.parse(addIpo.qualityController.text))
        : addIpo.qualityController.text.isEmpty
            ? addIpo.qualityController.text = ""
            : addIpo.requriedprice =
                double.parse(mainstream.minPrice!).toInt() *
                    (int.parse(addIpo.qualityController.text));
    if (addIpo.qualityController.text.isNotEmpty) {
      if (addIpo.requriedprice > _maxUPIAmt) {
        addIpo.qualityerrortext =
            "Maximum investment upto ₹${_maxUPIAmt.toInt()} only ";
        setisMainIPOPlaceOrderBtnActiveValue = false;
      } else {
        addIpo.qualityerrortext = "";
      }
    }
    notifyListeners();
  }

  smeipocategory(SMEIPO ipo) {
    ipoCategory = [];
    ipoCategoryvalue = "";
    try {
      toggleLoadingOn(true);
      for (var i = 0; i < ipo.subCategorySettings!.length; i++) {
        if (ipo.subCategorySettings![i].allowUpi!) {
          if (ipo.subCategorySettings![i].subCatCode == "IND") {
            if (ipo.type == "BSE") {
              ipoCategory.add({
                "subCatCode": "Individual",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            } else if (ipo.subCategorySettings![i].caCode == "RETAIL") {
              ipoCategory.add({
                "subCatCode": "Individual",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            } else if (ipo.subCategorySettings![i].caCode == "NIB") {
              ipoCategory.add({
                "subCatCode": "HNI",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            }
          } else if (ipo.subCategorySettings![i].subCatCode == "EMP") {
            ipoCategory.add({
              "subCatCode": "Employee",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          } else if (ipo.subCategorySettings![i].subCatCode == "SHA") {
            ipoCategory.add({
              "subCatCode": "Shareholder",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          } else if (ipo.subCategorySettings![i].subCatCode == "POL") {
            ipoCategory.add({
              "subCatCode": "Policyholder",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          }
        }
      }
      final seen = <String>{};
      ipoCategory = ipoCategory.where((map) {
        // Create a unique key string for each map
        final key = map.entries.map((e) => '${e.key}:${e.value}').join(',');
        if (seen.contains(key)) {
          return false;
        } else {
          seen.add(key);
          return true;
        }
      }).toList();
      ipoCategory.sort((a, b) => customIpoCategoryListOrder
          .indexOf(a['subCatCode'])
          .compareTo(customIpoCategoryListOrder.indexOf(b['subCatCode'])));
      ipoCategoryvalue = ipoCategory[0]["subCatCode"];
      _maxUPIAmt = double.parse(ipoCategory[0]["upiLimit"]);
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  mainipocategory(MainIPO ipo) async {
    try {
      toggleLoadingOn(true);
      ipoCategory = [];
      ipoCategoryvalue = "";
      for (var i = 0; i < ipo.subCategorySettings!.length; i++) {
        if (ipo.subCategorySettings![i].allowUpi!) {
          if (ipo.subCategorySettings![i].subCatCode == "IND") {
            if (ipo.type == "BSE") {
              ipoCategory.add({
                "subCatCode": "Individual",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            } else if (ipo.subCategorySettings![i].caCode == "RETAIL") {
              ipoCategory.add({
                "subCatCode": "Individual",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            } else if (ipo.subCategorySettings![i].caCode == "NIB") {
              ipoCategory.add({
                "subCatCode": "HNI",
                "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
              });
            }
          } else if (ipo.subCategorySettings![i].subCatCode == "EMP") {
            ipoCategory.add({
              "subCatCode": "Employee",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          } else if (ipo.subCategorySettings![i].subCatCode == "SHA") {
            ipoCategory.add({
              "subCatCode": "Shareholder",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          } else if (ipo.subCategorySettings![i].subCatCode == "POL") {
            ipoCategory.add({
              "subCatCode": "Policyholder",
              "upiLimit": "${ipo.subCategorySettings![i].maxUpiLimit}"
            });
          }
        }
      }
      final seen = <String>{};
      ipoCategory = ipoCategory.where((map) {
        // Create a unique key string for each map
        final key = map.entries.map((e) => '${e.key}:${e.value}').join(',');
        if (seen.contains(key)) {
          return false;
        } else {
          seen.add(key);
          return true;
        }
      }).toList();

      ipoCategory.sort((a, b) => customIpoCategoryListOrder
          .indexOf(a['subCatCode'])
          .compareTo(customIpoCategoryListOrder.indexOf(b['subCatCode'])));

      ipoCategoryvalue = ipoCategory[0]["subCatCode"];
      _maxUPIAmt = double.parse(ipoCategory[0]["upiLimit"]);

      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
    notifyListeners();
  }

  policyfunction(bool ischecked, IpoDetails addIpo, double maxUPIAmt,
      BuildContext context) {
    ischecked = !ischecked;
    if (addIpo.requriedprice > maxUPIAmt) {
      warningMessage(context,
          "Maximum investment upto ₹${double.parse(maxUPIAmt.toString()).toInt()} only ");

      ischecked = false;
    } else if (addIpo.bidpricecontroller.text.isEmpty) {
      warningMessage(context, "*Bid Price Value is required");
      ischecked = false;
    }
    notifyListeners();
  }

  upiIDvalidation(String value, FundProvider upiid, String upierrortext) {
    upiid.viewupiid.text = value;
    if (upiid.viewupiid.text.isEmpty) {
      upierrortext = "* UPI ID cannot be empty";
    } else if (!RegExp(r'^[\w.-]+@[\w]+$')
        .hasMatch(upiid.viewupiid.text = value)) {
      upierrortext = 'Invalid UPI ID format';
    } else {
      upierrortext = '';
    }
    notifyListeners();
  }

  List<double> getCustomItemsHeight(List numofList) {
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

  modifyipocategory() {
    ipoCategory = [];
    for (var element = 0; element < ipoOrderBookModel!.length; element++) {
      for (var settings = 0;
          settings < ipoOrderBookModel![element].subcategorysettings!.length;
          settings++) {
        if (ipoOrderBookModel![element]
                .subcategorysettings![settings]
                .allowUpi ==
            true) {
          if (ipoOrderBookModel![element]
                      .subcategorysettings![settings]
                      .subCatCode ==
                  "IND" &&
              ipoOrderBookModel![element]
                      .subcategorysettings![settings]
                      .caCode ==
                  "RETAIL") {
            ipoCategory.add({
              "subCatCode": "Individual",
              "upiLimit":
                  "${ipoOrderBookModel![element].subcategorysettings![settings].maxUpiLimit}"
            });
          } else if (ipoOrderBookModel![element]
                  .subcategorysettings![settings]
                  .subCatCode ==
              "EMP") {
            ipoCategory.add({
              "subCatCode": "Employee",
              "upiLimit":
                  "${ipoOrderBookModel![element].subcategorysettings![settings].maxUpiLimit}"
            });
          } else if (ipoOrderBookModel![element]
                  .subcategorysettings![settings]
                  .subCatCode ==
              "SHA") {
            ipoCategory.add({
              "subCatCode": "Shareholder",
              "upiLimit":
                  "${ipoOrderBookModel![element].subcategorysettings![settings].maxUpiLimit}"
            });
          } else if (ipoOrderBookModel![element]
                  .subcategorysettings![settings]
                  .subCatCode ==
              "POL") {
            ipoCategory.add({
              "subCatCode": "Policyholder",
              "upiLimit":
                  "${ipoOrderBookModel![element].subcategorysettings![settings].maxUpiLimit}"
            });
          }
        }
      }
    }

    final seen = <String>{};
    ipoCategory = ipoCategory.where((map) {
      // Create a unique key string for each map
      final key = map.entries.map((e) => '${e.key}:${e.value}').join(',');
      if (seen.contains(key)) {
        return false;
      } else {
        seen.add(key);
        return true;
      }
    }).toList();
    ipoCategory.sort((a, b) => customIpoCategoryListOrder
        .indexOf(a['subCatCode'])
        .compareTo(customIpoCategoryListOrder.indexOf(b['subCatCode'])));
    ipoCategoryvalue = ipoCategory[0]["subCatCode"];
    _maxUPIAmt = double.parse(ipoCategory[0]["upiLimit"]);
    notifyListeners();
  }

  List ipoCategory = [];

  chngCategoryType(String val) async {
    for (var element in ipoCategory) {
      if (val == element['subCatCode']) {
        _maxUPIAmt = double.parse(element['upiLimit']);
      }
    }

    ipoCategoryvalue = val;
    notifyListeners();
  }

  List<DropdownMenuItem<String>> addDividerSubCategory(List numofList) {
    List<DropdownMenuItem<String>> menuItems = [];
    for (var item in numofList) {
      menuItems.addAll(
        [
          DropdownMenuItem<String>(
              value: item["subCatCode"].toString(),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(item["subCatCode"].toString()))),
          //If it's last item, we will not add Divider after it.
          if (item != numofList.last)
            DropdownMenuItem<String>(
              enabled: false,
              child: Divider(
                color: colors.colorDivider,
              ),
            ),
        ],
      );
    }
    return menuItems;
  }

  final List _ipoOrderBookTabNameBtns = [
    {"btnName": "Open Order", "imgPath": assets.dInfo},
    {"btnName": "Closed Order", "imgPath": assets.charticon},
  ];
  List get ipoOrderBookTabNameBtns => _ipoOrderBookTabNameBtns;

  String _ipoOrderBookTabNameAct = "Open Order";
  String get ipoOrderBookTabNameAct => _ipoOrderBookTabNameAct;

  chngOrderBookTabNameBtn(currentTab) {
    _ipoOrderBookTabNameAct = currentTab;
    notifyListeners();
  }

  // List<Tab> _ipoOrderBookTabs = [
  //   // const Tab(text: "Open order"),
  //   // const Tab(text: "Close order"),
  // ];
  // List<Tab> get ipoOrderBookTabs => _ipoOrderBookTabs;

  // ipotab() {
  //    _ipoOrderBookTabs= [
  //     Tab(
  //         child: Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //           Text("Open Order (${_openorder!.length})"),
  //         ])),
  //     Tab(
  //         child: Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             crossAxisAlignment: CrossAxisAlignment.center,
  //             children: [
  //           Text("Close Order  (${_closeorder!.length})"),
  //         ]))
  //   ];
  //   notifyListeners();
  // }

  ordersplit() {
    _openorder = [];
    _closeorder = [];
    _maxValue = "";
    _stringList = [];
    try {
      togglefundLoadingOn(true);

      for (var element in _ipoOrderBookModel!) {
        if (element.reponseStatus == 'new success' ||
            element.reponseStatus == 'pending') {
          _openorder!.add(element);
          // _openorder!.sort((a, b) => a.companyName!.compareTo(b.companyName!));
        } else {
          _closeorder!.add(element);
          // _closeorder!.sort((a, b) => a.companyName!.compareTo(b.companyName!));
        }
      }
      _openorder?.sort((b, a) {
        try {
          // Handle empty or null responseDatetime
          if (a.responseDatetime == null ||
              a.responseDatetime.toString().isEmpty) {
            return 1; // Put items with null/empty datetime at the end
          }
          if (b.responseDatetime == null ||
              b.responseDatetime.toString().isEmpty) {
            return -1; // Put items with null/empty datetime at the end
          }

          DateTime dateA = DateTime.parse(a.responseDatetime.toString());
          DateTime dateB = DateTime.parse(b.responseDatetime.toString());
          return dateA.compareTo(dateB); // Newest first (descending order)
        } catch (e) {
          return 0; // Keep original order if parsing fails
        }
      });
      _closeorder?.sort((b, a) {
        try {
          // Handle empty or null responseDatetime
          if (a.responseDatetime == null ||
              a.responseDatetime.toString().isEmpty) {
            return 1; // Put items with null/empty datetime at the end
          }
          if (b.responseDatetime == null ||
              b.responseDatetime.toString().isEmpty) {
            return -1; // Put items with null/empty datetime at the end
          }

          DateTime dateA = DateTime.parse(a.responseDatetime.toString());
          DateTime dateB = DateTime.parse(b.responseDatetime.toString());
          return dateA.compareTo(dateB); // Newest first (descending order)
        } catch (e) {
          return 0; // Keep original order if parsing fails
        }
      });
    } catch (e) {
    } finally {
      togglefundLoadingOn(false);
    }

    notifyListeners();
  }

  Upcoming_ipo? _upcomingModel;
  Upcoming_ipo? get upcomingModel => _upcomingModel;

//// API CALLS
  Future getipoorderbookmodel1(bool isTrue) async {
    try {
      _displayload = true;
      _ipoOrderBookModel = await api.fetchipoorderbook();
      ordersplit();
      //  print("IPO RES ORDERBOOK ::: ${_ipoOrderBookModel![0].bidDetail![0].amount}");
      notifyListeners();
      return _ipoOrderBookModel;
    } catch (e) {
    } finally {
      _displayload = false;
    }
  }

  Future getUpcomingIpoModel() async {
    try {
      // _displayload = true;
      _upcomingModel = await api.fetchIpoUpcomingApi();
      ordersplit();
      //  print("IPO RES ORDERBOOK ::: ${_ipoOrderBookModel![0].bidDetail![0].amount}");
      notifyListeners();
      return _upcomingModel;
    } catch (e) {
    } finally {
      // _displayload = false;
    }
  }

  Future getipoorderbookmodel(BuildContext context, bool isTrue) async {
    try {
      _myBidsload = true;
      _ipoOrderBookModel = await api.fetchipoorderbook();
      ordersplit();
      //  print("IPO RES ORDERBOOK ::: ${_ipoOrderBookModel![0].bidDetail![0].amount}");
      notifyListeners();
      return _ipoOrderBookModel;
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //     error(context, "Error in fetching IPO Order Book"));
      _myBidsload = false;
    } finally {
      _myBidsload = false;
    }
  }

  bool _singlepageapply = false;
  bool get singlepageapply => _singlepageapply;

  void setSinglepageapply(bool value) {
    _singlepageapply = value;
    notifyListeners();
  }

  Future<bool> fetchupiidvalidation(BuildContext context, String upiId,
      String accno, MenuData menudata, List<IposBid> iposbids, String iposupiid,
      {bool isOverlayDialog = false}) async {
    try {
      toggleIpoOrderLoading(true);
      _upiIdValidationModel = await api.getVerifyUpi(upiId, accno);
      if (_upiIdValidationModel!.data!.verifiedVPAStatus1 == "Available" ||
          _upiIdValidationModel!.data!.verifiedVPAStatus2 == "Available") {
        await getipoplaceorder(context, menudata, iposbids, iposupiid);
        getipoorderbookmodel(context, true);
        // ipotab();
        _upierror = "";
        _upivalid = false;
        setSelectedTab(2);

        // Only use Navigator.pop if not in overlay dialog
        // Overlay dialogs are closed via their callbacks
        if (!isOverlayDialog) {
          Navigator.pop(context);
          Navigator.pop(context);
          if (singlepageapply) {
            Navigator.pop(context);
          }
        }
        // Navigator.pushNamed(context, Routes.ipo, arguments: 2);
        return true;
      } else {
        _upivalid = true;
        _upierror = "Invalid UPI ID";
        showResponsiveWarning(context, 'Invalid UPI ID');
        return false;
      }

      //log("HDFC BANK $_upiIdValidationModel");
    } catch (e) {
      log("Failed to fetch bank Data:: ${e.toString()}");

      notifyListeners();
      return false;
    } finally {
      toggleIpoOrderLoading(false);
    }
  }

  Future getipoplaceorder(BuildContext context, MenuData menudata,
      List<IposBid> iposbids, String iposupiid) async {
    try {
      _ipoOrderResponcesModel =
          await api.fetchipoplaceorder(menudata, iposbids, iposupiid);
      getipoorderbookmodel(context, true);
      // ipotab();

      setSelectedTab(2); // "My Bids" tab
      showResponsiveSuccess(
          context,
          (_ipoOrderResponcesModel?.msg != null &&
                  _ipoOrderResponcesModel!.msg!.isNotEmpty)
              ? _ipoOrderResponcesModel!.msg!
              : 'Order placed successfully');

      return _ipoOrderResponcesModel;
    } catch (e) {
      notifyListeners();
    }
  }

  Future getipoperfomance(int year) async {
    try {
      toggleLoadingOn(true);
      _ipoPerformanceModel = await api.fetchipoperfomance(year);
      notifyListeners();
      return _ipoPerformanceModel;
    } catch (e) {
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future getmainstreamipo(BuildContext context, {bool showLoader = true}) async {
    try {
      if (showLoader) toggleLoadingOn(true);
      _mainStreamIpoModel = await api.fetchmainstreamoipo();
      // print("object ${_mainStreamIpoModel!.mainIPO![0].asbanonasba}");
      getipoorderbookmodel(context, true);
      notifyListeners();

      return _mainStreamIpoModel;
    } catch (e) {
    } finally {
      if (showLoader) toggleLoadingOn(false);
    }
  }

  Future getSmeIpo({bool showLoader = true}) async {
    try {
      if (showLoader) toggleLoadingOn(true);
      _smeIpoModel = await api.fetchsmeipo();

      // tabSize();
      notifyListeners();
      return _smeIpoModel;
    } catch (e) {
    } finally {
      if (showLoader) toggleLoadingOn(false);
    }
  }

  /// Combined method to fetch both SME and Mainstream IPOs with single loader
  Future fetchAllOpenIpos(BuildContext context) async {
    try {
      toggleLoadingOn(true);
      await getSmeIpo(showLoader: false);
      await getmainstreamipo(context, showLoader: false);
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future getDashboardIpos() async {
    try {
      _dashboardIpoModel = await api.fetchDashbordIposIPOS();
      log("message dbdbdb $_dashboardIpoModel");
      notifyListeners();
      return _dashboardIpoModel;
    } catch (e) {
    }
  }

  Future getIpoSinglePage({required String ipoName}) async {
    try {
      togglefundLoadingOn(true);
      _ipoSinglePage = await api.fetchiposinglepage(ipoName);
      if (iposinglepage!.scripdata != null) {
        iposinglepage!.scripdata!["IPO_Timeline"].removeLast();
      }

      // print("object :::: ${_ipoSinglePage!.data}");
      notifyListeners();
      return _ipoSinglePage;
    } catch (e) {
    } finally {
      togglefundLoadingOn(false);
    }
  }

  Future fetchIpoPreClose() async {
    try {
      // togglefundLoadingOn(true);
      _ipoPreClose = await api.fetchIpoPreCloseApi();
      // print("object :::: ${_ipoPreClose}");
      notifyListeners();
      return _ipoPreClose;
    } catch (e) {
    // } finally {
      // togglefundLoadingOn(false);
    }
  }

  sortpreCloseIPOListByDate(List<Msg> data) {
    try {
      data.sort((a, b) {
        final DateFormat dateFormat = DateFormat("MMMM d, yyyy");
        DateTime dateA = dateFormat.parse(a.listedDate.toString());
        DateTime dateB = dateFormat.parse(b.listedDate.toString());
        return dateB.compareTo(dateA);
      }); // Sort by date
    } catch (e) {}
  }

  convertDatetime(String? data) {
    try {
      final DateFormat dateFormat = DateFormat("MMMM d, yyyy");
      return dateFormat.parse(data.toString());
    } catch (e) {
      return data;
    }
  }
}

extension DateTimeExtension on DateTime? {
  bool? isAfterOrEqualTo(DateTime dateTime) {
    final date = this;
    if (date != null) {
      final isAtSameMomentAs = dateTime.isAtSameMomentAs(date);
      return isAtSameMomentAs | date.isAfter(dateTime);
    }
    return null;
  }

  bool? isBeforeOrEqualTo(DateTime dateTime) {
    final date = this;
    if (date != null) {
      final isAtSameMomentAs = dateTime.isAtSameMomentAs(date);
      return isAtSameMomentAs | date.isBefore(dateTime);
    }
    return null;
  }

  bool? isBetween(
    DateTime fromDateTime,
    DateTime toDateTime,
  ) {
    final date = this;
    if (date != null) {
      final isAfter = date.isAfterOrEqualTo(fromDateTime) ?? false;
      final isBefore = date.isBeforeOrEqualTo(toDateTime) ?? false;
      return isAfter && isBefore;
    }
    return null;
  }
}

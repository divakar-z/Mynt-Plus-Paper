import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/core/api_export.dart';
import '../locator/constant.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
// import '../models/fund_model/show_upi_model.dart';
import '../models/desk_reports_model/pledge_unpledge_model.dart';
import '../models/mf_model/mf_bank_detail_model.dart';
import '../models/profile_model/fund_detial_model.dart';
import '../models/profile_model/hs_token_model.dart';
import '../models/profile_model/option_z_model.dart';
import '../res/res.dart';
import '../routes/route_names.dart';
import '../sharedWidget/functions.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';

final fundProvider = ChangeNotifierProvider((ref) => FundProvider(ref));

class FundProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();
  FundDetailModel? _fundDetailModel;
  FundDetailModel? get fundDetailModel => _fundDetailModel;

  final TextEditingController viewupiid = TextEditingController();
  PledgeAndUnpledgeModel? _pledgeAndUnpledgeModel;
  PledgeAndUnpledgeModel? get pledgeAndUnpledgeModel => _pledgeAndUnpledgeModel;

  // ViewUpiIdModel? _viewUpiIdModel;
  // ViewUpiIdModel? get viewUpiIdModel => _viewUpiIdModel;

  final FToast _fToast = FToast();
  FToast get fToast => _fToast;
  GetHsTokenModel? _getHsTokenModel;
  final List _margin = [];
  final List _utlization = [];
  List get margin => _margin;
  List get utlization => _utlization;
  final Ref ref;

  // Derived from _fundDetailModel — no mutable list state to keep in sync.
  // Avoids the concurrent-fetch race where two in-flight fetchFunds calls
  // could each append to the same list and duplicate rows on screen.
  List get listOfCredits {
    final m = _fundDetailModel;
    if (m == null) return const [];
    final items = [];
    void addIfNonZero(String? raw, String name) {
      final v = double.tryParse(raw ?? "0.00") ?? 0;
      if (v != 0) items.add({"value": "$v", "name": name});
    }
    addIfNonZero(m.cash, "Opening Balance");
    addIfNonZero(m.payin, "Payin");
    addIfNonZero(m.payout, "Payout");
    addIfNonZero(m.brkcollamt, "Collateral");
    addIfNonZero(m.unclearedcash, "Uncleared Cash");
    addIfNonZero(m.auxDaycash, "Aux Day Cash");
    addIfNonZero(m.auxBrkcollamt, "Aux Broker collateral");
    addIfNonZero(m.auxUnclearedcash, "Aux Uncleared Cash");
    addIfNonZero(m.daycash, "Day Cash");
    addIfNonZero(m.collateral, "Collateral");
    return items;
  }

  List get listOfUsedMrgn {
    final m = _fundDetailModel;
    if (m == null) return const [];
    final items = [];
    void addIfNonZero(String? raw, String name) {
      final v = double.tryParse(raw ?? "0.00") ?? 0;
      if (v != 0) items.add({"value": "$v", "name": name});
    }
    addIfNonZero(m.span, "Span");
    addIfNonZero(m.expo, "Exposure");
    addIfNonZero(m.addmrg, "Additional Margin");
    addIfNonZero(m.premium, "Option Premium");
    addIfNonZero(m.brokerage, "Unrealized Expenses");
    final urmtom = double.tryParse(m.urmtom ?? "0.00") ?? 0;
    if (urmtom > 0) items.add({"value": "$urmtom", "name": "Unrealized MTM"});
    return items;
  }

  OptionZmodel? _optionZmodel;
  OptionZmodel? get optionZmodel => _optionZmodel;

  FundProvider(this.ref);

  GetHsTokenModel? get fundHstoken => _getHsTokenModel;

  bool _showMrgnnBreakup = false;
  bool get showMrgnBreakup => _showMrgnnBreakup;

// MF Order

  TextEditingController invAmt = TextEditingController();
  TextEditingController upiId = TextEditingController();
  String? invAmtError, upiError;

  List _paymentMethod = [];

  List get paymentMethod => _paymentMethod;

  String _paymentName = "";

  String get paymentName => _paymentName;

  String _accNum = "";

  String get accNum => _accNum;

  String _ifsc = "";

  String get ifsc => _ifsc;

  String _bankname = "";

  String get bankname => _bankname;

  List<BankData>? _bankData = [];
  List<BankData>? get bankData => _bankData;

  BankDetailsModel? _bankDetailsModel;
  UPIDetailsModel? _upiDetailsModel;
  UPIDetailsModel? get upiDetailsModel => _upiDetailsModel;
  BankDetailsModel? get bankDetailsModel => _bankDetailsModel;

  bool _isLoadingPledgeDetails = false;
  bool get isLoadingPledgeDetails => _isLoadingPledgeDetails;

  clearTxtError() {
    invAmtError = null;
    upiError = null;
    notifyListeners();
  }

  chngPayName(String val) {
    _paymentName = val;
    notifyListeners();
  }

  clearFunds() {
    _fundDetailModel = null;
    notifyListeners();
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

  Future eDis(BuildContext context) async {
    var enCodePass = utf8.encode(
        'sLoginId=${fundHstoken!.uid}&sAccountId=${fundHstoken!.actid}&prd=C&token=${fundHstoken!.hstk}&sBrokerId=ZEBU&open=edis');
    var base64Pass = base64Url.encode(enCodePass);

    await Navigator.pushNamed(context, Routes.edis, arguments: base64Pass);
    'sLoginId=${fundHstoken!.uid}&token=${fundHstoken!.hstk}';

    // launch("https://go.mynt.in/NorenEdis/NonPoaHoldings/?$base64Pass");
  }

  /// E-DIS for Web - Opens in new browser tab
  Future<void> eDisWeb() async {
    // Log the HS Token data we received
    log("===== E-DIS Web Debug Info =====");
    log("HS Token Model: ${fundHstoken != null ? 'Received' : 'NULL'}");
    if (fundHstoken != null) {
      log("HS Token UID: ${fundHstoken!.uid}");
      log("HS Token ActID: ${fundHstoken!.actid}");
      log("HS Token HSTK: ${fundHstoken!.hstk}");
      log("HS Token Stat: ${fundHstoken!.stat}");
    }

    // Construct the encoded parameters
    final String rawParams =
        'sLoginId=${fundHstoken!.uid}&sAccountId=${fundHstoken!.actid}&prd=C&token=${fundHstoken!.hstk}&sBrokerId=ZEBU&open=edis';
    log("Raw Params (before encoding): $rawParams");

    var enCodePass = utf8.encode(rawParams);
    var base64Pass = base64Url.encode(enCodePass);
    log("Base64 Encoded Params: $base64Pass");

    // Construct the final E-DIS URL
    final String edisUrl = "https://go.mynt.in/NorenEdis/NonPoaHoldings/?$base64Pass";
    log("E-DIS URL being opened: $edisUrl");
    log("================================");

    // Open in new browser tab
    final Uri uri = Uri.parse(edisUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      log("E-DIS URL launched successfully in new tab");
    } else {
      log("ERROR: Could not launch E-DIS URL");
    }
  }

  /// E-DIS for Mutual Funds Web - Opens in new browser tab
  Future<void> eDisMfWeb() async {
    log("===== MF E-DIS Web Debug Info =====");
    log("HS Token Model: ${fundHstoken != null ? 'Received' : 'NULL'}");
    if (fundHstoken != null) {
      log("HS Token UID: ${fundHstoken!.uid}");
      log("HS Token ActID: ${fundHstoken!.actid}");
      log("HS Token HSTK: ${fundHstoken!.hstk}");
      log("HS Token Stat: ${fundHstoken!.stat}");
    }

    final String rawParams =
        'sLoginId=${fundHstoken!.uid}&sAccountId=${fundHstoken!.actid}&prd=C&token=${fundHstoken!.hstk}&sBrokerId=ZEBU&open=edis';
    log("MF Raw Params (before encoding): $rawParams");

    var enCodePass = utf8.encode(rawParams);
    var base64Pass = base64.encode(enCodePass);
    log("MF Base64 Encoded Params: $base64Pass");

    final String edisUrl =
        "https://go.mynt.in/NorenMfEdis/NonPoaHoldings/?$base64Pass";
    log("MF E-DIS URL being opened: $edisUrl");
    log("================================");

    final Uri uri = Uri.parse(edisUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      log("MF E-DIS URL launched successfully in new tab");
    } else {
      log("ERROR: Could not launch MF E-DIS URL");
    }
  }

  optionZ(BuildContext context) async {
    var enCodePass = utf8.encode(
        'sLoginId=${pref.clientId}&sAccountId=${pref.clientId}&token=${fundHstoken!.hstk}&sBrokerId=ZEBU');
    var base64Pass = base64Url.encode(enCodePass);
    // Redirecting OptionZ by using HS token encryption
    await fetchOptionZ(base64Pass, context);
  }

  Future<void> openOptionZInNewTab() => openSsoInNewTab('instaoptions');

  Future<void> openSsoInNewTab(String vc) async {
    final String? hstk = fundHstoken?.hstk;
    if (hstk == null || hstk.isEmpty) {
      debugPrint("[SSO:$vc] ⛔ skipped — HS token unavailable "
          "(fundHstoken=${fundHstoken == null ? 'null' : 'present'})");
      return;
    }
    final String rawKey =
        'sLoginId=${pref.clientId}&sAccountId=${pref.clientId}&token=$hstk&sBrokerId=ZEBU';
    final String key = base64Url.encode(utf8.encode(rawKey));
    final String url = "https://be.mynt.in/SSONew/OAuthNew?vc=$vc&key=$key";

    // ---- Verification logs (browser console) ----
    // debugPrint("[SSO:$vc] clientId   = ${pref.clientId}");
    // debugPrint("[SSO:$vc] token/hstk = $hstk");
    // debugPrint("[SSO:$vc] rawKey     = $rawKey");
    // debugPrint("[SSO:$vc] base64 key = $key");
    // debugPrint("[SSO:$vc] url        = $url");

    final Uri uri = Uri.parse(url);
    final bool can = await canLaunchUrl(uri);
    if (can) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("[SSO:$vc] ❌ could not launch url");
    }
  }

  Future fetchOptionZ(String key, BuildContext context) async {
    try {
      String url = 
          "https://be.mynt.in/SSONew/OAuthNew?vc=instaoptions&key=$key";

        Navigator.pushNamed(context, Routes.optionZWebView,
            arguments: url);

    } catch (e) {
      rethrow;
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchHstoken(BuildContext context) async {
    try {
      toggleLoadingOn(true);

      final GetHsTokenModel data = await api.getHsToken();
      _getHsTokenModel = data;
      ConstantName.sessCheck = true;
      if (_getHsTokenModel!.emsg == "Session Expired :  Invalid Session Key" &&
          _getHsTokenModel!.stat == "Not_Ok") {
        ref.read(authProvider).ifSessionExpired(context);
      }
    } catch (e) {
      log("Failed to fetch Profile Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API HS Token", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchFunds(BuildContext context) async {
    try {
      _fundDetailModel = await api.getFunds();

      if (_fundDetailModel!.emsg == "Session Expired :  Invalid Session Key") {
        ref.read(authProvider).ifSessionExpired(context);
      } else {
        ConstantName.sessCheck = true;

        double parse(String? raw) => double.tryParse(raw ?? "0.00") ?? 0.00;

        final cash = parse(_fundDetailModel!.cash);
        final payin = parse(_fundDetailModel!.payin);
        final payout = parse(_fundDetailModel!.payout);
        final brkcollamt = parse(_fundDetailModel!.brkcollamt);
        final unclearedcash = parse(_fundDetailModel!.unclearedcash);
        final auxDaycash = parse(_fundDetailModel!.auxDaycash);
        final auxBrkcollamt = parse(_fundDetailModel!.auxBrkcollamt);
        final auxUnclearedcash = parse(_fundDetailModel!.auxUnclearedcash);
        final daycash = parse(_fundDetailModel!.daycash);
        final collateral = parse(_fundDetailModel!.collateral);

        fundDetailModel!.totCredit = (cash +
                payin +
                payout +
                brkcollamt +
                collateral +
                unclearedcash +
                auxDaycash +
                auxBrkcollamt +
                auxUnclearedcash +
                daycash)
            .toStringAsFixed(2);

        final utilizedMrgn = parse(fundDetailModel!.marginused);
        fundDetailModel!.utilizedMrgn = utilizedMrgn.toStringAsFixed(2);

        fundDetailModel!.avlMrg =
            (parse(fundDetailModel!.totCredit) - utilizedMrgn)
                .toStringAsFixed(2);
        final avlMrgnPer = (parse(fundDetailModel!.avlMrg) /
                parse(fundDetailModel!.totCredit)) *
            100;

        fundDetailModel!.avlMrgPercentage =
            (avlMrgnPer.isNaN ? 0.00 : avlMrgnPer).toStringAsFixed(2);
      }
      notifyListeners();

      return _fundDetailModel;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "API Funds", "Error": "$e"});
      notifyListeners();
    }
  }

  showMrgBreak() {
    _showMrgnnBreakup = !_showMrgnnBreakup;
    notifyListeners();
  }

  //  Future fetchviewupiid() async {
  //   try {
  //     toggleLoadingOn(true);
  //     _viewUpiIdModel = await api.getviewupiid();
  //     if (_viewUpiIdModel!.data!.isEmpty) {
  //       viewupiid.clear();
  //     } else {
  //       viewupiid.text = "${_viewUpiIdModel!.data![0].upiId}";
  //     }
  //     log("view upi id ${_viewUpiIdModel!.data![0].upiId}.");
  //   } catch (e) {
  //     log("Failed to fetch bank Data:: ${e.toString()}");
  //     ref.read(indexListProvider)
  //         .logError
  //         .add({"type": "View upi id", "Error": "$e"});
  //     notifyListeners();
  //   } finally {
  //     toggleLoadingOn(false);
  //   }
  // }

// Fetching data from the api and stored in a variable
  Future fetchUpiDetail() async {
    try {
      _paymentMethod = [];
      _upiDetailsModel = await api.getUPI();

      if (_upiDetailsModel!.stat == "Ok") {
        _paymentMethod.add("UPI");
      }
      notifyListeners();
    } catch (e) {
    }
  }

// Fetching data from the api and stored in a variable
  Future fetchBankDetail() async {
    upiId.text = "";
    try {
      _bankDetailsModel = await api.getBankDetail();
      _bankData = [];
      if (_bankDetailsModel!.stat == "Ok") {
        _paymentMethod.add("Net banking");
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
    }
  }

  Future fetchPledgeDetails() async {
    try {
      _isLoadingPledgeDetails = true;
      notifyListeners();

      _pledgeAndUnpledgeModel = await api.getPledgeDetails();
      // print("Pledge Details => ${_pledgeAndUnpledgeModel!.bOID}");

      _isLoadingPledgeDetails = false;
      notifyListeners();
    } catch (e) {
      _isLoadingPledgeDetails = false;
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
                    style:
                        textStyle(const Color(0xff000000), 13, 0),
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

  // Adding  dropdown items divider

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
                    Text("${item.bankName}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            textStyle(colors.colorBlack, 14, 0)),
                    const SizedBox(height: 2),
                    Text("*******${item.bankAcNo!.substring(8)}",
                        style:
                            textStyle(colors.colorGrey, 12, 0)),
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

// Validate UPI Id
  bool isValidUpiId() {
    final RegExp upiRegex =
        RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$', caseSensitive: false);
    clearTxtError();
    if (invAmt.text.isEmpty) {
      invAmtError = "Please enter Investment amount";
    } else if (upiId.text.isEmpty) {
      upiError = "Please enter UPI ID";
    } else if (!upiRegex.hasMatch(upiId.text)) {
      upiError = "Please enter valid UPI ID";
    }

    return invAmtError == null && upiError == null;
  }
}

// ignore_for_file: use_build_context_synchronously, deprecated_member_use
//import 'dart:developer';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/provider/iop_provider.dart';
import 'package:mynt_plus/screens/web/profile/fund_screen/upi_apps_screens/cancel_request_alert_box.dart';
import 'package:mynt_plus/screens/web/profile/fund_screen/upi_apps_screens/no_upi_apps_alert.dart';
import 'package:mynt_plus/screens/web/profile/fund_screen/upi_apps_screens/upi_apps_payment_failed.dart';
import 'package:mynt_plus/screens/web/profile/fund_screen/upi_id_screens/upi_id_payment_fail_or_success.dart';
import 'package:number_to_words/number_to_words.dart';
import 'package:public_ip_address/public_ip_address.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fund_model_testing_copy/indent_upi_request_model.dart';
import '../models/fund_model_testing_copy/wrapper_check_status_model.dart';
import '../models/fund_model_testing_copy/mtf_limits_model.dart';
import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../models/fund_model_testing_copy/fund_direct_payment_model.dart';
import '../models/fund_model_testing_copy/fund_pay.model.dart';
import '../models/fund_model_testing_copy/fund_payment_status_model.dart';
import '../models/fund_model_testing_copy/fund_payment_withdraw.dart';
import '../models/fund_model_testing_copy/fund_razorpay_model.dart';
import '../models/fund_model_testing_copy/fund_razorpay_status_model.dart';
import '../models/fund_model_testing_copy/fund_tranction_his_model.dart';
import '../models/fund_model_testing_copy/fund_upi_status_model.dart';
import '../models/fund_model_testing_copy/fund_validation_token.dart';
import '../models/fund_model_testing_copy/fund_withdraw_model.dart';
import '../models/fund_model_testing_copy/fund_withdraw_status_model.dart';
import '../models/fund_model_testing_copy/secured_bank_detalis_model.dart';
import '../models/mf_model/client_bank_details_model.dart';
import '../models/fund_model_testing_copy/secured_client_data_model.dart';
import '../models/fund_model_testing_copy/view_upi_id.dart';
import '../res/res.dart';

import '../sharedWidget/functions.dart';
import '../sharedWidget/fund_function.dart';
import '../sharedWidget/snack_bar.dart';
import 'auth_provider.dart';
import 'core/default_change_notifier.dart';
import 'index_list_provider.dart';
// import 'package:http/http.dart' as http;

final transcationProvider =
    ChangeNotifierProvider((ref) => TranctionProvider(ref));

class TranctionProvider extends DefaultChangeNotifier {
  final api = locator<ApiExporter>();

  TextEditingController amount = TextEditingController();
  TextEditingController upiid = TextEditingController();
  TextEditingController withdrawamount = TextEditingController();

  // TranctionHistoryModel? _tranctionHistoryModel;
  // TranctionHistoryModel? get tranctionHistoryModel => _tranctionHistoryModel;

  int _selectedIndex = -1;
  int get selectedindex => _selectedIndex;

  int _intValue = 0;
  int get intValue => _intValue;

  int _indexss = 0;
  int get indexss => _indexss;

  String _ifsc = '';
  String get ifsc => _ifsc;

  String _bankname = '';
  String get bankname => _bankname;

  String _textValue = '';
  String get textValue => _textValue;

  String _accno = '';
  String get accno => _accno;

  String _multipleAccno = '';
  String get multipleAccno => _multipleAccno;

  String _initbank = '';
  String get initbank => _initbank;

  String _textResult = "";
  String get textResult => _textResult;

  String _funderror = '';
  String get funderror => _funderror;

  String _allacc = "";

  String _maxfunderror = '';
  String get maxfunderror => _maxfunderror;

  String _ipAddress = '';
  String get ipAddress => _ipAddress;

  bool _enable = true;
  bool get enable => _enable;

  bool _upiIdbutton = true;
  bool get upiIdbutton => _upiIdbutton;

  List<String>? _urls = [];
  List<String>? get url => _urls;

  Map<String, dynamic>? _dsds = {};
  Map<String, dynamic>? get dsds => _dsds;

  upiAppsAccnoFormat(String accono) {
    List y = [accono];

    for (var i in bankdetails!.dATA!) {
      if (y.length == 4) {
        break;
      }
      if (!y.contains(i[2])) {
        y.add(i[2]);
      }
    }

    String number = y.join("!");
    _multipleAccno = number;
    // print("DDDDDDDDDDD $number");
  }

  bankselection(int index) {
    _initbank =
        '${bankdetails!.dATA![index][1]}-${hideAccountNumber(bankdetails!.dATA![index][2])}';

    _accno = bankdetails!.dATA![index][2];
    upiAppsAccnoFormat(_accno);
    _ifsc = bankdetails!.dATA![index][3];
    _bankname = bankdetails!.dATA![index][1];

    notifyListeners();
  }

  segmentselection(int index) {
    final codes = decryptclientcheck?.companyCode;
    if (codes == null || index < 0 || index >= codes.length) return;
    _textValue = codes[index];
    notifyListeners();
  }

  changeIndex(int value) {
    _selectedIndex = value;
    notifyListeners();
  }

  changebool(bool value) {
    _enable = value;
    notifyListeners();
  }

  textFiledonChange(String value) {
    _selectedIndex = 0;
    if (amount.text.isNotEmpty) {
      var val = int.parse(value);
      _intValue = val;

      if (_intValue < 50) {
        _funderror = "Min amount ₹50";
      } else if (_intValue > 100000) {
        _selectedIndex = 2;
      }
      if (_intValue > 5000000) {
        _maxfunderror = "Max amount ₹5,000,000";
      }
    }

    int number = int.tryParse(value) ?? 0;
    String result = NumberToWord().convert('en-in', number);
    _textResult = capitalizeFirstLetter(result);
    notifyListeners();
  }

  FocusNode _focusNode = FocusNode();
  FocusNode get focusNode => _focusNode;

  List<String> _companycode = [];
  List<String> get companycodes => _companycode;

  RegExp _upiPattern = RegExp(r'^[\w.-]+@[\w.-]+$');
  RegExp get upiPattern => _upiPattern;

  // Replace single bottom sheet flag with two separate flags
  bool _isUpiAppsBottomSheetShown = false;
  bool get isUpiAppsBottomSheetShown => _isUpiAppsBottomSheetShown;

  bool _isUpiIdBottomSheetShown = false;
  bool get isUpiIdBottomSheetShown => _isUpiIdBottomSheetShown;

  final List _defaultUpiapps = [
    {'name': 'Scan QR', 'image': assets.upiIcon1, 'limit': '1,00,000'},
    {'name': 'UPI ID', 'image': assets.upiIcon1, 'limit': '1,00,000'},
    {
      'name': 'NET BANKING',
      'image': assets.netbankingIcon,
      'limit': '5,000,000'
    },
  ];
  List get defaultUpiapps => _defaultUpiapps;

  final List _addfundIcons = [
    {
      'image': assets.upiIcon,
    },
    {
      'image': assets.upiIcon,
    },
    {
      'image': assets.netbankingIcon,
    },
  ];
  List get addfundIcons => _addfundIcons;

  upiidOnchange(String value) {
    // upiid.text = value;
    notifyListeners();
  }

  ip() async {
    try {
      toggleLoadingOn(true);
      String ip = await IpAddress().getIp();
      _ipAddress = ip;
      return _ipAddress;
    } finally {
      toggleLoadingOn(false);
    }
  }

  initialdata(BuildContext contex) {
    // Reset form state
    _intValue = 0;
    _funderror = '';
    _maxfunderror = '';
    amount.clear();
    // upiid.clear();

    // Reset other form-related states
    _selectedIndex = -1;
    _upiIdbutton = true;
    upiiderror = null;
    amounterror = null;

    // Reset bottom sheet state
    _isUpiAppsBottomSheetShown = false;
    _isUpiIdBottomSheetShown = false;

    // Guard against missing/empty bank and client data
    final data = bankdetails?.dATA;
    if (data == null || data.isEmpty) return;
    final safeIndex = index >= 0 && index < data.length ? index : 0;
    final safeIndexss = indexss >= 0 && indexss < data.length ? indexss : 0;

    // Initialize bank and account data
    _multipleAccno = _accno = data[safeIndex][2];
    _ifsc = data[safeIndexss][3];
    _bankname = data[safeIndexss][1];
    upiAppsAccnoFormat(data[safeIndexss][2]);
    _initbank =
        '${data[safeIndexss][1]} - ${hideAccountNumber(accno)}';

    final codes = decryptclientcheck?.companyCode;
    if (codes == null || codes.isEmpty) return;
    _textValue = codes[0];
    _companycode = codes;
    setAccountslist(_accno);
    if (_companycode.contains("NSE_FNO")) {
      _textValue = "NSE_FNO";
    } else if (_companycode.contains("NSE_CASH")) {
      _textValue = "NSE_CASH";
    } else if (_companycode.contains("MCX")) {
      _textValue = "MCX";
    } else if (_companycode.isNotEmpty) {
      _textValue = _companycode[0];
    } else {
      _textValue = '';
    }
  }

  bool get hasActiveSegments =>
      (decryptclientcheck?.companyCode?.isNotEmpty ?? false);

  changeValue(bool value, BuildContext context, {bool isUpiApps = true}) {
    if (isUpiApps) {
      _isUpiAppsBottomSheetShown = value;
    } else {
      _isUpiIdBottomSheetShown = value;
    }
    Navigator.pop(context);
    notifyListeners();
  }

  void resetBankDetails() {
    _accno = '';
    _bankname = '';
    _ifsc = '';
    _initbank = '';
    _multipleAccno = '';
    _indexss = 0;
    _bankdetails = null;
    _clientBankDetails = null;
    _decryptclientcheck = null;
    notifyListeners();
  }

  // Reset bottom sheet state when starting a new payment process
  void resetBottomSheetState() {
    _isUpiAppsBottomSheetShown = false;
    _isUpiIdBottomSheetShown = false;
    _upiCollectResponse = null;
    stopUpiCollectStatusPolling();
    notifyListeners();
  }

  String? amounterror, upiiderror;

  clearerror() {
    upiiderror = null;
    amounterror = null;
    notifyListeners();
  }

  validateUPI(String value) {
    // upiid.text = value;
    if (upiid.text.isEmpty) {
      upiiderror = 'Please enter a UPI ID';
    } else if (!_upiPattern.hasMatch(upiid.text)) {
      upiiderror = 'Please enter a valid UPI ID';
    } else {
      _upiIdbutton = false;
      upiiderror = null;
      upiiderror = "";
    }
    notifyListeners();
    return upiiderror == null && _upiIdbutton == false;
  }

  int index = 0;

  List<ViewUpiIdModel>? _viewUpiIdModel;
  List<ViewUpiIdModel>? get viewUpiIdModel => _viewUpiIdModel;

  DecryptClientCheck? _decryptclientcheck;
  DecryptClientCheck? get decryptclientcheck => _decryptclientcheck;

  PayoutDetails? _payoutdetails;
  PayoutDetails? get payoutdetails => _payoutdetails;

  HdfcPaymentModel? _hdfcpaymentdata;
  HdfcPaymentModel? get hdfcpaymentdata => _hdfcpaymentdata;

  HdfcTranctionModel? _hdfctranction;
  HdfcTranctionModel? get hdfctranction => _hdfctranction;

  HdfcPaymentStatus? _hdfcpaymentstatus;
  HdfcPaymentStatus? get hdfcpaymentstatus => _hdfcpaymentstatus;

  List<UpiId>? _upiid;
  List<UpiId>? get upiId => _upiid;

  List<WithdrawStatus>? _withdrawstatus = [];
  List<WithdrawStatus>? get withdrawstatus => _withdrawstatus;

  PaymentWithdraw? _paymentWithdraw;
  PaymentWithdraw? get paymentWithdraw => _paymentWithdraw;

  HdfcDirectPayment? _hdfcdirectpayment;
  HdfcDirectPayment? get hdfcdirectpayment => _hdfcdirectpayment;

  BankDetails? _bankdetails;
  BankDetails? get bankdetails => _bankdetails;

  ClientBankDetailsResponse? _clientBankDetails;
  ClientBankDetailsResponse? get clientBankDetails => _clientBankDetails;
  List<ClientBankDetail> get clientBankList => _clientBankDetails?.data ?? [];

  Razorpays? _razorpay;
  Razorpays? get razorpay => _razorpay;

  Map<String, dynamic>? _razorpayOptions;
  Map<String, dynamic>? get razorpayOptions => _razorpayOptions;

  RazorpayTranstationRes? _razorpayTranstationRes;
  RazorpayTranstationRes? get razorpayTranstationRes => _razorpayTranstationRes;

  HdfcUPIStatus? _hdfcUPIStatus;
  HdfcUPIStatus? get hdfcUPIStatus => _hdfcUPIStatus;

  IndentUpiResponse? _upiCollectResponse;
  IndentUpiResponse? get upiCollectResponse => _upiCollectResponse;

  FundTokenValidation? _fundTokenValidation;
  FundTokenValidation? get fundTokenValidation => _fundTokenValidation;

  final Ref ref;

  TranctionProvider(this.ref);

  redirectToUPI() async {
    String url = '${_hdfcdirectpayment!.data!.upilink}';
    await launch(url);
    notifyListeners();
  }

  Future fetchValidateToken(BuildContext context) async {
    try {
      togglefundLoading(true);

      _fundTokenValidation = await api.getFundvalidateSession();
      if (_fundTokenValidation!.emsg == "invalid token") {
        ref.read(authProvider).ifSessionExpired(context);
        notifyListeners();
      }
      notifyListeners();
      //  print("------------ ${_fundTokenValidation!.msg}}");
    } catch (e) {
      //  log("validate session:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchValidateToken", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchUpiPaymentstatus(
    BuildContext context,
    String orderNo,
    String upiTranID,
  ) async {
    //final localstorage = await SharedPreferences.getInstance();
    try {
      if (!context.mounted) {
        return false;
      }
      togglefundLoading(true);
      _hdfcUPIStatus = await api.getHdfcUPIStatus(orderNo, upiTranID);
      if (!context.mounted) {
        return false;
      }
      if (hdfcUPIStatus?.data?.status == "FAILED" ||
          hdfcUPIStatus?.data?.status == "REJECTED" ||
          hdfcUPIStatus?.data?.status == "SUCCESS") {
        if (!_isUpiAppsBottomSheetShown) {
          _isUpiAppsBottomSheetShown = true;
          if (context.mounted) {
            showModalBottomSheet(
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                backgroundColor: const Color(0xffffffff),
                isDismissible: false,
                enableDrag: false,
                showDragHandle: false,
                useSafeArea: false,
                isScrollControlled: true,
                context: context,
                builder: (BuildContext context) {
                  return PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, result) async {
                        if (didPop) return;
                      },
                      child: const UPIAppsPaymentSuccessAlert());
                }).whenComplete(() {
              _isUpiAppsBottomSheetShown = false;
            });
          }
        }
        return false;
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ref
            .read(indexListProvider)
            .logError
            .add({"type": "fetchUpiPaymentstatus", "Error": "$e"});
        notifyListeners();
      }
      return true;
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchc(BuildContext context) async {
    //final localstorage = await SharedPreferences.getInstance();
    try {
      toggleLoadingOn(true);

      _decryptclientcheck = await api.getClientDetails();

      // print("client emsg ${_decryptclientcheck!.emsg}");
      //   print("------------ ${_decryptclientcheck!.companyCode!}");
    } catch (e) {
      //log("Failed to fetch Profile Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchclient", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future fetchcwithdraw(BuildContext context) async {
    //final localstorage = await SharedPreferences.getInstance();
    try {
      toggleLoadingOn(true);

      _payoutdetails = await api.getWithdrawPayout(context);

      fetchPaymentWithDrawStatus(context);
      double marg = 0;
      double reqs = 0;

      double ledger =
          double.tryParse(_payoutdetails!.totalLedger.toString()) ?? 0;

      double brkColl =
          double.tryParse(_payoutdetails!.brkcollamt.toString()) ?? 0;
      double collateral =
          double.tryParse(_payoutdetails!.collateral.toString()) ?? 0;
      double margin = double.tryParse(_payoutdetails!.margin.toString()) ?? 0;
      double fd = double.tryParse(_payoutdetails!.fD.toString()) ?? 0;

      if (ledger > 0) {
        marg = brkColl > 0
            ? brkColl - margin
            : collateral > 0
                ? collateral - margin
                : 0;

        if (marg <= 0 && fd > 0) {
          reqs = marg + fd;
        }
        if (reqs <= 0) {
          reqs = reqs + ledger;
        }
      }

      _payoutdetails!.withdrawAmount = (margin > 0 && (reqs > 0 || marg > 0))
          ? ((reqs > 0 ? reqs : ledger)).toStringAsFixed(2)
          : (double.tryParse(_payoutdetails!.withdrawAmount.toString()) ?? 0)
              .toStringAsFixed(2);

      //  print("------------ ${ApiLinks.token}");

      // print("WITHDRAW PAYOUT ${_payoutdetails!.withdrawAmount}.");
      // print("WITHDRAW PAYOUT ${_payoutdetails!.cash}.");
    } catch (e) {
      // log("Failed to Get Payout Detial:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchcwithdraw", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future fetchfundbank(BuildContext context) async {
    try {
      toggleLoadingOn(true);
      _clientBankDetails = await api.getAllClientBankDetails();
      if (_clientBankDetails?.stat == "Ok" &&
          _clientBankDetails!.data != null &&
          _clientBankDetails!.data!.isNotEmpty) {
        // Auto-select default bank or first bank
        final defaultIndex = _clientBankDetails!.data!
            .indexWhere((b) => b.defaultBankFlag == "Y");
        selectClientBank(defaultIndex >= 0 ? defaultIndex : 0);
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchfundbank", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

 Future fetchfundbanks(BuildContext context) async {
    try {
      toggleLoadingOn(true);
      _bankdetails = await api.getbankDetails();
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchfundbanks", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  void selectClientBank(int index) {
    if (_clientBankDetails?.data == null ||
        index >= _clientBankDetails!.data!.length) return;
    final bank = _clientBankDetails!.data![index];
    _bankname = bank.bankName ?? '';
    _accno = bank.accountNo ?? '';
    _ifsc = bank.ifscCode ?? '';
    _initbank = '$_bankname-${hideAccountNumber(_accno)}';
    upiAppsAccnoFormat(_accno);
    _setClientAccountsList(_accno);
    notifyListeners();
  }

  void _setClientAccountsList(String accno) {
    List<AccountItem> items = [];
    for (var bank in _clientBankDetails?.data ?? []) {
      if (accno != bank.accountNo) {
        items.add(AccountItem(
            accno: bank.accountNo ?? '', ifsc: bank.ifscCode ?? ''));
      }
    }
    _allacc =
        "$accno${items.isNotEmpty ? '!' : ''}${getFormattedAccountNumbers(items)}";
  }

  Future fetcUPIIDPayment(
      BuildContext context, String upiId, String clientId, String accno) async {
    try {
      togglefundLoading(true);
      _hdfcpaymentdata =
          await api.getUPIIDPayment(upiId, clientId, accno, _bankname);

// print("bankname()*(*):: ${bankdetails!.dATA![indexss][1]}");
      if (hdfcpaymentdata!.data!.verifiedVPAStatus1 == "Not Available" ||
          hdfcpaymentdata!.data!.verifiedVPAStatus2 == "Not Available") {
        upiiderror = 'UPI ID is Invaild';
        notifyListeners();

        return; // Stop the flow if UPI ID is invalid
      }
    } catch (e) {
      //log("Failed to fetch bank Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetcUPIIDPayment", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchHdfctranction(
    BuildContext context,
    String upiId,
    int amount,
    String accno,
    String clientId,
  ) async {
    try {
      togglefundLoading(true);
      if (hdfcpaymentdata!.data!.verifiedVPAStatus1 == "Available" ||
          hdfcpaymentdata!.data!.verifiedVPAStatus2 == "Available") {
        _hdfctranction =
            await api.getHdfcTranction(upiId, amount, _allacc, clientId);
      }
      //print("HDFC BANK ${hdfcpaymentdata!.data!.clientVPA![0]}");
    } catch (e) {
      //log("Failed to fetch bank Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchHdfctranction", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchUPIPaymet(BuildContext context, String amt, String bankaccno,
      String clientid, String name) async {
    try {
      togglefundLoading(true);
      _hdfcdirectpayment =
          await api.getUPIAppsPayment(amt, _allacc, clientid, name);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
      } else {
        if (_fundTokenValidation?.emsg == "invalid token") {
        } else {
          checkAndLaunchUrl("${_hdfcdirectpayment!.data!.upilink}", context);
        }
      }
    } catch (e) {
      //log("Failed to fetch bank Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchUPIPaymet", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  // --- QR Payment (Scan QR) ---
  IndentUpiResponse? _indentUpiResponse;
  IndentUpiResponse? get indentUpiResponse => _indentUpiResponse;

  WrapperCheckStatusResponse? _qrCheckStatusResponse;
  WrapperCheckStatusResponse? get qrCheckStatusResponse => _qrCheckStatusResponse;

  String? _qrCodeUrl;
  String? get qrCodeUrl => _qrCodeUrl;

  bool _qrPaymentLoading = false;
  bool get qrPaymentLoading => _qrPaymentLoading;

  bool _qrPolling = false;
  bool get qrPolling => _qrPolling;

  Timer? _qrPollTimer;

  Future<bool> fetchIndentUpiRequest(BuildContext context) async {
    try {
      _qrPaymentLoading = true;
      notifyListeners();

      final clientData = _decryptclientcheck!.clientCheck!.dATA![_indexss];
      final clientCode = clientData[0];
      final clientName = clientData[2];
      final clientEmail = clientData[4];
      final clientMobile = clientData[5];

      _indentUpiResponse = await api.indentUpiRequest(
        name: clientName,
        email: clientEmail,
        mobile: clientMobile,
        bankName: _bankname,
        seg: _textValue,
        code: clientCode,
        custAcc: _accno,
        bankIfsc: _ifsc,
        amt: "${amount.text}.00",
      );

      if (_indentUpiResponse?.data?.status == "INITIATED" &&
          _indentUpiResponse?.data?.upilink != null) {
        _qrCodeUrl = api.buildQrCodeUrl(
          orderNumber: _indentUpiResponse!.data!.upiTransactionNo!,
          paidToVPA: _indentUpiResponse!.data!.paidToVPA!,
          amount: _indentUpiResponse!.data!.amount!,
          code: clientCode,
          gateway: _indentUpiResponse!.gateway ?? 'HDFC',
        );
        notifyListeners();
        return true;
      } else {
        notifyListeners();
        return false;
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchIndentUpiRequest", "Error": "$e"});
      notifyListeners();
      return false;
    } finally {
      _qrPaymentLoading = false;
      notifyListeners();
    }
  }

  /// Initiate UPI Collect Request (UPI ID payment flow via wrapper)
  Future<bool> fetchUpiCollectRequest(BuildContext context) async {
    try {
      togglefundLoading(true);

      final clientData = _decryptclientcheck!.clientCheck!.dATA![_indexss];
      final clientCode = clientData[0];
      final clientName = clientData[2];
      final clientEmail = clientData[4];
      final clientMobile = clientData[5];

      _upiCollectResponse = await api.upiCollectRequest(
        name: clientName,
        email: clientEmail,
        mobile: clientMobile,
        bankName: _bankname,
        seg: _textValue,
        code: clientCode,
        custAcc: _allacc,
        bankIfsc: _ifsc,
        amt: "${amount.text}.00",
        upi: upiid.text,
      );

      if (_upiCollectResponse?.data?.status == "INITIATED") {
        notifyListeners();
        return true;
      } else {
        notifyListeners();
        return false;
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchUpiCollectRequest", "Error": "$e"});
      notifyListeners();
      return false;
    } finally {
      togglefundLoading(false);
    }
  }

  /// Poll UPI collect payment status via wrapper check_status
  Timer? _upiCollectPollTimer;
  bool _upiCollectPolling = false;

  void startUpiCollectStatusPolling(BuildContext context, {Function(String status)? onStatusUpdate}) {
    _upiCollectPolling = true;
    notifyListeners();

    _upiCollectPollTimer?.cancel();
    _upiCollectPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_upiCollectPolling) {
        timer.cancel();
        return;
      }
      try {
        final response = await api.wrapperCheckStatus(
          orderNo: _upiCollectResponse!.data!.orderNumber!,
          upiTranID: _upiCollectResponse!.data!.upiTransactionNo!,
          clientID: _decryptclientcheck!.clientCheck!.dATA![_indexss][0],
          gateway: _upiCollectResponse!.gateway ?? 'HDFC',
        );

        final status = response.data?.status ?? '';

        if (status == "SUCCESS" || status == "FAILED" || status == "REJECTED" || status == "EXPIRED") {
          _qrCheckStatusResponse = response;
          _upiCollectPolling = false;
          timer.cancel();
          notifyListeners();
          onStatusUpdate?.call(status);
        } else if (status == "FAILURE" || status == "PENDING FROM BANK" || status == "NODATA" || status == "PENDING") {
          // Continue polling
        } else {
          _qrCheckStatusResponse = response;
          _upiCollectPolling = false;
          timer.cancel();
          notifyListeners();
          onStatusUpdate?.call(status);
        }
      } catch (e) {
        // Continue polling on error
      }
    });
  }

  void stopUpiCollectStatusPolling() {
    _upiCollectPolling = false;
    _upiCollectPollTimer?.cancel();
    _upiCollectPollTimer = null;
    notifyListeners();
  }

  Future<WrapperCheckStatusResponse?> checkUpiCollectStatusOnce() async {
    try {
      final response = await api.wrapperCheckStatus(
        orderNo: _upiCollectResponse!.data!.orderNumber!,
        upiTranID: _upiCollectResponse!.data!.upiTransactionNo!,
        clientID: _decryptclientcheck!.clientCheck!.dATA![_indexss][0],
        gateway: _upiCollectResponse!.gateway ?? '',
      );
      notifyListeners();
      return response;
    } catch (e) {
      return null;
    }
  }

  void startQrStatusPolling(BuildContext context, {Function(String status)? onStatusUpdate}) {
    _qrPolling = true;
    notifyListeners();

    _qrPollTimer?.cancel();
    _qrPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_qrPolling) {
        timer.cancel();
        return;
      }
      try {
        _qrCheckStatusResponse = await api.wrapperCheckStatus(
          orderNo: _indentUpiResponse!.data!.orderNumber!,
          upiTranID: _indentUpiResponse!.data!.upiTransactionNo!,
          clientID: _decryptclientcheck!.clientCheck!.dATA![_indexss][0],
          gateway: _indentUpiResponse!.gateway ?? 'HDFC',
        );

        final status = _qrCheckStatusResponse?.data?.status ?? '';

        if (status == "SUCCESS" || status == "FAILED" || status == "REJECTED" || status == "EXPIRED") {
          stopQrStatusPolling();
          onStatusUpdate?.call(status);
        }
        notifyListeners();
      } catch (e) {
        // Keep polling on error
      }
    });
  }

  void clearPaymentResult() {
    _razorpayTranstationRes = null;
    _qrCheckStatusResponse = null;
    notifyListeners();
  }

  void stopQrStatusPolling() {
    _qrPolling = false;
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
    notifyListeners();
  }

  Future<WrapperCheckStatusResponse?> checkQrStatusOnce() async {
    try {
      _qrCheckStatusResponse = await api.wrapperCheckStatus(
        orderNo: _indentUpiResponse!.data!.orderNumber!,
        upiTranID: _indentUpiResponse!.data!.upiTransactionNo!,
        clientID: _decryptclientcheck!.clientCheck!.dATA![_indexss][0],
        gateway: _indentUpiResponse!.gateway ?? 'HDFC',
      );
      notifyListeners();
      return _qrCheckStatusResponse;
    } catch (e) {
      return null;
    }
  }
  // --- End QR Payment ---

  // --- MTF Transfer ---
  MtfLimitsResponse? _mtfLimits;
  MtfLimitsResponse? get mtfLimits => _mtfLimits;

  MtfLimitsMTFResponse? _mtfLimitsMTF;
  MtfLimitsMTFResponse? get mtfLimitsMTF => _mtfLimitsMTF;

  bool _mtfLoading = false;
  bool get mtfLoading => _mtfLoading;

  bool _mtfTransferLoading = false;
  bool get mtfTransferLoading => _mtfTransferLoading;

  bool? _mtfActive;
  bool? get mtfActive => _mtfActive;

  Future<void> fetchMtfLimits() async {
    try {
      _mtfLoading = true;
      notifyListeners();

      final clientId = _decryptclientcheck!.clientCheck!.dATA![_indexss][0];
      _mtfLimits = await api.getAllLimits(clientId);

      if (_mtfLimits?.stat == 'Ok') {
        _mtfLimitsMTF = await api.getAllLimitsMTF(clientId);
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchMtfLimits", "Error": "$e"});
    } finally {
      _mtfLoading = false;
      notifyListeners();
    }
  }

  Future<MtfFundTransferResponse?> submitMtfTransfer(String amount) async {
    try {
      _mtfTransferLoading = true;
      notifyListeners();

      final actId = _mtfLimits?.actid ??
          _decryptclientcheck!.clientCheck!.dATA![_indexss][0];
      final result = await api.fundTransferMTF(actId, amount);
      if (result.pymtStatus == 'OK') {
        // Refresh limits after successful transfer
        await fetchMtfLimits();
      }
      return result;
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "submitMtfTransfer", "Error": "$e"});
      return null;
    } finally {
      _mtfTransferLoading = false;
      notifyListeners();
    }
  }

  double get mtfTotalAmount {
    if (_mtfLimits == null) return 0.0;
    final cash = double.tryParse(_mtfLimits!.cash ?? '0') ?? 0;
    final payin = double.tryParse(_mtfLimits!.payin ?? '0') ?? 0;
    final payout = double.tryParse(_mtfLimits!.payout ?? '0') ?? 0;
    final marginused = double.tryParse(_mtfLimits!.marginused ?? '0') ?? 0;
    final total = (cash + payin - payout.abs()) - marginused.abs();
    return total;
  }

  double get mtfAmount {
    return double.tryParse(_mtfLimitsMTF?.cash ?? '0') ?? 0;
  }

  void checkMtfStatus() {
    _mtfActive = _decryptclientcheck?.mtfStatus == true;
    notifyListeners();
  }
  // --- End MTF Transfer ---

  setAccountslist(String accno) {
    List<AccountItem> items = [];
    for (var i = 0; i < _bankdetails!.dATA!.length; i++) {
      if (accno != _bankdetails?.dATA?[i][2]) {
        items.add(AccountItem(
            accno: _bankdetails?.dATA?[i][2], ifsc: _bankdetails?.dATA?[i][3]));
      }
    }
    _allacc =
        "$accno${items.isNotEmpty ? '!' : ''}${getFormattedAccountNumbers(items)}";
  }

  String setAccountis(AccountItem item) {
    String selectedAccNo = item.accno;
    if (item.ifsc.startsWith("SBIN") || item.ifsc.startsWith("CBIN")) {
      int bankcount = selectedAccNo.length;
      if (bankcount <= 17) {
        int remaining = 17 - bankcount;
        String paddedAccountNumber = '0' * remaining + selectedAccNo;
        selectedAccNo = paddedAccountNumber;
      }
    }
    return selectedAccNo;
  }

  String getFormattedAccountNumbers(List<AccountItem> items) {
    List<String> selectedAccounts = items.take(3).map(setAccountis).toList();
    return selectedAccounts.join("!");
  }

  Future<void> checkAndLaunchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // Only show bottom sheet if it hasn't been shown yet
      if (!_isUpiIdBottomSheetShown) {
        _isUpiIdBottomSheetShown = true;

        // Final check before showing bottom sheet
        if (context.mounted) {
          showModalBottomSheet(
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              backgroundColor: const Color(0xffffffff),
              isDismissible: false,
              enableDrag: false,
              showDragHandle: false,
              useSafeArea: false,
              isScrollControlled: true,
              context: context,
              builder: (BuildContext context) {
                return PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) async {
                      if (didPop) return;
                    },
                    child: const PaymentCancelAlert());
              });
        }
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Only show bottom sheet if it hasn't been shown yet
      if (!_isUpiIdBottomSheetShown) {
        _isUpiIdBottomSheetShown = true;

        // Final check before showing bottom sheet
        if (context.mounted) {
          showModalBottomSheet(
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16))),
              backgroundColor: const Color(0xffffffff),
              context: context,
              builder: (BuildContext context) {
                return const NoUPIAppsAlert();
              });
        }
      }
    }
  }

  Future<bool> fetchHdfcpaymetstatus(
      BuildContext context, String ordno, String upiTransid) async {
    try {
      if (!context.mounted) {
        return false;
      }
      togglefundLoading(true);
      _hdfcpaymentstatus = await api.getHdfcPaymentstatus(ordno, upiTransid);
      if (!context.mounted) {
        return false;
      }
      if (hdfcpaymentstatus?.upiId?.status == "EXPIRED" ||
          hdfcpaymentstatus?.upiId?.status == "REJECTED" ||
          hdfcpaymentstatus?.upiId?.status == "SUCCESS" ||
          hdfcpaymentstatus?.upiId?.status == "FAILED") {
        if (!_isUpiIdBottomSheetShown) {
          _isUpiIdBottomSheetShown = true;
          if (context.mounted) {
            showModalBottomSheet(
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                backgroundColor: Colors.transparent,
                isDismissible: false,
                enableDrag: false,
                showDragHandle: false,
                useSafeArea: false,
                isScrollControlled: true,
                context: context,
                builder: (BuildContext context) {
                  return PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, result) async {
                        if (didPop) return;
                      },
                      child:
                          Container(child: const UpiIdSucessorFaliureScreen()));
                }).whenComplete(() {
              _isUpiIdBottomSheetShown = false;
            });
          }
        }
        return false;
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ref
            .read(indexListProvider)
            .logError
            .add({"type": "fetchHdfcpaymetstatus", "Error": "$e"});
        notifyListeners();
      }
      return true;
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchrazorpay(
    BuildContext context,
    String amt,
    String accno,
    String name,
    String ifsc,
    Razorpay? razorpay, // Make nullable for web
  ) async {
    try {
      togglefundLoading(true);
      _razorpayOptions = null;
      _razorpay = await api.getrazorpay(amt, accno, name, ifsc);
      if (_razorpay?.status == "created") {
        _razorpayOptions = {
          'key': 'rzp_live_M3tazzVCcFf8Iq',
          'amount': int.parse("${_razorpay!.amount}").toString(),
          'name': 'Zebu Fund',
          'currency': 'INR',
          'order_id': _razorpay!.id,
          'image': "https://zebuetrade.com/wp-content/uploads/2020/07/logo.png",
          'description':
              "Fund add to ${_decryptclientcheck!.clientCheck!.dATA![_indexss][0]}",
          'send_sms_hash': true,
          'prefill': {
            'name': _decryptclientcheck!.clientCheck!.dATA![_indexss][2],
            'email': _decryptclientcheck!.clientCheck!.dATA![_indexss][4],
            'contact': _decryptclientcheck!.clientCheck!.dATA![_indexss][5],
            'method': 'netbanking',
            'bank': _bankname,
          },
          'notes': {
            'clientcode':
                "${_decryptclientcheck!.clientCheck!.dATA![_indexss][0]}",
            'acc_no': _accno,
            'ifsc': _ifsc,
            'bankname': _bankname,
            'company_code': _textValue,
          },
          'theme': {
            'color': "#3399cc",
          },
          'retry': {
            'enabled': false,
            'max_count': 0,
          },
        };
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e, stackTrace) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "RAZORPAY", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchrazorpayStatus(String paymentid) async {
    _razorpayTranstationRes = null;
    try {
      togglefundLoading(true);
      _razorpayTranstationRes = await api.getrazorpayStatus(paymentid);
    } catch (e, stackTrace) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchrazorpayStatus", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchupiIdView(String bankname, String accountnumber) async {
    try {
      toggleLoadingOn(true);

      _viewUpiIdModel = await api.getUpiId(bankname, accountnumber);
      amount.clear();
      if (_viewUpiIdModel!.isNotEmpty) {
        upiid.text = "${_viewUpiIdModel![0].upiId}";
        ref.read(ipoProvide).viewupiid.text = "${_viewUpiIdModel![0].upiId}";
      } else {
        upiid.clear();
      }
    } catch (e) {
      //log("Failed to fetch bank Data:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchupiIdView", "Error": "$e"});
      notifyListeners();
    } finally {
      toggleLoadingOn(false);
    }
  }

  Future fetchPaymentWithDraw(
      String ip, String amount, String segment, BuildContext context) async {
    try {
      togglefundLoading(true);
      _paymentWithdraw = await api.getpayemntwithdraw(ip, amount, segment);
      if (_paymentWithdraw!.msg == "Sucess") {
            successMessage(context, 'Withdrawal request sent successfully');
        withdrawamount.clear();
        fetchPaymentWithDrawStatus(context);
      } else {
        warningMessage(
            context, 'Withdrawal failed: ${_paymentWithdraw!.msg}');
      }
    } catch (e) {
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchPaymentWithDraw", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }

  Future fetchPaymentWithDrawStatus(BuildContext context) async {
    try {
      togglefundLoading(true);

      _withdrawstatus = await api.getWithDrawStatus();
      //print("${_withdrawstatus?[0].eNTRYTIME}");
      // print("${_withdrawstatus?[0].msg}");
    } catch (e) {
      //log("Failed to Payment withdraw:: ${e.toString()}");
      ref
          .read(indexListProvider)
          .logError
          .add({"type": "fetchPaymentWithDrawStatus", "Error": "$e"});
      notifyListeners();
    } finally {
      togglefundLoading(false);
    }
  }
}

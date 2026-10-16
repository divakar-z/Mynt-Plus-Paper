import '../../models/bonds_model/place_order_response_model.dart';
import '../../models/desk_reports_model/placeorder_response_model.dart';
import '../../models/fund_model_testing_copy/fund_direct_payment_model.dart';
import '../../models/fund_model_testing_copy/fund_pay.model.dart';
import '../../models/fund_model_testing_copy/fund_payment_withdraw.dart';
import '../../models/fund_model_testing_copy/fund_razorpay_model.dart';
import '../../models/fund_model_testing_copy/indent_upi_request_model.dart';
import '../../models/fund_model_testing_copy/mtf_limits_model.dart';
import '../../models/fund_model_testing_copy/view_upi_id.dart';
import '../../models/ipo_model/ipo_order_res_model.dart';
import '../../models/ipo_model/ipo_place_order_model.dart';
import '../../models/mf_model/mf_create_mandate.dart';
import '../../models/mf_model/mf_lumpsum_order.dart';
import '../../models/mf_model/mf_x_sip_order_responces.dart';
import '../../models/mf_model/redemption_model.dart';
import '../../models/mf_model/upi_respose_model.dart';
import '../../models/mf_model/x_sip_cancel_order_model.dart';
import '../../models/order_book_model/modify_sip_model.dart';
import '../../models/order_book_model/place_gtt_order.dart';
import '../../models/order_book_model/sip_order_book.dart';
import '../../models/order_book_model/sip_order_cancel.dart';
import '../../models/order_book_model/sip_place_order.dart';
import '../core/api_export.dart';

/// Thrown when a live-only action is attempted while in paper trading mode.
class PaperTradingUnsupportedException implements Exception {
  final String action;
  PaperTradingUnsupportedException(this.action);

  @override
  String toString() => '$action is not available in paper trading mode.';
}

/// Safety net for paper trading mode.
///
/// Every ApiExporter call that places, modifies or cancels a real order, or
/// moves real money, and is NOT simulated by the paper engine is overridden
/// here to fail before any network request is made. The real API methods
/// already rethrow on failure, so callers handle this exactly like a failed
/// request — nothing ever reaches the broker, bank or RTA.
///
/// Read-only calls (order books, status checks, quotes) are left untouched.
/// When adding a new write API to ApiExporter, add a blocking override here
/// unless the paper engine simulates it.
mixin PaperSafetyGuard on ApiExporter {
  Never _block(String action) => throw PaperTradingUnsupportedException(action);

  // ── GTT / OCO ──────────────────────────────────────────────────────────
  @override
  Future<PlaceGttOrderModel> placeGTTOrderAPI(PlaceGTTOrderInput input) async =>
      _block('GTT order');

  @override
  Future<PlaceGttOrderModel> modifyGTTOrderAPI(PlaceGTTOrderInput input) async =>
      _block('GTT order modify');

  @override
  Future<PlaceGttOrderModel> cancelGTTOrderAPI(String cancelId) async =>
      _block('GTT order cancel');

  @override
  Future<PlaceGttOrderModel> placeOCOOrderAPI(PlaceOcoOrderInput input) async =>
      _block('OCO order');

  @override
  Future<PlaceGttOrderModel> modifyOCOOrderAPI(PlaceOcoOrderInput input) async =>
      _block('OCO order modify');

  // ── Live-account books ─────────────────────────────────────────────────
  // The paper app must never show the user's REAL GTT / SIP orders.
  @override
  Future<Map<String, dynamic>> getGTTOrderBook() async =>
      {"stat": "no data", "data": []};

  @override
  Future<Map<String, dynamic>> getTriggeredGTTOrders() async =>
      {"stat": "no data", "data": []};

  @override
  Future<SipOrderBookModel> getSipOrderBook() async =>
      SipOrderBookModel.fromJson({"stat": "Not_Ok", "emsg": "no data"});

  // ── Equity SIP ─────────────────────────────────────────────────────────
  @override
  Future<SipPlaceOrderModel> getPlaceSipOrder(SipInputField sipInputField) async =>
      _block('SIP order');

  @override
  Future<SipPlaceOrderModel> getPlaceSipBasketOrder(
          SipBasketInput sipBasketInput) async =>
      _block('SIP basket order');

  @override
  Future<ModifySIPModel> getmodifysiporder(ModifySipInput modifysipinput) async =>
      _block('SIP modify');

  @override
  Future<CancleSipOrder> getSipCancelOrder(String sipOrderno) async =>
      _block('SIP cancel');

  // ── IPO / Bonds ────────────────────────────────────────────────────────
  @override
  Future<IpoOrderResponcesModel> fetchipoplaceorder(
          MenuData menudata, List<IposBid> iposbids, String iposupiid) async =>
      _block('IPO application');

  @override
  Future<PlacedBondOrderResp> placeBondOrderApi(
          String symbol, int investmentValue, int price) async =>
      _block('Bond order');

  @override
  Future<PlacedBondOrderResp> cancelBondOrderApi(
          String symbol,
          String investmentValue,
          int price,
          String clientApplicationNumber,
          String orderNumber) async =>
      _block('Bond order cancel');

  // ── Mutual funds ───────────────────────────────────────────────────────
  @override
  Future<MfPlaceOrderResponces> getLumpSumOrder(scode, amt,
          [bool isAdditional = false]) async =>
      _block('Mutual fund order');

  @override
  Future<RedemptionModel> getMFRedemption(String scheme, String qty) async =>
      _block('Mutual fund redemption');

  @override
  Future<XsipOrderResponces> getXsipPurchase(
          String schemecode,
          String startDate,
          String freqtype,
          String amt,
          String noofinstallment,
          String enddate,
          String mandateId,
          [bool isAdditional = false,
          bool firstInstallment = false]) async =>
      _block('Mutual fund SIP');

  @override
  Future<MfCreateMandateModel> getCreateMandate(
          String amount, String startDate, String endDate) async =>
      _block('Mandate creation');

  @override
  Future<XsipOrderCancleResponces> getxsipCancle(String xsipregno,
          String internalrefno, String caseno, String remarks) async =>
      _block('Mutual fund SIP cancel');

  @override
  Future<UpiIdOrderResponse> apiPushUpiTrigger(id, val, upiid, ordertype) async =>
      _block('Mutual fund payment');

  // ── Funds: pay-in / withdrawal / transfer ──────────────────────────────
  @override
  Future<HdfcPaymentModel> getUPIIDPayment(
          String upiId, String clientId, String accno, String bankName) async =>
      _block('Add funds (UPI)');

  @override
  Future<HdfcDirectPayment> getUPIAppsPayment(
          String amt, String bankaccno, String clientid, String name) async =>
      _block('Add funds (UPI app)');

  @override
  Future<Razorpays> getrazorpay(
          String amt, String accno, String name, String ifsc) async =>
      _block('Add funds (net banking)');

  @override
  Future<PaymentWithdraw> getpayemntwithdraw(
          String ip, String amount, String segment) async =>
      _block('Withdraw funds');

  @override
  Future<IndentUpiResponse> indentUpiRequest({
    required String name,
    required String email,
    required String mobile,
    required String bankName,
    required String seg,
    required String code,
    required String custAcc,
    required String bankIfsc,
    required String amt,
  }) async =>
      _block('Add funds (UPI intent)');

  @override
  Future<IndentUpiResponse> upiCollectRequest({
    required String name,
    required String email,
    required String mobile,
    required String bankName,
    required String seg,
    required String code,
    required String custAcc,
    required String bankIfsc,
    required String amt,
    required String upi,
  }) async =>
      _block('Add funds (UPI collect)');

  @override
  Future<MtfFundTransferResponse> fundTransferMTF(
          String clientId, String amount) async =>
      _block('MTF fund transfer');

  @override
  Future<List<ViewUpiIdModel>> updateUpiId(
          String accountnumber, String upiid, String bankName) async =>
      _block('UPI ID update');

  // ── Corporate actions ──────────────────────────────────────────────────
  @override
  Future<placeOrderResponseCopModel> putorderapicopaction(
          String tabval,
          String sym,
          String exchange,
          String issueType,
          String qty,
          String price,
          String ordertype,
          String appno) async =>
      _block('Corporate action order');
}

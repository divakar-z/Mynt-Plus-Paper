import 'dart:developer';

import 'package:flutter/material.dart';
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
import '../models/fund_model_testing_copy/withdraw_request_model.dart';
import '../models/fund_model_testing_copy/secured_bank_detalis_model.dart';
import '../models/fund_model_testing_copy/secured_client_data_model.dart';
import '../models/fund_model_testing_copy/view_upi_id.dart';
import '../models/fund_model_testing_copy/indent_upi_request_model.dart';
import '../models/fund_model_testing_copy/wrapper_check_status_model.dart';
import '../models/fund_model_testing_copy/mtf_limits_model.dart';
import '../models/fund_model_testing_copy/client_history_model.dart';
import '../sharedWidget/fund_function.dart';
import 'core/api_core.dart';

mixin TranscationApi on ApiCore {
  Future<FundTokenValidation> getFundvalidateSession() async {
    try {
      final uri = Uri.parse(apiLinks.fundvalidatetoken);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode(
              {"clientid": "${prefs.clientId}", "token": "${prefs.token}"}));
      final json = jsonDecode(res.body);
      //  log("validate session => ${res.body}");
      final fundValidateToken = FundTokenValidation.fromJson(json);
      return fundValidateToken;
    } catch (e) {
      rethrow;
    }
  }

  Future<HdfcPaymentModel> getUPIIDPayment(
      String upiId, String clientId, String accno, String bankName) async {
    try {
      final uri = Uri.parse(apiLinks.verifyUPI);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode(
              {"VPA": upiId, "clientID": clientId, "bank_acc": accno}));
      final json = jsonDecode(res.body);
      // log("getUPIIDPayment => ${res.body}");
      final hdfcbankpayment = HdfcPaymentModel.fromJson(json);
      try {
        await updateUpiId(accno, upiId, bankName);
      } catch (updateError) {
      }

      return hdfcbankpayment;
    } catch (e) {
      rethrow;
    }
  }

  Future<HdfcUPIStatus> getHdfcUPIStatus(
      String orderNo, String upiTranID) async {
    try {
      final uri = Uri.parse(apiLinks.fundUpiStatus);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "OrderNo": orderNo,
            "upiTranID": upiTranID,
            "clientID": prefs.clientId
          }));
      final json = jsonDecode(res.body);
      // log("getHdfcUPIStatus => ${res.body}");
      final hdfcupistatus = HdfcUPIStatus.fromJson(json);
      return hdfcupistatus;
    } catch (e) {
      rethrow;
    }
  }

  Future<HdfcDirectPayment> getUPIAppsPayment(
      String amt, String bankaccno, String clientid, String name) async {
    try {
      final uri = Uri.parse(apiLinks.fundpayment);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "amount": amt,
            "bank_acc": bankaccno,
            "clientID": clientid,
            "Name": name
          }));
      final json = jsonDecode(res.body);
      log("getUPIAppsPayment => ${res.body}");
      final hdfcdirectbankpayment = HdfcDirectPayment.fromJson(json);
      return hdfcdirectbankpayment;
    } catch (e) {
      rethrow;
    }
  }

  Future<Razorpays> getrazorpay(
      String amt, String accno, String name, String ifsc) async {
    String url =
        "https://fundapi.mynt.in/razorpay/razorpay?amount=$amt&method=netbanking&account_number=$accno&name=$name&ifsc=$ifsc&ccode=${prefs.clientId}";
    //log(url);
    try {
      final res = await apiClient.post(
        Uri.parse(url),
        body: jsonEncode({
          'amount': amt,
          'method': 'netbanking',
          'account_number': accno,
          'name': name,
          'ifsc': ifsc,
          'ccode': prefs.clientId
        }),
        headers: razorpaytHeaders,
      );

      final json = jsonDecode(res.body);
      final razorpay = Razorpays.fromJson(json);
      return razorpay;
    } catch (e) {
      rethrow;
    }
  }

  Future<RazorpayTranstationRes> getrazorpayStatus(String paymentid) async {
    String url = "https://fundapi.mynt.in/razorpay/status?id=$paymentid";
    //log(url);
    try {
      final res = await apiClient.post(
        Uri.parse(url),
        body: jsonEncode({'id': paymentid}),
        headers: razorpaytHeaders,
      );

      final json = jsonDecode(res.body);
      final razorpay = RazorpayTranstationRes.fromJson(json);
      return razorpay;
    } catch (e) {
      rethrow;
    }
  }

  Future<HdfcPaymentStatus> getHdfcPaymentstatus(
      String ordno, String upiTransid) async {
    try {
      final uri = Uri.parse(apiLinks.tranctiontstatus);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "OrderNo": ordno,
            "upiTranID": upiTransid,
            "clientID": prefs.clientId
          }));
      final json = jsonDecode(res.body);
      log("getHdfcPaymentstatus=> ${res.body}");
      final hdfcbankpaymentstatus = HdfcPaymentStatus.fromJson(json);
      return hdfcbankpaymentstatus;
    } catch (e) {
      rethrow;
    }
  }

  Future<HdfcTranctionModel> getHdfcTranction(
    String upiId,
    int amount,
    String accno,
    String clientId,
  ) async {
    try {
      final uri = Uri.parse(apiLinks.moneytransction);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "VPA": upiId,
            "amount": amount,
            "bank_acc": accno,
            "clientID": clientId
          }));
      final json = jsonDecode(res.body);
      //  log("getHdfcTranction => ${res.body}");
      final hdfctranction = HdfcTranctionModel.fromJson(json);
      return hdfctranction;
    } catch (e) {
      rethrow;
    }
  }

  Future<DecryptClientCheck> getClientDetails() async {
    String payload = jsonEncode({"client_code": prefs.clientId});
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.clientcheck);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"code": encryptedPayload}));
      Map<String, dynamic> json = jsonDecode(res.body);
      if (json.containsKey('emsg')) {
        return DecryptClientCheck.fromJson(json);
      } else {
        final decryptedData = decryptionFunction(json["str"]);
        // log("client Data------------ ${jsonDecode(jsonEncode(decryptedData))}}");
        return DecryptClientCheck.fromJson(jsonDecode(decryptedData));
      }
    } catch (e) {
      // print("object :: $e");
      rethrow;
    }
  }

  Future<PayoutDetails> getWithdrawPayout(BuildContext context) async {
    String payload = jsonEncode({"client_id": prefs.clientId});
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.withdraw);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      Map<String, dynamic> json = jsonDecode(res.body);

      if (json.containsKey('emsg')) {
        return PayoutDetails.fromJson(json);
      } else {
        final decryptedData = decryptionFunction(json["str"]);
        // log("getWithdrawPayout------------ ${jsonDecode(jsonEncode(decryptedData))}}");
        return PayoutDetails.fromJson(jsonDecode(decryptedData));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<BankDetails> getbankDetails() async {
    String payload = jsonEncode({"client_code": prefs.clientId});
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.bankcheck);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"code": encryptedPayload}));
      final json = jsonDecode(res.body);
      final decryptedData = decryptionFunction(json["str"]);
      // log("getbankDetails------------ ${jsonDecode(jsonEncode(decryptedData))}}");
      return BankDetails.fromJson(jsonDecode(decryptedData));
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ViewUpiIdModel>> getUpiId(
      String bankname, String accountnumber) async {
    String payload = jsonEncode({
      "account_number": accountnumber,
      "bank_name": bankname,
      "client_id": prefs.clientId,
    });
    String encryptedPayload = encryptionFunction(payload);
    final decre = decryptionFunction(
        "mVMBKEzQyO1npWs7mdLchfJKFRBwM3at30m6tjToqhuUThQLEh1QVlMB+cYpTC4WTbvUhaTlJL3MAj+HYF1kf78LDUHH7PZIvYVWiqcET24KgqfbukuqEXsqWk1kt7FfzNJt/1OUoHNpKLKmhdSHyIyISAHf8K0U7L2D80TmaSY=");

    try {
      final uri = Uri.parse(apiLinks.fundUpiIdView);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      final json = jsonDecode(res.body);

      final decryptedData = decryptionFunction(json["str"]);
      List<dynamic> myList = jsonDecode(decryptedData);
      final List<ViewUpiIdModel> data = [];
      for (var element in myList) {
        data.add(ViewUpiIdModel.fromJson(element as Map<String, dynamic>));
      }
      //  log("getUpiId ---> $myList");

      return data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ViewUpiIdModel>> updateUpiId(
      String accountnumber, String upiid, String bankName) async {
    String payload = jsonEncode({
      "account_number": accountnumber,
      "bank_name": bankName,
      "client_id": prefs.clientId,
      "upi_id": upiid
    });
    String encryptedPayload = encryptionFunction(payload);
    final decre = decryptionFunction(
        "mVMBKEzQyO1npWs7mdLchfJKFRBwM3at30m6tjToqhuUThQLEh1QVlMB+cYpTC4WTbvUhaTlJL3MAj+HYF1kf78LDUHH7PZIvYVWiqcET24KgqfbukuqEXsqWk1kt7FfzNJt/1OUoHNpKLKmhdSHyIyISAHf8K0U7L2D80TmaSY=");

    try {
      final uri = Uri.parse(apiLinks.upiIdUpdate);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      final json = jsonDecode(res.body);

      final decryptedData = decryptionFunction(json["str"]);
      List<dynamic> myList = jsonDecode(decryptedData);

      return decryptedData;
    } catch (e) {
      rethrow;
    }
  }

  Future<PaymentWithdraw> getpayemntwithdraw(
      String ip, String amount, String segment) async {
    String payload = jsonEncode({
      "accountcode": "${prefs.clientId}",
      "ip": ip,
      "amount": amount,
      "company_code": segment,
    });
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.paymentwithdraw);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      final json = jsonDecode(res.body);
      final decryptedData = decryptionFunction(json["str"]);
      //  log("getpayemntwithdraw------------ ${jsonDecode(jsonEncode(decryptedData))}}");
      return PaymentWithdraw.fromJson(jsonDecode(decryptedData));
    } catch (e) {
      rethrow;
    }
  }

  Future<List<WithdrawStatus>> getWithDrawStatus() async {
    String payload = jsonEncode({"client_id": prefs.clientId});
    String encryptedPayload = encryptionFunction(payload);
    try {
      final uri = Uri.parse(apiLinks.withdrawstatus);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"string": encryptedPayload}));
      final json = jsonDecode(res.body);
      final decryptedData = decryptionFunction(json["str"]);
      final List<WithdrawStatus> data = [];
      try {
        dynamic decodedJson = jsonDecode(decryptedData);
        if (decodedJson is List<dynamic>) {
          for (var element in decodedJson) {
            data.add(WithdrawStatus.fromJson(element as Map<String, dynamic>));
          }
          //  log("getWithDrawStatus ---> ${data[0].iPADDRESS}");
        } else if (decodedJson is Map<String, dynamic>) {
          final WithdrawStatus msg = WithdrawStatus.fromJson(decodedJson);
          return [msg];
        }
      } catch (e) {
      }
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Backend `/withdraw/max_payout`: `withdraw_amount` is the authoritative
  /// withdrawable amount; failures come back as `{"msg":"error"}`.
  Future<MaxPayoutModel> getMaxPayoutAmount() async {
    final data = await _withdrawPost(apiLinks.withdrawMaxPayout,
        {"client_id": "${prefs.clientId}"}, const Duration(seconds: 20));
    if (data is! Map<String, dynamic>) {
      return const MaxPayoutModel(stat: 'Not_Ok', emsg: 'Invalid response');
    }
    final amount = data['withdraw_amount'];
    if (amount != null) {
      return MaxPayoutModel(stat: 'Ok', payout: amount.toString());
    }
    return MaxPayoutModel(
        stat: 'Not_Ok', emsg: (data['emsg'] ?? data['msg'])?.toString());
  }

  /// Posts an encrypted body to the withdraw backend and returns the
  /// decrypted JSON. Session errors come back unencrypted (`emsg`, no `str`);
  /// those are returned as-is with `_httpStatus` added.
  Future<dynamic> _withdrawPost(
      String url, Map<String, dynamic> payload, Duration timeout) async {
    final res = await apiClient
        .post(Uri.parse(url),
            headers: funddefaultHeaders,
            body: jsonEncode({"string": encryptionFunction(jsonEncode(payload))}))
        .timeout(timeout);
    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      final str = json['str'];
      if (str is String && str.isNotEmpty) {
        return jsonDecode(decryptionFunction(str));
      }
      if (json.containsKey('emsg')) {
        return {...json, '_httpStatus': res.statusCode};
      }
    }
    throw FormatException('Unexpected withdraw response (${res.statusCode})');
  }

  /// Places a withdrawal. [ip] is sent only when the lookup succeeded.
  Future<WithdrawActionResponse> placeWithdraw(
      {required String amount,
      required String companyCode,
      String? ip}) async {
    final data = await _withdrawPost(
      apiLinks.withdrawPayment,
      {
        "accountcode": "${prefs.clientId}",
        "company_code": companyCode,
        "amount": amount,
        if (ip != null && ip.isNotEmpty) "ip": ip,
      },
      // Long enough for Noren + backoffice; a timeout here does not mean the
      // request failed, so the screen re-reads the list afterwards.
      const Duration(seconds: 45),
    );
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected withdraw response');
    }
    return WithdrawActionResponse.fromJson(data,
        httpStatus: _toHttpStatus(data['_httpStatus']));
  }

  /// Cancels a pending withdrawal by its request id.
  Future<WithdrawActionResponse> cancelWithdraw(
      {required int requestId, String? remarks}) async {
    final data = await _withdrawPost(
      apiLinks.withdrawCancel,
      {
        "request_id": requestId,
        if (remarks != null && remarks.trim().isNotEmpty)
          "remarks": remarks.trim(),
      },
      const Duration(seconds: 45),
    );
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected cancel response');
    }
    return WithdrawActionResponse.fromJson(data,
        httpStatus: _toHttpStatus(data['_httpStatus']));
  }

  /// Recent withdraw requests for the logged-in client, newest first.
  Future<WithdrawRequestsResult> getWithdrawRequests() async {
    final data = await _withdrawPost(
        apiLinks.withdrawRequests, {}, const Duration(seconds: 20));
    if (data is List) {
      return WithdrawRequestsResult(
        requests: [
          for (final e in data)
            if (e is Map<String, dynamic>) WithdrawRequest.fromJson(e),
        ],
      );
    }
    if (data is Map<String, dynamic> && data.containsKey('emsg')) {
      return WithdrawRequestsResult(
          emsg: '${data['emsg']}',
          httpStatus: _toHttpStatus(data['_httpStatus']));
    }
    // `{"msg": "error"}` or any other shape is a failure, not an empty list.
    throw const FormatException('Unexpected withdraw requests response');
  }

  int? _toHttpStatus(dynamic v) => v is int ? v : null;

  /// Initiate UPI QR payment via wrapper API
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
  }) async {
    try {
      final uri = Uri.parse(apiLinks.indentUpiRequest);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "name": name,
            "email": email,
            "mobile": mobile,
            "bankname": bankName,
            "seg": seg,
            "code": code,
            "custacc": custAcc,
            "bankifsc": bankIfsc,
            "amt": amt,
          }));
      final json = jsonDecode(res.body);
      log("indentUpiRequest => ${res.body}");
      return IndentUpiResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  /// Initiate UPI Collect Request via wrapper API (for UPI ID flow)
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
  }) async {
    try {
      final uri = Uri.parse(apiLinks.upiCollectRequest);
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({
            "name": name,
            "email": email,
            "mobile": mobile,
            "bankname": bankName,
            "seg": seg,
            "code": code,
            "custacc": custAcc,
            "bankifsc": bankIfsc,
            "amt": amt,
            "upi": upi,
          }));
      final json = jsonDecode(res.body);
      log("upiCollectRequest => ${res.body}");
      return IndentUpiResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  /// Check UPI QR payment status via wrapper API
  Future<WrapperCheckStatusResponse> wrapperCheckStatus({
    required String orderNo,
    required String upiTranID,
    required String clientID,
    required String gateway,
  }) async {
    try {
      final uri = Uri.parse(apiLinks.wrapperCheckStatus);
      final res = await apiClient.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "OrderNo": orderNo,
            "upiTranID": upiTranID,
            "clientID": clientID,
            "gateway": gateway,
          }));
      final json = jsonDecode(res.body);
      log("wrapperCheckStatus => ${res.body}");
      return WrapperCheckStatusResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  /// Build QR code image URL
  String buildQrCodeUrl({
    required String orderNumber,
    required String paidToVPA,
    required String amount,
    required String code,
    required String gateway,
  }) {
    return '${apiLinks.qrCodeUrl}?orderNumber=$orderNumber&paid_to_VPA=$paidToVPA&amount=$amount&code=$code&gateway=$gateway';
  }

  /// Fetch all limits (cash, payin, payout, marginused)
  Future<MtfLimitsResponse> getAllLimits(String clientId) async {
    try {
      final uri = Uri.parse(apiLinks.allLimits);
      final res = await apiClient.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"clientid": clientId}));
      final json = jsonDecode(res.body);
      log("getAllLimits => ${res.body}");
      return MtfLimitsResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch MTF limits
  Future<MtfLimitsMTFResponse> getAllLimitsMTF(String clientId) async {
    try {
      final uri = Uri.parse(apiLinks.allLimitsMTF);
      final res = await apiClient.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"clientid": clientId}));
      final json = jsonDecode(res.body);
      log("getAllLimitsMTF => ${res.body}");
      return MtfLimitsMTFResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  /// Transfer fund to MTF
  Future<MtfFundTransferResponse> fundTransferMTF(
      String clientId, String amount) async {
    try {
      final uri = Uri.parse(apiLinks.fundTransfer);
      final res = await apiClient.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "clientid": clientId,
            "tranfer_amount": amount,
            "move": "MTF",
          }));
      final json = jsonDecode(res.body);
      log("fundTransferMTF => ${res.body}");
      return MtfFundTransferResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  Future<ClientHistoryResponse> getClientHistory() async {
    try {
      final uri = Uri.parse("https://funduat.mynt.in/logs/ClientHistory");
      final res = await apiClient.post(uri,
          headers: funddefaultHeaders,
          body: jsonEncode({"clientid": prefs.clientId}));
      final json = jsonDecode(res.body);
      return ClientHistoryResponse.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }
}

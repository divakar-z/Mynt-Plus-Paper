import 'dart:convert';

import 'package:http/http.dart' show BaseRequest, ByteStream, StreamedResponse;

/// Last line of defence for paper trading: a network-level denylist.
///
/// [PaperSafetyGuard] blocks known write APIs method by method. This guard
/// sits under it, inside the shared HTTP client, so even a write API added by
/// a future web-repo sync can never reach a real order, payment or pledge
/// endpoint while paper mode is on.
///
/// Matching is on host + path only (query strings ignored).
class PaperNetworkGuard {
  PaperNetworkGuard._();

  /// Hosts where every request moves real money — blocked entirely.
  static const List<String> _blockedHosts = [
    'fundapi.mynt.in', // pay-in (UPI/HDFC/Razorpay), withdrawals, UPI ID
  ];

  /// Host+path prefixes blocked entirely.
  static const List<String> _blockedPrefixes = [
    'rekycbe.mynt.in/pledge', // pledge / unpledge requests
  ];

  /// Path endings that place, modify or cancel real orders / move money.
  static const List<String> _blockedPathSuffixes = [
    // Noren order endpoints
    '/PlaceOrder',
    '/ModifyOrder',
    '/CancelOrder',
    '/ExitSNOOrder',
    '/ProductConversion',
    '/PlaceGTTOrder',
    '/ModifyGTTOrder',
    '/CancelGTTOrder',
    '/PlaceOCOOrder',
    '/ModifyOCOOrder',
    '/PlaceSipOrder',
    '/ModifySipOrder',
    '/CancelSipOrder',
    // IPO / bonds / corporate actions
    'addIPOtoPortfolio',
    'addNCBtoPortfolio',
    'addSGBtoPortfolio',
    '/addCorporateAction',
    // Mutual funds
    '/order/PlaceLumpsumOrder',
    '/order/PlaceRedeemOrder',
    '/order/xsip_purchase',
    '/order/xsip_cancel',
    '/order/xsip_pause',
    '/order/all_payment',
    '/order/mandate_creation',
    '/mf/xsip_cancel',
    // Fund transfer between segments
    '/FundTransfer',
  ];

  /// Returns true when [url] must never be called in paper mode.
  static bool isBlocked(Uri url) {
    final host = url.host.toLowerCase();
    if (_blockedHosts.contains(host)) return true;

    final hostPath = '$host${url.path}';
    if (_blockedPrefixes.any(hostPath.startsWith)) return true;

    final path = url.path.replaceAll(RegExp(r'/+$'), '');
    return _blockedPathSuffixes.any(path.endsWith);
  }

  /// A local "failed" response in the common broker shape, so callers that
  /// check `stat` / `emsg` show a normal error instead of crashing.
  static StreamedResponse blockedResponse(BaseRequest request) {
    final body = utf8.encode(jsonEncode({
      'stat': 'Not_Ok',
      'emsg': 'Not available in paper trading mode.',
      'msg': 'Not available in paper trading mode.',
    }));
    return StreamedResponse(
      ByteStream.fromBytes(body),
      403,
      request: request,
      headers: {'content-type': 'application/json'},
      reasonPhrase: 'Blocked in paper trading mode',
    );
  }
}

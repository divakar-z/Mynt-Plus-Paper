import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/api/paper/paper_network_guard.dart';

void main() {
  bool blocked(String url) => PaperNetworkGuard.isBlocked(Uri.parse(url));

  test('blocks real order endpoints', () {
    for (final ep in [
      'PlaceOrder',
      'ModifyOrder',
      'CancelOrder',
      'ExitSNOOrder',
      'ProductConversion',
      'PlaceGTTOrder',
      'ModifyGTTOrder',
      'CancelGTTOrder',
      'PlaceOCOOrder',
      'ModifyOCOOrder',
      'PlaceSipOrder',
      'ModifySipOrder',
      'CancelSipOrder',
    ]) {
      expect(blocked('https://go.mynt.in/NorenWClientWeb/$ep'), isTrue,
          reason: ep);
    }
  });

  test('blocks money, IPO, bond, MF and pledge endpoints', () {
    expect(blocked('https://fundapi.mynt.in/razorpay/razorpay?amount=1'), isTrue);
    expect(blocked('https://fundapi.mynt.in/withdraw/payment'), isTrue);
    expect(blocked('https://fundapi.mynt.in/withdraw/cancel'), isTrue);
    expect(blocked('https://fundapi.mynt.in/wrapper/IndentUPIRequest'), isTrue);
    expect(blocked('https://rekycbe.mynt.in/pledge/response'), isTrue);
    expect(blocked('https://rekycbe.mynt.in/pledge//del_pledge'), isTrue);
    expect(blocked('https://v3.mynt.in/mfapi/order/PlaceLumpsumOrder'), isTrue);
    expect(blocked('https://v3.mynt.in/mfapi/order/xsip_purchase'), isTrue);
    expect(blocked('https://v3.mynt.in/ipo/addCorporateAction'), isTrue);
    expect(blocked('https://x.mynt.in/ipo/addIPOtoPortfolio'), isTrue);
    expect(blocked('https://x.mynt.in/ipo/addNCBtoPortfolio'), isTrue);
  });

  test('blocks legacy mutual fund write endpoints', () {
    for (final ep in [
      'mf/lumsum_purchase',
      'mf/xsip_purchase',
      'mf/lumsum_purchase_mob',
      'mf/lumsum_redemption_mob',
      'mf/lumsum_redemption_cancel',
      'mf/xsip_cancel',
      'mf/xsip_pause',
      'mfapi/mandate_creation',
    ]) {
      expect(blocked('https://v3.mynt.in/$ep'), isTrue, reason: ep);
    }
  });

  test('blocks order endpoints with new names or different case', () {
    expect(blocked('https://go.mynt.in/NorenWClientWeb/PlaceBasketOrder'), isTrue);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/placeorder'), isTrue);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/PlaceOrder/'), isTrue);
    expect(blocked('https://uat.mynt.in/NorenWClient/ExitOrder'), isTrue);
  });

  test('paper mode is locked on and the browser guard loads first', () {
    expect(File('lib/locator/locator.dart').readAsStringSync(),
        contains('const bool isPaperTrading = true;'));
    final html = File('web/index.html').readAsStringSync();
    expect(html.indexOf('paper_guard.js'), greaterThan(-1));
    expect(html.indexOf('paper_guard.js'),
        lessThan(html.indexOf('flutter_bootstrap.js')));
    expect(html.indexOf('paper_guard.js'), lessThan(html.indexOf('<script>')));
  });

  test('blocks real account changes but not account reads', () {
    for (final p in ['mail_otpsend', 'file_write_email', 'mob_otp_ver', 'file_write_mob', 'adr_chn', 'bank', 'DDPI', 'mtf', 'income', 'nominee', 'add_segment', 'img_upload', 'cdsl/signature_upload', 'send_link_request', 'closure']) {
      expect(blocked('https://rekycbe.mynt.in//$p'), isTrue, reason: p);
    }
    for (final e in ['UserApiKeyRenReq', 'GetUserApiKey', 'AppKeyStore', 'GenSecretKey']) {
      expect(blocked('https://go.mynt.in/NorenWClientWeb/$e'), isTrue, reason: e);
    }
    for (final a in ['create', 'update', 'delete']) {
      expect(blocked('https://ws.mynt.in/login//oauth-apps/$a'), isTrue, reason: a);
    }
    expect(blocked('https://ws.mynt.in/login//oauth-apps/list'), isFalse);
    for (final p in ['profile', 'check_closure', 'getholdingscheck', 'nom_stat']) {
      expect(blocked('https://rekycbe.mynt.in//$p'), isFalse, reason: p);
    }
  });

  test('allows market data and read-only calls', () {
    expect(blocked('https://go.mynt.in/NorenWClientWeb/GetQuotes'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/SearchScrip'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/OrderBook'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/GetOrderMargin'), isFalse);
    expect(blocked('https://v3.mynt.in/mfapi/order/OrderBook'), isFalse);
  });
}

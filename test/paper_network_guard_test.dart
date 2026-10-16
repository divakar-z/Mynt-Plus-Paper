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
    expect(blocked('https://fundapi.mynt.in/wrapper/IndentUPIRequest'), isTrue);
    expect(blocked('https://rekycbe.mynt.in/pledge/response'), isTrue);
    expect(blocked('https://v3.mynt.in/mfapi/order/PlaceLumpsumOrder'), isTrue);
    expect(blocked('https://v3.mynt.in/mfapi/order/xsip_purchase'), isTrue);
    expect(blocked('https://v3.mynt.in/ipo/addCorporateAction'), isTrue);
    expect(blocked('https://x.mynt.in/ipo/addIPOtoPortfolio'), isTrue);
    expect(blocked('https://x.mynt.in/ipo/addNCBtoPortfolio'), isTrue);
  });

  test('allows market data and read-only calls', () {
    expect(blocked('https://go.mynt.in/NorenWClientWeb/GetQuotes'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/SearchScrip'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/OrderBook'), isFalse);
    expect(blocked('https://go.mynt.in/NorenWClientWeb/GetOrderMargin'), isFalse);
    expect(blocked('https://v3.mynt.in/mfapi/order/OrderBook'), isFalse);
  });
}

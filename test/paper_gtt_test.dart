import 'package:flutter_test/flutter_test.dart';
import 'package:mynt_plus/api/paper/paper_order_engine.dart';
import 'package:mynt_plus/api/paper/paper_portfolio_service.dart';
import 'package:mynt_plus/models/order_book_model/place_gtt_order.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sym = 'NIFTY25JAN24000CE';
const _token = '111';

PlaceOrderInput _order(String side, int qty) => PlaceOrderInput(
      amo: 'No',
      exch: 'NFO',
      tsym: _sym,
      qty: '$qty',
      trgprc: '',
      trailprc: '',
      blprc: '',
      bpprc: '',
      prc: '0',
      dscqty: '0',
      prd: 'I',
      trantype: side,
      prctype: 'MKT',
      ret: 'DAY',
      mktProt: '',
      channel: 'WEB',
      token: _token,
    );

PlaceGTTOrderInput _gtt(String side, String ait, String d,
        {int qty = 75, String alid = ''}) =>
    PlaceGTTOrderInput(
      exch: 'NFO',
      qty: '$qty',
      tsym: _sym,
      trgprc: '0',
      ait: ait,
      prc: '0',
      prd: 'I',
      trantype: side,
      ret: 'DAY',
      d: d,
      prctyp: 'MKT',
      remarks: '',
      validity: 'GTT',
      alid: alid,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = PaperOrderEngine.instance;

  int net() {
    var n = 0;
    for (final t in engine.trades) {
      final q = int.parse(t.flqty ?? '0');
      n += t.trantype == 'B' ? q : -q;
    }
    return n;
  }

  int book() => (engine.getGttBook()['data'] as List).length;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await engine.reset();
  });

  test('long: stoploss exits and removes the target', () async {
    await engine.placeOrder(_order('B', 75), '100');
    expect(engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100).stat, 'OI created');
    expect(engine.placeGtt(_gtt('S', 'LTP_A_O', '120'), 100).stat, 'OI created');

    expect(await engine.onLtpUpdateByToken(_token, 95), isFalse);
    expect(net(), 75);

    expect(await engine.onLtpUpdateByToken(_token, 89), isTrue);
    expect(net(), 0);
    expect(book(), 0);
    expect(engine.trades.first.flprc, '89.00');

    await engine.onLtpUpdateByToken(_token, 130);
    expect(net(), 0, reason: 'the target must not open a short');
  });

  test('long: target exits at LTP', () async {
    await engine.placeOrder(_order('B', 75), '100');
    engine.placeGtt(_gtt('S', 'LTP_A_O', '120'), 100);
    await engine.onLtpUpdateByToken(_token, 121);
    expect(net(), 0);
  });

  test('short: stoploss above and target below', () async {
    await engine.placeOrder(_order('S', 75), '100');
    engine.placeGtt(_gtt('B', 'LTP_A_O', '110'), 100);
    engine.placeGtt(_gtt('B', 'LTP_B_O', '80'), 100);
    await engine.onLtpUpdateByToken(_token, 111);
    expect(net(), 0);
    expect(book(), 0);
  });

  test('two ticks at once fire only one exit', () async {
    await engine.placeOrder(_order('B', 75), '100');
    engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100);
    await Future.wait([
      engine.onLtpUpdateByToken(_token, 89),
      engine.onLtpUpdateByToken(_token, 88),
    ]);
    expect(net(), 0);
    expect(engine.trades.length, 2);
  });

  test('refuses without a position or past the trigger', () async {
    expect(engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100).stat, 'Not_Ok');
    await engine.placeOrder(_order('B', 75), '100');
    expect(engine.placeGtt(_gtt('B', 'LTP_A_O', '90'), 100).stat, 'Not_Ok',
        reason: 'a buy would add to a long');
    expect(engine.placeGtt(_gtt('S', 'LTP_B_O', '105'), 100).stat, 'Not_Ok');
  });

  test('limit orders only fill when the market reaches them', () async {
    final buy = _order('B', 1)
      ..prctype = 'LMT'
      ..prc = '700';
    await engine.placeOrder(buy, '755');
    expect(engine.orders.first.status, 'PENDING');

    await engine.onLtpUpdateByToken(_token, 750);
    expect(engine.orders.first.status, 'PENDING');

    await engine.onLtpUpdateByToken(_token, 699);
    expect(engine.orders.first.status, 'COMPLETE');
    expect(engine.orders.first.avgprc, '700.00');
  });

  test('no live price keeps a limit order pending', () async {
    final buy = _order('B', 1)
      ..prctype = 'LMT'
      ..prc = '700';
    await engine.placeOrder(buy, '0');
    expect(engine.orders.first.status, 'PENDING');
  });

  test('marketable limit fills at the market price', () async {
    final buy = _order('B', 1)
      ..prctype = 'LMT'
      ..prc = '800';
    await engine.placeOrder(buy, '755');
    expect(engine.orders.first.avgprc, '755.00');
  });

  test('re-entry keeps the new average and books P&L once', () async {
    await engine.placeOrder(_order('B', 65), '131.20');
    await engine.placeOrder(_order('S', 65), '135.45');
    await engine.placeOrder(_order('B', 65), '134.40');

    final p = PaperPortfolioService.instance.getPositionBook()['data'].first;
    expect(p.netqty, '65');
    expect(p.netavgprc, '134.40');
    expect(p.rpnl, '276.25');
  });

  test('flipping long to short splits realized and open', () async {
    await engine.placeOrder(_order('B', 10), '100');
    await engine.placeOrder(_order('S', 15), '110');

    final p = PaperPortfolioService.instance.getPositionBook()['data'].first;
    expect(p.netqty, '-5');
    expect(p.netavgprc, '110.00');
    expect(p.rpnl, '100.00');
  });

  test('manual exit removes triggers', () async {
    await engine.placeOrder(_order('B', 75), '100');
    engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100);
    await engine.placeOrder(_order('S', 75), '100');
    expect(book(), 0);
  });

  test('partial exit limits the trigger to the remaining qty', () async {
    await engine.placeOrder(_order('B', 75), '100');
    engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100);
    await engine.placeOrder(_order('S', 25), '100');
    await engine.onLtpUpdateByToken(_token, 89);
    expect(net(), 0);
  });

  test('modify and cancel, and triggers survive a restart', () async {
    await engine.placeOrder(_order('B', 75), '100');
    final id = engine.placeGtt(_gtt('S', 'LTP_B_O', '90'), 100).alId!;
    expect(engine.modifyGtt(_gtt('S', 'LTP_B_O', '85', alid: id), 100).stat,
        'OI replaced');
    await Future<void>.delayed(Duration.zero);
    await engine.init();
    expect(book(), 1);
    expect(engine.cancelGtt(id).stat, 'OI deleted');
    expect(engine.cancelGtt(id).stat, 'Invalid Oi');
  });
}

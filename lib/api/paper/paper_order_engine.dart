import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order_book_model/cancel_order_model.dart';
import '../../models/order_book_model/modify_order_model.dart';
import '../../models/order_book_model/order_book_model.dart';
import '../../models/order_book_model/order_history_model.dart';
import '../../models/order_book_model/place_order_model.dart';
import '../../models/order_book_model/trade_book_model.dart';
import 'virtual_wallet.dart';

/// Local order matching engine for paper trading.
/// Handles MARKET, LIMIT, SL-LMT, and SL-MKT order types.
/// Persists orders and trades to SharedPreferences.
class PaperOrderEngine {
  static const String _ordersKey = 'paper_orders';
  static const String _tradesKey = 'paper_trades';
  static const String _orderCounterKey = 'paper_order_counter';

  static PaperOrderEngine? _instance;
  static PaperOrderEngine get instance {
    _instance ??= PaperOrderEngine._();
    return _instance!;
  }

  PaperOrderEngine._();

  final List<OrderBookModel> _orders = [];
  final List<TradeBookModel> _trades = [];
  int _orderCounter = 0;

  List<OrderBookModel> get orders => List.unmodifiable(_orders);
  List<TradeBookModel> get trades => List.unmodifiable(_trades);

  // ── Initialization ──────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _orderCounter = prefs.getInt(_orderCounterKey) ?? 0;

    final ordersJson = prefs.getString(_ordersKey);
    if (ordersJson != null) {
      final List list = jsonDecode(ordersJson);
      _orders.clear();
      for (final item in list) {
        _orders.add(OrderBookModel.fromJson(item));
      }
    }

    final tradesJson = prefs.getString(_tradesKey);
    if (tradesJson != null) {
      final List list = jsonDecode(tradesJson);
      _trades.clear();
      for (final item in list) {
        _trades.add(TradeBookModel.fromJson(item));
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_orderCounterKey, _orderCounter);
    await prefs.setString(
        _ordersKey, jsonEncode(_orders.map((e) => e.toJson()).toList()));
    await prefs.setString(
        _tradesKey, jsonEncode(_trades.map((e) => e.toJson()).toList()));
  }

  // ── Order ID Generation ─────────────────────────────────────────

  String _generateOrderId() {
    _orderCounter++;
    return 'PAPER_${DateTime.now().millisecondsSinceEpoch}_$_orderCounter';
  }

  String _generateTradeId() {
    return 'PTR_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  String _nowTimestamp() {
    final now = DateTime.now();
    // Format: dd-MM-yyyy HH:mm:ss (matches Noren format)
    return '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  // ── Place Order ─────────────────────────────────────────────────

  /// Places an order. MARKET orders execute immediately at [currentLtp].
  /// LIMIT and SL orders are stored as OPEN pending execution.
  /// Returns PlaceOrderModel matching the real API response shape.
  Future<PlaceOrderModel> placeOrder(
    PlaceOrderInput input,
    String currentLtp,
  ) async {
    final orderId = _generateOrderId();
    final now = _nowTimestamp();
    final double ltp = double.tryParse(currentLtp) ?? 0.0;
    final double qty = double.tryParse(input.qty.replaceAll('-', '')) ?? 0;
    final double price = double.tryParse(input.prc) ?? 0.0;

    // Validate quantity
    if (qty <= 0) {
      return PlaceOrderModel.fromJson({
        'stat': 'Not_Ok',
        'emsg': 'Invalid quantity',
      });
    }

    // Determine net existing position for this symbol to know if SELL closes a long
    final bool isFnO = _isFnOExchange(input.exch);
    final int existingNetQty = _getNetPosition(input.exch, input.tsym, input.prd);

    // Determine how much of this order opens a new position vs closes existing
    final double fillPriceEstimate =
        (input.prctype == 'MKT' || input.prctype == 'SL-MKT') ? ltp : price;

    if (input.trantype == 'B') {
      // BUY: if we have a short position, part of this closes the short (no cost)
      //       remaining opens a new long (needs funds)
      final int closingQty = (existingNetQty < 0) ? min(qty.toInt(), -existingNetQty) : 0;
      final int openingQty = qty.toInt() - closingQty;
      if (openingQty > 0) {
        final double cost = fillPriceEstimate * openingQty;
        if (!VirtualWallet.instance.hasSufficientBalance(cost)) {
          return PlaceOrderModel.fromJson({
            'stat': 'Not_Ok',
            'emsg': 'Insufficient funds. Required: ${cost.toStringAsFixed(2)}, '
                'Available: ${VirtualWallet.instance.balance.toStringAsFixed(2)}',
          });
        }
      }
    } else if (input.trantype == 'S') {
      // SELL: if we have a long position, part of this closes the long (credits funds)
      //       remaining opens a new short
      final int closingQty = (existingNetQty > 0) ? min(qty.toInt(), existingNetQty) : 0;
      final int openingQty = qty.toInt() - closingQty;
      if (isFnO && openingQty > 0) {
        // Opening a new short in F&O requires margin
        final double cost = _estimateMarginRequired(
          exch: input.exch,
          trantype: 'S',
          qty: openingQty.toDouble(),
          price: fillPriceEstimate,
        );
        if (!VirtualWallet.instance.hasSufficientBalance(cost)) {
          return PlaceOrderModel.fromJson({
            'stat': 'Not_Ok',
            'emsg': 'Insufficient funds. Required: ${cost.toStringAsFixed(2)}, '
                'Available: ${VirtualWallet.instance.balance.toStringAsFixed(2)}',
          });
        }
      }
    }

    // Determine product alias for display
    String prdAlias = _getProductAlias(input.prd);

    // Create order entry
    final order = OrderBookModel(
      norenordno: orderId,
      uid: 'PAPER',
      actid: 'PAPER',
      exch: input.exch,
      tsym: input.tsym,
      qty: qty.toInt().toString(),
      prc: (input.prctype == 'MKT' || input.prctype == 'SL-MKT')
          ? '0.00'
          : input.prc,
      prctyp: input.prctype,
      prd: input.prd,
      trantype: input.trantype,
      ret: input.ret,
      status: 'PENDING',
      stat: 'Ok',
      norentm: now,
      ordenttm: now,
      fillshares: '0',
      avgprc: '0.00',
      amo: input.amo,
      trgprc: input.trgprc,
      blprc: input.blprc,
      bpprc: input.bpprc,
      trailprc: input.trailprc,
      mktProtection: input.mktProt,
      sPrdtAli: prdAlias,
      ordersource: 'WEB',
      dscqty: input.dscqty,
      rejreason: '',
      ltp: currentLtp,
      token: input.token ?? '',
      dname: input.dname ?? '',
      pp: '2',
      ls: '1',
      ti: '0.05',
      rprc: '0.00',
      rqty: '0',
    );

    _orders.insert(0, order);

    // MARKET orders execute immediately
    if (input.prctype == 'MKT') {
      await _executeOrder(order, ltp);
    }
    // SL-MKT / SL-LMT: check if trigger already met
    else if (input.prctype == 'SL-MKT' || input.prctype == 'SL-LMT') {
      final double triggerPrice = double.tryParse(input.trgprc) ?? 0.0;
      if (triggerPrice > 0) {
        bool triggered = false;
        if (input.trantype == 'B' && ltp >= triggerPrice) triggered = true;
        if (input.trantype == 'S' && ltp <= triggerPrice) triggered = true;

        if (triggered) {
          final execPrice =
              input.prctype == 'SL-MKT' ? ltp : price;
          await _executeOrder(order, execPrice);
        }
      }
    }
    // LIMIT: check if can fill immediately
    else if (input.prctype == 'LMT') {
      if (price > 0) {
        bool canFill = false;
        if (input.trantype == 'B' && ltp <= price) canFill = true;
        if (input.trantype == 'S' && ltp >= price) canFill = true;

        if (canFill) {
          await _executeOrder(order, price);
        }
      }
    }

    await _save();

    return PlaceOrderModel(
      norenordno: orderId,
      stat: 'Ok',
      requestTime: now,
      status: order.status,
    );
  }

  // ── Execute Order (fill) ────────────────────────────────────────

  Future<void> _executeOrder(OrderBookModel order, double fillPrice) async {
    final now = _nowTimestamp();
    final int qty = int.tryParse(order.qty ?? '0') ?? 0;
    final double totalValue = fillPrice * qty;

    // Settlement uses simple premium flow:
    //   BUY  → debit premium (pay to buy)
    //   SELL → credit premium (receive on sell)
    // This ensures round-trip trades always net to P&L.
    // F&O margin validation is handled separately in placeOrder() pre-check.
    if (order.trantype == 'B') {
      final success = await VirtualWallet.instance.debit(
        totalValue,
        'BUY ${order.qty} ${order.tsym} @ ${fillPrice.toStringAsFixed(2)}',
      );
      if (!success) {
        order.status = 'REJECTED';
        order.rejreason = 'Insufficient funds';
        return;
      }
    } else {
      await VirtualWallet.instance.credit(
        totalValue,
        'SELL ${order.qty} ${order.tsym} @ ${fillPrice.toStringAsFixed(2)}',
      );
    }

    // Update order status
    order.status = 'COMPLETE';
    order.fillshares = order.qty;
    order.avgprc = fillPrice.toStringAsFixed(2);
    order.exchTm = now;

    // Create trade entry
    final trade = TradeBookModel(
      stat: 'Ok',
      norenordno: order.norenordno,
      uid: 'PAPER',
      actid: 'PAPER',
      exch: order.exch,
      prctyp: order.prctyp,
      ret: order.ret,
      sPrdtAli: order.sPrdtAli,
      prd: order.prd,
      flid: _generateTradeId(),
      fltm: now,
      trantype: order.trantype,
      tsym: order.tsym,
      qty: order.qty,
      token: order.token,
      fillshares: order.qty,
      flqty: order.qty,
      pp: order.pp,
      ls: order.ls,
      ti: order.ti,
      prc: order.prc,
      prcftr: '1.00',
      flprc: fillPrice.toStringAsFixed(2),
      norentm: now,
      avgprc: fillPrice.toStringAsFixed(2),
      exchTm: now,
      exchordid: 'PAPER_EXCH_${DateTime.now().millisecondsSinceEpoch}',
      symbol: order.symbol,
      expDate: order.expDate,
      dname: order.dname,
      option: order.option,
    );

    _trades.insert(0, trade);
  }

  // ── Cancel Order ────────────────────────────────────────────────

  Future<CancelOrderModel> cancelOrder(String orderNo) async {
    final idx = _orders.indexWhere((o) => o.norenordno == orderNo);
    if (idx == -1) {
      return CancelOrderModel.fromJson({
        'stat': 'Not_Ok',
        'emsg': 'Order not found: $orderNo',
      });
    }

    final order = _orders[idx];
    if (order.status == 'COMPLETE' || order.status == 'CANCELLED') {
      return CancelOrderModel.fromJson({
        'stat': 'Not_Ok',
        'emsg': 'Order already ${order.status}',
      });
    }

    order.status = 'CANCELLED';
    await _save();

    return CancelOrderModel(
      stat: 'Ok',
      result: orderNo,
      requestTime: _nowTimestamp(),
    );
  }

  // ── Modify Order ────────────────────────────────────────────────

  Future<ModifyOrderModel> modifyOrder(ModifyOrderInput input) async {
    final idx = _orders.indexWhere((o) => o.norenordno == input.orderNum);
    if (idx == -1) {
      return ModifyOrderModel.fromJson({
        'stat': 'Not_Ok',
        'emsg': 'Order not found: ${input.orderNum}',
      });
    }

    final order = _orders[idx];
    if (order.status == 'COMPLETE' || order.status == 'CANCELLED') {
      return ModifyOrderModel.fromJson({
        'stat': 'Not_Ok',
        'emsg': 'Cannot modify ${order.status} order',
      });
    }

    // Update order fields
    order.qty = input.qty.replaceAll('-', '');
    order.prc = (input.prctyp == 'MKT' || input.prctyp == 'SL-MKT')
        ? '0.00'
        : input.prc;
    order.prctyp = input.prctyp;
    order.trgprc = input.trgprc;
    order.blprc = input.blprc;
    order.bpprc = input.bpprc;
    order.ret = input.ret;
    order.dscqty = input.dscqty;

    await _save();

    return ModifyOrderModel(
      stat: 'Ok',
      result: input.orderNum,
      requestTime: _nowTimestamp(),
    );
  }

  // ── Order History ───────────────────────────────────────────────

  List<OrderHistoryModel> getOrderHistory(String orderNo) {
    final order = _orders.firstWhere(
      (o) => o.norenordno == orderNo,
      orElse: () => OrderBookModel(stat: 'Not_Ok', emsg: 'Order not found'),
    );

    if (order.stat == 'Not_Ok') {
      return [OrderHistoryModel(stat: 'Not_Ok', emsg: 'Order not found')];
    }

    // Generate history entries based on order status
    final List<OrderHistoryModel> history = [];

    // Entry 1: Order placed
    history.add(OrderHistoryModel(
      stat: 'Ok',
      norenordno: order.norenordno,
      uid: 'PAPER',
      actid: 'PAPER',
      exch: order.exch,
      tsym: order.tsym,
      qty: order.qty,
      trantype: order.trantype,
      prctyp: order.prctyp,
      ret: order.ret,
      prd: order.prd,
      sPrdtAli: order.sPrdtAli,
      status: 'PENDING',
      rpt: 'New',
      ordenttm: order.ordenttm,
      norentm: order.norentm,
      prc: order.prc,
      token: order.token,
      ordersource: 'WEB',
    ));

    // Entry 2: Final status
    if (order.status == 'COMPLETE') {
      history.add(OrderHistoryModel(
        stat: 'Ok',
        norenordno: order.norenordno,
        uid: 'PAPER',
        actid: 'PAPER',
        exch: order.exch,
        tsym: order.tsym,
        qty: order.qty,
        trantype: order.trantype,
        prctyp: order.prctyp,
        ret: order.ret,
        prd: order.prd,
        sPrdtAli: order.sPrdtAli,
        status: 'COMPLETE',
        rpt: 'Fill',
        ordenttm: order.ordenttm,
        norentm: order.exchTm ?? order.norentm,
        prc: order.avgprc,
        token: order.token,
        ordersource: 'WEB',
      ));
    } else if (order.status == 'CANCELLED') {
      history.add(OrderHistoryModel(
        stat: 'Ok',
        norenordno: order.norenordno,
        uid: 'PAPER',
        actid: 'PAPER',
        exch: order.exch,
        tsym: order.tsym,
        qty: order.qty,
        trantype: order.trantype,
        prctyp: order.prctyp,
        ret: order.ret,
        prd: order.prd,
        sPrdtAli: order.sPrdtAli,
        status: 'CANCELLED',
        rpt: 'Cancelled',
        ordenttm: order.ordenttm,
        norentm: order.norentm,
        prc: order.prc,
        token: order.token,
        ordersource: 'WEB',
      ));
    }

    return history;
  }

  // ── Get Order Book (matches API return shape) ───────────────────

  Map<String, dynamic> getOrderBook() {
    if (_orders.isEmpty) {
      return {"stat": "no data", "data": <OrderBookModel>[]};
    }
    return {"stat": "success", "data": List<OrderBookModel>.from(_orders)};
  }

  // ── Get Trade Book (matches API return shape) ───────────────────

  Map<String, dynamic> getTradeBook() {
    if (_trades.isEmpty) {
      return {"stat": "no data", "data": <TradeBookModel>[]};
    }
    return {"stat": "success", "data": List<TradeBookModel>.from(_trades)};
  }

  // ── LTP Update: Match Pending Orders ────────────────────────────

  /// Called when LTP updates arrive. Checks all PENDING orders
  /// and executes any that now qualify for fill.
  Future<bool> onLtpUpdate(String tsym, double ltp) async {
    bool anyFilled = false;

    for (final order in _orders) {
      if (order.status != 'PENDING') continue;
      if (order.tsym != tsym) continue;

      final double price = double.tryParse(order.prc ?? '0') ?? 0;
      final double triggerPrice = double.tryParse(order.trgprc ?? '0') ?? 0;

      switch (order.prctyp) {
        case 'LMT':
          if (order.trantype == 'B' && ltp <= price) {
            await _executeOrder(order, price);
            anyFilled = true;
          } else if (order.trantype == 'S' && ltp >= price) {
            await _executeOrder(order, price);
            anyFilled = true;
          }
          break;

        case 'SL-MKT':
          if (triggerPrice > 0) {
            if (order.trantype == 'B' && ltp >= triggerPrice) {
              await _executeOrder(order, ltp);
              anyFilled = true;
            } else if (order.trantype == 'S' && ltp <= triggerPrice) {
              await _executeOrder(order, ltp);
              anyFilled = true;
            }
          }
          break;

        case 'SL-LMT':
          if (triggerPrice > 0) {
            bool triggered = false;
            if (order.trantype == 'B' && ltp >= triggerPrice) triggered = true;
            if (order.trantype == 'S' && ltp <= triggerPrice) triggered = true;

            if (triggered && price > 0) {
              await _executeOrder(order, price);
              anyFilled = true;
            }
          }
          break;
      }
    }

    if (anyFilled) await _save();
    return anyFilled;
  }

  /// Token-based variant for real WebSocket ticks. No-op unless a PENDING
  /// order exists for the token.
  Future<bool> onLtpUpdateByToken(String token, double ltp) async {
    String? tsym;
    for (final o in _orders) {
      if (o.status == 'PENDING' && o.token == token) {
        tsym = o.tsym;
        break;
      }
    }
    if (tsym == null) return false;
    return onLtpUpdate(tsym, ltp);
  }

  // ── Exit SNO Order ──────────────────────────────────────────────

  Future<CancelOrderModel> exitSNOOrder(String orderNo, String prd) async {
    return cancelOrder(orderNo);
  }

  // ── Reset ───────────────────────────────────────────────────────

  Future<void> reset() async {
    _orders.clear();
    _trades.clear();
    _orderCounter = 0;
    await _save();
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String _getProductAlias(String prd) {
    switch (prd) {
      case 'C':
        return 'CNC';
      case 'I':
        return 'MIS';
      case 'M':
        return 'NRML';
      case 'F':
        return 'MTF';
      case 'B':
        return 'BO';
      case 'H':
        return 'CO';
      default:
        return prd;
    }
  }

  /// Calculate net position qty for a symbol from completed trades.
  /// Positive = long, negative = short, 0 = flat.
  int _getNetPosition(String exch, String tsym, String prd) {
    int netQty = 0;
    for (final trade in _trades) {
      if (trade.exch == exch && trade.tsym == tsym && trade.prd == prd) {
        final int tQty = int.tryParse(trade.flqty ?? trade.qty ?? '0') ?? 0;
        if (trade.trantype == 'B') {
          netQty += tQty;
        } else {
          netQty -= tQty;
        }
      }
    }
    return netQty;
  }

  /// Check if exchange is F&O (derivatives).
  bool _isFnOExchange(String exch) {
    return exch == 'NFO' || exch == 'BFO' || exch == 'MCX' || exch == 'CDS';
  }

  /// Estimate margin required for an order.
  /// BUY equity: full cost (qty * price).
  /// BUY F&O: premium cost (qty * price).
  /// SELL F&O (option writing): ~10x premium as approximate SPAN margin.
  ///
  /// Real SPAN margin for NIFTY option writing is typically ~10x the premium
  /// (e.g., SELL 65 qty @ 245 premium → real margin ≈ 1,55,640).
  double _estimateMarginRequired({
    required String exch,
    required String trantype,
    required double qty,
    required double price,
  }) {
    final double orderValue = qty * price;

    if (!_isFnOExchange(exch)) {
      // Equity: full cost for BUY
      return orderValue;
    }

    if (trantype == 'B') {
      // F&O BUY (option buying): pay the premium
      return orderValue;
    }

    // F&O SELL (option/future writing): use ~10x premium as SPAN estimate.
    // Real SPAN uses underlying price, volatility, etc. but 10x premium
    // is a close approximation for near-ATM options observed from live API.
    return orderValue * 10;
  }
}

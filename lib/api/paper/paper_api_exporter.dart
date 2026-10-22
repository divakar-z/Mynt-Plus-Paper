import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/auth_model/desk_logout_model.dart';
import '../../models/auth_model/logout_model.dart';
import '../../models/auth_model/mobile_login_model.dart';
import '../../models/auth_model/mobile_otp_model.dart';
import '../../models/order_book_model/cancel_order_model.dart';
import '../../models/order_book_model/get_brokerage.dart';
import '../../models/order_book_model/modify_order_model.dart';
import '../../models/order_book_model/order_history_model.dart';
import '../../models/order_book_model/order_margin_model.dart';
import '../../models/order_book_model/place_order_model.dart';
import '../../models/portfolio_model/position_convertion_model.dart';
import '../../models/profile_model/fund_detial_model.dart';
import '../../models/profile_model/hs_token_model.dart';
import '../core/api_export.dart';
import 'paper_ltp_service.dart';
import 'paper_order_engine.dart';
import 'paper_portfolio_service.dart';
import 'paper_safety_guard.dart';
import 'virtual_wallet.dart';

/// Drop-in replacement for ApiExporter that intercepts all trading operations
/// and routes them through local paper trading logic.
///
/// Market data methods (watchlists, quotes, charts, search, option chain)
/// are NOT overridden — they still hit real APIs so users see live prices.
///
/// Register this in GetIt instead of ApiExporter when paper trading is enabled.
class PaperApiExporter extends ApiExporter with PaperSafetyGuard {
  // ════════════════════════════════════════════════════════════════
  //  AUTHENTICATION — mock login, always succeed
  // ════════════════════════════════════════════════════════════════

  @override
  Future<MobileLoginModel?> getMobileLogin({
    required String uniqueId,
    required String mobileRclient,
    required String password,
    required String imei,
    required bool totp,
    required BuildContext context,
  }) async {
    // Simulate successful login — return OTP stage
    return MobileLoginModel.fromJson({
      'stat': 'Ok',
      'msg': 'OTP sent successfully',
      'otp': '123456',
      'emsg': '',
    });
  }

  @override
  Future<MobileOtpModel?> getMobileOtp({
    required String uniqueId,
    required String mobileRclient,
    required String imei,
    required String otp,
    required BuildContext context,
  }) async {
    // Simulate successful OTP verification
    return MobileOtpModel.fromJson({
      'stat': 'Ok',
      'clientid': 'PAPER_USER',
      'apitoken': 'paper_token_${DateTime.now().millisecondsSinceEpoch}',
      'token': 'paper_session_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Paper Trader',
      'mobile': '9999999999',
      'source': 'WEB',
      'url': '',
      'wss': '',
      'emsg': '',
    });
  }

  @override
  Future<LogoutModel?> getLogout() async {
    return LogoutModel(stat: 'Ok', requestTime: DateTime.now().toString());
  }

  @override
  Future<DeskLogoutModel?> getDeskLogout() async {
    return DeskLogoutModel(msg: 'Logged out successfully');
  }

  // ════════════════════════════════════════════════════════════════
  //  ORDER PLACEMENT — route to PaperOrderEngine
  // ════════════════════════════════════════════════════════════════

  @override
  Future<PlaceOrderModel> getPlaceOrder(
      PlaceOrderInput placeOrderInput, String ip) async {
    // For market orders, determine a reasonable fill price.
    // The prc field may be "0" (standard for MKT orders in real API).
    // We need actual LTP from the input or a fallback.
    String currentLtp = placeOrderInput.prc;
    if (placeOrderInput.prctype == 'MKT' ||
        placeOrderInput.prctype == 'SL-MKT') {
      if (placeOrderInput.prc.isEmpty ||
          placeOrderInput.prc == '0' ||
          placeOrderInput.prc == '0.00') {
        // Use the LTP from PaperLtpService if available
        if (placeOrderInput.token != null &&
            placeOrderInput.token!.isNotEmpty) {
          final simLtp =
              PaperLtpService.instance.getLtp(placeOrderInput.token!);
          if (simLtp != null && simLtp != '0' && simLtp != '0.00') {
            currentLtp = simLtp;
          }
        }
        // No live price: reject rather than filling at a made-up price
        if (currentLtp == '0' || currentLtp == '0.00' || currentLtp.isEmpty) {
          return PlaceOrderModel.fromJson({
            'stat': 'Not_Ok',
            'emsg': 'Live price not available. Please try again.',
          });
        }
      }
    }
    return PaperOrderEngine.instance.placeOrder(placeOrderInput, currentLtp);
  }

  // ════════════════════════════════════════════════════════════════
  //  ORDER BOOK — return local orders
  // ════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> getOrderBook() async {
    return PaperOrderEngine.instance.getOrderBook();
  }

  // ════════════════════════════════════════════════════════════════
  //  TRADE BOOK — return local trades
  // ════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> getTradeBook() async {
    return PaperOrderEngine.instance.getTradeBook();
  }

  // ════════════════════════════════════════════════════════════════
  //  ORDER HISTORY — return local order history
  // ════════════════════════════════════════════════════════════════

  @override
  Future<List<OrderHistoryModel>> getOrderHistory(String orderNum) async {
    return PaperOrderEngine.instance.getOrderHistory(orderNum);
  }

  // ════════════════════════════════════════════════════════════════
  //  CANCEL ORDER — cancel from local engine
  // ════════════════════════════════════════════════════════════════

  @override
  Future<CancelOrderModel> getCancelOrder(String orderNo) async {
    return PaperOrderEngine.instance.cancelOrder(orderNo);
  }

  // ════════════════════════════════════════════════════════════════
  //  EXIT SNO ORDER — cancel from local engine
  // ════════════════════════════════════════════════════════════════

  @override
  Future<CancelOrderModel> getExitSNOOrder(String orderNo, String prd) async {
    return PaperOrderEngine.instance.exitSNOOrder(orderNo, prd);
  }

  // ════════════════════════════════════════════════════════════════
  //  MODIFY ORDER — modify in local engine
  // ════════════════════════════════════════════════════════════════

  @override
  Future<ModifyOrderModel> getModifyOrder(
      ModifyOrderInput input, String ip) async {
    return PaperOrderEngine.instance.modifyOrder(input);
  }

  // ════════════════════════════════════════════════════════════════
  //  ORDER MARGIN — return simulated margin from wallet
  // ════════════════════════════════════════════════════════════════

  @override
  Future<OrderMarginModel> getOrderMargin(OrderMarginInput input) async {
    final double qty = double.tryParse(input.qty) ?? 0;
    final double prc = double.tryParse(input.prc) ?? 0;
    final double available = VirtualWallet.instance.balance;

    // Estimate margin based on instrument type and existing position
    final bool isFnO = input.exch == 'NFO' ||
        input.exch == 'BFO' ||
        input.exch == 'MCX' ||
        input.exch == 'CDS';

    // Check existing position to determine closing vs opening
    final trades = PaperOrderEngine.instance.trades;
    int existingNetQty = 0;
    for (final trade in trades) {
      if (trade.exch == input.exch && trade.tsym == input.tsym) {
        final int tQty = int.tryParse(trade.flqty ?? trade.qty ?? '0') ?? 0;
        if (trade.trantype == 'B') {
          existingNetQty += tQty;
        } else {
          existingNetQty -= tQty;
        }
      }
    }

    double orderMargin;
    final int orderQty = qty.toInt();

    if (input.trantype == 'B') {
      // BUY: closing short portion costs nothing, opening long costs full price
      final int closingQty = (existingNetQty < 0) ? min(orderQty, -existingNetQty) : 0;
      final int openingQty = orderQty - closingQty;
      orderMargin = openingQty * prc;
    } else {
      // SELL: closing long portion costs nothing
      final int closingQty = (existingNetQty > 0) ? min(orderQty, existingNetQty) : 0;
      final int openingQty = orderQty - closingQty;
      if (isFnO && openingQty > 0) {
        // F&O short opening: ~10x premium as SPAN margin estimate
        orderMargin = openingQty * prc * 10;
      } else {
        orderMargin = openingQty * prc;
      }
    }

    // Check if funds are sufficient and set remarks accordingly
    final String remarks =
        available < orderMargin ? 'Insufficient Balance' : 'Paper Trading';

    return OrderMarginModel(
      stat: 'Ok',
      requestTime: DateTime.now().toString(),
      cash: available.toStringAsFixed(2),
      marginused: orderMargin.toStringAsFixed(2),
      marginusedprev: '0.00',
      marginusedtrade: orderMargin.toStringAsFixed(2),
      ordermargin: orderMargin.toStringAsFixed(2),
      remarks: remarks,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BROKERAGE — return zero brokerage for paper trading
  // ════════════════════════════════════════════════════════════════

  @override
  Future<GetBrokerageModel> getBrokerage(BrokerageInput input) async {
    return GetBrokerageModel(
      stat: 'Ok',
      requestTime: DateTime.now().toString(),
      brkageAmt: '0.00',
      sttAmt: '0.00',
      exchChrg: '0.00',
      sebiChrg: '0.00',
      stampDuty: '0.00',
      clrChrg: '0.00',
      gst: '0.00',
      ipftAmt: '0.00',
      cmAmt: '0.00',
      totChrg: '0.00',
      remarks: 'Paper Trading - No charges',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HOLDINGS — return computed holdings from trades
  // ════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> getHolding({String prd = "C"}) async {
    // Paper trading has no MTF book — only delivery (C) holdings exist.
    if (prd != "C") return {"stat": "no data", "data": []};
    return PaperPortfolioService.instance.getHoldings();
  }

  // ════════════════════════════════════════════════════════════════
  //  POSITION BOOK — return computed positions from trades
  // ════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> getPositionBook() async {
    return PaperPortfolioService.instance.getPositionBook();
  }

  // ════════════════════════════════════════════════════════════════
  //  POSITION CONVERSION — mock success
  // ════════════════════════════════════════════════════════════════

  @override
  Future<PositionConvertionModel> getPositionConvertion(
      dynamic positionConvertionInput) async {
    return PositionConvertionModel(
      stat: 'Ok',
      requestTime: DateTime.now().toString(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  FUNDS — return virtual wallet balance
  // ════════════════════════════════════════════════════════════════

  @override
  Future<FundDetailModel> getFunds() async {
    final balance = VirtualWallet.instance.balance;
    final trades = PaperOrderEngine.instance.trades;

    // Compute open positions and margin metrics from trades
    double totalSpanMargin = 0;
    double totalOptionPremium = 0;
    double totalRealizedPnl = 0;

    // Aggregate positions by exch_tsym_prd
    final Map<String, _FundPositionAgg> positions = {};
    for (final trade in trades) {
      final key = '${trade.exch}_${trade.tsym}_${trade.prd}';
      positions.putIfAbsent(key, () => _FundPositionAgg(
        exch: trade.exch ?? '',
        isFnO: trade.exch == 'NFO' || trade.exch == 'BFO' ||
               trade.exch == 'MCX' || trade.exch == 'CDS',
      ));
      final int qty = int.tryParse(trade.flqty ?? trade.qty ?? '0') ?? 0;
      final double price = double.tryParse(trade.flprc ?? trade.avgprc ?? '0') ?? 0;
      if (trade.trantype == 'B') {
        positions[key]!.buyQty += qty;
        positions[key]!.buyAmt += qty * price;
      } else {
        positions[key]!.sellQty += qty;
        positions[key]!.sellAmt += qty * price;
      }
    }

    for (final pos in positions.values) {
      final int netQty = pos.buyQty - pos.sellQty;
      final int closedQty = min(pos.buyQty, pos.sellQty);
      final double buyAvg = pos.buyQty > 0 ? pos.buyAmt / pos.buyQty : 0;
      final double sellAvg = pos.sellQty > 0 ? pos.sellAmt / pos.sellQty : 0;

      // Realized P&L from closed portion
      if (closedQty > 0) {
        totalRealizedPnl += closedQty * (sellAvg - buyAvg);
      }

      // Margin for open F&O positions
      if (netQty != 0 && pos.isFnO) {
        final double avgPrice = netQty > 0 ? buyAvg : sellAvg;
        final double openValue = netQty.abs() * avgPrice;
        if (netQty < 0) {
          // Short position: SPAN margin estimate (~10x premium)
          totalSpanMargin += openValue * 10;
        }
        // Option premium blocked for open positions
        totalOptionPremium += openValue;
      }
    }

    final double marginUsed = totalSpanMargin + totalOptionPremium;
    final double availableMargin = balance;

    return FundDetailModel(
      stat: 'Ok',
      requestTime: DateTime.now().toString(),
      cash: balance.toStringAsFixed(2),
      payin: '0.00',
      payout: '0.00',
      brkcollamt: '0.00',
      unclearedcash: '0.00',
      daycash: '0.00',
      marginused: marginUsed.toStringAsFixed(2),
      span: totalSpanMargin.toStringAsFixed(2),
      expo: '0.00',
      premium: totalOptionPremium.toStringAsFixed(2),
      urmtom: '0.00',
      rpnl: totalRealizedPnl.toStringAsFixed(2),
      avlMrg: availableMargin.toStringAsFixed(2),
      totCredit: balance.toStringAsFixed(2),
      utilizedMrgn: marginUsed.toStringAsFixed(2),
      pendordval: '0.00',
      collateral: '0.00',
    );
  }

  @override
  Future<GetHsTokenModel> getHsToken() async {
    return GetHsTokenModel(
      stat: 'Ok',
      requestTime: DateTime.now().toString(),
      hstk: 'paper_hs_token',
      uid: 'PAPER_USER',
      actid: 'PAPER_USER',
      brkname: 'Paper Trading',
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  METHODS THAT REMAIN UNTOUCHED (inherited from ApiExporter):
  //
  //  - All MarketWatchApi methods (watchlists, quotes, search, charts)
  //  - All IndexApi methods
  //  - All NotificationApi methods
  //  - All StocksAPI methods (news, indices, top lists)
  //  - All BannerApi methods
  //  - All VersionApi methods
  //  - All ProfileAllDetailsApi methods
  //
  //  These still hit real APIs for live market data.
  // ════════════════════════════════════════════════════════════════
}

/// Helper for aggregating position data in getFunds().
class _FundPositionAgg {
  final String exch;
  final bool isFnO;
  int buyQty = 0;
  double buyAmt = 0;
  int sellQty = 0;
  double sellAmt = 0;

  _FundPositionAgg({required this.exch, required this.isFnO});
}

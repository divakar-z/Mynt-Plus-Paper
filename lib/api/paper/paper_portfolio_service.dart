import '../../models/order_book_model/order_book_model.dart';
import '../../models/portfolio_model/holdings_model.dart';
import '../../models/portfolio_model/position_book_model.dart';
import 'paper_order_engine.dart';

/// Builds Holdings and Positions from paper trade history.
/// No persistence needed — derives everything from PaperOrderEngine trades.
class PaperPortfolioService {
  static PaperPortfolioService? _instance;
  static PaperPortfolioService get instance {
    _instance ??= PaperPortfolioService._();
    return _instance!;
  }

  PaperPortfolioService._();

  // ── Holdings (CNC / delivery trades) ────────────────────────────

  /// Returns holdings in the same Map shape that PortfolioAPI.getHolding() returns.
  /// Provider checks result['stat'] and result['data'].
  Map<String, dynamic> getHoldings() {
    // The engine keeps newest first; averages need oldest first.
    final trades = PaperOrderEngine.instance.trades.reversed;

    // Filter only CNC/delivery trades (prd == 'C')
    final deliveryTrades = trades.where((t) => t.prd == 'C').toList();

    if (deliveryTrades.isEmpty) {
      return {"stat": "no data", "data": <HoldingsModel>[]};
    }

    // Aggregate by tsym: net qty and avg price
    final Map<String, _HoldingAgg> aggMap = {};

    for (final trade in deliveryTrades) {
      final tsym = trade.tsym ?? '';
      if (tsym.isEmpty) continue;

      final key = '${trade.exch}_$tsym';
      aggMap.putIfAbsent(key, () => _HoldingAgg(exch: trade.exch ?? '', tsym: tsym, token: trade.token ?? ''));

      final int qty = int.tryParse(trade.flqty ?? trade.qty ?? '0') ?? 0;
      final double price = double.tryParse(trade.flprc ?? trade.avgprc ?? '0') ?? 0;

      if (trade.trantype == 'B') {
        final newTotalQty = aggMap[key]!.qty + qty;
        if (newTotalQty > 0) {
          // Weighted average price
          aggMap[key]!.avgPrice =
              ((aggMap[key]!.avgPrice * aggMap[key]!.qty) + (price * qty)) /
                  newTotalQty;
        }
        aggMap[key]!.qty = newTotalQty;
      } else {
        aggMap[key]!.qty -= qty;
        // Keep avgPrice unchanged on sell
      }
    }

    // Build HoldingsModel list from aggregation (only positive qty)
    final List<HoldingsModel> holdings = [];
    for (final agg in aggMap.values) {
      if (agg.qty <= 0) continue;

      final exchTsym = ExchTsym(
        exch: agg.exch,
        token: agg.token,
        tsym: agg.tsym,
        pp: '2',
        ti: '0.05',
        ls: '1',
        lp: '0.00', // Will be updated by WebSocket
      );

      final invested = (agg.avgPrice * agg.qty).toStringAsFixed(2);

      holdings.add(HoldingsModel(
        stat: 'Ok',
        exchTsym: [exchTsym],
        upldprc: agg.avgPrice.toStringAsFixed(2),
        holdqty: agg.qty.toString(),
        dpQty: agg.qty.toString(),
        benqty: '0',
        npoadqty: '0',
        npoadt1qty: '0',
        btstqty: '0',
        brkcolqty: '0',
        usedqty: '0',
        trdqty: agg.qty.toString(),
        prd: 'C',
        sPrdtAli: 'CNC',
        invested: invested,
        currentValue: '0.00', // Updated by provider with live LTP
        totalPnL: '0.00',
        currentQty: agg.qty,
        saleableQty: agg.qty,
        avgPrc: agg.avgPrice.toStringAsFixed(2),
      ));
    }

    if (holdings.isEmpty) {
      return {"stat": "no data", "data": <HoldingsModel>[]};
    }

    return {"stat": "success", "data": holdings};
  }

  // ── Positions (Intraday / F&O trades) ───────────────────────────

  /// Returns positions in the same Map shape that PortfolioAPI.getPositionBook() returns.
  Map<String, dynamic> getPositionBook() {
    // The engine keeps newest first; averages need oldest first.
    final trades = PaperOrderEngine.instance.trades.reversed;

    // Filter intraday trades (prd != 'C')
    final intradayTrades = trades.where((t) => t.prd != 'C').toList();

    if (intradayTrades.isEmpty) {
      return {"stat": "no data", "data": <PositionBookModel>[]};
    }

    // Aggregate by exch_tsym_prd
    final Map<String, _PositionAgg> aggMap = {};

    for (final trade in intradayTrades) {
      final tsym = trade.tsym ?? '';
      if (tsym.isEmpty) continue;

      final key = '${trade.exch}_${tsym}_${trade.prd}';
      aggMap.putIfAbsent(key, () => _PositionAgg(
        exch: trade.exch ?? '',
        tsym: tsym,
        token: trade.token ?? '',
        prd: trade.prd ?? 'I',
        prdAlias: trade.sPrdtAli ?? 'MIS',
        symbol: trade.symbol,
        expDate: trade.expDate,
        option: trade.option,
        dname: trade.dname,
      ));

      final int qty = int.tryParse(trade.flqty ?? trade.qty ?? '0') ?? 0;
      final double price = double.tryParse(trade.flprc ?? trade.avgprc ?? '0') ?? 0;

      if (trade.trantype == 'B') {
        aggMap[key]!.dayBuyQty += qty;
        aggMap[key]!.dayBuyAmt += price * qty;
      } else {
        aggMap[key]!.daySellQty += qty;
        aggMap[key]!.daySellAmt += price * qty;
      }
      aggMap[key]!.applyFill(trade.trantype == 'B' ? qty : -qty, price);
    }

    // Build PositionBookModel list
    final List<PositionBookModel> positions = [];
    for (final agg in aggMap.values) {
      final int netQty = agg.dayBuyQty - agg.daySellQty;
      final double dayBuyAvg = agg.dayBuyQty > 0 ? agg.dayBuyAmt / agg.dayBuyQty : 0;
      final double daySellAvg = agg.daySellQty > 0 ? agg.daySellAmt / agg.daySellQty : 0;
      final double netAvgPrice = netQty != 0 ? agg.openAvg : 0;
      final double rpnl = agg.realized;

      positions.add(PositionBookModel(
        stat: 'Ok',
        actid: 'PAPER',
        uid: 'PAPER',
        exch: agg.exch,
        tsym: agg.tsym,
        token: agg.token,
        prd: agg.prd,
        sPrdtAli: agg.prdAlias,
        netqty: netQty.toString(),
        netavgprc: netAvgPrice.toStringAsFixed(2),
        daybuyqty: agg.dayBuyQty.toString(),
        daybuyamt: agg.dayBuyAmt.toStringAsFixed(2),
        daybuyavgprc: dayBuyAvg.toStringAsFixed(2),
        daysellqty: agg.daySellQty.toString(),
        daysellamt: agg.daySellAmt.toStringAsFixed(2),
        daysellavgprc: daySellAvg.toStringAsFixed(2),
        cfbuyqty: '0',
        cfbuyamt: '0.00',
        cfbuyavgprc: '0.00',
        cfsellqty: '0',
        cfsellamt: '0.00',
        cfsellavgprc: '0.00',
        openbuyqty: '0',
        openbuyamt: '0.00',
        openbuyavgprc: '0.00',
        opensellqty: '0',
        opensellamt: '0.00',
        opensellavgprc: '0.00',
        totbuyamt: agg.dayBuyAmt.toStringAsFixed(2),
        totbuyavgprc: dayBuyAvg.toStringAsFixed(2),
        totsellamt: agg.daySellAmt.toStringAsFixed(2),
        totsellavgprc: daySellAvg.toStringAsFixed(2),
        rpnl: rpnl.toStringAsFixed(2),
        urmtom: '0.00', // Updated by provider with live LTP
        lp: '0.00',
        pp: '2',
        ti: '0.05',
        ls: '1',
        mult: '1',
        prcftr: '1.00',
        upldprc: '0.00',
        netupldprc: '0.00',
        symbol: agg.symbol,
        expDate: agg.expDate,
        option: agg.option,
        dname: agg.dname,
      ));
    }

    if (positions.isEmpty) {
      return {"stat": "no data", "data": <PositionBookModel>[]};
    }

    return {"stat": "success", "data": positions};
  }

  // ── Get open (pending) orders for a symbol ──────────────────────

  List<OrderBookModel> getPendingOrdersForSymbol(String tsym) {
    return PaperOrderEngine.instance.orders
        .where((o) => o.tsym == tsym && o.status == 'PENDING')
        .toList();
  }

  // ── Reset ───────────────────────────────────────────────────────

  Future<void> reset() async {
    await PaperOrderEngine.instance.reset();
  }
}

// ── Aggregation helpers ─────────────────────────────────────────

class _HoldingAgg {
  final String exch;
  final String tsym;
  final String token;
  int qty = 0;
  double avgPrice = 0;

  _HoldingAgg({required this.exch, required this.tsym, required this.token});
}

class _PositionAgg {
  final String exch;
  final String tsym;
  final String token;
  final String prd;
  final String prdAlias;
  final String? symbol;
  final String? expDate;
  final String? option;
  final String? dname;
  int dayBuyQty = 0;
  double dayBuyAmt = 0;
  int daySellQty = 0;
  double daySellAmt = 0;

  /// Signed open quantity, its average cost, and profit already booked.
  int openQty = 0;
  double openAvg = 0;
  double realized = 0;

  /// [signedQty] is positive for a buy. Closing fills book P&L against the
  /// average cost; anything beyond the open quantity starts a new position.
  void applyFill(int signedQty, double price) {
    final bool closes = openQty != 0 && (openQty > 0) != (signedQty > 0);
    if (closes) {
      final int closing =
          signedQty.abs() < openQty.abs() ? signedQty.abs() : openQty.abs();
      realized += closing * (price - openAvg) * (openQty > 0 ? 1 : -1);
      openQty += openQty > 0 ? -closing : closing;
      signedQty += signedQty > 0 ? -closing : closing;
      if (openQty == 0) openAvg = 0;
    }
    if (signedQty != 0) {
      final int total = openQty.abs() + signedQty.abs();
      openAvg = (openAvg * openQty.abs() + price * signedQty.abs()) / total;
      openQty += signedQty;
    }
  }

  _PositionAgg({
    required this.exch,
    required this.tsym,
    required this.token,
    required this.prd,
    required this.prdAlias,
    this.symbol,
    this.expDate,
    this.option,
    this.dname,
  });
}

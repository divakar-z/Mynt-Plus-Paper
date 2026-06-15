import 'package:mynt_plus/models/marketwatch_model/alert_model/alert_pending_model.dart';
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/option_underlying_match.dart';

/// Open-orders predicate — mirrors `OrderProvider` lines 1483-1491.
bool isOpenOrder(OrderBookModel o) =>
    o.stat == 'Ok' &&
    o.status != 'REJECTED' &&
    o.status != 'CANCELED' &&
    o.status != 'COMPLETE' &&
    o.status != 'INVALID_STATUS_TYPE';

/// Looks up the open net position for `(exch, token)` and computes the P&L
/// that would be realized if a closing order at `exitPrice` for `orderQty`
/// units fires. Returns `null` if no opposite-direction open position
/// matches the order (i.e. it's a fresh order, not a TP/SL on a position).
///
/// `orderTrantype` is 'B' (Buy) or 'S' (Sell). A long position (`netqty > 0`)
/// matches with a SELL closing order; a short position matches with a BUY.
double? _projectedClosePnl({
  required List<PositionBookModel> positions,
  required String exch,
  required String token,
  required String orderTrantype,
  required int orderQty,
  required double exitPrice,
}) {
  if (orderQty <= 0 || exitPrice <= 0) return null;
  for (final p in positions) {
    if (p.exch != exch || p.token != token) continue;
    final netQty = int.tryParse(p.netqty ?? '0') ?? 0;
    if (netQty == 0) continue;
    final isLong = netQty > 0;
    // Order must be in the CLOSING direction for the position.
    if (isLong && orderTrantype != 'S') continue;
    if (!isLong && orderTrantype != 'B') continue;
    final avg = double.tryParse(p.netavgprc ?? '') ?? 0;
    if (avg <= 0) continue;
    final closeQty = orderQty < netQty.abs() ? orderQty : netQty.abs();
    final directionSign = isLong ? 1 : -1;
    return (exitPrice - avg) * closeQty * directionSign;
  }
  return null;
}

/// Computes the chart-overlay list for a single pane, given its scrip and the
/// current positions + orders. Returns an empty list when scrip is null.
List<Map<String, Object?>> overlaysForPane({
  required ChartScrip? scrip,
  required List<PositionBookModel> positions,
  required List<OrderBookModel> orders,
  required List<AlertPendingModel> alerts,
  List<GttOrderBookModel> ocoOrders = const [],
}) {
  if (scrip == null) return const [];
  final exch = scrip.exch;
  final token = scrip.token;
  final out = <Map<String, Object?>>[];

  for (final p in positions) {
    if (p.exch != exch || p.token != token) continue;
    final qty = int.tryParse(p.netqty ?? '0') ?? 0;
    if (qty == 0) continue;
    final avg = double.tryParse(p.netavgprc ?? '') ?? 0;
    final pnl = double.tryParse(p.mTm ?? '') ?? 0;
    final pnlPct = (avg > 0 && qty != 0) ? (pnl / (avg * qty.abs())) * 100 : 0.0;
    out.add({
      'id': 'pos-$exch-$token',
      'kind': 'position',
      'side': qty > 0 ? 'buy' : 'sell',
      'qty': qty,
      'price': avg,
      'pnl': pnl,
      'pnlPct': pnlPct,
    });
  }

  // Phase 17.A — surface OPTION positions on the UNDERLYING index chart.
  // When the user holds e.g. NIFTY 25250 CE and the pane shows NIFTY spot,
  // we emit a horizontal overlay at strike 25250 with the option's live
  // P&L and a close × that squares off THE OPTION (not the underlying).
  for (final p in positions) {
    final qty = int.tryParse(p.netqty ?? '0') ?? 0;
    if (qty == 0) continue;
    // Skip if this position is on the same scrip as the pane — the regular
    // 'position' kind loop above already handles those.
    if (p.exch == exch && p.token == token) continue;
    ParsedOption? parsed;
    final matched = positionOptionMatchesPane(
      paneScrip: scrip,
      pos: p,
      parsedOut: (po) => parsed = po,
    );
    if (!matched || parsed == null) continue;
    final pnl = double.tryParse(p.mTm ?? '') ?? 0;
    // ID embeds the OPTION's exch+token so the shell's close handler can
    // route the square-off to the right scrip.
    //
    // The nullability guard below is load-bearing: `PositionBookModel.exch`
    // and `.token` are typed `String?`, and the earlier same-scrip skip
    // (`p.exch == exch`) compares nullable against non-null without
    // dereferencing, so a null exch/token would silently produce a malformed
    // 'optStrike--' id. The close handler depends on the format being
    // 'optStrike-<exch>-<token>' with both fields non-empty.
    final posExch = p.exch ?? '';
    final posToken = p.token ?? '';
    if (posExch.isEmpty || posToken.isEmpty) continue;
    out.add({
      'id': 'optStrike-$posExch-$posToken',
      'kind': 'optionStrike',
      'side': qty > 0 ? 'buy' : 'sell',
      'qty': qty,
      'price': parsed!.strike,
      'pnl': pnl,
      'optionLabel': parsed!.shortLabel,
    });
  }

  for (final o in orders) {
    if (o.exch != exch || o.token != token) continue;
    if (!isOpenOrder(o)) continue;
    final id = o.norenordno ?? '';
    final isBuy = o.trantype == 'B';
    final qtyRaw = int.tryParse(o.qty ?? '0') ?? 0;
    final signedQty = isBuy ? qtyRaw : -qtyRaw;
    final prctyp = o.prctyp ?? '';
    if (prctyp == 'LMT') {
      final price = double.tryParse(o.prc ?? '') ?? 0;
      final projPnl = _projectedClosePnl(
        positions: positions,
        exch: exch,
        token: token,
        orderTrantype: o.trantype ?? '',
        orderQty: qtyRaw,
        exitPrice: price,
      );
      out.add({
        'id': 'ord-$id',
        'kind': projPnl != null ? 'tp' : 'limit',
        'side': isBuy ? 'buy' : 'sell',
        'qty': signedQty,
        'price': price,
        if (projPnl != null) 'projectedPnl': projPnl,
      });
    } else if (prctyp == 'SL-MKT' || prctyp == 'SL-LMT') {
      final trg = double.tryParse(o.trgprc ?? '') ?? 0;
      final projTrgPnl = _projectedClosePnl(
        positions: positions,
        exch: exch,
        token: token,
        orderTrantype: o.trantype ?? '',
        orderQty: qtyRaw,
        exitPrice: trg,
      );
      out.add({
        'id': 'sl-$id',
        'kind': 'sl',
        'side': isBuy ? 'buy' : 'sell',
        'qty': signedQty,
        'price': trg,
        if (projTrgPnl != null) 'projectedPnl': projTrgPnl,
      });
      if (prctyp == 'SL-LMT') {
        final lim = double.tryParse(o.prc ?? '') ?? 0;
        final projLimPnl = _projectedClosePnl(
          positions: positions,
          exch: exch,
          token: token,
          orderTrantype: o.trantype ?? '',
          orderQty: qtyRaw,
          exitPrice: lim,
        );
        out.add({
          'id': 'sl-l-$id',
          'kind': 'sl-l',
          'side': isBuy ? 'buy' : 'sell',
          'qty': signedQty,
          'price': lim,
          if (projLimPnl != null) 'projectedPnl': projLimPnl,
        });
      }
    }
  }

  for (final a in alerts) {
    if (a.exch != exch || a.token != token) continue;
    // Alert target price lives in `d`. The `pp` field is "price
    // precision" (decimal count e.g. "2") — using it here was the cause
    // of every alert line rendering at price 2 / off-chart.
    final price = double.tryParse(a.d ?? '');
    if (price == null || price <= 0) continue;
    final aiT = a.aiT ?? '';
    out.add({
      'id': 'alert-${a.alId ?? ''}',
      'kind': 'alert',
      'side': aiT == 'LTP_A' ? 'buy' : 'sell',
      'qty': 0,
      'price': price,
    });
  }

  // OCO brackets (GTT) for this scrip. Each OCO carries two legs:
  //   oivariable[0] / leg1 → TARGET (TP, green dashed)
  //   oivariable[1] / leg2 → STOP   (SL, red)
  // Both share the same al_id so the chart can route a drag-modify to the
  // right leg (ModifyOCOOrder) and a cancel to the whole OCO. Projected
  // P&L is shown when the bracket sits against a matching open position.
  for (final g in ocoOrders) {
    if (g.exch != exch || g.token != token) continue;
    if (g.placeOrderParamsLeg2 == null) continue; // single GTT, not an OCO
    final alId = g.alId ?? '';
    if (alId.isEmpty) continue;
    final ov = g.oivariable;
    if (ov == null || ov.length < 2) continue;
    final tpPrice = double.tryParse(ov[0].d ?? '');
    final slPrice = double.tryParse(ov[1].d ?? '');
    final leg1 = g.placeOrderParams;
    final leg2 = g.placeOrderParamsLeg2;
    final tpTrantype = leg1?.trantype ?? g.trantype ?? '';
    final slTrantype = leg2?.trantype ?? g.trantype ?? '';
    final tpQtyRaw = leg1?.qty ?? g.qty ?? 0;
    final slQtyRaw = leg2?.qty ?? 0;
    final isBuy = tpTrantype == 'B';
    if (tpPrice != null && tpPrice > 0) {
      final projPnl = _projectedClosePnl(
        positions: positions,
        exch: exch,
        token: token,
        orderTrantype: tpTrantype,
        orderQty: tpQtyRaw,
        exitPrice: tpPrice,
      );
      out.add({
        'id': 'ocoTp-$alId',
        'kind': 'ocoTp',
        'side': isBuy ? 'buy' : 'sell',
        'qty': isBuy ? tpQtyRaw : -tpQtyRaw,
        'price': tpPrice,
        if (projPnl != null) 'projectedPnl': projPnl,
      });
    }
    if (slPrice != null && slPrice > 0) {
      final projPnl = _projectedClosePnl(
        positions: positions,
        exch: exch,
        token: token,
        orderTrantype: slTrantype,
        orderQty: slQtyRaw,
        exitPrice: slPrice,
      );
      out.add({
        'id': 'ocoSl-$alId',
        'kind': 'ocoSl',
        'side': slTrantype == 'B' ? 'buy' : 'sell',
        'qty': slTrantype == 'B' ? slQtyRaw : -slQtyRaw,
        'price': slPrice,
        if (projPnl != null) 'projectedPnl': projPnl,
      });
    }
  }

  return out;
}

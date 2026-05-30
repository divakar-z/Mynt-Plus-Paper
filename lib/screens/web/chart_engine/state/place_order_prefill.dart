import 'package:flutter/foundation.dart';
import 'package:mynt_plus/models/marketwatch_model/scrip_info.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';

/// Variants of an order pre-fill — used by the chart-overlay layer when
/// opening the existing `PlaceOrderScreenWeb` from a chip / menu item.
enum OrderPrefillKind {
  buyLimit,
  sellLimit,
  buyStopMkt,
  sellStopMkt,
  buyStopLmt,
  sellStopLmt,
  blank, // "Create new order…" — symbol + qty only, no side / type / price
}

/// Builds the `arguments` Map for `ResponsiveNavigation.toPlaceOrderScreen`.
///
/// The launcher (`lib/utils/responsive_navigation.dart`) unpacks the Map and
/// passes `orderArg` + `scripInfo` as TYPED objects to `PlaceOrderScreenWeb`,
/// so this function constructs `OrderScreenArgs` + `ScripInfoModel` directly
/// — passing raw Maps causes a null-check crash inside the screen's initState.
Map<String, dynamic> buildOrderScreenArgs({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  double? price,
  ScripInfoModel? realScripInfo,
}) {
  String? prctyp;
  bool isBuy = true; // default for blank/create-new-order
  double? prc;
  double? trgprc;
  switch (kind) {
    case OrderPrefillKind.buyLimit:
      prctyp = 'LMT';
      isBuy = true;
      prc = price;
      break;
    case OrderPrefillKind.sellLimit:
      prctyp = 'LMT';
      isBuy = false;
      prc = price;
      break;
    case OrderPrefillKind.buyStopMkt:
      prctyp = 'SL-MKT';
      isBuy = true;
      trgprc = price;
      break;
    case OrderPrefillKind.sellStopMkt:
      prctyp = 'SL-MKT';
      isBuy = false;
      trgprc = price;
      break;
    case OrderPrefillKind.buyStopLmt:
      prctyp = 'SL-LMT';
      isBuy = true;
      trgprc = price;
      prc = price != null ? price + scrip.ti : null;
      break;
    case OrderPrefillKind.sellStopLmt:
      prctyp = 'SL-LMT';
      isBuy = false;
      trgprc = price;
      prc = price != null ? price - scrip.ti : null;
      break;
    case OrderPrefillKind.blank:
      break;
  }

  // PlaceOrderScreenWeb's initState treats a non-empty `raw` as "the caller
  // is supplying every field" and reads each one literally — missing keys
  // collapse to bad defaults that get sent to the server:
  //   - `ret` missing → '' → server rejects "Invalid order duration"
  //   - `prd` missing → InvestType.carryForward → NRML, which equity
  //     exchanges reject ("Product NRML not enabled on exchange NSE")
  // Pick the right product code based on the exchange: NSE/BSE equity →
  // 'C' (CNC); everything else (NFO/BFO/MCX/derivatives) → 'M' (NRML).
  final isEquity = scrip.exch == 'NSE' || scrip.exch == 'BSE';
  final defaultPrd = isEquity ? 'C' : 'M';
  final raw = <String, dynamic>{
    if (prctyp != null) 'prctyp': prctyp,
    'qty': qty.toString(),
    if (prc != null) 'prc': prc.toStringAsFixed(2),
    if (trgprc != null) 'trgprc': trgprc.toStringAsFixed(2),
    'ret': 'DAY',
    'prd': defaultPrd,
  };

  // Display price for the screen's price field; prefer limit, else trigger,
  // else fall back to "0" so the LTP field has a usable initial value.
  final displayLtp = (prc ?? trgprc)?.toStringAsFixed(2) ?? '0';

  final orderArg = OrderScreenArgs(
    exchange: scrip.exch,
    token: scrip.token,
    tSym: scrip.tsym,
    transType: isBuy,
    perChange: '0',
    lotSize: scrip.ls.toString(),
    ltp: displayLtp,
    isExit: false,
    orderTpye: '',
    isModify: false,
    raw: raw,
    holdQty: '',
  );

  // Prefer the real ScripInfoModel from the marketwatch API cache — it has
  // the populated fields (symbol/expDate/option/instname/seg/frzqty/lc/uc)
  // that PlaceOrderScreenWeb's build() dereferences with `!`. If absent,
  // fall back to a sparse synthetic one so the screen still opens (some
  // fields will render blank but it won't crash).
  final scripInfo = realScripInfo ??
      (ScripInfoModel()
        ..exch = scrip.exch
        ..token = scrip.token
        ..tsym = scrip.tsym
        ..dname = scrip.dispName
        ..ls = scrip.ls.toString()
        ..ti = scrip.ti.toString()
        ..symbol = scrip.tsym
        ..symname = scrip.dispName
        ..expDate = ''
        ..option = ''
        ..instname = ''
        ..seg = ''
        ..frzqty = '0'
        ..lc = '0.00'
        ..uc = '0.00'
        ..ordMsg = ''
        ..lp = displayLtp
        ..mult = '1'
        ..prcftrD = '1');

  return {
    'orderArg': orderArg,
    'scripInfo': scripInfo,
    'isBskt': '',
    'fromChart': true,
  };
}

/// Builds a typed `PlaceOrderInput` for instant-mode placement from the
/// chart `+` menu. Mirror of `buildOrderScreenArgs` minus the
/// ScripInfoModel — we only need the order side itself.
///
/// `deviceInfo` should come from `ref.read(authProvider).deviceInfo`.
PlaceOrderInput buildPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required OrderPrefillKind kind,
  required double price,
  required Map<String, dynamic> deviceInfo,
}) {
  String prctype = 'LMT';
  bool isBuy = true;
  double? prc = price;
  double? trgprc;
  switch (kind) {
    case OrderPrefillKind.buyLimit:
      prctype = 'LMT';
      isBuy = true;
      prc = price;
      break;
    case OrderPrefillKind.sellLimit:
      prctype = 'LMT';
      isBuy = false;
      prc = price;
      break;
    case OrderPrefillKind.buyStopMkt:
      prctype = 'SL-MKT';
      isBuy = true;
      prc = null;
      trgprc = price;
      break;
    case OrderPrefillKind.sellStopMkt:
      prctype = 'SL-MKT';
      isBuy = false;
      prc = null;
      trgprc = price;
      break;
    case OrderPrefillKind.buyStopLmt:
      prctype = 'SL-LMT';
      isBuy = true;
      trgprc = price;
      prc = price + scrip.ti;
      break;
    case OrderPrefillKind.sellStopLmt:
      prctype = 'SL-LMT';
      isBuy = false;
      trgprc = price;
      prc = price - scrip.ti;
      break;
    case OrderPrefillKind.blank:
      // Should never be called for instant mode — the caller must filter.
      break;
  }

  final isEquity = scrip.exch == 'NSE' || scrip.exch == 'BSE';
  final prd = isEquity ? 'C' : 'M';
  final channel = defaultTargetPlatform == TargetPlatform.android
      ? '${deviceInfo["brand"]}'
      : '${deviceInfo["model"]}';

  return PlaceOrderInput(
    exch: scrip.exch,
    tsym: scrip.tsym,
    qty: qty.toString(),
    prc: (prc ?? 0).toStringAsFixed(2),
    prctype: prctype,
    trantype: isBuy ? 'B' : 'S',
    prd: prd,
    ret: 'DAY',
    trgprc: trgprc != null ? trgprc.toStringAsFixed(2) : '',
    blprc: '',
    bpprc: '',
    dscqty: '',
    amo: '',
    trailprc: '',
    mktProt: '',
    channel: channel,
    frzqty: 0,
  );
}

// Default percentage offsets from position avg for the chart's quick
// TP / SL buttons. These are the STARTING values pre-filled into
// PlaceOrderScreen — the user always reviews and can adjust before
// submitting (TP/SL never fire instantly, regardless of the Instant
// toggle — opening exposure deserves a deliberate confirmation).
const double _defaultTpPct = 0.03; // 3% — favourable side
const double _defaultSlPct = 0.015; // 1.5% — protective side

double _snapToTick(double price, double ti) {
  if (ti <= 0) return price;
  return (price / ti).round() * ti;
}

double tpPriceFromAvg({
  required double avg,
  required bool isLong,
  double ti = 0.05,
}) {
  final raw =
      isLong ? avg * (1 + _defaultTpPct) : avg * (1 - _defaultTpPct);
  return _snapToTick(raw, ti);
}

double slTriggerFromAvg({
  required double avg,
  required bool isLong,
  double ti = 0.05,
}) {
  final raw =
      isLong ? avg * (1 - _defaultSlPct) : avg * (1 + _defaultSlPct);
  return _snapToTick(raw, ti);
}

/// Builds the `arguments` map for opening `PlaceOrderScreenWeb` pre-filled
/// to add a TP (`isTp == true`) or SL (`isTp == false`) for an existing
/// position. Side is automatically opposite of the position. Price is
/// snapped to the scrip's tick size so the exchange doesn't reject with
/// "Price not a multiple of tick size".
Map<String, dynamic> buildTpSlOrderScreenArgs({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,
  required double avg,
  ScripInfoModel? realScripInfo,
}) {
  final price = isTp
      ? tpPriceFromAvg(avg: avg, isLong: isLong, ti: scrip.ti)
      : slTriggerFromAvg(avg: avg, isLong: isLong, ti: scrip.ti);
  final kind = isTp
      ? (isLong ? OrderPrefillKind.sellLimit : OrderPrefillKind.buyLimit)
      : (isLong ? OrderPrefillKind.sellStopMkt : OrderPrefillKind.buyStopMkt);
  return buildOrderScreenArgs(
    scrip: scrip,
    qty: qty,
    kind: kind,
    price: price,
    realScripInfo: realScripInfo,
  );
}

/// Builds a typed `PlaceOrderInput` for instant-mode TP/SL placement.
PlaceOrderInput buildTpSlPlaceOrderInput({
  required ChartScrip scrip,
  required int qty,
  required bool isLong,
  required bool isTp,
  required double avg,
  required Map<String, dynamic> deviceInfo,
}) {
  final price = isTp
      ? tpPriceFromAvg(avg: avg, isLong: isLong, ti: scrip.ti)
      : slTriggerFromAvg(avg: avg, isLong: isLong, ti: scrip.ti);
  final kind = isTp
      ? (isLong ? OrderPrefillKind.sellLimit : OrderPrefillKind.buyLimit)
      : (isLong ? OrderPrefillKind.sellStopMkt : OrderPrefillKind.buyStopMkt);
  return buildPlaceOrderInput(
    scrip: scrip,
    qty: qty,
    kind: kind,
    price: price,
    deviceInfo: deviceInfo,
  );
}

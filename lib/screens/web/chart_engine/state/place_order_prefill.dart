import 'package:flutter/foundation.dart';
import 'package:mynt_plus/models/marketwatch_model/scrip_info.dart';
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/chart_engine_store.dart';
import 'package:mynt_plus/screens/web/chart_engine/state/option_underlying_match.dart';

/// Resolves the product code for an order on [scrip] from the user's Order
/// Defaults (Product Type tab), picking the right family setting:
///   equity (NSE/BSE)        → equityProduct  ('C' delivery | 'I' intraday)
///   options (NFO/BFO + OPT) → optionsProduct ('M' normal   | 'I' intraday)
///   futures / other deriv.  → futuresProduct ('M' normal   | 'I' intraday)
/// Falls back to the conservative C/M split when no defaults are supplied
/// (e.g. a code path that doesn't pass them).
String resolveProduct(ChartScrip scrip, OrderDefaults? defaults) {
  final isEquity = scrip.exch == 'NSE' || scrip.exch == 'BSE';
  if (defaults == null) return isEquity ? 'C' : 'M';
  if (isEquity) return defaults.equityProduct;
  final instname = scrip.instname.toUpperCase();
  final isOption =
      instname.startsWith('OPT') || parseOptionTsym(scrip.tsym) != null;
  return isOption ? defaults.optionsProduct : defaults.futuresProduct;
}

/// Whether an order on [exch] placed *now* should be flagged AMO (After Market
/// Order) because the market is closed. Mirrors `PlaceOrderScreenWeb`'s
/// `_checkMarketClosed` so chart orders behave like the normal place-order
/// screen: MCX/NCOM close at 23:50 IST, every other exchange at 16:00 IST, and
/// the window carries past midnight until 02:00 IST for every exchange.
bool isAmoTime(String exch) {
  final nowIst =
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final minutes = nowIst.hour * 60 + nowIst.minute;
  // Checked first: the minute counter resets at midnight, so the overnight
  // stretch has to be handled before the per-exchange close times.
  if (minutes < 2 * 60) return true; // 00:00 - 01:59 IST
  if (exch == 'MCX' || exch == 'NCOM') return minutes >= 23 * 60 + 50;
  return minutes >= 16 * 60;
}

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
  // The REAL live LTP (from the shared WS feed) for this scrip. When > 0 it
  // seeds `orderArg.ltp` so PlaceOrderScreenWeb validates the trigger against
  // the actual last-traded price and shows it in the header. Without it the
  // screen fell back to the ORDER's own price as "LTP", producing a false
  // "Trigger should be greater than LTP" warning and a wrong header LTP.
  double? liveLtp,
  // Drives the product code (Delivery/Intraday/Normal) from the user's
  // Order Defaults → Product Type. Without it the order would always open
  // as CNC/NRML regardless of the user's intraday preference.
  OrderDefaults? orderDefaults,
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
  final defaultPrd = resolveProduct(scrip, orderDefaults);
  final raw = <String, dynamic>{
    if (prctyp != null) 'prctyp': prctyp,
    // PlaceOrderScreenWeb reads `raw['trantype']` to seed its Buy/Sell toggle
    // ('S' → sell, anything else → buy). Without it the screen always lands on
    // Buy regardless of which side (bid/ask, or the +-menu pick) was chosen.
    'trantype': isBuy ? 'B' : 'S',
    'qty': qty.toString(),
    if (prc != null) 'prc': prc.toStringAsFixed(2),
    if (trgprc != null) 'trgprc': trgprc.toStringAsFixed(2),
    'ret': 'DAY',
    'prd': defaultPrd,
    // Auto-flag AMO when the market is closed — PlaceOrderScreenWeb reads
    // raw['amo'] verbatim (its own auto-AMO is skipped when a prefill is
    // present), so without this a chart order placed after close is rejected.
    'amo': isAmoTime(scrip.exch) ? 'Yes' : '',
  };

  // Display price for the screen's price field; prefer limit, else trigger,
  // else fall back to "0" so the LTP field has a usable initial value.
  final displayLtp = (prc ?? trgprc)?.toStringAsFixed(2) ?? '0';

  // The value handed to the screen as "LTP". Prefer the caller-supplied live
  // LTP (used for trigger validation + header display); only fall back to the
  // order's own price when no live tick is available.
  final ltpStr =
      (liveLtp != null && liveLtp > 0) ? liveLtp.toStringAsFixed(2) : displayLtp;

  final orderArg = OrderScreenArgs(
    exchange: scrip.exch,
    token: scrip.token,
    tSym: scrip.tsym,
    transType: isBuy,
    perChange: '0',
    lotSize: scrip.ls.toString(),
    ltp: ltpStr,
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
        ..lp = ltpStr
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
  // Product from Order Defaults → Product Type (per instrument family).
  // Without it instant orders always fired as CNC/NRML, ignoring the
  // user's intraday preference.
  OrderDefaults? orderDefaults,
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

  final prd = resolveProduct(scrip, orderDefaults);
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
    // Instant orders fire directly (no PlaceOrderScreen), so AMO must be set
    // here too or an after-close instant order is rejected.
    amo: isAmoTime(scrip.exch) ? 'Yes' : '',
    trailprc: '',
    mktProt: '',
    channel: channel,
    frzqty: 0,
  );
}

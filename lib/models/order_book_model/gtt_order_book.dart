import 'package:mynt_plus/sharedWidget/functions.dart';

class GttOrderBookModel {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  /// Ready contract name for display: master name when available, else the
  /// existing symbol/expiry/option assembly (never a raw tsym).
  String get displayName =>
      masterName ??
      '${symbol?.replaceAll("-EQ", "").toUpperCase() ?? ''} ${expDate ?? ''} ${option ?? ''}';

  String? emsg;
  String? stat;
  String? aiT;
  String? alId;
  String? tsym;
  String? exch;
  String? token;
  String? remarks;
  String? validity;
  String? norentm;
  String? ordDate;
  String? pp;
  String? ls;
  String? ti;
  String? brkname;
  String? actid;
  String? trantype;
  String? prctyp;
  int? qty;
  String? prc;
  String? c;
  String? prd;
  String? ordersource;
  PlaceOrderParams? placeOrderParams;
  PlaceOrderParamsLeg2? placeOrderParamsLeg2;
  String? d;
  List<Oivariable>? oivariable;
  String? symbol;
  String? expDate;
  String? option;
  String? ltp;
  String? open;
  String? high;
  String? close;
  String? low;
  String? perChange;
  String? change;
  String? gttOrderCurrentStatus;

  GttOrderBookModel(
      {this.stat,
      this.aiT,
      this.alId,
      this.tsym,
      this.exch,
      this.token,
      this.remarks,
      this.validity,
      this.norentm,
      this.pp,
      this.ls,
      this.ti,
      this.brkname,
      this.actid,
      this.trantype,
      this.prctyp,
      this.qty,
      this.prc,
      this.c,
      this.prd,
      this.ordersource,
      this.placeOrderParams,
      this.d,
      this.oivariable,
      this.placeOrderParamsLeg2,
      this.expDate,
      this.option,
      this.symbol,
      this.emsg,
      this.ltp,
      this.open,
      this.high,
      this.close,
      this.low,
      this.change,
      this.perChange,
      this.ordDate});

  GttOrderBookModel.fromJson(Map<String, dynamic> json) {
    gttOrderCurrentStatus = "Pending";

    stat = json['stat'];
    emsg = json['emsg'];
    aiT = json['ai_t'];
    alId = json['al_id'];
    tsym = json['tsym'];
    exch = json['exch'];
    token = json['token'];
    remarks = json['remarks'];
    validity = json['validity'];
    norentm = json['norentm'];
    pp = json['pp'];
    ls = json['ls'];
    ti = json['ti'];
    ordDate = json['ordDate'];
    brkname = json['brkname'];
    actid = json['actid'];
    trantype = json['trantype'];
    prctyp = json['prctyp'];
    qty = json['qty'];
    prc = json['prc'];
    c = json['C'];
    prd = json['prd'];
    ordersource = json['ordersource'];
    // A BUY OCO leaves this app with its two legs swapped - see
    // OrderApi._ocoLegsInBrokerOrder. The broker's first slot always means
    // "LTP goes above", and a buy target sits BELOW the LTP, so the upper
    // level (the stoploss) has to be sent first. Swap that pair back here so
    // every screen above this model keeps reading leg 1 as the Target and
    // leg 2 as the Stoploss, exactly as it already does for a sell. A single
    // GTT has no leg 2 and is never touched.
    final dynamic leg1Json = json['place_order_params'];
    final dynamic leg2Json = json['place_order_params_leg2'];
    final String? ocoSide = (json['trantype'] ??
            (leg1Json is Map ? leg1Json['trantype'] : null))
        ?.toString();
    final bool swapLegs = leg2Json != null && ocoSide == 'B';

    final dynamic targetParams = swapLegs ? leg2Json : leg1Json;
    final dynamic stoplossParams = swapLegs ? leg1Json : leg2Json;

    placeOrderParams =
        targetParams != null ? PlaceOrderParams.fromJson(targetParams) : null;
    placeOrderParamsLeg2 = stoplossParams != null
        ? PlaceOrderParamsLeg2.fromJson(stoplossParams)
        : null;
    d = json['d'];
    if (json['oivariable'] != null) {
      oivariable = <Oivariable>[];
      json['oivariable'].forEach((v) {
        oivariable!.add(Oivariable.fromJson(v));
      });
      if (swapLegs && oivariable!.length > 1) {
        oivariable = oivariable!.reversed.toList();
      }
      // Keep the headline trigger in step with leg 1 after a swap, so the GTT
      // table and the details pane quote the same number for a buy OCO.
      if (swapLegs && oivariable!.isNotEmpty) {
        d = oivariable![0].d ?? d;
      }
    }
    expDate = json['expDate'];
    option = json['option'];
    symbol = json['symbol'];
    ltp = json['ltp'];

    low = low == null ? "0.00" : json['low'];
    high = high == null ? "0.00" : json['high'];
    open = open == null ? "0.00" : json['open'];
    close = json['close'];
    change = change == null ? "0.00" : json['change'];
    perChange = perChange == null ? "0.00" : json['perChange'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stat'] = stat;
    data['ai_t'] = aiT;
    data['al_id'] = alId;
    data['tsym'] = tsym;
    data['exch'] = exch;
    data['token'] = token;
    data['remarks'] = remarks;
    data['validity'] = validity;
    data['norentm'] = norentm;
    data['pp'] = pp;
    data['ls'] = ls;
    data['ti'] = ti;
    data['brkname'] = brkname;
    data['actid'] = actid;
    data['trantype'] = trantype;
    data['prctyp'] = prctyp;
    data['qty'] = qty;
    data['prc'] = prc;
    data['C'] = c;
    data['ordDate'] = ordDate;
    data['prd'] = prd;
    data['ordersource'] = ordersource;
    if (placeOrderParams != null) {
      data['place_order_params'] = placeOrderParams!.toJson();
    }
    if (placeOrderParamsLeg2 != null) {
      data['place_order_params_leg2'] = placeOrderParamsLeg2!.toJson();
    }
    data['d'] = d;
    if (oivariable != null) {
      data['oivariable'] = oivariable!.map((v) => v.toJson()).toList();
    }
    data['symbol'] = symbol;
    data['option'] = option;
    data['expDate'] = expDate;
    data['emsg'] = emsg;
    data["ltp"] = ltp;
    data["open"] = open;
    data["high"] = high;
    data["close"] = close;
    data["low"] = low;
    data["perChange"] = perChange;
    data["change"] = change;
    return data;
  }
}

class PlaceOrderParamsLeg2 {
  String? actid;
  String? trantype;
  String? prctyp;
  int? qty;
  String? prc;
  String? c;
  String? prd;
  String? ordersource;
  String? ipaddr;
  String? trgprc;

  PlaceOrderParamsLeg2(
      {this.actid,
      this.trantype,
      this.prctyp,
      this.qty,
      this.prc,
      this.c,
      this.prd,
      this.ordersource,
      this.ipaddr,
      this.trgprc});

  PlaceOrderParamsLeg2.fromJson(Map<String, dynamic> json) {
    actid = json['actid'];
    trantype = json['trantype'];
    prctyp = json['prctyp'];
    qty = json['qty'];
    prc = json['prc'];
    c = json['C'];
    prd = json['prd'];
    ordersource = json['ordersource'];
    ipaddr = json['ipaddr'];
    trgprc = json['trgprc'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['actid'] = actid;
    data['trantype'] = trantype;
    data['prctyp'] = prctyp;
    data['qty'] = qty;
    data['prc'] = prc;
    data['C'] = c;
    data['prd'] = prd;
    data['ordersource'] = ordersource;
    data['ipaddr'] = ipaddr;
    data['trgprc'] = trgprc;
    return data;
  }
}

class PlaceOrderParams {
  String? actid;
  String? trantype;
  String? prctyp;
  int? qty;
  String? prc;
  String? c;
  String? sPrdtAli;
  String? prd;
  String? ordersource;
  String? ipaddr;

  String? trgprc;

  PlaceOrderParams(
      {this.actid,
      this.trantype,
      this.prctyp,
      this.qty,
      this.prc,
      this.c,
      this.sPrdtAli,
      this.prd,
      this.ordersource,
      this.ipaddr,
      this.trgprc});

  PlaceOrderParams.fromJson(Map<String, dynamic> json) {
    actid = json['actid'];
    trantype = json['trantype'];
    prctyp = json['prctyp'];
    qty = json['qty'];
    prc = json['prc'];
    c = json['C'];
    sPrdtAli = json['s_prdt_ali'];
    prd = json['prd'];
    ordersource = json['ordersource'];
    ipaddr = json['ipaddr'];
    trgprc = json['trgprc'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['actid'] = actid;
    data['trantype'] = trantype;
    data['prctyp'] = prctyp;
    data['qty'] = qty;
    data['prc'] = prc;
    data['C'] = c;
    data['s_prdt_ali'] = sPrdtAli;
    data['prd'] = prd;
    data['ordersource'] = ordersource;
    data['ipaddr'] = ipaddr;
    data['trgprc'] = trgprc;
    return data;
  }
}

class Oivariable {
  String? varName;
  String? d;

  Oivariable({this.varName, this.d});

  Oivariable.fromJson(Map<String, dynamic> json) {
    varName = json['var_name'];
    d = json['d'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['var_name'] = varName;
    data['d'] = d;
    return data;
  }
}

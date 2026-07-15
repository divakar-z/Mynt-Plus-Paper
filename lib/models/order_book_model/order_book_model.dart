import 'package:mynt_plus/sharedWidget/functions.dart';

class OrderBookModel {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  /// Ready contract name for display: master name when available, else the
  /// existing symbol/expiry/option assembly (never a raw tsym).
  String get displayName =>
      masterName ??
      '${symbol?.replaceAll("-EQ", "") ?? ''} ${expDate ?? ''} ${option ?? ''}';

  String? actid;
  String? avgprc;
  String? dscqty;
  String? exch;
  String? exchTm;
  String? exchordid;
  String? fillshares;
  String? kidid;
  String? trailprc;
  String? amo;
  String? mktProtection;
  String? emsg;
  String? ls;
  String? mult;
  String? norenordno;
  String? norentm;
  String? ordenttm;
  String? pp;
  String? prc;
  String? prcftr;
  String? prctyp;
  String? prd;
  String? qty;
  String? remarks;
  String? ret;
  String? rprc;
  String? rqty;
  String? sPrdtAli;
  String? stIntrn;
  String? stat;
  String? status;
  String? ti;
  String? token;
  String? trantype;
  String? tsym;
  String? uid;
  String? ltp;
  String? open;
  String? high;
  String? close;
  String? low;
  String? perChange;
  String? change;
  String? trgprc;
  String? blprc;
  String? bpprc;
  String? rejreason;
  String? symbol;
  String? expDate;
  String? option;
  String? rejby;
  String? srcUid;
  String? snoFillid;
  String? dname;
  String? ordersource;
  String? brnchid;
  String? c;
  String? snonum;
  String? snoordt;
  String? instname;
  bool? isExitSelection;

  OrderBookModel(
      {this.actid,
      this.avgprc,
      this.dscqty,
      this.exch,
      this.exchTm,
      this.exchordid,
      this.fillshares,
      this.kidid,
      this.emsg,
      this.trailprc,
      this.ls,
      this.mult,
      this.amo,
      this.norenordno,
      this.mktProtection,
      this.norentm,
      this.ordenttm,
      this.pp,
      this.dname,
      this.prc,
      this.prcftr,
      this.prctyp,
      this.prd,
      this.qty,
      this.remarks,
      this.ret,
      this.rprc,
      this.rqty,
      this.sPrdtAli,
      this.stIntrn,
      this.stat,
      this.status,
      this.ti,
      this.token,
      this.trantype,
      this.tsym,
      this.rejreason,
      this.uid,
      this.ltp,
      this.open,
      this.high,
      this.close,
      this.low,
      this.change,
      this.perChange,
      this.trgprc,
      this.blprc,
      this.bpprc,
      this.expDate,
      this.option,
      this.symbol,
      this.rejby,
      this.srcUid,
      this.snoFillid,
      this.ordersource,
      this.brnchid,
      this.c,
      this.snonum,
      this.snoordt,
      this.instname,
      this.isExitSelection});

  OrderBookModel.fromJson(Map<String, dynamic> json) {
    actid = json['actid'];
    avgprc = json['avgprc'];
    dscqty = json['dscqty'];
    exch = json['exch'];
    exchTm = json['exch_tm'];
    exchordid = json['exchordid'];
    fillshares = json['fillshares'];
    kidid = json['kidid'];
    ls = json['ls'];
    mult = json['mult'];
    norenordno = json['norenordno'];
    norentm = json['norentm'];
    ordenttm = json['ordenttm'];
    mktProtection = json['mkt_protection'];
    pp = json['pp'];
    prc = json['prc'];
    amo = json['amo'];
    prcftr = json['prcftr'];
    trailprc = json['trailprc'];
    prctyp = json['prctyp'];
    prd = json['prd'];
    emsg = json['emsg'];
    qty = json['qty'];
    remarks = json['remarks'];
    ret = json['ret'];
    rprc = json['rprc'];
    rqty = json['rqty'];
    sPrdtAli = json['s_prdt_ali'];
    stIntrn = json['st_intrn'];
    stat = json['stat'];
    status = json['status'];
    rejreason = json['rejreason'];
    ti = json['ti'];
    token = json['token'];
    trantype = json['trantype'];
    tsym = json['tsym'];
    uid = json['uid'];
    ltp = json['ltp'];
    trgprc = json['trgprc'];
    blprc = json['blprc'];
    bpprc = json['bpprc'];
    low = low == null ? "0.00" : json['low'];
    high = high == null ? "0.00" : json['high'];
    open = open == null ? "0.00" : json['open'];
    close = json['close'];
    change = change == null ? "0.00" : json['change'];
    perChange = perChange == null ? "0.00" : json['perChange'];
    expDate = json['expDate'];
    option = json['option'];
    symbol = json['symbol'];
    rejby = json['rejby'];
    srcUid = json['src_uid'];
    snoFillid = json['sno_fillid'];
    ordersource = json['ordersource'];
    brnchid = json['brnchid'];
    c = json['C'];
    snonum = json['snonum'];
    snoordt = json['snoordt'];
    instname = json['instname'];
    dname = json['dname'];
    isExitSelection = json['isExitSelection'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['actid'] = actid;
    data['avgprc'] = avgprc;
    data['dscqty'] = dscqty;
    data['exch'] = exch;
    data['exch_tm'] = exchTm;
    data['exchordid'] = exchordid;
    data['fillshares'] = fillshares;
    data['kidid'] = kidid;
    data['rejreason'] = rejreason;
    data['ls'] = ls;
    data['trailprc'] = trailprc;
    data['mult'] = mult;
    data['emsg'] = emsg;
    data['norenordno'] = norenordno;
    data['norentm'] = norentm;
    data['ordenttm'] = ordenttm;
    data['pp'] = pp;
    data['prc'] = prc;
    data['prcftr'] = prcftr;
    data['prctyp'] = prctyp;
    data['prd'] = prd;
    data['qty'] = qty;
    data['remarks'] = remarks;
    data['ret'] = ret;
    data['mkt_protection'] = mktProtection;
    data['rprc'] = rprc;
    data['rqty'] = rqty;
    data['s_prdt_ali'] = sPrdtAli;
    data['st_intrn'] = stIntrn;
    data['stat'] = stat;
    data['status'] = status;
    data['ti'] = ti;
    data['token'] = token;
    data['trantype'] = trantype;
    data['tsym'] = tsym;
    data['uid'] = uid;
    data["ltp"] = ltp;
    data["open"] = open;
    data["high"] = high;
    data["close"] = close;
    data["low"] = low;
    data['amo'] = amo;
    data["perChange"] = perChange;
    data["change"] = change;
    data['trgprc'] = trgprc;
    data['blprc'] = blprc;
    data['bpprc'] = bpprc;
    data['symbol'] = symbol;
    data['option'] = option;
    data['expDate'] = expDate;
    data['rejby'] = rejby;
    data['src_uid'] = srcUid;
    data['sno_fillid'] = snoFillid;
    data['ordersource'] = ordersource;
    data['brnchid'] = brnchid;
    data['C'] = c;
    data['dname'] = dname;
    data['snonum'] = snonum;
    data['snoordt'] = snoordt;

    data['instname'] = instname;
    data['isExitSelection'] = isExitSelection;
    return data;
  }
}

class OrderScreenArgs {
  String exchange;
  String token;
  String tSym, orderTpye;
  bool transType;
  bool isExit;
  String? prd, ltp, perChange, lotSize, holdQty;
  bool isModify;
  Map raw;

  OrderScreenArgs(
      {required this.exchange,
      required this.token,
      required this.tSym,
      this.prd,
      required this.transType,
      required this.perChange,
      required this.lotSize,
      required this.ltp,
      required this.isExit,
      required this.orderTpye,
      required this.isModify,
      required this.raw,
      required this.holdQty});
}

class OrderInput {
  String exchange;
  String token;
  String tSym;
  String quantity;
  String price;
  String product;
  String priceTyp;
  String diskQty;
  String stopLoss;
  String target;
  String trailingStoploss;
  String validityType;
  String amo;
  String trantype;
  String mktProtection;
  String triggerPrice;
  OrderInput({
    required this.exchange,
    required this.token,
    required this.tSym,
    required this.quantity,
    required this.price,
    required this.product,
    required this.priceTyp,
    required this.diskQty,
    required this.stopLoss,
    required this.target,
    required this.trailingStoploss,
    required this.validityType,
    required this.amo,
    required this.trantype,
    required this.mktProtection,
    required this.triggerPrice,
  });
}

class ExitPositionInput {
  String exchange;
  String tSym;
  String quantity;
  String price;
  String product;
  String priceTyp;
  String diskQty;
  String validityType;
  String trantype;
  ExitPositionInput(
      {required this.exchange,
      required this.tSym,
      required this.quantity,
      required this.price,
      required this.product,
      required this.priceTyp,
      required this.diskQty,
      required this.validityType,
      required this.trantype});
}

import 'package:mynt_plus/sharedWidget/functions.dart';

class TradeBookModel {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  /// Ready contract name for display: master name when available, else the
  /// existing symbol/expiry/option assembly (never a raw tsym).
  String get displayName =>
      masterName ??
      '${symbol?.replaceAll("-EQ", "") ?? ''} ${expDate ?? ''} ${option ?? ''}';

  String? stat;
  String? emsg;
  String? norenordno;
  String? uid;
  String? actid;
  String? exch;
  String? prctyp;
  String? ret;
  String? sPrdtAli;
  String? prd;
  String? flid;
  String? fltm;
  String? trantype;
  String? tsym;
  String? qty;
  String? token;
  String? fillshares;
  String? flqty;
  String? pp;
  String? ls;
  String? ti;
  String? ltp;
  String? perChange;
  String? change;
  String? prc;
  String? prcftr;
  String? flprc;
  String? norentm;
  String? avgprc;
  String? exchTm;
  String? exchordid;
  String? symbol;
  String? expDate;
  String? dname;
  String? option;

  TradeBookModel(
      {this.stat,
      this.emsg,
      this.norenordno,
      this.uid,
      this.actid,
      this.exch,
      this.prctyp,
      this.ret,
      this.sPrdtAli,
      this.prd,
      this.flid,
      this.fltm,
      this.trantype,
      this.tsym,
      this.qty,
      this.token,
      this.fillshares,
      this.flqty,
      this.pp,
      this.ls,
      this.ti,
      this.ltp,
      this.change,
      this.perChange,
      this.prc,
      this.prcftr,
      this.dname,
      this.flprc,
      this.norentm,
      this.avgprc,
      this.exchTm,
      this.exchordid,
      this.expDate,
      this.option,
      this.symbol});

  TradeBookModel.fromJson(Map<String, dynamic> json) {
    stat = json['stat'];
    emsg = json['emsg'];
    norenordno = json['norenordno'];
    uid = json['uid'];
    actid = json['actid'];
    exch = json['exch'];
    prctyp = json['prctyp'];
    ret = json['ret'];
    sPrdtAli = json['s_prdt_ali'];
    prd = json['prd'];
    flid = json['flid'];
    fltm = json['fltm'];
    trantype = json['trantype'];
    tsym = json['tsym'];
    qty = json['qty'];
    token = json['token'];
    fillshares = json['fillshares'];
    flqty = json['flqty'];
    pp = json['pp'];
    ls = json['ls'];
    ti = json['ti'];
    ltp = json['ltp'];
    change = change == null ? "0.00" : json['change'];
    perChange = perChange == null ? "0.00" : json['perChange'];
    prc = json['prc'];
    prcftr = json['prcftr'];
    dname = json['dname'];
    flprc = json['flprc'];
    norentm = json['norentm'];
    avgprc = json['avgprc'];
    exchTm = json['exch_tm'];
    exchordid = json['exchordid'];
    expDate = json['expDate'];
    symbol = json['symbol'];
    option = json['option'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stat'] = stat;
    data['emsg'] = emsg;
    data['norenordno'] = norenordno;
    data['uid'] = uid;
    data['actid'] = actid;
    data['exch'] = exch;
    data['prctyp'] = prctyp;
    data['ret'] = ret;
    data['s_prdt_ali'] = sPrdtAli;
    data['prd'] = prd;
    data['flid'] = flid;
    data['fltm'] = fltm;
    data['trantype'] = trantype;
    data['tsym'] = tsym;
    data['qty'] = qty;
    data['token'] = token;
    data['fillshares'] = fillshares;
    data['flqty'] = flqty;
    data['pp'] = pp;
    data['ls'] = ls;
    data['ti'] = ti;
    data["ltp"] = ltp;
    data["perChange"] = perChange;
    data["change"] = change;
    data['prc'] = prc;
    data['prcftr'] = prcftr;
    data['flprc'] = flprc;
    data['norentm'] = norentm;
    data['avgprc'] = avgprc;
    data['exch_tm'] = exchTm;
    data['exchordid'] = exchordid;
    data['option'] = option;
    data['expDate'] = expDate;
    data['dname'] = dname;
    data['symbol'] = symbol;
    return data;
  }
}

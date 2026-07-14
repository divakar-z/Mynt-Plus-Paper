import 'package:mynt_plus/sharedWidget/functions.dart';

class PositionBookModel {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  String? actid;
  String? bep;
  String? cfbuyqty;
  String? cfsellqty;
  String? cfbuyamt;
  String? cfbuyavgprc;
  String? cfsellamt;
  String? cfsellavgprc;
  String? dayavgprc;
  String? daybuyamt;
  String? daybuyavgprc;
  String? daybuyqty;
  String? daysellamt;
  String? daysellavgprc;
  String? daysellqty;
  String? exch;
  String? frzqty;
  String? lp;
  String? emsg;
  String? ls;
  String? mult;
  String? netavgprc;
  String? netqty;
  String? netupldprc;
  String? openbuyamt;
  String? openbuyavgprc;
  String? openbuyqty;
  String? opensellamt;
  String? opensellavgprc;
  String? opensellqty;
  String? pp;
  String? prcftr;
  String? prd;
  String? rpnl;
  String? sPrdtAli;
  String? stat;
  String? ti;
  String? token;
  String? totbuyamt;
  String? totbuyavgprc;
  String? totsellamt;
  String? totsellavgprc;
  String? tsym;
  String? uid;
  String? upldprc;
  String? urmtom;
  String? profitNloss;
  String? temppnl;
  String? mTm;
  String? perChange;
  String? symbol;
  String? expDate;
  String? option;
  String? chng;
  String? avgPrc;
  String? qty;
  String? unRealMtm;
  String? dname;
  String? bookedPnL;
  // Underlying linkage for derivatives (OPTFUT/OPTSTK/FUT). The broker gives
  // the option's underlying directly, so we don't have to parse the tsym:
  //   und_exch / und_tk → the underlying future/spot's exch + token
  //   symname           → clean underlying symbol, e.g. "NATGASMINI"
  String? undExch;
  String? undTk;
  String? symname;
  bool? isExitSelection;
  bool? isAlreadyGroup;
  PositionBookModel(
      {this.actid,
      this.bep,
      this.cfbuyqty,
      this.cfsellqty,
      this.cfbuyamt,
      this.cfbuyavgprc,
      this.cfsellamt,
      this.cfsellavgprc,
      this.dayavgprc,
      this.daybuyamt,
      this.daybuyavgprc,
      this.daybuyqty,
      this.daysellamt,
      this.daysellavgprc,
      this.daysellqty,
      this.exch,
      this.frzqty,
      this.dname,
      this.lp,
      this.emsg,
      this.ls,
      this.mult,
      this.netavgprc,
      this.netqty,
      this.netupldprc,
      this.openbuyamt,
      this.openbuyavgprc,
      this.openbuyqty,
      this.opensellamt,
      this.opensellavgprc,
      this.opensellqty,
      this.pp,
      this.prcftr,
      this.prd,
      this.rpnl,
      this.sPrdtAli,
      this.stat,
      this.ti,
      this.token,
      this.totbuyamt,
      this.totbuyavgprc,
      this.totsellamt,
      this.totsellavgprc,
      this.tsym,
      this.uid,
      this.upldprc,
      this.urmtom,
      this.mTm,
      this.profitNloss,
      this.temppnl,
      this.expDate,
      this.option,
      this.symbol,
      this.chng,
      this.avgPrc,
      this.qty,
      this.unRealMtm,
      this.bookedPnL,
      this.undExch,
      this.undTk,
      this.symname,
      this.isExitSelection,
      this.isAlreadyGroup});

  PositionBookModel.fromJson(Map<String, dynamic> json) {
    actid = json['actid'];
    bep = json['bep'];
    cfbuyqty = json['cfbuyqty'];
    cfsellqty = json['cfsellqty'];
    cfbuyamt = json['cfbuyamt'];
    cfbuyavgprc = json['cfbuyavgprc'];
    cfsellamt = json['cfsellamt'];
    cfsellavgprc = json['cfsellavgprc'];
    dayavgprc = json['dayavgprc'];
    daybuyamt = json['daybuyamt'];
    daybuyavgprc = json['daybuyavgprc'];
    dname = json['dname'];
    daybuyqty = json['daybuyqty'];
    daysellamt = json['daysellamt'];
    daysellavgprc = json['daysellavgprc'];
    daysellqty = json['daysellqty'];
    exch = json['exch'];
    frzqty = json['frzqty'];
    lp = json['lp'];
    emsg = json['emsg'];
    ls = json['ls'];
    mult = json['mult'];
    netavgprc = json['netavgprc'];
    netqty = json['netqty'];
    netupldprc = json['netupldprc'];
    openbuyamt = json['openbuyamt'];
    openbuyavgprc = json['openbuyavgprc'];
    openbuyqty = json['openbuyqty'];
    opensellamt = json['opensellamt'];
    opensellavgprc = json['opensellavgprc'];
    opensellqty = json['opensellqty'];
    pp = json['pp'];
    prcftr = json['prcftr'];
    prd = json['prd'];
    rpnl = json['rpnl'];
    sPrdtAli = json['s_prdt_ali'];
    stat = json['stat'];
    ti = json['ti'];
    token = json['token'];
    totbuyamt = json['totbuyamt'];
    totbuyavgprc = json['totbuyavgprc'];
    totsellamt = json['totsellamt'];
    totsellavgprc = json['totsellavgprc'];
    tsym = json['tsym'];
    undExch = json['und_exch'];
    undTk = json['und_tk'];
    symname = json['symname'];
    uid = json['uid'];
    upldprc = json['upldprc'];
    urmtom = json['urmtom'];
    profitNloss = json['profitNloss'];
    temppnl = json['temppnl'];
    perChange = json['perChange'];
    mTm = json['mTm'];
    chng = json['chng'];
    expDate = json['expDate'];
    symbol = json['symbol'];
    option = json['option'];
    avgPrc = json['avgPrc'];
    qty = json['qty'];
    isExitSelection = json['isExitSelection'];
    unRealMtm = json['unRealMtm'];
    bookedPnL = json['bookedPnL'];
    isAlreadyGroup = json['isAlreadyGroup'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['actid'] = actid;
    data['bep'] = bep;
    data['cfbuyqty'] = cfbuyqty;
    data['cfsellqty'] = cfsellqty;
    data['cfbuyamt'] = cfbuyamt;
    data['cfbuyavgprc'] = cfbuyavgprc;
    data['cfsellamt'] = cfsellamt;
    data['cfsellavgprc'] = cfsellavgprc;
    data['dayavgprc'] = dayavgprc;
    data['daybuyamt'] = daybuyamt;
    data['daybuyavgprc'] = daybuyavgprc;
    data['daybuyqty'] = daybuyqty;
    data['daysellamt'] = daysellamt;
    data['daysellavgprc'] = daysellavgprc;
    data['daysellqty'] = daysellqty;
    data['exch'] = exch;
    data['frzqty'] = frzqty;
    data['lp'] = lp;
    data['ls'] = ls;
    data['emsg'] = emsg;
    data['mult'] = mult;
    data['netavgprc'] = netavgprc;
    data['dname'] = dname;
    data['netqty'] = netqty;
    data['netupldprc'] = netupldprc;
    data['openbuyamt'] = openbuyamt;
    data['openbuyavgprc'] = openbuyavgprc;
    data['openbuyqty'] = openbuyqty;
    data['opensellamt'] = opensellamt;
    data['opensellavgprc'] = opensellavgprc;
    data['opensellqty'] = opensellqty;
    data['pp'] = pp;
    data['prcftr'] = prcftr;
    data['prd'] = prd;
    data['rpnl'] = rpnl;
    data['s_prdt_ali'] = sPrdtAli;
    data['stat'] = stat;
    data['ti'] = ti;
    data['token'] = token;
    data['totbuyamt'] = totbuyamt;
    data['totbuyavgprc'] = totbuyavgprc;
    data['totsellamt'] = totsellamt;
    data['totsellavgprc'] = totsellavgprc;
    data['tsym'] = tsym;
    data['uid'] = uid;
    data['upldprc'] = upldprc;
    data['urmtom'] = urmtom;
    data['profitNloss'] = profitNloss;
    data['temppnl'] = temppnl;
    data['perChange'] = perChange;
    data['mTm'] = mTm;
    data['option'] = option;
    data['expDate'] = expDate;
    data['symbol'] = symbol;
    data['chng'] = chng;
    data['avgPrc'] = avgPrc;
    data['qty'] = qty;
    data['unRealMtm'] = unRealMtm;
    data['bookedPnL'] = bookedPnL;
    data['isExitSelection'] = isExitSelection;
    data['isAlreadyGroup'] = isAlreadyGroup;
    return data;
  }
}

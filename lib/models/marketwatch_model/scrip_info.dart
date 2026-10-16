import 'package:mynt_plus/sharedWidget/functions.dart';

class ScripInfoModel {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  String? requestTime;
  String? stat;
  String? exch;
  String? tsym;
  String? cname;
  String? symname;
  String? seg;
  String? instname;
  String? exd;
  String? strprc;
  String? optt;
  String? isin;
  String? mult;
  String? ti;
  String? ls;
  String? pp;
  String? gpNd;
  String? prcunt;
  String? prcqqty;
  String? trdunt;
  String? delunt;
  String? frzqty;
  String? gsmind;
  String? elmbmrg;
  String? elmsmrg;
  String? addbmrg;
  String? addsmrg;
  String? splbmrg;
  String? splsmrg;
  String? delmrg;
  String? tenmrg;
  String? tenstrd;
  String? tenendd;
  String? exestrd;
  String? exeendd;
  String? mktT;
  String? issueD;
  String? listingD;
  String? lastTrdD;
  String? elmmrg;
  String? varmrg;
  String? expmrg;
  String? token;
  String? prcftrD;
  String? weekly;
  String? nontrd;
  String? dname;
  String? exptime;
  String? uc;
  String? emsg;
  String? lc;
  String? undExch;
  String? undTk;
  String? symbol;
  String? expDate;
  String? option;
  String? lp;
  String? perChng;
  String? ordMsg;
  String? idx;


  ScripInfoModel(
      {this.requestTime,
      this.stat,
      this.exch,
      this.tsym,
      this.cname,
      this.symname,
      this.seg,
      this.instname,
      this.exd,
      this.strprc,
      this.optt,
      this.isin,
      this.mult,
      this.ti,
      this.ls,
      this.pp,
      this.gpNd,
      this.prcunt,
      this.prcqqty,
      this.trdunt,
      this.delunt,
      this.frzqty,
      this.gsmind,
      this.elmbmrg,
      this.elmsmrg,
      this.addbmrg,
      this.addsmrg,
      this.splbmrg,
      this.splsmrg,
      this.delmrg,
      this.tenmrg,
      this.tenstrd,
      this.tenendd,
      this.exestrd,
      this.exeendd,
      this.mktT,
      this.issueD,
      this.listingD,
      this.lastTrdD,
      this.elmmrg,
      this.varmrg,
      this.expmrg,
      this.token,
      this.prcftrD,
      this.weekly,
      this.nontrd,
      this.dname,
      this.exptime,
      this.lc,
      this.uc,
      this.emsg,
      this.undExch,
      this.undTk,
      this.expDate,
      this.option,
      this.symbol,
      this.lp,
      this.perChng,
      this.ordMsg,
      this.idx});

  ScripInfoModel.fromJson(Map<String, dynamic> json) {
    requestTime = json['request_time'];
    stat = json['stat'];
    exch = json['exch'];
    tsym = json['tsym'];
    cname = json['cname'];
    symname = json['symname'];
    seg = json['seg'];
    instname = json['instname'];
    exd = json['exd'];
    strprc = json['strprc'];
    optt = json['optt'];
    isin = json['isin'];
    mult = json['mult'];
    ti = json['ti'];
    ls = json['ls'];
    pp = json['pp'];
    gpNd = json['gp_nd'];
    prcunt = json['prcunt'];
    prcqqty = json['prcqqty'];
    trdunt = json['trdunt'];
    delunt = json['delunt'];
    frzqty = json['frzqty'];
    gsmind = json['gsmind'];
    elmbmrg = json['elmbmrg'];
    elmsmrg = json['elmsmrg'];
    addbmrg = json['addbmrg'];
    addsmrg = json['addsmrg'];
    splbmrg = json['splbmrg'];
    splsmrg = json['splsmrg'];
    delmrg = json['delmrg'];
    tenmrg = json['tenmrg'];
    tenstrd = json['tenstrd'];
    tenendd = json['tenendd'];
    exestrd = json['exestrd'];
    exeendd = json['exeendd'];
    mktT = json['mkt_t'];
    issueD = json['issue_d'];
    listingD = json['listing_d'];
    lastTrdD = json['last_trd_d'];
    elmmrg = json['elmmrg'];
    varmrg = json['varmrg'];
    expmrg = json['expmrg'];
    token = json['token'];
    prcftrD = json['prcftr_d'];
    weekly = json['weekly'];
    nontrd = json['nontrd'];
    dname = json['dname'];
    exptime = json['exptime'];
    lc = json['lc'];
    uc = json['uc'];
    undExch = json['und_exch'];
    undTk = json['und_tk'];
    expDate = json['expDate'];
    symbol = json['symbol'];
    option = json['option'];
    ordMsg = json['ord_msg'];
    emsg = json['emsg'].toString();
    idx = json['idx'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['request_time'] = requestTime;
    data['stat'] = stat;
    data['exch'] = exch;
    data['tsym'] = tsym;
    data['cname'] = cname;
    data['emsg'] = emsg;
    data['symname'] = symname;
    data['seg'] = seg;
    data['instname'] = instname;
    data['exd'] = exd;
    data['strprc'] = strprc;
    data['optt'] = optt;
    data['isin'] = isin;
    data['mult'] = mult;
    data['ti'] = ti;
    data['ls'] = ls;
    data['pp'] = pp;
    data['gp_nd'] = gpNd;
    data['prcunt'] = prcunt;
    data['prcqqty'] = prcqqty;
    data['trdunt'] = trdunt;
    data['delunt'] = delunt;
    data['frzqty'] = frzqty;
    data['gsmind'] = gsmind;
    data['elmbmrg'] = elmbmrg;
    data['elmsmrg'] = elmsmrg;
    data['addbmrg'] = addbmrg;
    data['addsmrg'] = addsmrg;
    data['splbmrg'] = splbmrg;
    data['splsmrg'] = splsmrg;
    data['delmrg'] = delmrg;
    data['tenmrg'] = tenmrg;
    data['tenstrd'] = tenstrd;
    data['tenendd'] = tenendd;
    data['exestrd'] = exestrd;
    data['exeendd'] = exeendd;
    data['mkt_t'] = mktT;
    data['issue_d'] = issueD;
    data['listing_d'] = listingD;
    data['last_trd_d'] = lastTrdD;
    data['elmmrg'] = elmmrg;
    data['varmrg'] = varmrg;
    data['expmrg'] = expmrg;
    data['token'] = token;
    data['prcftr_d'] = prcftrD;
    data['weekly'] = weekly;
    data['nontrd'] = nontrd;
    data['dname'] = dname;
    data['exptime'] = exptime;
    data['lc'] = lc;
    data['uc'] = uc;
    data['und_exch'] = undExch;
    data['und_tk'] = undTk;
    data['option'] = option;
    data['expDate'] = expDate;
    data['symbol'] = symbol;
    data['ord_msg'] = ordMsg;
    data['idx'] = idx;
    return data;
  }
}

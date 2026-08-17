class FundDetailModel {
  String? prfname;
  String? cash;
  String? payin;
  String? payout;
  String? brkcollamt;
  String? unclearedcash;
  String? auxDaycash;
  String? auxBrkcollamt;
  String? auxUnclearedcash;
  String? daycash;
  String? remarksAmt;
  String? remarksText;
  String? marginused;
  String? peakMar;
  String? mtomcurper;
  String? margincurper;
  String? urmtom;
  String? span;
  String? expo;
  String? spanCM;
  String? expoCM;
  String? addmrg;
  String? addmrgCM;
  String? uzpnlCM;
  String? uzpnlDM;
  String? spanDM;
  String? expoDM;
  String? expiryMar;
  String? turnover;
  String? brokerage;
  String? brkageEC;
  String? blkAmt;
  String? cbu;
  String? premiumDM;
  String? premiumDI;
  String? premiumCI;
  String? premiumCM;
  String? brkageDM;
  String? premium;
  String? scripbskmarEI;
  String? scripbskmrg;
  String? scripbskmar;
  String? avlMrg;
  String? avlMrgPercentage;
  String? requestTime;
  String? stat;
  String? totCredit;
  String? rzpnlEI;
  String? uzpnlEI;
  String? emsg;
  String? equitymargintot;
  String? mrgprt;
  String? rpnl;
  String? utilizedMrgn;
  String? pendordval;
  String? collateral;
  String? cashcoll;
  String? cobomargin;
  String? deliverySellBenefit;

  FundDetailModel(
      {this.prfname,
      this.cash,
      this.payin,
      this.payout,
      this.brkcollamt,
      this.unclearedcash,
      this.auxDaycash,
      this.auxBrkcollamt,
      this.auxUnclearedcash,
      this.daycash,
      this.remarksAmt,
      this.remarksText,
      this.marginused,
      this.peakMar,
      this.mtomcurper,
      this.margincurper,
      this.urmtom,
      this.span,
      this.expo,
      this.spanCM,
      this.expoCM,
      this.addmrg,
      this.addmrgCM,
      this.uzpnlCM,
      this.uzpnlDM,
      this.spanDM,
      this.expoDM,
      this.expiryMar,
      this.turnover,
      this.brokerage,
      this.brkageEC,
      this.blkAmt,
      this.cbu,
      this.premiumDM,
      this.premiumDI,
      this.premiumCI,
      this.premiumCM,
      this.brkageDM,
      this.premium,
      this.scripbskmarEI,
      this.scripbskmrg,
      this.avlMrg,
      this.requestTime,
      this.stat,
      this.totCredit,
      this.avlMrgPercentage,
      this.rzpnlEI,
      this.uzpnlEI,
      this.emsg,
      this.equitymargintot,
      this.mrgprt,
      this.rpnl,
      this.utilizedMrgn,
      this.pendordval,
      this.scripbskmar,
      this.collateral,
      this.cashcoll,
      this.cobomargin,
      this.deliverySellBenefit});

  FundDetailModel.fromJson(Map<String, dynamic> json) {
    prfname = json['prfname'];
    cash = json['cash'];
    payin = json['payin'];
    payout = json['payout'];
    brkcollamt = json['brkcollamt'];
    unclearedcash = json['unclearedcash'];
    auxDaycash = json['aux_daycash'];
    auxBrkcollamt = json['aux_brkcollamt'];
    auxUnclearedcash = json['aux_unclearedcash'];
    daycash = json['daycash'];
    scripbskmar = json['scripbskmar'];
    remarksAmt = json['remarks_amt'];
    remarksText = json['remarks_text'];
    marginused = json['marginused'];
    peakMar = json['peak_mar'];
    mtomcurper = json['mtomcurper'];
    margincurper = json['margincurper'];
    urmtom = json['urmtom'];
    span = json['span'];
    expo = json['expo'];
    spanCM = json['span_c_m'];
    expoCM = json['expo_c_m'];
    addmrg = json['addmrg'];
    addmrgCM = json['addmrg_c_m'];
    uzpnlCM = json['uzpnl_c_m'];
    uzpnlDM = json['uzpnl_d_m'];
    spanDM = json['span_d_m'];
    expoDM = json['expo_d_m'];
    expiryMar = json['expiry_mar'];
    turnover = json['turnover'];
    brokerage = json['brokerage'];
    brkageEC = json['brkage_e_c'];
    blkAmt = json['blk_amt'];
    cbu = json['cbu'];
    premiumDM = json['premium_d_m'];
    // Segment-and-product option premium. Suffix reads <segment>_<product>:
    // d = derivative, c = commodity; i = intraday (MIS), m = margin (NRML/CF).
    // Verified against the vendor Margins page on 17-08-2026.
    premiumDI = json['premium_d_i'];
    premiumCI = json['premium_c_i'];
    premiumCM = json['premium_c_m'];
    brkageDM = json['brkage_d_m'];
    premium = json['premium'];
    scripbskmarEI = json['scripbskmar_e_i'];
    scripbskmrg = json['scripbskmrg'];
    avlMrg = json['avlMrg'];
    requestTime = json['request_time'];
    stat = json['stat'];
    totCredit = json['totCredit'];
    rzpnlEI = json['rzpnl_e_i'];
    uzpnlEI = json['uzpnl_e_i'];
    emsg = json['emsg'];
    equitymargintot = json['equitymargintot'];
    mrgprt = json['mrgprt'];
    rpnl = json['rpnl'];
    utilizedMrgn = json['utilizedMrgn'];
    pendordval = json['pendordval'];
    collateral = json['collateral'];
    cashcoll = json['cash_coll'];
    cobomargin = json['marprt'];
    deliverySellBenefit = json['csc'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['prfname'] = prfname;
    data['cash'] = cash;
    data['payin'] = payin;
    data['payout'] = payout;
    data['scripbskmar'] = scripbskmar;
    data['brkcollamt'] = brkcollamt;
    data['unclearedcash'] = unclearedcash;
    data['aux_daycash'] = auxDaycash;
    data['aux_brkcollamt'] = auxBrkcollamt;
    data['aux_unclearedcash'] = auxUnclearedcash;
    data['daycash'] = daycash;
    data['remarks_amt'] = remarksAmt;
    data['remarks_text'] = remarksText;
    data['marginused'] = marginused;
    data['peak_mar'] = peakMar;
    data['mtomcurper'] = mtomcurper;
    data['margincurper'] = margincurper;
    data['urmtom'] = urmtom;
    data['span'] = span;
    data['expo'] = expo;
    data['span_c_m'] = spanCM;
    data['expo_c_m'] = expoCM;
    data['addmrg'] = addmrg;
    data['addmrg_c_m'] = addmrgCM;
    data['uzpnl_c_m'] = uzpnlCM;
    data['uzpnl_d_m'] = uzpnlDM;
    data['span_d_m'] = spanDM;
    data['expo_d_m'] = expoDM;
    data['expiry_mar'] = expiryMar;
    data['turnover'] = turnover;
    data['brokerage'] = brokerage;
    data['brkage_e_c'] = brkageEC;
    data['blk_amt'] = blkAmt;
    data['cbu'] = cbu;
    data['premium_d_m'] = premiumDM;
    data['premium_d_i'] = premiumDI;
    data['premium_c_i'] = premiumCI;
    data['premium_c_m'] = premiumCM;
    data['brkage_d_m'] = brkageDM;
    data['premium'] = premium;
    data['scripbskmar_e_i'] = scripbskmarEI;
    data['scripbskmrg'] = scripbskmrg;
    data['avlMrg'] = avlMrg;
    data['request_time'] = requestTime;
    data['stat'] = stat;
    data['totCredit'] = totCredit;
    data['rzpnl_e_i'] = rzpnlEI;
    data['uzpnl_e_i'] = uzpnlEI;
    data['emsg'] = emsg;
    data['equitymargintot'] = equitymargintot;
    data['mrgprt'] = mrgprt;
    data['rpnl'] = rpnl;
    data['utilizedMrgn'] = utilizedMrgn;
    data['pendordval'] = pendordval;
    data['collateral'] = collateral;
    data['cash_coll'] = cashcoll;
    data['marprt'] = cobomargin;
    data['csc'] = deliverySellBenefit;
    return data;
  }
}

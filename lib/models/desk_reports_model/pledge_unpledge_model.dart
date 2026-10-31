class PledgeAndUnpledgeModel {
  String? bOID;
  String? cLIENTCODE;
  String? cLIENTTEXT;
  String? cLIENTNAME;
  List<Data>? data;
  String? estTotalAvailable;
  String? marginTotalAvailable;
  String? noOfNonApprovedStocks;
  String? cashEquivalent;
  String? noncashEquivalent;
  String? noOfStocks;
  String? pledgeHistory;
  String? stocksValue;
  String? unpledgeHistory;

  PledgeAndUnpledgeModel(
      {this.bOID,
      this.cLIENTCODE,
      this.cLIENTTEXT,
      this.cLIENTNAME,
      this.data,
      this.estTotalAvailable,
      this.marginTotalAvailable,
      this.noOfNonApprovedStocks,
      this.cashEquivalent,
      this.noncashEquivalent,
      this.noOfStocks,
      this.pledgeHistory,
      this.stocksValue,
      this.unpledgeHistory});

  PledgeAndUnpledgeModel.fromJson(Map<String, dynamic> json) {
    bOID = json['BOID'].toString();
    cLIENTCODE = json['CLIENTCODE'].toString();
    cLIENTTEXT = json['CLIENTTEXT'].toString();
    cLIENTNAME = json['CLIENT_NAME'].toString();
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    estTotalAvailable = json['est_total_available'].toString();
    marginTotalAvailable = json['margin_total_available'].toString();
    noOfNonApprovedStocks = json['no_of_non_approved_stocks'].toString();
    cashEquivalent = json['cashEquivalent'].toString();
    noncashEquivalent = json['noncashEquivalent'].toString();
    noOfStocks = json['no_of_stocks'].toString();
    pledgeHistory = json['pledge_history'].toString();
    stocksValue = json['stocks_value'].toString();
    unpledgeHistory = json['unpledge_history'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['BOID'] = bOID;
    data['CLIENTCODE'] = cLIENTCODE;
    data['CLIENTTEXT'] = cLIENTTEXT;
    data['CLIENT_NAME'] = cLIENTNAME;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['est_total_available'] = estTotalAvailable;
    data['margin_total_available'] = marginTotalAvailable;
    data['no_of_non_approved_stocks'] = noOfNonApprovedStocks;
    data['cashEquivalent'] = cashEquivalent;
    data['noncashEquivalent'] = noncashEquivalent;
    data['no_of_stocks'] = noOfStocks;
    data['pledge_history'] = pledgeHistory;
    data['stocks_value'] = stocksValue;
    data['unpledge_history'] = unpledgeHistory;
    return data;
  }
}

class Data {
  String? aMOUNT;
  String? aMOUNT1;
  String? bENQTY;
  String? bSESYMBOL;
  String? cOLQTY;
  String? cPUCC;
  String? hAIRCUT;
  String? hCAMOUNT;
  String? hCPRICE;
  String? haircut;
  String? iNSHORT;
  String? iNSTTYPE;
  String? iSIN;
  String? iSINCD;
  String? nET;
  String? nETQTYAFTRLIMITS;
  String? nETVALUEAFTRLIMITS;
  String? nSESYMBOL;
  String? nSOHQTY;
  String? oUTSHORT;
  String? pLEDGEQTY;
  String? price;
  String? sCRIPNAME;
  String? sCRIPVALUE;
  String? sERIES;
  String? sOHQTY;
  String? sYMB;
  String? status;
  CashEqColl? cashEqColl;
  List<String>? eligibleSegments;
  String? estPercentage;
  String? cRnc;
  String? estimated;
  String? dummvalue;
  String? segmentselect;
  String? dummunpledgevalue;
  String? deleteselected;
  String? initiated;
  String? margin;
  String? plegeQty;
  String? unPlegeQty;
  String? mTFPLEDGEDQTY;
  String? mTFUNPLEDGEQTY;

  static int _qty(String? v) {
    final n = (double.tryParse(v ?? '') ?? 0).toInt();
    return n < 0 ? 0 : n;
  }

  /// Total pledged qty (COLQTY), 0 when missing or negative.
  int get colQty => _qty(cOLQTY);

  /// Pending MTF unpledge request qty (mtf_unpledge_qty).
  int get mtfPendingQty => _qty(mTFUNPLEDGEQTY);

  /// Pending Regular unpledge request qty (un_plege_qty).
  int get regularPendingQty => _qty(unPlegeQty);

  /// MTF pledged qty. MTF_PLEDGED_QTY already drops by the pending MTF
  /// request, so it is added back; never more than [colQty].
  int get mtfQty {
    final mtf = _qty(mTFPLEDGEDQTY) + mtfPendingQty;
    return mtf > colQty ? colQty : mtf;
  }

  /// Regular (non-MTF) pledged qty.
  int get normalQty => colQty - mtfQty;

  /// Pledged qty for an unpledge product: "F" = MTF, "C" = Regular.
  int pledgedQtyFor(String prd) => prd == 'F' ? mtfQty : normalQty;

  /// Pending request qty for an unpledge product: "F" = MTF, "C" = Regular.
  int pendingQtyFor(String prd) =>
      prd == 'F' ? mtfPendingQty : regularPendingQty;

  Data(
      {this.aMOUNT,
      this.aMOUNT1,
      this.bENQTY,
      this.bSESYMBOL,
      this.cOLQTY,
      this.cPUCC,
      this.hAIRCUT,
      this.hCAMOUNT,
      this.hCPRICE,
      this.haircut,
      this.iNSHORT,
      this.iNSTTYPE,
      this.iSIN,
      this.iSINCD,
      this.nET,
      this.nETQTYAFTRLIMITS,
      this.nETVALUEAFTRLIMITS,
      this.nSESYMBOL,
      this.nSOHQTY,
      this.oUTSHORT,
      this.pLEDGEQTY,
      this.price,
      this.sCRIPNAME,
      this.sCRIPVALUE,
      this.sERIES,
      this.sOHQTY,
      this.sYMB,
      this.status,
      this.cashEqColl,
      this.eligibleSegments,
      this.estPercentage,
      this.cRnc,
      this.estimated,
      this.dummvalue,
      this.segmentselect,
      this.dummunpledgevalue,
      this.deleteselected,
      this.initiated,
      this.margin,
      this.plegeQty,
      this.unPlegeQty});

  Data.fromJson(Map<String, dynamic> json) {
    aMOUNT = json['AMOUNT'].toString();
    aMOUNT1 = json['AMOUNT1'].toString();
    bENQTY = json['BENQTY'].toString();
    bSESYMBOL = json['BSE_SYMBOL'].toString();
    cOLQTY = json['COLQTY'].toString();
    cPUCC = json['CPUCC'].toString();
    hAIRCUT = json['HAIRCUT'].toString();
    hCAMOUNT = json['HC_AMOUNT'].toString();
    hCPRICE = json['HC_PRICE'].toString();
    haircut = json['Haircut'].toString();
    iNSHORT = json['INSHORT'].toString();
    iNSTTYPE = json['INST_TYPE'].toString();
    iSIN = json['ISIN'].toString();
    iSINCD = json['ISINCD'].toString();
    nET = json['NET'].toString();
    nETQTYAFTRLIMITS = json['NET_QTY_AFTR_LIMITS'].toString();
    nETVALUEAFTRLIMITS = json['NET_VALUE_AFTR_LIMITS'].toString();
    nSESYMBOL = json['NSE_SYMBOL'].toString();
    nSOHQTY = json['NSOHQTY'].toString();
    oUTSHORT = json['OUTSHORT'].toString();
    pLEDGEQTY = json['PLEDGE_QTY'].toString();
    price = json['Price'].toString();
    sCRIPNAME = json['SCRIP_NAME'].toString();
    sCRIPVALUE = json['SCRIP_VALUE'].toString();
    sERIES = json['SERIES'].toString();
    sOHQTY = json['SOHQTY'].toString();
    sYMB = json['SYMB'].toString();
    status = json['Status'].toString();
    cashEqColl = json['cash_eq_coll'] != null
        ? CashEqColl.fromJson(json['cash_eq_coll'])
        : null;
    eligibleSegments = json['eligible_segments'].cast<String>();
    estPercentage = json['est_percentage'].toString();
    cRnc = json['c_nc'].toString();
    estimated = json['estimated'].toString();
    dummvalue = json['dummvalue'].toString();
    segmentselect = json['segmentselect'].toString();
    dummunpledgevalue = json['dummunpledgevalue'].toString();
    deleteselected = json['deleteselected'].toString();
    initiated = json['initiated'].toString();
    margin = json['margin'].toString();
    plegeQty = json['plege_qty'].toString();
    unPlegeQty = json['un_plege_qty'].toString();
    mTFPLEDGEDQTY = json['MTF_PLEDGED_QTY'].toString();
    mTFUNPLEDGEQTY = json['mtf_unpledge_qty'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['AMOUNT'] = aMOUNT;
    data['AMOUNT1'] = aMOUNT1;
    data['BENQTY'] = bENQTY;
    data['BSE_SYMBOL'] = bSESYMBOL;
    data['COLQTY'] = cOLQTY;
    data['CPUCC'] = cPUCC;
    data['HAIRCUT'] = hAIRCUT;
    data['HC_AMOUNT'] = hCAMOUNT;
    data['HC_PRICE'] = hCPRICE;
    data['Haircut'] = haircut;
    data['INSHORT'] = iNSHORT;
    data['INST_TYPE'] = iNSTTYPE;
    data['ISIN'] = iSIN;
    data['ISINCD'] = iSINCD;
    data['NET'] = nET;
    data['NET_QTY_AFTR_LIMITS'] = nETQTYAFTRLIMITS;
    data['NET_VALUE_AFTR_LIMITS'] = nETVALUEAFTRLIMITS;
    data['NSE_SYMBOL'] = nSESYMBOL;
    data['NSOHQTY'] = nSOHQTY;
    data['OUTSHORT'] = oUTSHORT;
    data['PLEDGE_QTY'] = pLEDGEQTY;
    data['Price'] = price;
    data['SCRIP_NAME'] = sCRIPNAME;
    data['SCRIP_VALUE'] = sCRIPVALUE;
    data['SERIES'] = sERIES;
    data['SOHQTY'] = sOHQTY;
    data['SYMB'] = sYMB;
    data['Status'] = status;
    if (cashEqColl != null) {
      data['cash_eq_coll'] = cashEqColl!.toJson();
    }
    data['eligible_segments'] = eligibleSegments;
    data['est_percentage'] = estPercentage;
    data['c_nc'] = cRnc;
    data['estimated'] = estimated;
    data['initiated'] = initiated;
    data['margin'] = margin;
    data['plege_qty'] = plegeQty;
    data['un_plege_qty'] = unPlegeQty;
    data['MTF_PLEDGED_QTY'] = mTFPLEDGEDQTY;
    data['mtf_unpledge_qty'] = mTFUNPLEDGEQTY;
    return data;
  }
}

class CashEqColl {
  String? comCashEq;
  String? foCashEq;
  String? cdCashEq;

  CashEqColl({this.comCashEq, this.foCashEq, this.cdCashEq});

  CashEqColl.fromJson(Map<String, dynamic> json) {
    comCashEq = json['com_cash_eq'].toString();
    foCashEq = json['fo_cash_eq'].toString();
    cdCashEq = json['cd_cash_eq'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['com_cash_eq'] = comCashEq;
    data['fo_cash_eq'] = foCashEq;
    data['cd_cash_eq'] = cdCashEq;
    return data;
  }
}

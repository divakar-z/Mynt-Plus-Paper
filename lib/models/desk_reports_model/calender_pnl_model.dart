class CalenderpnlModel {
  List<TradeData>? data;
  Map? data2;
  Map? dateWise;
  Map? symbolWise;
  Map? summary;
  Map? symbolarr;
  Map? fullresponse;
  List<Journal>? journal;
  Map? stat;
  
  double realized = 0;
  double unrealized = 0;
  double? totalCharges;
  String? segment;
  String? message;

  CalenderpnlModel({
    this.data,
    this.data2,
    this.dateWise,
    this.symbolWise,
    this.journal,
    this.totalCharges,
    this.summary,
    this.symbolarr,
    this.stat,
    this.fullresponse,
    this.segment,
    this.message
  });

  CalenderpnlModel.fromJson(Map<String, dynamic> json) {
    segment = json['segment'];
    message = json['message'];
    
    // RESPONSE 1: Commodity format (dateWise/symbolWise/stat)
    if (json['dateWise'] != null) {
      dateWise = json['dateWise'];
      symbolWise = json['symbolWise'];
      stat = json['stat'];
      summary = json['summary'];
      
      data = <TradeData>[];
      
      // Flatten dateWise trades into data array
      (json['dateWise'] as Map).forEach((date, dateData) {
        if (dateData['trades'] != null) {
          (dateData['trades'] as List).forEach((trade) {
            realized += (trade['PL_AMT'] ?? 0.0);
            data!.add(TradeData.fromCommodityJson(trade));
          });
        }
      });
      
      // Extract totals from stat
      if (json['stat'] != null) {
        totalCharges = json['stat']['total_charges']?.toDouble();
        // Cross-verify realized P&L
        if (json['stat']['total_realised_pnl'] != null) {
          realized = json['stat']['total_realised_pnl'].toDouble();
        }
        if (json['stat']['total_unrealised_pnl'] != null) {
          unrealized = json['stat']['total_unrealised_pnl'].toDouble();
        }
      }
      
      // Build journal from dateWise
      if (dateWise != null) {
        journal = <Journal>[];
        (dateWise as Map).forEach((date, dateData) {
          journal!.add(Journal(
            tRADEDATE: date,
            realisedpnl: dateData['realised_pnl']?.toString() ?? '0',
            unrealisedpnl: '0',
            totalBillNet: '0'
          ));
        });
      }
    }
    
    // RESPONSE 2: Equity/FNO format (Data/Data2)
    else if (json['Data2'] != null) {
      data = <TradeData>[];
      json['Data2'].forEach((v) {
        var trade = TradeData.fromJson(v);
        realized += double.tryParse(trade.realisedpnl ?? '0') ?? 0.0;
        unrealized += double.tryParse(trade.unrealisedpnl ?? '0') ?? 0.0;
        data!.add(trade);
      });
      
      data2 = json['Data'];
      summary = json['summary'];
      symbolarr = json['symbolarr'];
      
      // Extract journal
      if (json['journal'] != null) {
        journal = <Journal>[];
        json['journal'].forEach((v) {
          journal!.add(Journal.fromJson(v));
        });
      }
      
      totalCharges = json['total_charges']?.toDouble();
    }

    fullresponse = json;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    
    if (this.data != null) {
      data['Data2'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (this.data2 != null) {
      data['Data'] = this.data2;
    }
    if (this.dateWise != null) {
      data['dateWise'] = this.dateWise;
    }
    if (this.symbolWise != null) {
      data['symbolWise'] = this.symbolWise;
    }
    if (this.summary != null) {
      data['summary'] = this.summary;
    }
    if (this.stat != null) {
      data['stat'] = this.stat;
    }
    if (this.symbolarr != null) {
      data['symbolarr'] = this.symbolarr;
    }
    if (journal != null) {
      data['journal'] = journal!.map((v) => v.toJson()).toList();
    }
    
    data['fullresponse'] = fullresponse;
    data['total_charges'] = this.totalCharges;
    data['realized'] = this.realized;
    data['unrealized'] = this.unrealized;
    data['segment'] = this.segment;
    
    return data;
  }

  // Helper methods for UI
  bool get isCommodityFormat => dateWise != null;
  bool get hasData => (data != null && data!.isNotEmpty) || message != 'No Data';
  
  double get totalPnl => realized + unrealized;
  double get netPnl => totalPnl - (totalCharges ?? 0);
}

class TradeData {
  // Common fields
  String? aDJUSTEDNETRATE;
  String? bAMT;
  String? bQTY;
  String? bRATE;
  String? cLOSINGPRICE;
  String? cOMPANYCODE;
  String? eXCHANGE;
  String? nETAMT;
  String? nETQTY;
  String? nRATE;
  String? sAMT;
  String? sCRIPNAME;
  String? sCRIPSYMBOL;
  String? sQTY;
  String? sRATE;
  String? tRADEDATE;
  String? updatedNETQTY;
  String? cfBuyAmt;
  String? cfBuyQty;
  String? cfSellAmt;
  String? cfSellQty;
  String? index;
  bool? last;
  String? realisedpnl;
  String? totalBuyQty;
  String? totalBuyRate;
  String? totalRealisedPnl;
  String? totalSellQty;
  String? totalSellRate;
  String? unrealisedpnl;
  String? oQTY;
  String? oRATE;
  
  // Commodity-specific fields
  String? eXPIRYDATE;
  String? bRANCHCODE;
  String? bRANCHNAME;
  String? tRADETYPE;
  String? iNSTRUMENTTYPE;
  String? oPTIONTYPE;
  String? fullScripSymbol;
  String? profitDay;
  String? buyDate;
  String? sellDate;

  TradeData({
    this.aDJUSTEDNETRATE,
    this.bAMT,
    this.bQTY,
    this.bRATE,
    this.cLOSINGPRICE,
    this.cOMPANYCODE,
    this.eXCHANGE,
    this.nETAMT,
    this.nETQTY,
    this.nRATE,
    this.sAMT,
    this.sCRIPNAME,
    this.sCRIPSYMBOL,
    this.sQTY,
    this.sRATE,
    this.tRADEDATE,
    this.updatedNETQTY,
    this.cfBuyAmt,
    this.cfBuyQty,
    this.cfSellAmt,
    this.cfSellQty,
    this.index,
    this.last,
    this.realisedpnl,
    this.totalBuyQty,
    this.totalBuyRate,
    this.totalRealisedPnl,
    this.totalSellQty,
    this.totalSellRate,
    this.unrealisedpnl,
    this.oQTY,
    this.oRATE,
    this.eXPIRYDATE,
    this.bRANCHCODE,
    this.bRANCHNAME,
    this.tRADETYPE,
    this.iNSTRUMENTTYPE,
    this.oPTIONTYPE,
    this.fullScripSymbol,
    this.profitDay,
    this.buyDate,
    this.sellDate,
  });

  // Equity/FNO format constructor
  TradeData.fromJson(Map<String, dynamic> json) {
    aDJUSTEDNETRATE = json['ADJUSTED_NETRATE']?.toString();
    bAMT = json['BAMT']?.toString();
    bQTY = json['BQTY']?.toString();
    bRATE = json['BRATE']?.toString();
    cLOSINGPRICE = json['CLOSING_PRICE']?.toString();
    cOMPANYCODE = json['COMPANY_CODE']?.toString();
    eXCHANGE = json['EXCHANGE']?.toString();
    nETAMT = json['NETAMT']?.toString();
    nETQTY = json['NETQTY']?.toString();
    nRATE = json['NRATE']?.toString();
    sAMT = json['SAMT']?.toString();
    sCRIPNAME = json['SCRIP_NAME']?.toString();
    sCRIPSYMBOL = json['SCRIP_SYMBOL']?.toString();
    sQTY = json['SQTY']?.toString();
    sRATE = json['SRATE']?.toString();
    tRADEDATE = json['TRADE_DATE']?.toString();
    updatedNETQTY = json['Updated_NETQTY']?.toString();
    cfBuyAmt = json['cf_buy_amt']?.toString();
    cfBuyQty = json['cf_buy_qty']?.toString();
    cfSellAmt = json['cf_sell_amt']?.toString();
    cfSellQty = json['cf_sell_qty']?.toString();
    index = json['index']?.toString();
    last = json['last'];
    realisedpnl = json['realisedpnl']?.toString();
    totalBuyQty = json['total_buy_qty']?.toString();
    totalBuyRate = json['total_buy_rate']?.toString();
    totalRealisedPnl = json['total_realised_pnl']?.toString();
    totalSellQty = json['total_sell_qty']?.toString();
    totalSellRate = json['total_sell_rate']?.toString();
    unrealisedpnl = json['unrealisedpnl']?.toString();
    oQTY = json['Open_Qty']?.toString();
    oRATE = json['Open_Rate']?.toString();
  }

  // Commodity format constructor
  TradeData.fromCommodityJson(Map<String, dynamic> json) {
    index = json['REC']?.toString();
    
    // Buy details
    bAMT = json['BUYAMT']?.toString();
    bQTY = json['BUYQTY']?.toString();
    bRATE = json['BUYRATE']?.toString();
    
    // Sell details
    sAMT = json['SALEAMT']?.toString();
    sQTY = json['SALEQTY']?.toString();
    sRATE = json['SALERATE']?.toString();
    
    // Instrument details
    sCRIPNAME = json['SCRIP_NAME']?.toString();
    sCRIPSYMBOL = json['SCRIP_SYMBOL']?.toString();
    cOMPANYCODE = json['COCD']?.toString();
    eXCHANGE = json['COCD']?.toString(); // Use COCD as exchange for commodity
    
    // Dates
    tRADEDATE = json['BUY_TRADE_DATE']?.toString();
    eXPIRYDATE = json['EXPIRY_DATE']?.toString();
    
    // P&L and positions
    realisedpnl = json['PL_AMT']?.toString();
    unrealisedpnl = json['trade_unrealized_pnl']?.toString() ?? '0';
    nETAMT = json['NETAMT']?.toString();
    nETQTY = json['NETQTY']?.toString();
    updatedNETQTY = json['NETQTY']?.toString(); // Map for UI display
    
    // Open position - CRITICAL for UI bottom sheet
    oQTY = json['open_qty']?.toString() ?? '0';
    oRATE = json['open_rate']?.toString() ?? '0';
    
    // Closing price
    cLOSINGPRICE = json['CL_PRICE']?.toString() ?? '0';
    
    // Branch/Client info
    bRANCHCODE = json['BRANCH_CODE']?.toString();
    bRANCHNAME = json['BRANCH_NAME']?.toString();
    
    // Commodity-specific fields for cf_ values
    cfBuyAmt = json['BUYAMT']?.toString();
    cfBuyQty = json['BUYQTY']?.toString();
    cfSellAmt = json['SALEAMT']?.toString();
    cfSellQty = json['SALEQTY']?.toString();
    
    // Trade type
    tRADETYPE = json['TRADE_TYPE']?.toString();
    iNSTRUMENTTYPE = json['INSTRUMENT_TYPE']?.toString();
    oPTIONTYPE = json['OPTION_TYPE']?.toString();
    
    // Additional fields
    fullScripSymbol = json['FULL_SCRIP_SYMBOL']?.toString();
    profitDay = json['profit_day']?.toString();
    buyDate = json['buy_date']?.toString();
    sellDate = json['sell_date']?.toString();
    
    // Set totals for UI display (shown in bottom sheet)
    totalBuyQty = json['BUYQTY']?.toString();
    totalBuyRate = json['BUYRATE']?.toString();
    totalSellQty = json['SALEQTY']?.toString();
    totalSellRate = json['SALERATE']?.toString();
    totalRealisedPnl = json['PL_AMT']?.toString();
    
    // Set defaults for equity-only fields
    aDJUSTEDNETRATE = '0';
    nRATE = '0';
    
    // Set last flag
    last = false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['ADJUSTED_NETRATE'] = aDJUSTEDNETRATE;
    data['BAMT'] = bAMT;
    data['BQTY'] = bQTY;
    data['BRATE'] = bRATE;
    data['CLOSING_PRICE'] = cLOSINGPRICE;
    data['COMPANY_CODE'] = cOMPANYCODE;
    data['EXCHANGE'] = eXCHANGE;
    data['NETAMT'] = nETAMT;
    data['NETQTY'] = nETQTY;
    data['NRATE'] = nRATE;
    data['SAMT'] = sAMT;
    data['SCRIP_NAME'] = sCRIPNAME;
    data['SCRIP_SYMBOL'] = sCRIPSYMBOL;
    data['SQTY'] = sQTY;
    data['SRATE'] = sRATE;
    data['TRADE_DATE'] = tRADEDATE;
    data['Updated_NETQTY'] = updatedNETQTY;
    data['cf_buy_amt'] = cfBuyAmt;
    data['cf_buy_qty'] = cfBuyQty;
    data['cf_sell_amt'] = cfSellAmt;
    data['cf_sell_qty'] = cfSellQty;
    data['index'] = index;
    data['last'] = last;
    data['realisedpnl'] = realisedpnl;
    data['total_buy_qty'] = totalBuyQty;
    data['total_buy_rate'] = totalBuyRate;
    data['total_realised_pnl'] = totalRealisedPnl;
    data['total_sell_qty'] = totalSellQty;
    data['total_sell_rate'] = totalSellRate;
    data['unrealisedpnl'] = unrealisedpnl;
    data['Open_Qty'] = oQTY;
    data['Open_Rate'] = oRATE;
    
    // Commodity fields
    data['EXPIRY_DATE'] = eXPIRYDATE;
    data['BRANCH_CODE'] = bRANCHCODE;
    data['BRANCH_NAME'] = bRANCHNAME;
    data['TRADE_TYPE'] = tRADETYPE;
    data['INSTRUMENT_TYPE'] = iNSTRUMENTTYPE;
    data['OPTION_TYPE'] = oPTIONTYPE;
    data['FULL_SCRIP_SYMBOL'] = fullScripSymbol;
    data['profit_day'] = profitDay;
    data['buy_date'] = buyDate;
    data['sell_date'] = sellDate;
    
    return data;
  }
  
  // Helper methods for safe parsing in UI
  int get safeOpenQty => double.tryParse(oQTY ?? '0')?.toInt() ?? 0;
  double get safeOpenRate => double.tryParse(oRATE ?? '0') ?? 0.0;
  int get safeBuyQty => double.tryParse(bQTY ?? '0')?.toInt() ?? 0;
  double get safeBuyRate => double.tryParse(bRATE ?? '0') ?? 0.0;
  int get safeSellQty => double.tryParse(sQTY ?? '0')?.toInt() ?? 0;
  double get safeSellRate => double.tryParse(sRATE ?? '0') ?? 0.0;
  int get safeNetQty => double.tryParse(updatedNETQTY ?? '0')?.toInt() ?? 0;
  double get safeRealisedPnl => double.tryParse(realisedpnl ?? '0') ?? 0.0;
  double get safeUnrealisedPnl => double.tryParse(unrealisedpnl ?? '0') ?? 0.0;
}

class Journal {
  String? tRADEDATE;
  String? realisedpnl;
  String? totalBillNet;
  String? unrealisedpnl;

  Journal({
    this.tRADEDATE,
    this.realisedpnl,
    this.totalBillNet,
    this.unrealisedpnl
  });

  Journal.fromJson(Map<String, dynamic> json) {
    tRADEDATE = json['TRADE_DATE'];
    realisedpnl = json['realisedpnl']?.toString();
    totalBillNet = json['total_bill_net']?.toString();
    unrealisedpnl = json['unrealisedpnl']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['TRADE_DATE'] = tRADEDATE;
    data['realisedpnl'] = realisedpnl;
    data['total_bill_net'] = totalBillNet;
    data['unrealisedpnl'] = unrealisedpnl;
    return data;
  }
}

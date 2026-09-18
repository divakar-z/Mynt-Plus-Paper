import 'package:mynt_plus/sharedWidget/functions.dart';

class HoldingsModel {
  String? stat;
  List<ExchTsym>? exchTsym;
  String? upldprc;
  String? sellAmt;
  String? holdqty;
  String? npoadqty;
  String? npoadt1qty;
  String? benqty;
  String? sPrdtAli;
  String? prd;
  String? btstqty;
  String? usedqty;
  String? trdqty;
  String? invested;
  String? totalPnL;
  String? currentValue;
  String? emsg;
  String? brkcolqty;
  int? currentQty;
  int? saleableQty;
  String? dpQty;
  bool? isExitHoldings;
  String? rpnl;

  String? avgPrc;

  HoldingsModel(
      {this.stat,
      this.exchTsym,
      this.upldprc,
      this.sellAmt,
      this.holdqty,
      this.npoadqty,
      this.benqty,
      this.sPrdtAli,
      this.prd,
      this.btstqty,
      this.usedqty,
      this.emsg,
      this.invested,
      this.brkcolqty,
      this.currentQty,
      this.npoadt1qty,
      this.dpQty,
      this.trdqty,
      this.currentValue,
      this.totalPnL,
      this.saleableQty,
      this.isExitHoldings,
      this.avgPrc,
      this.rpnl});

  HoldingsModel.fromJson(Map<String, dynamic> json) {
    stat = json['stat'];
    if (json['exch_tsym'] != null) {
      exchTsym = <ExchTsym>[];
      json['exch_tsym'].forEach((v) {
        exchTsym!.add(ExchTsym.fromJson(v));
      });
    }
    upldprc = json['upldprc'];
    sellAmt = json['sell_amt'];
    holdqty = json['holdqty'];
    npoadqty = json['npoadqty'];
    benqty = json['benqty'];
    brkcolqty = json['brkcolqty'];
    sPrdtAli = json['s_prdt_ali'];
    prd = json['prd'];
    dpQty = json['dpqty'];
    npoadt1qty = json['npoadt1qty'];
    btstqty = json['btstqty'];
    usedqty = json['usedqty'];
    currentValue = json['currentValue'];
    emsg = json['emsg'].toString();
    trdqty = json['trdqty'];
    avgPrc = json['avgPrc'];
    currentQty = json["currentQty"];
    saleableQty = json['saleableQty'];
    invested = invested == null ? "0.00" : json['invested'];
    totalPnL = totalPnL == null ? "0.00" : json['totalPnL'];
    isExitHoldings = json['isExitHoldings'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stat'] = stat;
    if (exchTsym != null) {
      data['exch_tsym'] = exchTsym!.map((v) => v.toJson()).toList();
    }
    data['upldprc'] = upldprc;
    data['sell_amt'] = sellAmt;
    data['currentValue'] = currentValue;
    data['holdqty'] = holdqty;
    data['npoadqty'] = npoadqty;
    data['npoadt1qty'] = npoadt1qty;
    data['brkcolqty'] = brkcolqty;
    data['benqty'] = benqty;
    data['s_prdt_ali'] = sPrdtAli;
    data['prd'] = prd;
    data['currentQty'] = currentQty;
    data['btstqty'] = btstqty;
    data['usedqty'] = usedqty;
    data['trdqty'] = trdqty;
    data['invested'] = invested;
    data['emsg'] = emsg;
    data['saleableQty'] = saleableQty;
    data['totalPnL'] = totalPnL;
    data['dpqty'] = dpQty;
    data['avgPrc'] = avgPrc;
    data['isExitHoldings'] = isExitHoldings;
    return data;
  }

    /// Updates this HoldingsModel by merging in the new model's data.
  /// Primitive fields are updated if the new model provides a non-null value.
  /// For the 'exchTsym' list, existing elements are updated by matching on token;
  /// if a new element is not already present, it is added.
  void updateFrom(HoldingsModel newModel) {
    stat = newModel.stat ?? stat;
    upldprc = newModel.upldprc ?? upldprc;
    sellAmt = newModel.sellAmt ?? sellAmt;
    holdqty = newModel.holdqty ?? holdqty;
    npoadqty = newModel.npoadqty ?? npoadqty;
    npoadt1qty = newModel.npoadt1qty ?? npoadt1qty;
    benqty = newModel.benqty ?? benqty;
    sPrdtAli = newModel.sPrdtAli ?? sPrdtAli;
    prd = newModel.prd ?? prd;
    btstqty = newModel.btstqty ?? btstqty;
    usedqty = newModel.usedqty ?? usedqty;
    trdqty = newModel.trdqty ?? trdqty;
    invested = newModel.invested ?? invested;
    totalPnL = newModel.totalPnL ?? totalPnL;
    currentValue = newModel.currentValue ?? currentValue;
    emsg = newModel.emsg ?? emsg;
    currentQty = newModel.currentQty ?? currentQty;
    saleableQty = newModel.saleableQty ?? saleableQty;
    dpQty = newModel.dpQty ?? dpQty;
    avgPrc = newModel.avgPrc ?? avgPrc;
    isExitHoldings = newModel.isExitHoldings ?? isExitHoldings;

    // Update exchTsym list
    if (newModel.exchTsym != null) {
      if (exchTsym == null || exchTsym!.isEmpty) {
        exchTsym = newModel.exchTsym;
      } else {
        // For each new ExchTsym item, update if exists, or add new one.
        for (var newExch in newModel.exchTsym!) {
          int index =
              exchTsym!.indexWhere((exch) => exch.token == newExch.token);
          if (index != -1) {
            exchTsym![index].updateFrom(newExch);
          } else {
            exchTsym!.add(newExch);
          }
        }
      }
    }
  }
}

class ExchTsym {
  /// Backend display name from the DerivativeMaster (keyed by exch:token), or
  /// null when the contract isn't in the master (equities / indices).
  String? get masterName => DerivativeMaster.nameFor(exch, token);

  /// Ready contract name for display: master name when available, else the
  /// existing tsym/expiry/option assembly.
  String get displayName =>
      masterName ??
      '${tsym?.replaceAll("-EQ", "") ?? ''} ${expDate ?? ''} ${option ?? ''}';

  String? exch;
  String? token;
  String? tsym;
  String? pp;
  String? ti;
  String? ls;
  String? isin;
  String? lp;
  String? low;
  String? high;
  String? open;
  String? close;
  String? profitNloss;
  String? change;
  String? perChange;
  String? pNlChng;
  String? currentAmt;
  bool? isExit;
  String? oneDayChg;
  String? symbol;
  String? expDate;
  String? option;
  ExchTsym(
      {this.exch,
      this.token,
      this.tsym,
      this.pp,
      this.ti,
      this.ls,
      this.isin,
      this.lp,
      this.low,
      this.high,
      this.open,
      this.close,
      this.profitNloss,
      this.change,
      this.perChange,
      this.pNlChng,
      this.currentAmt,
      this.isExit,
      this.oneDayChg,
      this.expDate,
      this.option,
      this.symbol});

  ExchTsym.fromJson(Map<String, dynamic> json) {
    exch = json['exch'];
    token = json['token'];
    tsym = json['tsym'];
    pp = json['pp'];
    ti = json['ti'];
    ls = json['ls'];
    isin = json['isin'];
    lp = lp == null ? "0.00" : json['lp'];
    low = low == null ? "0.00" : json['low'];
    high = high == null ? "0.00" : json['high'];
    open = open == null ? "0.00" : json['open'];
    close = close == null ? "0.00" : json['close'];
    profitNloss = profitNloss == null ? "0.00" : json['profitNloss'];
    change = change == null ? "0.00" : json['change'];
    perChange = perChange == null ? "0.00" : json['perChange'];
    pNlChng = pNlChng == null ? "0.00" : json['pNlChng'];
    currentAmt = currentAmt == null ? "0.00" : json['currentAmt'];
    isExit = json['isExit'];
    oneDayChg = json['oneDayChg'];
    expDate = json['expDate'];
    symbol = json['symbol'];
    option = json['option'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['exch'] = exch;
    data['token'] = token;
    data['tsym'] = tsym;
    data['pp'] = pp;
    data['ti'] = ti;
    data['ls'] = ls;
    data['isin'] = isin;
    data['lp'] = lp;
    data['low'] = low;
    data['high'] = high;
    data['open'] = open;
    data['close'] = close;
    data['profitNloss'] = profitNloss;
    data['change'] = change;
    data['perChange'] = perChange;
    data['pNlChng'] = pNlChng;
    data['isExit'] = isExit;
    data['currentAmt'] = currentAmt;
    data['oneDayChg'] = oneDayChg;
    data['option'] = option;
    data['expDate'] = expDate;
    data['symbol'] = symbol;
    return data;
  }

  /// Updates this ExchTsym instance with values from [newExch].
  /// Only non-null values from [newExch] will overwrite the current values.
  void updateFrom(ExchTsym newExch) {
    exch = newExch.exch ?? exch;
    token = newExch.token ?? token;
    tsym = newExch.tsym ?? tsym;
    pp = newExch.pp ?? pp;
    ti = newExch.ti ?? ti;
    ls = newExch.ls ?? ls;
    isin = newExch.isin ?? isin;
    if (double.parse(newExch.lp!) != 0) {
    lp = newExch.lp ?? lp;
    close = newExch.close ?? close;
    profitNloss = newExch.profitNloss ?? profitNloss;
    change = newExch.change ?? change;
    perChange = newExch.perChange ?? perChange;
    pNlChng = newExch.pNlChng ?? pNlChng;
    oneDayChg = newExch.oneDayChg ?? oneDayChg;
    }
    low = newExch.low ?? low;
    high = newExch.high ?? high;
    open = newExch.open ?? open;
    currentAmt = newExch.currentAmt ?? currentAmt;
    isExit = newExch.isExit ?? isExit;
    expDate = newExch.expDate ?? expDate;
    symbol = newExch.symbol ?? symbol;
    option = newExch.option ?? option;
  
  }
}
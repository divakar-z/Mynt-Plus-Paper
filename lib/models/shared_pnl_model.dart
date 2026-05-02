// Response model for POST /report/getsharedata.
//
// Public viewer fetches a previously-shared PnL by Unique_Code (ucode in URL).
// Backend returns the trader's name, date range, segment, and the entire PnL
// payload that was originally pushed via /sharenew.

class SharedPnlModel {
  final String? uname;
  final String? cc;
  final String? fromDate;
  final String? toDate;
  final String? segment;
  final String? msg;
  final String? oldNew;
  final SharedPnlData? data;

  SharedPnlModel({
    this.uname,
    this.cc,
    this.fromDate,
    this.toDate,
    this.segment,
    this.msg,
    this.oldNew,
    this.data,
  });

  bool get isSharingTurnedOff => msg == 'Sharing is Turned Off';
  bool get isCommodity => segment == 'Commodity';

  /// Replace the inner [data] (used after the commodity second-call enrichment).
  SharedPnlModel withData(SharedPnlData newData) => SharedPnlModel(
        uname: uname,
        cc: cc,
        fromDate: fromDate,
        toDate: toDate,
        segment: segment,
        msg: msg,
        oldNew: oldNew,
        data: newData,
      );

  factory SharedPnlModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final inner = raw is Map ? Map<String, dynamic>.from(raw) : null;

    // Some commodity responses omit metadata at the top level; check inner too.
    String? pick(String key) =>
        json[key]?.toString() ?? inner?[key]?.toString();

    final parsedData =
        inner != null ? SharedPnlData.fromJson(inner) : null;

    // Infer segment if backend didn't include `seg` but the payload is clearly
    // commodity-shaped (dateWise/symbolWise present).
    var segment = pick('seg');
    if ((segment == null || segment.isEmpty) &&
        inner != null &&
        (inner.containsKey('dateWise') || inner.containsKey('symbolWise'))) {
      segment = 'Commodity';
    }

    return SharedPnlModel(
      uname: pick('uname'),
      cc: pick('cc'),
      fromDate: pick('from_date'),
      toDate: pick('to_date'),
      segment: segment,
      msg: pick('msg'),
      oldNew: pick('old_new'),
      data: parsedData,
    );
  }
}

class SharedPnlData {
  // Date-keyed map: { "2026-04-17 00:00:00": [<trade>, ...], ... }
  // Each trade in this list uses the BQTY / BRATE / SQTY / SRATE field scheme.
  final Map<String, List<SharedTrade>> dateGrouped;
  // Flat list of trades (Data2). Uses the total_buy_qty / total_buy_rate scheme.
  // Items where last==true represent the latest aggregate per symbol.
  final List<SharedTrade> trades;
  final List<SharedJournalEntry> journal;
  final List<dynamic> symbolArr;
  final double totalCharges;
  // Set for commodity, where Vue uses stat.total_realised_pnl directly
  // and forces unrealised to 0 (Daily_pnl.vue:2856-2857).
  final double? realisedOverride;
  final double? unrealisedOverride;

  SharedPnlData({
    required this.dateGrouped,
    required this.trades,
    required this.journal,
    required this.symbolArr,
    required this.totalCharges,
    this.realisedOverride,
    this.unrealisedOverride,
  });

  /// Realised P&L. For Equity/FNO/Currency, summed from Data2 trades
  /// (Vue line 2697-2706). For Commodity, taken from stat.total_realised_pnl.
  double get realisedTotal =>
      realisedOverride ?? trades.fold<double>(0, (s, t) => s + t.realisedPnl);

  /// Unrealised P&L. For Equity/FNO/Currency, summed from Data2 trades.
  /// For Commodity, hardcoded to 0 (matching Vue line 2857).
  double get unrealisedTotal =>
      unrealisedOverride ?? trades.fold<double>(0, (s, t) => s + t.unrealisedPnl);

  factory SharedPnlData.fromJson(Map<String, dynamic> json) {
    // Commodity payloads use a totally different shape (dateWise/symbolWise/stat).
    // If we see those keys, route to the commodity factory.
    if (json.containsKey('dateWise') || json.containsKey('symbolWise')) {
      return SharedPnlData.fromCommodityJson(json);
    }

    final dataField = json['Data'];
    final data2 = json['Data2'];
    final journalRaw = json['journal'];
    final symbolArrRaw = json['symbolarr'];

    // Build date-keyed groups. Each value is a list of per-trade rows whose
    // qty/rate fields use the BQTY/BRATE scheme. Pass aggregate=false so the
    // factory prefers the per-trade fields, not the symbol-aggregate ones.
    final groups = <String, List<SharedTrade>>{};
    if (dataField is Map) {
      dataField.forEach((dateKey, value) {
        if (value is List) {
          groups[dateKey.toString()] = value
              .whereType<Map>()
              .map((m) => SharedTrade.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      });
    }

    return SharedPnlData(
      dateGrouped: groups,
      // Data2 entries are per-symbol aggregates → aggregate=true.
      trades: data2 is List
          ? data2
              .whereType<Map>()
              .map((m) => SharedTrade.fromJson(
                    Map<String, dynamic>.from(m),
                    aggregate: true,
                  ))
              .toList()
          : <SharedTrade>[],
      journal: journalRaw is List
          ? journalRaw
              .whereType<Map>()
              .map((m) =>
                  SharedJournalEntry.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : <SharedJournalEntry>[],
      symbolArr: symbolArrRaw is List ? symbolArrRaw : <dynamic>[],
      totalCharges: _toDouble(json['total_charges']),
    );
  }

  /// Builds the unified data shape from a commodity payload — either from
  /// `/getJournalDiary3` (Vue path) or from `/getsharedata` directly when the
  /// backend returns the full commodity data inline.
  ///
  /// Tolerates a wrapping `data` envelope: real production responses look like
  ///   { cc, data: { dateWise: {...}, symbolWise: {...}, stat: {...} } }
  /// while older docs / fallbacks have the keys at the top level.
  ///
  /// Each `dateWise[date].trades` is preserved as the per-date list (better
  /// than Vue's single-row collapse — visitors can see individual trades).
  factory SharedPnlData.fromCommodityJson(Map<String, dynamic> json) {
    // Unwrap if the actual payload is nested under `data`.
    final root = (json['data'] is Map &&
            ((json['data'] as Map).containsKey('dateWise') ||
                (json['data'] as Map).containsKey('symbolWise')))
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    final symbolWise = root['symbolWise'];
    final dateWise = root['dateWise'];
    final stat = root['stat'];

    // Script Wise — synthetic trade per symbol, fields lifted from details.sum.
    // Backend `sum` typically gives total_buy_qty + total_buy_amt but no
    // explicit total_buy_rate; derive rate = amt / qty before parsing so the
    // SharedTrade ends up with a non-zero rate. Mirrors the in-app fallback in
    // calenderPnl_screen.dart:_buildScriptWiseSection.
    final trades = <SharedTrade>[];
    if (symbolWise is Map) {
      symbolWise.forEach((symbol, details) {
        if (details is! Map) return;
        final sum = details['sum'];
        final sumMap = sum is Map
            ? Map<String, dynamic>.from(sum)
            : <String, dynamic>{};

        final buyQty = _toDouble(sumMap['total_buy_qty'] ??
            sumMap['BUYQTY'] ??
            sumMap['buy_qty']);
        final buyAmt = _toDouble(sumMap['total_buy_amt'] ??
            sumMap['BUYAMT'] ??
            sumMap['buy_amt'] ??
            sumMap['BUY_AMT']);
        if ((sumMap['total_buy_rate'] == null ||
                _toDouble(sumMap['total_buy_rate']) == 0) &&
            buyQty > 0 &&
            buyAmt != 0) {
          sumMap['total_buy_rate'] = buyAmt / buyQty;
        }

        final sellQty = _toDouble(sumMap['total_sell_qty'] ??
            sumMap['SALEQTY'] ??
            sumMap['sell_qty']);
        final sellAmt = _toDouble(sumMap['total_sell_amt'] ??
            sumMap['SALEAMT'] ??
            sumMap['sell_amt'] ??
            sumMap['SALE_AMT']);
        if ((sumMap['total_sell_rate'] == null ||
                _toDouble(sumMap['total_sell_rate']) == 0) &&
            sellQty > 0 &&
            sellAmt != 0) {
          sumMap['total_sell_rate'] = sellAmt / sellQty;
        }

        final merged = <String, dynamic>{
          ...sumMap,
          'symbol': symbol,
          'realisedpnl':
              details['realised_pnl'] ?? details['realisedpnl'] ?? 0,
          'unrealisedpnl': 0,
          'last': true,
        };
        // symbolWise.sum is a per-symbol aggregate → prefer total_* keys.
        trades.add(SharedTrade.fromJson(merged, aggregate: true));
      });
    }

    // Date Wise — expand each date's `trades[]` into individual SharedTrade rows.
    final groups = <String, List<SharedTrade>>{};
    final journal = <SharedJournalEntry>[];
    double realisedFromDateWise = 0;

    if (dateWise is Map) {
      dateWise.forEach((dateKey, value) {
        if (value is! Map) return;
        final realised = _toDouble(value['realised_pnl']);
        realisedFromDateWise += realised;

        final innerTrades = <SharedTrade>[];
        final inner = value['trades'];
        if (inner is List) {
          for (final t in inner) {
            if (t is Map) {
              final merged = <String, dynamic>{
                ...Map<String, dynamic>.from(t),
                'TRADE_DATE': dateKey,
              };
              innerTrades.add(SharedTrade.fromJson(merged));
            }
          }
        }
        // Fallback: synthesize one row from the day's totals if no inner trades.
        if (innerTrades.isEmpty) {
          final merged = <String, dynamic>{
            ...Map<String, dynamic>.from(value),
            'TRADE_DATE': dateKey,
            'realisedpnl': realised,
          };
          innerTrades.add(SharedTrade.fromJson(merged));
        }
        groups[dateKey.toString()] = innerTrades;
        journal.add(SharedJournalEntry(
          tradeDate: _parseTradeDate(dateKey),
          realisedPnl: realised,
        ));
      });
    }

    final statMap =
        stat is Map ? Map<String, dynamic>.from(stat) : <String, dynamic>{};
    // Prefer stat.total_realised_pnl; fall back to summed dateWise totals.
    final totalRealised = statMap.containsKey('total_realised_pnl')
        ? _toDouble(statMap['total_realised_pnl'])
        : realisedFromDateWise;

    return SharedPnlData(
      dateGrouped: groups,
      trades: trades,
      journal: journal,
      symbolArr: const <dynamic>[],
      totalCharges: _toDouble(statMap['total_charges']),
      realisedOverride: totalRealised,
      unrealisedOverride: 0.0,
    );
  }
}

class SharedJournalEntry {
  final DateTime? tradeDate;
  final double realisedPnl;

  SharedJournalEntry({this.tradeDate, required this.realisedPnl});

  factory SharedJournalEntry.fromJson(Map<String, dynamic> json) {
    return SharedJournalEntry(
      tradeDate: _parseTradeDate(json['TRADE_DATE']),
      realisedPnl: _toDouble(json['realisedpnl']),
    );
  }
}

class SharedTrade {
  final String symbol;
  final DateTime? tradeDate;
  final double buyQty;
  final double buyRate;
  final double sellQty;
  final double sellRate;
  final double netQty;
  final double closePrice;
  final double realisedPnl;
  final double unrealisedPnl;
  final double openQty;
  final double openRate;
  final bool isLast;

  SharedTrade({
    required this.symbol,
    this.tradeDate,
    required this.buyQty,
    required this.buyRate,
    required this.sellQty,
    required this.sellRate,
    required this.netQty,
    required this.closePrice,
    required this.realisedPnl,
    required this.unrealisedPnl,
    required this.openQty,
    required this.openRate,
    required this.isLast,
  });

  // Three different field-name schemes exist across the backend payloads:
  //   Equity/FNO Data2 (Script Wise, aggregate):  total_buy_qty / total_buy_rate / ...
  //   Equity/FNO Data[date] (Date Wise, per-trade): BQTY / BRATE / SQTY / SRATE
  //   Commodity dateWise[date].trades[]:           BUYQTY / BUYRATE / SALEQTY / SALERATE / PL_AMT
  //
  // Critically, Data[date] entries can contain BOTH `total_buy_qty` AND `BQTY`
  // — the former is the all-time aggregate across dates, the latter is the
  // per-day trade quantity. The factory must pick the right one per call site.
  //
  // Pass [aggregate]=true when parsing Data2 (Script Wise / per-symbol totals)
  // so total_* takes priority. Default false for per-trade rows where BQTY
  // comes first.
  factory SharedTrade.fromJson(Map<String, dynamic> json,
      {bool aggregate = false}) {
    final dynamic buyQtyVal = aggregate
        ? (json['total_buy_qty'] ??
            json['BQTY'] ??
            json['BUYQTY'] ??
            json['buy_qty'])
        : (json['BQTY'] ??
            json['BUYQTY'] ??
            json['total_buy_qty'] ??
            json['buy_qty']);
    final dynamic buyRateVal = aggregate
        ? (json['total_buy_rate'] ?? json['BRATE'] ?? json['BUYRATE'])
        : (json['BRATE'] ?? json['BUYRATE'] ?? json['total_buy_rate']);
    final dynamic sellQtyVal = aggregate
        ? (json['total_sell_qty'] ??
            json['SQTY'] ??
            json['SALEQTY'] ??
            json['sell_qty'])
        : (json['SQTY'] ??
            json['SALEQTY'] ??
            json['total_sell_qty'] ??
            json['sell_qty']);
    final dynamic sellRateVal = aggregate
        ? (json['total_sell_rate'] ?? json['SRATE'] ?? json['SALERATE'])
        : (json['SRATE'] ?? json['SALERATE'] ?? json['total_sell_rate']);

    return SharedTrade(
      symbol: (json['SCRIP_SYMBOL'] ?? json['symbol'] ?? json['name'] ?? '')
          .toString(),
      tradeDate: _parseTradeDate(json['TRADE_DATE']),
      buyQty: _toDouble(buyQtyVal),
      buyRate: _toDouble(buyRateVal),
      sellQty: _toDouble(sellQtyVal),
      sellRate: _toDouble(sellRateVal),
      netQty: _toDouble(json['Updated_NETQTY'] ?? json['NETQTY']),
      closePrice: _toDouble(json['CLOSING_PRICE'] ?? json['CL_PRICE']),
      realisedPnl: _toDouble(
          json['realisedpnl'] ?? json['realised_pnl'] ?? json['PL_AMT']),
      unrealisedPnl: _toDouble(
          json['unrealisedpnl'] ?? json['trade_unrealized_pnl']),
      openQty: _toDouble(json['Open_Qty']),
      openRate: _toDouble(json['Open_Rate']),
      isLast: json['last'] == true,
    );
  }
}

DateTime? _parseTradeDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  try {
    // Handles "2026-04-17T00:00:00" and "2026-04-17 00:00:00" — Vue does the same normalization.
    return DateTime.parse(s.replaceAll(' ', 'T').split('T').first);
  } catch (_) {
    return null;
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

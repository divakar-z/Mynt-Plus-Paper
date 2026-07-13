import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/marketwatch_model/linked_scrips.dart';
import 'package:mynt_plus/utils/rupee_convert_format.dart';
import 'package:mynt_plus/models/marketwatch_model/opt_chain_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/order_book_model/order_margin_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/models/strategy_builder_model/select_symbols_model.dart';
import 'package:mynt_plus/models/span_calc_model.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';

final strategyBuilderProvider =
    ChangeNotifierProvider((ref) => StrategyBuilderProvider(ref));

/// Basket item model for strategy builder
class StrategyBasketItem {
  final String tsym;
  final String token;
  final String exch;
  final String strprc;
  final String optt; // CE or PE
  final String expdate;
  String buySell; // BUY or SELL
  int ordlot;
  double entryPrice;
  double ltp;
  bool checkbox;
  int lotSize;

  // API leg definition — the source of truth for this leg's parameters
  // (exchange, symbol, option_type, expiry type/offset, strike type/offset)
  SelectSymbolsLegRequest? apiLeg;

  // Greeks
  double? iv;
  double? delta;
  double? gamma;
  double? theta;
  double? vega;

  StrategyBasketItem({
    required this.tsym,
    required this.token,
    required this.exch,
    required this.strprc,
    required this.optt,
    required this.expdate,
    required this.buySell,
    required this.ordlot,
    required this.entryPrice,
    required this.ltp,
    this.checkbox = true,
    this.lotSize = 1,
    this.apiLeg,
    this.iv,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
  });

  StrategyBasketItem copyWith({
    String? tsym,
    String? token,
    String? exch,
    String? strprc,
    String? optt,
    String? expdate,
    String? buySell,
    int? ordlot,
    double? entryPrice,
    double? ltp,
    bool? checkbox,
    int? lotSize,
    SelectSymbolsLegRequest? apiLeg,
    double? iv,
    double? delta,
    double? gamma,
    double? theta,
    double? vega,
  }) {
    return StrategyBasketItem(
      tsym: tsym ?? this.tsym,
      token: token ?? this.token,
      exch: exch ?? this.exch,
      strprc: strprc ?? this.strprc,
      optt: optt ?? this.optt,
      expdate: expdate ?? this.expdate,
      buySell: buySell ?? this.buySell,
      ordlot: ordlot ?? this.ordlot,
      entryPrice: entryPrice ?? this.entryPrice,
      ltp: ltp ?? this.ltp,
      checkbox: checkbox ?? this.checkbox,
      lotSize: lotSize ?? this.lotSize,
      apiLeg: apiLeg ?? this.apiLeg,
      iv: iv ?? this.iv,
      delta: delta ?? this.delta,
      gamma: gamma ?? this.gamma,
      theta: theta ?? this.theta,
      vega: vega ?? this.vega,
    );
  }
}

/// One leg's SPAN margin (span + expo) in the margin-benefit breakdown.
class StrategyMarginLeg {
  final String name;
  final double margin;
  StrategyMarginLeg(this.name, this.margin);
}

/// Result of the SpanCalc margin-benefit calculation shown in the Margin Info
/// dialog: each leg's own margin, their sum, the combined margin, and the
/// benefit (sum - combined). (Zerodha-style)
class StrategyMarginBenefit {
  final List<StrategyMarginLeg> legs;
  final double sumIndividual;
  final double combined;
  final double benefit;
  StrategyMarginBenefit({
    required this.legs,
    required this.sumIndividual,
    required this.combined,
    required this.benefit,
  });
}

/// Predefined strategy model
class PredefinedStrategy {
  final String title;
  final String type; // Bullish, Bearish, Neutral
  final String image;
  final List<StrategyLeg> legs;
  // Full API-format legs for saved strategies (used to call /select-symbols on load)
  final List<Map<String, dynamic>>? savedApiLegs;
  // Server-assigned UUID for CRUD operations
  final String? strategyId;

  PredefinedStrategy({
    required this.title,
    required this.type,
    required this.image,
    required this.legs,
    this.savedApiLegs,
    this.strategyId,
  });
}

/// Strategy leg definition
class StrategyLeg {
  final String action; // BUY or SELL
  final String optionType; // CE or PE
  final String strikeType; // ATM, ITM, OTM
  final int strikeOffset; // 0 for ATM, positive for OTM, negative for ITM

  StrategyLeg({
    required this.action,
    required this.optionType,
    required this.strikeType,
    required this.strikeOffset,
  });
}

/// Mutable draft model for custom strategy leg builder
class CustomStrategyLegDraft {
  String action; // 'BUY' or 'SELL'
  int ordlot; // lots (default 1)
  String optionType; // 'CE' or 'PE'
  int expiryOffset; // 0, 1, 2...
  String strikeType; // 'ATM', 'ITM', 'OTM', 'PREMIUM'
  int strikeOffset; // 0, 1, 2... (for ATM/ITM/OTM)
  double premiumValue; // premium price (for PREMIUM mode)
  bool checkbox; // selection state for clear

  CustomStrategyLegDraft({
    this.action = 'BUY',
    this.ordlot = 1,
    this.optionType = 'CE',
    this.expiryOffset = 0,
    this.strikeType = 'ATM',
    this.strikeOffset = 0,
    this.premiumValue = 0,
    this.checkbox = true,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'ordlot': ordlot,
        'optionType': optionType,
        'expiryOffset': expiryOffset,
        'strikeType': strikeType,
        'strikeOffset': strikeOffset,
        'premiumValue': premiumValue,
      };

  factory CustomStrategyLegDraft.fromJson(Map<String, dynamic> json) {
    return CustomStrategyLegDraft(
      action: json['action'] ?? 'BUY',
      ordlot: json['ordlot'] ?? 1,
      optionType: json['optionType'] ?? 'CE',
      expiryOffset: json['expiryOffset'] ?? 0,
      strikeType: json['strikeType'] ?? 'ATM',
      strikeOffset: json['strikeOffset'] ?? 0,
      premiumValue: (json['premiumValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Payoff metrics
class PayoffMetrics {
  final String maxProfit;
  final String maxLoss;
  final double popPercent;
  final String riskRewardRatio;
  final List<double> breakevens;

  PayoffMetrics({
    this.maxProfit = '--',
    this.maxLoss = '--',
    this.popPercent = 0,
    this.riskRewardRatio = '--',
    this.breakevens = const [],
  });
}

/// Payoff data point
class PayoffDataPoint {
  final double price;
  final double profit;

  PayoffDataPoint(this.price, this.profit);
}

class StrategyBuilderProvider extends DefaultChangeNotifier {
  final Ref ref;
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();

  StrategyBuilderProvider(this.ref);

  // Basket items
  final List<StrategyBasketItem> _basket = [];
  List<StrategyBasketItem> get basket => _basket;

  // Selected stock/index
  String _selectedSymbol = 'NIFTY 50';
  String get selectedSymbol => _selectedSymbol;

  String _selectedToken = '26000';
  String get selectedToken => _selectedToken;

  String _selectedExch = 'NSE';
  String get selectedExch => _selectedExch;

  // Spot price
  double _spotPrice = 0;
  double get spotPrice => _spotPrice;
  double _spotPriceChangePercent = 0;
  double get spotPriceChangePercent => _spotPriceChangePercent;

  // Expiry dates
  List<String> _expiryDates = [];
  List<String> get expiryDates => _expiryDates;

  String _selectedExpiry = '';
  String get selectedExpiry => _selectedExpiry;

  // Option chain data
  List<OptionValues> _optionChain = [];
  List<OptionValues> get optionChain => _optionChain;

  List<OptionExp> _expiryDataRaw = [];

  // Strategy type tab
  String _strategyTypeTab = 'Bullish';
  String get strategyTypeTab => _strategyTypeTab;

  // Active predefined strategy
  String? _activePredefinedStrategy;
  String? get activePredefinedStrategy => _activePredefinedStrategy;

  // Name of the saved custom builder strategy currently being edited
  String? _editingCustomBuilderName;
  String? get editingCustomBuilderName => _editingCustomBuilderName;

  // Lot multiplier
  int _lotMultiplier = 1;
  int get lotMultiplier => _lotMultiplier;

  // Payoff tab
  int _payoffTab = 0;
  int get payoffTab => _payoffTab;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isOrderLoading = false;
  bool get isOrderLoading => _isOrderLoading;

  bool _isPayoffLoading = false;
  bool get isPayoffLoading => _isPayoffLoading;

  // Monotonic counter to discard stale payoff API responses
  int _payoffRequestId = 0;

  // Target controls
  double _targetSpotPrice = 0;
  double get targetSpotPrice => _targetSpotPrice;
  bool _isTargetSpotActive = false;
  bool get isTargetSpotActive => _isTargetSpotActive;

  int _targetDaysToExpiry = 0;
  int get targetDaysToExpiry => _targetDaysToExpiry;

  int _daysToExpiry = 0;
  int get daysToExpiry => _daysToExpiry;

  // SD lines toggle
  bool _showSDLines = false;
  bool get showSDLines => _showSDLines;

  // Strike count for option chain
  int _selectedStrikeCount = 15;
  int get selectedStrikeCount => _selectedStrikeCount;

  Future<void> setStrikeCount(int count, BuildContext context) async {
    if (count == _selectedStrikeCount) return;
    _selectedStrikeCount = count;
    notifyListeners();
    await loadOptionChain(context);
  }

  /// Calculate SD price levels based on spot price, average IV, and days to expiry
  /// Returns a map with keys: -2σ, -1σ, +1σ, +2σ
  Map<String, double> get sdPrices {
    // Only return empty if we have no spot price at all
    if (_spotPrice <= 0) {
      return {};
    }

    // Calculate average IV from basket items that have IV
    double avgIV = 0.15; // Default 15% IV if no IV data available
    final itemsWithIV = _basket.where((item) => item.checkbox && item.iv != null && item.iv! > 0).toList();
    if (itemsWithIV.isNotEmpty) {
      avgIV = itemsWithIV.map((item) => item.iv!).reduce((a, b) => a + b) / itemsWithIV.length;
    }

    // Calculate 1 standard deviation price move
    // SD move = spotPrice × IV × √(T/365)
    // Use minimum of 7 days for calculation to show meaningful SD lines
    final daysForCalc = _daysToExpiry > 0 ? _daysToExpiry : 7;
    final timeInYears = daysForCalc / 365.0;
    final sdMove = _spotPrice * avgIV * math.sqrt(timeInYears);

    return {
      '-2σ': _spotPrice - (2 * sdMove),
      '-1σ': _spotPrice - sdMove,
      '+1σ': _spotPrice + sdMove,
      '+2σ': _spotPrice + (2 * sdMove),
    };
  }

  // Payoff data
  List<PayoffDataPoint> _payoffData = [];
  List<PayoffDataPoint> get payoffData => _payoffData;

  List<PayoffDataPoint> _targetPayoffData = [];
  List<PayoffDataPoint> get targetPayoffData => _targetPayoffData;

  PayoffMetrics _metrics = PayoffMetrics();
  PayoffMetrics get metrics => _metrics;

  // Margin
  OrderMarginModel? _basketMarginModel;
  OrderMarginModel? get basketMarginModel => _basketMarginModel;
  bool _includeExistingMargin = false;
  bool get includeExistingMargin => _includeExistingMargin;

  String get totalMargin {
    if (_basketMarginModel == null) return '--';
    if (_includeExistingMargin) {
      return _basketMarginModel!.basketMarginWithExisting.toIndianRupee();
    }
    return _basketMarginModel!.basketMargin.toIndianRupee();
  }

  String get marginBenefit {
    if (_basketMarginModel == null) return '--';
    final benefit = _basketMarginModel!.marginBenefit;
    return benefit > 1 ? benefit.toIndianRupee() : '--';
  }

  void toggleIncludeExistingMargin() {
    _includeExistingMargin = !_includeExistingMargin;
    notifyListeners();
  }

  // ── SpanCalc margin-benefit (shown in the Margin Info dialog) ──────────────
  // Phase 1: call SpanCalc once per leg (its individual margin) + once for all
  // legs together (combined), then benefit = sum(individual) - combined. Same
  // method the mobile SPAN calculator and Zerodha use. The full combined
  // response is logged so we can later check whether a single combined call is
  // enough (Phase 2).
  bool _isCalcMarginBenefit = false;
  bool get isCalcMarginBenefit => _isCalcMarginBenefit;
  StrategyMarginBenefit? _marginBenefitResult;
  StrategyMarginBenefit? get marginBenefitResult => _marginBenefitResult;
  String? _marginBenefitError;
  String? get marginBenefitError => _marginBenefitError;

  Future<void> calculateMarginBenefit() async {
    final selectedItems = _basket.where((item) => item.checkbox).toList();
    if (selectedItems.isEmpty) {
      _isCalcMarginBenefit = false;
      _marginBenefitResult = null;
      _marginBenefitError = 'Add at least one leg to see the margin benefit.';
      notifyListeners();
      return;
    }

    _isCalcMarginBenefit = true;
    _marginBenefitResult = null;
    _marginBenefitError = null;
    notifyListeners();

    try {
      final positions = <SpanCalcPositionItem>[];
      final legs = <StrategyMarginLeg>[];
      double sumIndividual = 0;

      for (final item in selectedItems) {
        // SpanCalc needs symname/instname (not stored on the basket item), so
        // fetch a quick quote per leg — same as the mobile calculator.
        final quote = await api.getScripQuote(item.token, item.exch);
        final qty = item.ordlot * item.lotSize * _lotMultiplier;
        final signedQty = (item.buySell == 'SELL' ? -qty : qty).toString();

        final pos = SpanCalcPositionItem(
          prd: 'M',
          exch: item.exch,
          tsym: item.tsym,
          symname: quote.symname ?? '',
          instname: quote.instname ?? '',
          exd: quote.exd ?? item.expdate,
          netqty: signedQty,
          optt: quote.optt ?? item.optt,
          strprc: quote.strprc ?? item.strprc,
        );
        positions.add(pos);

        // Individual margin for this leg alone = span + expo.
        final indResp = await api.spanCalc(actid: 'DEMOIT', positions: [pos]);
        final indMargin = indResp.spanValue + indResp.expoValue;
        sumIndividual += indMargin;

        final strike =
            double.tryParse(item.strprc)?.toStringAsFixed(0) ?? item.strprc;
        final legName =
            '${(quote.symname ?? '').trim()} $strike ${item.optt}'.trim();
        legs.add(StrategyMarginLeg(legName, indMargin));
      }

      // Combined margin for all legs together = span + expo.
      final combinedResp =
          await api.spanCalc(actid: 'DEMOIT', positions: positions);
      final combined = combinedResp.spanValue + combinedResp.expoValue;
      final benefit = sumIndividual - combined;

      _marginBenefitResult = StrategyMarginBenefit(
        legs: legs,
        sumIndividual: sumIndividual,
        combined: combined,
        benefit: benefit > 0 ? benefit : 0,
      );
    } catch (e) {
      _marginBenefitError = 'Could not calculate margin. Please try again.';
      log('[MarginBenefit] error: $e');
    } finally {
      _isCalcMarginBenefit = false;
      notifyListeners();
    }
  }

  // Custom strategies (API-based leg builder)
  final List<PredefinedStrategy> _customStrategies = [];
  List<PredefinedStrategy> get customStrategies => _customStrategies;
  List<CustomStrategyLegDraft> _draftLegs = [];
  List<CustomStrategyLegDraft> get draftLegs => _draftLegs;

  // Search
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _searchLoading = false;
  bool get searchLoading => _searchLoading;

  bool _searchDropdownVisible = false;
  bool get searchDropdownVisible => _searchDropdownVisible;

  void dismissSearchDropdown() {
    _searchDropdownVisible = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> get searchResults => _searchResults;

  // Flag to trigger auto-showing option chain dialog
  bool _shouldShowOptionChain = false;
  bool get shouldShowOptionChain => _shouldShowOptionChain;

  // Analyze mode (from positions)
  bool _isAnalyzeMode = false;
  bool get isAnalyzeMode => _isAnalyzeMode;

  void clearShouldShowOptionChain() {
    _shouldShowOptionChain = false;
  }

  // WebSocket subscription
  final List<String> _subscribedTokens = [];
  Timer? _refreshTimer;
  Timer? _payoffDebounceTimer;

  // Predefined strategies
  List<PredefinedStrategy> get predefinedStrategies {
    return [
      // Bullish strategies
      PredefinedStrategy(
        title: 'Long Call',
        type: 'Bullish',
        image: 'predefined_strategies/bullish/Buy_Call.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Short Put',
        type: 'Bullish',
        image: 'predefined_strategies/bullish/Sell_Put.svg',
        legs: [
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Bull Call Spread',
        type: 'Bullish',
        image: 'predefined_strategies/bullish/Bull_Call_Spread.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
        ],
      ),
      PredefinedStrategy(
        title: 'Bull Put Spread',
        type: 'Bullish',
        image: 'predefined_strategies/bullish/Bull_Put_Spread.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Long Combo (Risk Reversal)',
        type: 'Bullish',
        image: 'predefined_strategies/bullish/Range_Forward.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
        ],
      ),
      // Bearish strategies
      PredefinedStrategy(
        title: 'Long Put',
        type: 'Bearish',
        image: 'predefined_strategies/bearish/Buy_Put.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Short Call',
        type: 'Bearish',
        image: 'predefined_strategies/bearish/Sell_Call.svg',
        legs: [
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Bear Call Spread',
        type: 'Bearish',
        image: 'predefined_strategies/bearish/Bear_Call_Spread.svg',
        legs: [
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
        ],
      ),
      PredefinedStrategy(
        title: 'Bear Put Spread',
        type: 'Bearish',
        image: 'predefined_strategies/bearish/Bear_Put_Spread.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
        ],
      ),
      // Neutral strategies
      PredefinedStrategy(
        title: 'Short Straddle',
        type: 'Neutral',
        image: 'predefined_strategies/neutral/Short_Straddle.svg',
        legs: [
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Long Straddle',
        type: 'Neutral',
        image: 'predefined_strategies/others/Long_Straddle.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
        ],
      ),
      PredefinedStrategy(
        title: 'Short Strangle',
        type: 'Neutral',
        image: 'predefined_strategies/neutral/Short_Strangle.svg',
        legs: [
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
        ],
      ),
      PredefinedStrategy(
        title: 'Long Strangle',
        type: 'Neutral',
        image: 'predefined_strategies/others/Long_Strangle.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
        ],
      ),
      PredefinedStrategy(
        title: 'Iron Condor',
        type: 'Neutral',
        image: 'predefined_strategies/neutral/Short_Iron_Condor.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'OTM', strikeOffset: -2),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'OTM', strikeOffset: 2),
        ],
      ),
      PredefinedStrategy(
        title: 'Iron Butterfly',
        type: 'Neutral',
        image: 'predefined_strategies/neutral/Iron_Butterfly.svg',
        legs: [
          StrategyLeg(action: 'BUY', optionType: 'PE', strikeType: 'OTM', strikeOffset: -1),
          StrategyLeg(action: 'SELL', optionType: 'PE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'SELL', optionType: 'CE', strikeType: 'ATM', strikeOffset: 0),
          StrategyLeg(action: 'BUY', optionType: 'CE', strikeType: 'OTM', strikeOffset: 1),
        ],
      ),
    ];
  }

  /// Get filtered strategies by tab
  List<PredefinedStrategy> get filteredStrategies {
    if (_strategyTypeTab == 'CustomBuilder') {
      return _customStrategies;
    }
    return predefinedStrategies.where((s) => s.type == _strategyTypeTab).toList();
  }

  /// Initialize the strategy builder
  Future<void> initialize(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    // Load saved custom builder strategies from API
    await loadSavedCustomStrategies(context: context);

    try {
      // Fetch initial quote for NIFTY 50
      final quote = await api.getScripQuote(_selectedToken, _selectedExch);
      if (quote.stat == 'Ok') {
        _spotPrice = double.tryParse(quote.lp ?? '0') ?? 0;
        _targetSpotPrice = _spotPrice;
        final chng = double.tryParse(quote.chng ?? '0') ?? 0;
        final prevClose = _spotPrice - chng;
        _spotPriceChangePercent = prevClose > 0 ? (chng / prevClose) * 100 : 0;
      }

      // Fetch linked scrips for expiry list
      await _loadExpiryDates(context);

      // Subscribe to index updates
      _subscribeToIndex();

      // Start refresh timer
      _startRefreshTimer();
    } catch (e) {
      log('[StrategyBuilder] Initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load expiry dates
  Future<void> _loadExpiryDates(BuildContext context) async {
    try {
      final linkedData = await api.getLinkedScrip(_selectedToken, _selectedExch);
      if (linkedData.stat == "Ok" && linkedData.optExp != null && linkedData.optExp!.isNotEmpty) {
        final sortedExpiries = [...linkedData.optExp!];
        sortedExpiries.sort((a, b) {
          final dateA = _parseExpiryDate(a.exd ?? '');
          final dateB = _parseExpiryDate(b.exd ?? '');
          return dateA.compareTo(dateB);
        });

        _expiryDataRaw = sortedExpiries;
        _expiryDates = sortedExpiries.map((e) => e.exd ?? '').toSet().toList();

        if (_expiryDates.isNotEmpty) {
          if (_selectedExpiry.isEmpty || !_expiryDates.contains(_selectedExpiry)) {
            _selectedExpiry = _expiryDates[0];
          }
          await loadOptionChain(context);
        }
      }
    } catch (e) {
      log('[StrategyBuilder] Load expiry dates error: $e');
    }
  }

  DateTime _parseExpiryDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final monthMap = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
          'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
          'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
        };
        final month = monthMap[parts[1].toUpperCase()] ?? 1;
        int year = int.parse(parts[2]);
        // Handle 2-digit year (e.g., '26' -> 2026)
        if (year < 100) {
          year = 2000 + year;
        }
        log('[StrategyBuilder] _parseExpiryDate: dateStr=$dateStr, parsed day=$day, month=$month, year=$year');
        return DateTime(year, month, day);
      }
    } catch (e) {
      log('[StrategyBuilder] _parseExpiryDate error: $e');
    }
    return DateTime.now();
  }

  /// Recalculate _daysToExpiry from the nearest expiry leg in the basket.
  /// Falls back to _selectedExpiry if basket is empty.
  void _updateDaysToExpiryFromBasket() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final selectedItems = _basket.where((item) => item.checkbox).toList();

    if (selectedItems.isEmpty) {
      // Fallback to selected expiry dropdown
      final expiryDate = _parseExpiryDate(_selectedExpiry);
      _daysToExpiry = expiryDate.difference(today).inDays;
    } else {
      // Use the nearest (minimum) expiry from basket legs
      _daysToExpiry = selectedItems.map((item) {
        return _parseExpiryDate(item.expdate).difference(today).inDays;
      }).reduce((a, b) => a < b ? a : b);
    }

    if (_daysToExpiry < 0) _daysToExpiry = 0;
    // Reset target if it exceeds the new days to expiry
    if (_targetDaysToExpiry > _daysToExpiry) {
      _targetDaysToExpiry = 0;
    }
  }

  // ============ Option Strategy API Conversion Helpers ============

  /// Extract the underlying API symbol from trading symbol or display name
  /// e.g., "NIFTY27FEB25C24000" -> "NIFTY", "BANKNIFTY27FEB25P48000" -> "BANKNIFTY"
  String _extractUnderlyingSymbol() {
    // Try from expiry data tsym
    if (_expiryDataRaw.isNotEmpty) {
      final tsym = _expiryDataRaw.first.tsym ?? '';
      final match = RegExp(r'^([A-Z]+)\d').firstMatch(tsym);
      if (match != null) return match.group(1)!;
    }

    // Try from basket items
    if (_basket.isNotEmpty) {
      final tsym = _basket.first.tsym;
      final match = RegExp(r'^([A-Z]+)\d').firstMatch(tsym);
      if (match != null) return match.group(1)!;
    }

    // Fallback: map known display names
    const displayNameMap = {
      'NIFTY 50': 'NIFTY',
      'NIFTY BANK': 'BANKNIFTY',
      'BANK NIFTY': 'BANKNIFTY',
      'NIFTY FIN SERVICE': 'FINNIFTY',
      'NIFTY MID SELECT': 'MIDCPNIFTY',
      'SENSEX': 'SENSEX',
      'BANKEX': 'BANKEX',
    };
    return displayNameMap[_selectedSymbol] ??
        _selectedSymbol.replaceAll(' ', '');
  }

  /// Determine the options exchange for the underlying
  String _getOptionsExchange() {
    if (_basket.isNotEmpty) return _basket.first.exch;
    switch (_selectedExch) {
      case 'NSE':
        return 'NFO';
      case 'BSE':
        return 'BFO';
      case 'MCX':
        return 'MCX';
      default:
        return 'NFO';
    }
  }

  /// Determine if a given expiry date is weekly (W) or monthly (M)
  /// Monthly = last Thursday of the month (within 1-day tolerance for holiday shifts)
  String _getExpiryType(String expiryDateStr) {
    final expiryDate = _parseExpiryDate(expiryDateStr);

    // Find the last Thursday of the same month
    final lastDayOfMonth =
        DateTime(expiryDate.year, expiryDate.month + 1, 0);
    DateTime lastThursday = lastDayOfMonth;
    while (lastThursday.weekday != DateTime.thursday) {
      lastThursday = lastThursday.subtract(const Duration(days: 1));
    }

    // If within 1 day of last Thursday (handles holiday shifts), it's monthly
    final diff = (expiryDate.difference(lastThursday).inDays).abs();
    return diff <= 1 ? 'M' : 'W';
  }

  /// Check if the current underlying symbol supports weekly expiries.
  /// Only NIFTY (NFO) and SENSEX (BFO) have weekly option expiries.
  bool _hasWeeklyExpiry() {
    final symbol = _extractUnderlyingSymbol();
    return symbol == 'NIFTY' || symbol == 'SENSEX';
  }

  /// Calculate the expiry offset (0=nearest, 1=next, etc.) among same-type expiries
  int _getExpiryOffset(String expiryDateStr) {
    final expiryType = _getExpiryType(expiryDateStr);
    final now = DateTime.now();

    // Filter future expiries of the same type
    final sameTypeExpiries = _expiryDates.where((dateStr) {
      final date = _parseExpiryDate(dateStr);
      return _getExpiryType(dateStr) == expiryType &&
          date.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();

    // Sort chronologically
    sameTypeExpiries.sort(
        (a, b) => _parseExpiryDate(a).compareTo(_parseExpiryDate(b)));

    final index = sameTypeExpiries.indexOf(expiryDateStr);
    return index >= 0 ? index : 0;
  }

  /// Determine strike type (ATM/ITM/OTM) and offset from spot price
  Map<String, dynamic> _getStrikeTypeAndOffset(
      String strikePrice, String optionType) {
    final strike = double.tryParse(strikePrice) ?? 0;
    if (strike <= 0 || _spotPrice <= 0) {
      return {'strikeType': 'ATM', 'strikeOffset': 0};
    }

    // Build sorted unique strikes from option chain
    final strikes = _optionChain
        .where((o) => o.strprc != null)
        .map((o) => double.tryParse(o.strprc!) ?? 0)
        .where((s) => s > 0)
        .toSet()
        .toList()
      ..sort();

    if (strikes.isEmpty) {
      return {'strikeType': 'ATM', 'strikeOffset': 0};
    }

    // Find ATM strike (nearest to spot)
    double atmStrike = strikes.first;
    double minDiff = double.infinity;
    for (final s in strikes) {
      final diff = (s - _spotPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmStrike = s;
      }
    }

    if (strike == atmStrike) {
      return {'strikeType': 'ATM', 'strikeOffset': 0};
    }

    // Count steps from ATM
    final atmIndex = strikes.indexOf(atmStrike);
    final strikeIndex = strikes.indexOf(strike);

    if (atmIndex < 0 || strikeIndex < 0) {
      // Strike not in chain; estimate from step size
      if (strikes.length >= 2) {
        final stepSize = strikes[1] - strikes[0];
        if (stepSize > 0) {
          final stepsFromAtm = ((strike - atmStrike) / stepSize).round();
          return _classifyStrike(stepsFromAtm, optionType);
        }
      }
      return {'strikeType': 'ATM', 'strikeOffset': 0};
    }

    return _classifyStrike(strikeIndex - atmIndex, optionType);
  }

  /// Classify strike as ITM/ATM/OTM based on steps from ATM and option type
  Map<String, dynamic> _classifyStrike(int stepsFromAtm, String optionType) {
    if (stepsFromAtm == 0) {
      return {'strikeType': 'ATM', 'strikeOffset': 0};
    }

    // CE: higher strike (positive steps) = OTM, lower (negative) = ITM
    // PE: lower strike (negative steps) = OTM, higher (positive) = ITM
    if (optionType == 'CE') {
      if (stepsFromAtm > 0) {
        return {'strikeType': 'OTM', 'strikeOffset': stepsFromAtm};
      } else {
        return {'strikeType': 'ITM', 'strikeOffset': stepsFromAtm.abs()};
      }
    } else {
      // PE
      if (stepsFromAtm < 0) {
        return {'strikeType': 'OTM', 'strikeOffset': stepsFromAtm.abs()};
      } else {
        return {'strikeType': 'ITM', 'strikeOffset': stepsFromAtm};
      }
    }
  }

  /// Normalize API expiry format "27-Feb-2025" to provider format "27-FEB-2025"
  String _normalizeExpiryFromApi(String apiExpiry) {
    if (apiExpiry.isEmpty) return '';
    try {
      final parts = apiExpiry.split('-');
      if (parts.length == 3) {
        final day = parts[0];
        final month = parts[1].toUpperCase();
        final year = parts[2];
        return '$day-$month-$year';
      }
    } catch (e) {
      log('[StrategyBuilder] _normalizeExpiryFromApi error: $e');
    }
    return apiExpiry;
  }

  // ============ End Option Strategy API Conversion Helpers ============

  /// Load option chain
  Future<void> loadOptionChain(BuildContext context) async {
    if (_selectedExpiry.isEmpty) return;

    try {
      final selectedExpiryData = _expiryDataRaw.firstWhere(
        (e) => e.exd == _selectedExpiry,
        orElse: () => OptionExp(),
      );

      if (selectedExpiryData.tsym == null) return;

      final chainData = await api.getOptionChain(
        strPrc: _spotPrice.toStringAsFixed(2),
        tradeSym: selectedExpiryData.tsym!,
        exchange: selectedExpiryData.exch ?? 'NFO',
        context: context,
        numofStrike: _selectedStrikeCount.toString(),
      );

      if (chainData != null && chainData.stat == 'Ok' && chainData.optValue != null) {
        _optionChain = chainData.optValue!;

        // Calculate days to expiry (nearest basket leg, or selected expiry if basket empty)
        _updateDaysToExpiryFromBasket();
        log('[StrategyBuilder] daysToExpiry calculated: $_daysToExpiry, selectedExpiry=$_selectedExpiry');

        // Subscribe to option chain updates
        _subscribeToOptions();
      }
    } catch (e) {
      log('[StrategyBuilder] Load option chain error: $e');
    }
    notifyListeners();
  }

  /// Set selected expiry and reload option chain
  Future<void> setSelectedExpiry(String expiry, BuildContext context) async {
    if (expiry == _selectedExpiry) return;
    _selectedExpiry = expiry;
    notifyListeners();
    await loadOptionChain(context);
  }

  /// Search for stocks/indices - uses same API as watchlist search
  /// API: https://be.mynt.in/global/SearchScrip
  Future<void> searchStocks(String query) async {
    _searchQuery = query;
    if (query.length < 2) {
      _searchResults = [];
      _searchDropdownVisible = false;
      notifyListeners();
      return;
    }

    _searchLoading = true;
    _searchDropdownVisible = true;
    notifyListeners();

    try {
      // Use searchScripForStrategyBuilder with fixed exchange filter
      final results = await api.searchScripForStrategyBuilder(
        searchText: query,
        exchanges: ["NSE", "NFO", "BSE","BFO"],
      );

      if (results.stat == 'Ok' && results.values != null && results.values!.isNotEmpty) {
        // Filter for indices/underlyings that have F&O (UNDIND, INDEX, or stocks with F&O)
        _searchResults = results.values!
            .where((r) =>
                r.instname == 'UNDIND' ||
                r.instname == 'INDEX' ||
                r.exch == 'NSE' ||
                r.exch == 'BSE' // Include NSE stocks that may have F&O
            )
            .map((r) => {
                  'displayName': r.dname ?? r.tsym ?? '',
                  'tsym': r.tsym ?? '',
                  'token': r.token ?? '',
                  'exch': r.exch ?? '',
                  'instname': r.instname ?? '',
                })
            .toList();
      } else {
        _searchResults = [];
      }
    } catch (e) {
      log('[StrategyBuilder] Search error: $e');
      _searchResults = [];
    } finally {
      _searchLoading = false;
      _searchDropdownVisible = _searchResults.isNotEmpty;
      notifyListeners();
    }
  }

  /// Select stock from search
  Future<void> selectStock(Map<String, dynamic> stock, BuildContext context) async {
    _selectedSymbol = stock['displayName'] ?? stock['tsym'];
    _selectedToken = stock['token'];
    _selectedExch = stock['exch'];
    _searchResults = [];
    _searchDropdownVisible = false;
    _searchQuery = '';
    _selectedExpiry = '';
    _expiryDates = [];
    _optionChain = [];
    _targetSpotPrice = 0; // Reset target to fallback to spot price
    _lotMultiplier = 1;
    _basket.clear();
    _payoffData = [];
    _targetPayoffData = [];
    _daysToExpiry = 0;

    // Set loading state BEFORE showing dialog so it displays loader immediately
    _isLoading = true;
    // Set flag to show option chain dialog
    _shouldShowOptionChain = true;
    notifyListeners();

    // Load new data (dialog shows loader, will update when data is ready)
    await _loadDataAfterStockSelection(context);
  }

  /// Load data after stock selection (separate from initialize to avoid double-setting isLoading)
  Future<void> _loadDataAfterStockSelection(BuildContext context) async {
    try {
      // Fetch initial quote for selected stock
      final quote = await api.getScripQuote(_selectedToken, _selectedExch);
      if (quote.stat == 'Ok') {
        _spotPrice = double.tryParse(quote.lp ?? '0') ?? 0;
        _targetSpotPrice = _spotPrice;
        final chng = double.tryParse(quote.chng ?? '0') ?? 0;
        final prevClose = _spotPrice - chng;
        _spotPriceChangePercent = prevClose > 0 ? (chng / prevClose) * 100 : 0;
      }

      // Fetch linked scrips for expiry list
      await _loadExpiryDates(context);

      // Subscribe to index updates
      _subscribeToIndex();

      // Start refresh timer
      _startRefreshTimer();
    } catch (e) {
      log('[StrategyBuilder] Load data after stock selection error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set strategy type tab
  void setStrategyTypeTab(String tab) {
    _strategyTypeTab = tab;
    notifyListeners();
  }

  /// Set active predefined strategy
  Future<void> setActivePredefinedStrategy(PredefinedStrategy strategy, BuildContext context) async {
    // Skip if the same strategy is already active
    if (_activePredefinedStrategy == strategy.title && _basket.isNotEmpty) return;

    _activePredefinedStrategy = strategy.title;
    _lotMultiplier = 1;

    // Track editing state for CustomBuilder
    _editingCustomBuilderName = strategy.type == 'CustomBuilder' ? strategy.title : null;

    // If saved strategy has full API legs, use the API to resolve correct contracts
    // This ensures correct expiry, strike etc. even when loaded on a different day
    if (strategy.savedApiLegs != null && strategy.savedApiLegs!.isNotEmpty) {
      log('[StrategyBuilder] Loading saved strategy "${strategy.title}" via API with ${strategy.savedApiLegs!.length} legs');

      // Populate draft legs from savedApiLegs for CustomBuilder editing
      if (strategy.type == 'CustomBuilder') {
        _draftLegs = strategy.savedApiLegs!.map((entry) {
          final legJson = entry['leg'] as Map<String, dynamic>? ?? {};
          return CustomStrategyLegDraft(
            action: entry['action'] as String? ?? 'BUY',
            ordlot: entry['ordlot'] as int? ?? 1,
            optionType: legJson['option_type'] as String? ?? 'CE',
            expiryOffset: legJson['option_expiry_offset'] as int? ?? 0,
            strikeType: legJson['strike_type'] as String? ?? 'ATM',
            strikeOffset: legJson['strike_offset'] as int? ?? 0,
            premiumValue: (legJson['nearest_price'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      }

      await loadStrategyFromApiLegs(strategy.savedApiLegs!, context);
      _activePredefinedStrategy = strategy.title;
      notifyListeners();
      return;
    }

    // Predefined strategies — resolve locally from option chain, add all legs first, then call APIs once
    _basket.clear();

    if (_optionChain.isEmpty) {
      await loadOptionChain(context);
    }

    for (var leg in strategy.legs) {
      final options = _optionChain.where((o) => o.optt == leg.optionType).toList();
      options.sort((a, b) =>
        (double.tryParse(a.strprc ?? '0') ?? 0).compareTo(double.tryParse(b.strprc ?? '0') ?? 0)
      );

      // Find ATM index
      double minDiff = double.infinity;
      int atmIndex = 0;
      for (int i = 0; i < options.length; i++) {
        final strike = double.tryParse(options[i].strprc ?? '0') ?? 0;
        final diff = (strike - _spotPrice).abs();
        if (diff < minDiff) {
          minDiff = diff;
          atmIndex = i;
        }
      }

      int targetIndex = (atmIndex + leg.strikeOffset).clamp(0, options.length - 1);

      if (options.isNotEmpty && targetIndex < options.length) {
        final option = options[targetIndex];
        final cleanLp = (option.lp ?? '0').replaceAll(',', '').replaceAll(' ', '');
        final ltp = double.tryParse(cleanLp) ?? 0.0;
        final cleanLs = (option.ls ?? '1').replaceAll(',', '').replaceAll(' ', '');
        final lotSize = int.tryParse(cleanLs) ?? 1;

        final symbol = _extractUnderlyingSymbol();
        final exchange = _getOptionsExchange();
        final expiryType = _getExpiryType(_selectedExpiry);
        final expiryOffset = _getExpiryOffset(_selectedExpiry);
        final strikeInfo = _getStrikeTypeAndOffset(option.strprc ?? '0', option.optt ?? 'CE');

        _basket.add(StrategyBasketItem(
          tsym: option.tsym ?? '',
          token: option.token ?? '',
          exch: option.exch ?? 'NFO',
          strprc: normalizeStrike(option.strprc ?? '0'),
          optt: option.optt ?? 'CE',
          expdate: _selectedExpiry,
          buySell: leg.action,
          ordlot: 1,
          entryPrice: ltp,
          ltp: ltp,
          lotSize: lotSize,
          checkbox: true,
          apiLeg: SelectSymbolsLegRequest(
            exchange: exchange,
            symbol: symbol,
            underlyingType: 'CASH',
            optionType: option.optt ?? 'CE',
            optionExpiryType: expiryType,
            optionExpiryOffset: expiryOffset,
            strikeType: strikeInfo['strikeType'] as String,
            strikeOffset: strikeInfo['strikeOffset'] as int,
          ),
        ));
      }
    }

    notifyListeners();

    // Call all APIs once for the full basket
    await Future.wait([
      _fetchPayoffFromAPI(),
      _fetchGreeksForAllLegs(),
      _calculateMargin(context),
    ]);

    _activePredefinedStrategy = strategy.title;
    notifyListeners();
  }

  /// Add option to basket
  Future<void> addToBasket(OptionValues option, String buySell, BuildContext context) async {
    // Robust parsing for LTP and Lot Size
    final cleanLp = (option.lp ?? '0').replaceAll(',', '').replaceAll(' ', '');
    final ltp = double.tryParse(cleanLp) ?? 0.0;
    
    final cleanLs = (option.ls ?? '1').replaceAll(',', '').replaceAll(' ', '');
    final lotSize = int.tryParse(cleanLs) ?? 1;

    // Check if the same option (token) already exists in basket
    final existingIndex = _basket.indexWhere(
      (b) => b.token == (option.token ?? ''),
    );

    StrategyBasketItem basketItem;

    if (existingIndex != -1) {
      final existing = _basket[existingIndex];
      if (existing.buySell == buySell) {
        // Same direction clicked again — deselect (remove from basket)
        _basket.removeAt(existingIndex);
        notifyListeners();
        await Future.wait([
          _calculateMargin(context),
          _fetchPayoffFromAPI(),
        ]);
        notifyListeners();
        return;
      } else {
        // Opposite direction — replace buy/sell
        _basket[existingIndex].buySell = buySell;
        basketItem = _basket[existingIndex];
      }
    } else {
      // Build API leg definition for this basket item
      final symbol = _extractUnderlyingSymbol();
      final exchange = _getOptionsExchange();
      final expiryType = _getExpiryType(_selectedExpiry);
      final expiryOffset = _getExpiryOffset(_selectedExpiry);
      final strikeInfo = _getStrikeTypeAndOffset(option.strprc ?? '0', option.optt ?? 'CE');

      final apiLeg = SelectSymbolsLegRequest(
        exchange: exchange,
        symbol: symbol,
        underlyingType: 'CASH',
        optionType: option.optt ?? 'CE',
        optionExpiryType: expiryType,
        optionExpiryOffset: expiryOffset,
        strikeType: strikeInfo['strikeType'] as String,
        strikeOffset: strikeInfo['strikeOffset'] as int,
      );

      basketItem = StrategyBasketItem(
        tsym: option.tsym ?? '',
        token: option.token ?? '',
        exch: option.exch ?? 'NFO',
        strprc: normalizeStrike(option.strprc ?? '0'),
        optt: option.optt ?? 'CE',
        expdate: _selectedExpiry,
        buySell: buySell,
        ordlot: 1,
        entryPrice: ltp,
        ltp: ltp,
        lotSize: lotSize,
        checkbox: true,
        apiLeg: apiLeg,
      );

      // Bake current multiplier into existing items' ordlot before resetting
      if (_lotMultiplier > 1) {
        for (var item in _basket) {
          item.ordlot = item.ordlot * _lotMultiplier;
        }
        _lotMultiplier = 1;
      }
      _basket.add(basketItem);
    }

    notifyListeners();

    // Call APIs for payoff, Greeks (all legs), and margin
    await Future.wait([
      _fetchPayoffFromAPI(),
      _fetchGreeksForAllLegs(),
      _calculateMargin(context),
    ]);

    notifyListeners();
  }

  /// Remove from basket
  Future<void> removeFromBasket(int index, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      _basket.removeAt(index);
      notifyListeners();

      // Recalculate margin and fetch payoff
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
      ]);
      notifyListeners();
    }
  }

  /// Toggle buy/sell
  Future<void> toggleBuySell(int index, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      _basket[index].buySell = _basket[index].buySell == 'BUY' ? 'SELL' : 'BUY';
      notifyListeners();

      // Recalculate margin, fetch payoff, and update Greeks
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
        _fetchGreeksForAllLegs(),
      ]);
      notifyListeners();
    }
  }

  /// Toggle CE/PE — updates apiLeg option_type and resolves via API
  Future<void> toggleCePe(int index, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      final item = _basket[index];
      final newOptt = item.optt == 'CE' ? 'PE' : 'CE';

      // Update the apiLeg with new option type
      if (item.apiLeg != null) {
        _basket[index] = item.copyWith(
          optt: newOptt,
          apiLeg: SelectSymbolsLegRequest(
            exchange: item.apiLeg!.exchange,
            symbol: item.apiLeg!.symbol,
            underlyingType: item.apiLeg!.underlyingType,
            optionType: newOptt,
            optionExpiryType: item.apiLeg!.optionExpiryType,
            optionExpiryOffset: item.apiLeg!.optionExpiryOffset,
            strikeType: item.apiLeg!.strikeType,
            strikeOffset: item.apiLeg!.strikeOffset,
            underlyingExpiryType: item.apiLeg!.underlyingExpiryType,
            underlyingExpiryOffset: item.apiLeg!.underlyingExpiryOffset,
          ),
        );
      } else {
        // Fallback: find from option chain if no apiLeg
        final option = _optionChain.firstWhere(
          (o) => normalizeStrike(o.strprc ?? '') == item.strprc && o.optt == newOptt,
          orElse: () => OptionValues(),
        );
        if (option.token != null) {
          _basket[index] = item.copyWith(
            optt: newOptt,
            tsym: option.tsym,
            token: option.token,
            ltp: double.tryParse(option.lp ?? '0') ?? 0,
            entryPrice: double.tryParse(option.lp ?? '0') ?? 0,
          );
        }
      }

      notifyListeners();

      // Recalculate margin, fetch payoff, and update Greeks
      await Future.wait([
        _calculateMargin(context),
        _fetchGreeksForAllLegs(),
      ]);
      await _fetchPayoffFromAPI();
      notifyListeners();
    }
  }

  /// Update lots
  Future<void> updateLots(int index, int lots, BuildContext context) async {
    if (index >= 0 && index < _basket.length && lots > 0) {
      _basket[index].ordlot = lots;
      notifyListeners();

      // Recalculate margin, fetch payoff, and update Greeks from API
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
        _fetchGreeksForAllLegs(),
      ]);
      notifyListeners();
    }
  }

  /// Update entry price
  Future<void> updateEntryPrice(int index, double price, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      _basket[index].entryPrice = price;
      notifyListeners();

      // Recalculate margin and fetch payoff from API
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
      ]);
      notifyListeners();
    }
  }

  /// Refresh all entry prices to current LTP
  Future<void> refreshEntryPrices(BuildContext context) async {
    for (int i = 0; i < _basket.length; i++) {
      _basket[i].entryPrice = _basket[i].ltp;
    }
    notifyListeners();

    await Future.wait([
      _calculateMargin(context),
      _fetchPayoffFromAPI(),
    ]);
    notifyListeners();
  }

  /// Update expiry for basket item — calls selectSymbols API to resolve the new contract
  Future<void> updateExpiry(int index, String expiry, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      final item = _basket[index];

      // Update expiry locally first for immediate UI feedback
      _basket[index] = item.copyWith(expdate: expiry);
      notifyListeners();

      // Call selectSymbols API to resolve the correct contract for new expiry
      try {
        final request = SelectSymbolsDirectRequest(
          exchange: item.exch.isNotEmpty ? item.exch : _getOptionsExchange(),
          symbol: _extractUnderlyingSymbol(),
          optionType: item.optt,
          expiry: expiry,
          strikeprice: item.strprc,
        );

        final response = await api.selectSymbolsDirect(request);

        if (!response.hasError && response.token != null) {
          final normalizedExpiry = _normalizeExpiryFromApi(response.expiry ?? expiry);

          // Update apiLeg offsets for consistency
          final newExpiryType = _getExpiryType(expiry);
          final newExpiryOffset = _getExpiryOffset(expiry);

          _basket[index] = _basket[index].copyWith(
            token: response.token,
            tsym: response.selectedSymbol ?? _basket[index].tsym,
            expdate: normalizedExpiry,
            strprc: normalizeStrike(response.strike ?? item.strprc),
            ltp: response.optionPrice ?? 0.0,
            entryPrice: response.optionPrice ?? 0.0,
            lotSize: int.tryParse(response.lotSize ?? '') ?? _basket[index].lotSize,
            apiLeg: item.apiLeg != null
                ? SelectSymbolsLegRequest(
                    exchange: item.apiLeg!.exchange,
                    symbol: item.apiLeg!.symbol,
                    underlyingType: item.apiLeg!.underlyingType,
                    optionType: item.apiLeg!.optionType,
                    optionExpiryType: newExpiryType,
                    optionExpiryOffset: newExpiryOffset,
                    strikeType: item.apiLeg!.strikeType,
                    strikeOffset: item.apiLeg!.strikeOffset,
                    underlyingExpiryType: item.apiLeg!.underlyingExpiryType,
                    underlyingExpiryOffset: item.apiLeg!.underlyingExpiryOffset,
                  )
                : null,
          );
          notifyListeners();
        } else {
          // Strike not available in new expiry — reset LTP and entry price to 0
          _basket[index] = _basket[index].copyWith(
            ltp: 0.0,
            entryPrice: 0.0,
            token: '',
          );
          notifyListeners();
        }
      } catch (e) {
        log('[StrategyBuilder] updateExpiry selectSymbolsDirect error: $e');
        // On error, reset LTP and entry price to 0
        _basket[index] = _basket[index].copyWith(
          ltp: 0.0,
          entryPrice: 0.0,
        );
        notifyListeners();
      }

      // Recalculate margin and fetch payoff
      await Future.wait([
        _calculateMargin(context),
      ]);
      await _fetchPayoffFromAPI();
      notifyListeners();
    }
  }

  /// Update strike for basket item — calls selectSymbols API to resolve the new contract
  Future<void> updateStrike(int index, String strike, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      final item = _basket[index];

      // Update strike locally first for immediate UI feedback
      _basket[index] = item.copyWith(strprc: normalizeStrike(strike));
      notifyListeners();

      // Call selectSymbols API to resolve the correct contract for new strike
      try {
        final request = SelectSymbolsDirectRequest(
          exchange: item.exch.isNotEmpty ? item.exch : _getOptionsExchange(),
          symbol: _extractUnderlyingSymbol(),
          optionType: item.optt,
          expiry: item.expdate,
          strikeprice: normalizeStrike(strike),
        );

        final response = await api.selectSymbolsDirect(request);

        if (!response.hasError && response.token != null) {
          // Compute new strike type and offset for apiLeg consistency
          final strikeInfo = _getStrikeTypeAndOffset(strike, item.optt);
          final newStrikeType = strikeInfo['strikeType'] as String;
          final newStrikeOffset = strikeInfo['strikeOffset'] as int;

          _basket[index] = _basket[index].copyWith(
            token: response.token,
            tsym: response.selectedSymbol ?? _basket[index].tsym,
            strprc: normalizeStrike(response.strike ?? strike),
            ltp: response.optionPrice ?? 0.0,
            entryPrice: response.optionPrice ?? 0.0,
            lotSize: int.tryParse(response.lotSize ?? '') ?? _basket[index].lotSize,
            apiLeg: item.apiLeg != null
                ? SelectSymbolsLegRequest(
                    exchange: item.apiLeg!.exchange,
                    symbol: item.apiLeg!.symbol,
                    underlyingType: item.apiLeg!.underlyingType,
                    optionType: item.apiLeg!.optionType,
                    optionExpiryType: item.apiLeg!.optionExpiryType,
                    optionExpiryOffset: item.apiLeg!.optionExpiryOffset,
                    strikeType: newStrikeType,
                    strikeOffset: newStrikeOffset,
                    underlyingExpiryType: item.apiLeg!.underlyingExpiryType,
                    underlyingExpiryOffset: item.apiLeg!.underlyingExpiryOffset,
                  )
                : null,
          );
          notifyListeners();
        } else {
          // Strike not available — reset LTP and entry price to 0
          _basket[index] = _basket[index].copyWith(
            ltp: 0.0,
            entryPrice: 0.0,
            token: '',
          );
          notifyListeners();
        }
      } catch (e) {
        log('[StrategyBuilder] updateStrike selectSymbolsDirect error: $e');
        // On error, reset LTP and entry price to 0
        _basket[index] = _basket[index].copyWith(
          ltp: 0.0,
          entryPrice: 0.0,
        );
        notifyListeners();
      }

      // Recalculate margin, fetch payoff, and update Greeks
      await Future.wait([
        _calculateMargin(context),
        _fetchGreeksForAllLegs(),
      ]);
      await _fetchPayoffFromAPI();
      notifyListeners();
    }
  }

  /// Toggle checkbox
  Future<void> toggleCheckbox(int index, BuildContext context) async {
    if (index >= 0 && index < _basket.length) {
      _basket[index].checkbox = !_basket[index].checkbox;
      notifyListeners();

      // Recalculate margin and fetch payoff from API
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
      ]);
      notifyListeners();
    }
  }

  /// Toggle all checkboxes
  Future<void> toggleAllCheckboxes(bool value, BuildContext context) async {
    for (var item in _basket) {
      item.checkbox = value;
    }
    notifyListeners();

    // Recalculate margin and fetch payoff from API
    await Future.wait([
      _calculateMargin(context),
      _fetchPayoffFromAPI(),
    ]);
    notifyListeners();
  }

  /// Check if all selected
  bool get isAllSelected => _basket.isNotEmpty && _basket.every((item) => item.checkbox);

  /// Clear basket
  void clearBasket() {
    _basket.clear();
    _draftLegs.clear();
    _lotMultiplier = 1;
    _activePredefinedStrategy = null;
    _editingCustomBuilderName = null;
    _payoffDebounceTimer?.cancel();
    _payoffData = [];
    _targetPayoffData = [];
    _metrics = PayoffMetrics();
    _basketMarginModel = null; // Reset margin
    notifyListeners();
  }

  // ============ End Local Storage ============

  // ============ Option Strategy API Save/Load Methods ============

  /// Build a saveable strategy with API-format legs + action/lot metadata
  List<Map<String, dynamic>> buildSaveableStrategy() {
    return _basket
        .where((item) => item.checkbox && item.apiLeg != null)
        .map((item) => {
          'leg': item.apiLeg!.toJson(),
          'action': item.buySell,
          'ordlot': item.ordlot,
        })
        .toList();
  }

  /// Load a strategy from stored API-format legs.
  /// Calls /select-symbols to resolve legs to actual contracts, then populates basket.
  Future<void> loadStrategyFromApiLegs(
    List<Map<String, dynamic>> savedLegs,
    BuildContext context,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final apiLegs = savedLegs.map((entry) {
        return SelectSymbolsLegRequest.fromJson(
          entry['leg'] as Map<String, dynamic>,
        );
      }).toList();

      // Call the Option Strategy API
      final responses = await api.selectSymbols(apiLegs);

      _basket.clear();
      _lotMultiplier = 1;

      // Update underlying info from first successful response
      final firstValid = responses.firstWhere(
        (r) => !r.hasError,
        orElse: () => responses.first,
      );

      if (firstValid.undSym != null) {
        _selectedSymbol = firstValid.undSym!;
        _selectedToken = firstValid.undTok ?? _selectedToken;
        _selectedExch = firstValid.undExch ?? _selectedExch;
      }

      if (firstValid.underlyingPrice != null &&
          firstValid.underlyingPrice! > 0) {
        _spotPrice = firstValid.underlyingPrice!;
        _targetSpotPrice = _spotPrice;
      }

      // Convert each response to a StrategyBasketItem
      for (int i = 0; i < responses.length && i < savedLegs.length; i++) {
        final resp = responses[i];
        final savedMeta = savedLegs[i];

        if (resp.hasError) {
          log('[StrategyBuilder] selectSymbols leg $i error: ${resp.error}');
          continue;
        }

        final normalizedExpiry = _normalizeExpiryFromApi(resp.expiry ?? '');

        // Restore the API leg definition so future modifications preserve it
        final apiLeg = SelectSymbolsLegRequest.fromJson(
          savedMeta['leg'] as Map<String, dynamic>,
        );

        final item = StrategyBasketItem(
          tsym: resp.selectedSymbol ?? '',
          token: resp.token ?? '',
          exch: resp.exch ?? 'NFO',
          strprc: normalizeStrike(resp.strike ?? '0'),
          optt: resp.optionType ?? 'CE',
          expdate: normalizedExpiry,
          buySell: savedMeta['action'] as String? ?? 'BUY',
          ordlot: savedMeta['ordlot'] as int? ?? 1,
          entryPrice: resp.optionPrice ?? 0.0,
          ltp: resp.optionPrice ?? 0.0,
          lotSize: int.tryParse(resp.lotSize ?? '1') ?? 1,
          checkbox: true,
          apiLeg: apiLeg,
        );

        _basket.add(item);
      }

      // Load expiry dates and option chain
      await _loadExpiryDates(context);

      if (_basket.isNotEmpty) {
        _selectedExpiry = _basket.first.expdate;
        _updateDaysToExpiryFromBasket();
      }

      await loadOptionChain(context);

      _subscribeToIndex();
      _startRefreshTimer();

      // Fetch API payoff, greeks, and margin
      await Future.wait([
        _fetchPayoffFromAPI(),
        _calculateMargin(context),
        _fetchGreeksForAllLegs(),
      ]);
    } catch (e) {
      log('[StrategyBuilder] loadStrategyFromApiLegs error: $e');
      ResponsiveSnackBar.showError(context, 'Failed to load strategy');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ End Option Strategy API Save/Load Methods ============

  // ============ Custom Builder (API Leg Builder) Methods ============

  /// Add a new draft leg with defaults
  void addDraftLeg() {
    _draftLegs.add(CustomStrategyLegDraft());
    notifyListeners();
  }

  /// Remove a draft leg
  void removeDraftLeg(int index) {
    if (index >= 0 && index < _draftLegs.length) {
      _draftLegs.removeAt(index);
      notifyListeners();
    }
  }

  /// Update a draft leg (called by UI on each field change)
  void updateDraftLeg(int index, CustomStrategyLegDraft leg) {
    if (index >= 0 && index < _draftLegs.length) {
      _draftLegs[index] = leg;
      notifyListeners();
    }
  }

  /// Whether all draft legs are selected
  bool get isAllDraftLegsSelected =>
      _draftLegs.isNotEmpty && _draftLegs.every((leg) => leg.checkbox);

  /// Toggle all draft leg checkboxes
  void toggleAllDraftLegCheckboxes(bool value) {
    for (var leg in _draftLegs) {
      leg.checkbox = value;
    }
    notifyListeners();
  }

  /// Clear checked draft legs (or all if none checked)
  void clearDraftLegs() {
    final hasChecked = _draftLegs.any((leg) => leg.checkbox);
    if (hasChecked) {
      _draftLegs.removeWhere((leg) => leg.checkbox);
    } else {
      _draftLegs.clear();
    }
    notifyListeners();
  }

  /// Apply custom strategy — resolve draft legs via /select-symbols API
  Future<void> applyCustomStrategy(BuildContext context) async {
    if (_draftLegs.isEmpty) {
      ResponsiveSnackBar.showError(context, 'Add at least one leg.');
      return;
    }

    final symbol = _extractUnderlyingSymbol();
    final exchange = _getOptionsExchange();
    final expiryType = _hasWeeklyExpiry() ? 'W' : 'M';

    final savedLegs = _draftLegs.map((draft) {
      final apiLeg = SelectSymbolsLegRequest(
        exchange: exchange,
        symbol: symbol,
        underlyingType: 'CASH',
        optionType: draft.optionType,
        optionExpiryType: expiryType,
        optionExpiryOffset: draft.expiryOffset,
        strikeType: draft.strikeType,
        strikeOffset: draft.strikeOffset,
        nearestPrice: draft.strikeType == 'PREMIUM' ? draft.premiumValue : null,
      );

      return <String, dynamic>{
        'leg': apiLeg.toJson(),
        'action': draft.action,
        'ordlot': draft.ordlot,
      };
    }).toList();

    await loadStrategyFromApiLegs(savedLegs, context);
    notifyListeners();
  }

  /// Convert savedApiLegs to the flat leg format for the strategy CRUD API
  List<Map<String, dynamic>> _buildCrudApiLegs(
      List<Map<String, dynamic>> savedApiLegs) {
    return savedApiLegs.map((entry) {
      final legJson =
          Map<String, dynamic>.from(entry['leg'] as Map<String, dynamic>? ?? {});
      return <String, dynamic>{
        ...legJson,
        'action': entry['action'],
        'quantity': entry['ordlot'] ?? 1,
      };
    }).toList();
  }

  /// Save custom strategy from draft legs
  Future<void> saveCustomStrategy(String name, BuildContext context) async {
    if (_draftLegs.isEmpty) {
      ResponsiveSnackBar.showError(context, 'Add at least one leg before saving.');
      return;
    }

    if (name.trim().isEmpty) {
      ResponsiveSnackBar.showError(context, 'Please enter a strategy name.');
      return;
    }

    final symbol = _extractUnderlyingSymbol();
    final exchange = _getOptionsExchange();
    final expiryType = _hasWeeklyExpiry() ? 'W' : 'M';
    final clientId = pref.clientId ?? '';

    final apiLegs = <Map<String, dynamic>>[];
    final legs = <StrategyLeg>[];

    for (final draft in _draftLegs) {
      final apiLeg = SelectSymbolsLegRequest(
        exchange: exchange,
        symbol: symbol,
        underlyingType: 'CASH',
        optionType: draft.optionType,
        optionExpiryType: expiryType,
        optionExpiryOffset: draft.expiryOffset,
        strikeType: draft.strikeType,
        strikeOffset: draft.strikeOffset,
        nearestPrice: draft.strikeType == 'PREMIUM' ? draft.premiumValue : null,
      );

      apiLegs.add({
        'leg': apiLeg.toJson(),
        'action': draft.action,
        'ordlot': draft.ordlot,
      });

      legs.add(StrategyLeg(
        action: draft.action,
        optionType: draft.optionType,
        strikeType: draft.strikeType,
        strikeOffset: draft.strikeOffset,
      ));
    }

    final existingIndex = _customStrategies.indexWhere(
      (s) => s.title.toLowerCase() == name.trim().toLowerCase(),
    );

    try {
      String? strategyId;
      final crudLegs = _buildCrudApiLegs(apiLegs);

      if (existingIndex >= 0 &&
          _customStrategies[existingIndex].strategyId != null) {
        // UPDATE existing strategy
        final response = await api.updateStrategy(
          strategyId: _customStrategies[existingIndex].strategyId!,
          clientId: clientId,
          name: name.trim(),
          legs: crudLegs,
        );
        strategyId = response['strategy_id'] as String?;
      } else {
        // CREATE new strategy
        final response = await api.createOptionStrategy(
          clientId: clientId,
          name: name.trim(),
          description: '',
          tags: ['custom_builder'],
          legs: crudLegs,
        );
        strategyId = response['strategy_id'] as String?;
      }

       final strategy = PredefinedStrategy(
      title: name.trim(),
      type: 'CustomBuilder',
        image: '',
        legs: legs,
      savedApiLegs: apiLegs,
        strategyId: strategyId,
      );

    if (existingIndex >= 0) {
      _customStrategies[existingIndex] = strategy;
      ResponsiveSnackBar.showSuccess(context, 'Custom builder "$name" updated');
    } else {
      _customStrategies.add(strategy);
      ResponsiveSnackBar.showSuccess(context, 'Custom builder "$name" saved');
    }

      _editingCustomBuilderName = name.trim();
    _activePredefinedStrategy = name.trim();
      notifyListeners();
    } catch (e) {
      log('[StrategyBuilder] saveCustomStrategy API error: $e');
      ResponsiveSnackBar.showError(
          context, 'Failed to save strategy. Please try again.');
    }
  }

  /// Delete a custom strategy
  Future<void> deleteCustomStrategy(String name, BuildContext context) async {
    final index = _customStrategies.indexWhere((s) => s.title == name);
    if (index < 0) return;

    final strategy = _customStrategies[index];
    final clientId = pref.clientId ?? '';

    try {
      if (strategy.strategyId != null) {
        await api.deleteStrategy(
          strategyId: strategy.strategyId!,
          clientId: clientId,
        );
      }

      _customStrategies.removeAt(index);
      if (_editingCustomBuilderName == name) {
      _editingCustomBuilderName = null;
    }
    if (_activePredefinedStrategy == name) {
      _activePredefinedStrategy = null;
    }
      notifyListeners();
      ResponsiveSnackBar.showSuccess(context, 'Strategy "$name" deleted');
    } catch (e) {
      log('[StrategyBuilder] deleteCustomStrategy API error: $e');
      ResponsiveSnackBar.showError(
          context, 'Failed to delete strategy. Please try again.');
    }
  }

  /// Load saved custom strategies from API
  Future<void> loadSavedCustomStrategies({BuildContext? context}) async {
    try {
      final clientId = pref.clientId ?? '';
      if (clientId.isEmpty) return;

      final response = await api.listStrategies(clientId: clientId);
      final strategiesList =
          response['strategies'] as List<dynamic>? ?? [];

      _customStrategies.clear();

      for (final entry in strategiesList) {
        final apiLegsRaw = entry['legs'] as List<dynamic>? ?? [];
        final legs = <StrategyLeg>[];
        final savedApiLegs = <Map<String, dynamic>>[];

        for (final rawLeg in apiLegsRaw) {
          final legMap = Map<String, dynamic>.from(rawLeg as Map);

          // Reconstruct the internal wrapped format:
          // { 'leg': { SelectSymbolsLegRequest fields }, 'action': ..., 'ordlot': ... }
          final selectSymbolsFields = Map<String, dynamic>.from(legMap);
          selectSymbolsFields.remove('action');
          selectSymbolsFields.remove('quantity');

          savedApiLegs.add({
            'leg': selectSymbolsFields,
            'action': legMap['action'] ?? 'BUY',
            'ordlot': legMap['quantity'] ?? 1,
          });

          legs.add(StrategyLeg(
            action: legMap['action'] ?? 'BUY',
            optionType: legMap['optionType'] ?? 'CE',
            strikeType: legMap['strikeType'] ?? 'ATM',
            strikeOffset: legMap['strikeOffset'] ?? 0,
          ));
        }

        _customStrategies.add(PredefinedStrategy(
          title: entry['name'] ?? '',
          type: 'CustomBuilder',
          image: '',
          legs: legs,
          savedApiLegs: savedApiLegs,
          strategyId: entry['strategy_id'],
        ));
      }

      log('[StrategyBuilder] Loaded ${_customStrategies.length} custom strategies from API');
      notifyListeners();
    } catch (e) {
      log('[StrategyBuilder] loadSavedCustomStrategies error: $e');
      if (context != null && context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to load saved strategies.');
      }
    }
  }

  // ============ End Custom Builder Methods ============

  /// Set lot multiplier
  Future<void> setLotMultiplier(int multiplier, BuildContext context) async {
    if (multiplier > 0) {
      _lotMultiplier = multiplier;
      notifyListeners();

      // Recalculate margin and payoff from API
      await Future.wait([
        _calculateMargin(context),
        _fetchPayoffFromAPI(),
      ]);
      notifyListeners();
    }
  }

  /// Set payoff tab
  void setPayoffTab(int tab) {
    _payoffTab = tab;
    notifyListeners();
  }

  /// Set target spot price
  void setTargetSpotPrice(double price) {
    _targetSpotPrice = price;
    _isTargetSpotActive = true;
    notifyListeners();
  }

  void resetTargetSpotPrice() {
    _targetSpotPrice = _spotPrice;
    _isTargetSpotActive = false;
    notifyListeners();
  }

  /// Set target days to expiry
  void setTargetDaysToExpiry(int days) {
    _targetDaysToExpiry = days;
    notifyListeners();
    _debouncedPayoffApiCall();
  }

  /// Debounced payoff API call — waits 500ms after last slider change
  void _debouncedPayoffApiCall() {
    _payoffDebounceTimer?.cancel();
    //  _payoffDebounceTimer = Timer(const Duration(seconds: 1), () async {
    _payoffDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _fetchPayoffFromAPI();
      notifyListeners();
    });
  }

  /// Toggle SD lines
  void toggleSDLines() {
    _showSDLines = !_showSDLines;
    notifyListeners();
  }

  /// Reset all basket items' Greeks to zero (used when API fails)
  void _resetGreeksToZero() {
    for (var item in _basket) {
      item.iv = 0;
      item.delta = 0;
      item.gamma = 0;
      item.theta = 0;
      item.vega = 0;
    }
  }

  /// Calculate net premium (per contract, not total cost)
  /// For display purposes: shows premium paid/received per contract
  double get netPremium {
    double total = 0;
    for (var item in _basket) {
      if (!item.checkbox) continue;
      final sign = item.buySell == 'SELL' ? 1 : -1;
      // Don't multiply by lotSize - show per-contract premium
      total += item.entryPrice * item.ordlot * _lotMultiplier * sign;
    }
    return total;
  }

  /// Calculate total premium cost (includes lotSize for actual P&L calculations)
  double get totalPremiumCost {
    double total = 0;
    for (var item in _basket) {
      if (!item.checkbox) continue;
      final sign = item.buySell == 'SELL' ? 1 : -1;
      total += item.entryPrice * item.ordlot * item.lotSize * _lotMultiplier * sign;
    }
    return total;
  }

  // ============ API-based Payoff and Greeks Calculation ============

  /// Fetch payoff data from API
  Future<void> _fetchPayoffFromAPI() async {
    if (_basket.isEmpty || _spotPrice == 0) {
      _payoffData = [];
      _targetPayoffData = [];
      _metrics = PayoffMetrics();
      _isPayoffLoading = false;
      return;
    }

    final selectedItems = _basket.where((item) => item.checkbox).toList();
    if (selectedItems.isEmpty) {
      _payoffData = [];
      _targetPayoffData = [];
      _metrics = PayoffMetrics();
      _isPayoffLoading = false;
      return;
    }

    // Track this request; discard response if a newer request was fired
    final requestId = ++_payoffRequestId;
    _isPayoffLoading = true;
    notifyListeners();

    try {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      // Build legs array for API — each leg gets its own daysToExpiry
      final legs = selectedItems.map((item) {
        final legExpiryDate = _parseExpiryDate(item.expdate);
        final legDaysToExpiry = legExpiryDate.difference(today).inDays.clamp(0, 9999);

        return {
          "exch": item.exch,
          "token": item.token,
          "tsym": item.tsym,
          "optt": item.optt,
          "pp": "2",
          "ls": item.lotSize.toString(),
          "ti": "0.05",
          "strprc": item.strprc,
          "instname": "OPTIDX",
          "cname": "${_selectedSymbol} ${item.expdate} ${item.strprc} ${item.optt} ",
          "dname": "${_selectedSymbol} ${item.expdate} ${item.strprc} ${item.optt} ",
          "bar": item.optt == 'CE' ? "#FF1717" : "#17FF17",
          "p": "",
          "ltp": item.ltp,
          "ask": item.ltp,
          "bid": item.ltp.toString(),
          "ch": "0",
          "chp": "0",
          "coi": 0,
          "oi": "0",
          "oich": "0",
          "vol": "0",
          "buySell": item.buySell,
          "expdate": _expiryDates,
          "ordvai": "MKT",
          "ordlot": (item.ordlot * _lotMultiplier).toString(),
          "ordprc": item.entryPrice.toString(),
          "checkbox": item.checkbox,
          "ser": item.expdate,
          "daysToExpiry": legDaysToExpiry,
          "tsyms": _selectedSymbol,
          "inx": DateTime.now().millisecondsSinceEpoch.toDouble(),
          "exp": "${item.strprc} ${item.optt}",
        };
      }).toList();

      // Use the nearest expiry (minimum daysToExpiry) from selected basket legs
      final minDaysToExpiry = selectedItems.map((item) {
        final legExpiry = _parseExpiryDate(item.expdate);
        return legExpiry.difference(today).inDays.clamp(0, 9999);
      }).reduce((a, b) => a < b ? a : b);

      final response = await api.getPayoffCalculation(
        strategy: "custom",
        isPosition: _isAnalyzeMode,
        spotPrice: _spotPrice.toStringAsFixed(2),
        daysToExpiry: _targetDaysToExpiry > 0 ? (minDaysToExpiry - _targetDaysToExpiry).clamp(0, 9999) : minDaysToExpiry,
        legs: legs,
      );

      // Discard if a newer request has been fired while this one was in flight
      if (requestId != _payoffRequestId) return;

      log('[StrategyBuilder] Payoff API Response: $response');

      // Parse response and update payoff data
      // Backend response structure:
      // { "success": true, "metrics": { ... }, "payoffData": { stockPrices, payoffs_expiry, payoffs_target, breakevens } }
      if (response['success'] == true || response['payoffData'] != null) {
        final payoffData = response['payoffData'] ?? response;
        final metricsData = response['metrics'] as Map<String, dynamic>?;

        // Extract stock prices and payoffs from API response
        // Backend uses mixed keys: stockPrices (camelCase), payoffs_expiry/payoffs_target (snake_case)
        final stockPrices = (payoffData['stockPrices'] as List?)?.cast<num>() ?? [];
        final payoffsExpiry = (payoffData['payoffs_expiry'] as List?)?.cast<num>() ?? [];
        final payoffsTarget = (payoffData['payoffs_target'] as List?)?.cast<num>() ?? [];
        final breakevens = (payoffData['breakevens'] as List?)?.cast<num>() ?? [];

        // Convert to PayoffDataPoint list
        _payoffData = [];
        _targetPayoffData = [];

        for (int i = 0; i < stockPrices.length && i < payoffsExpiry.length; i++) {
          _payoffData.add(PayoffDataPoint(
            stockPrices[i].toDouble(),
            payoffsExpiry[i].toDouble(),
          ));
        }

        for (int i = 0; i < stockPrices.length && i < payoffsTarget.length; i++) {
          _targetPayoffData.add(PayoffDataPoint(
            stockPrices[i].toDouble(),
            payoffsTarget[i].toDouble(),
          ));
        }

        if (_payoffData.isEmpty) {
          log('[StrategyBuilder] API returned empty payoff data');
          return;
        }

        // Extract metrics from the separate 'metrics' key in response
        final maxProfit = metricsData?['maxProfit'];
        final maxLoss = metricsData?['maxLoss'];
        final pop = metricsData?['popPercent'] ?? 0;
        final riskReward = metricsData?['riskRewardRatio'];

        // Format numeric values with Indian format, keep strings like "Unlimited" as-is
        String formatMetricValue(dynamic value) {
          if (value == null) return '--';
          if (value is num) return RupeeFormat.format(value);
          final parsed = double.tryParse(value.toString());
          if (parsed != null) return RupeeFormat.format(parsed);
          return value.toString();
        }

        _metrics = PayoffMetrics(
          maxProfit: formatMetricValue(maxProfit),
          maxLoss: formatMetricValue(maxLoss),
          popPercent: (pop is num) ? pop.toDouble() : 0,
          riskRewardRatio: riskReward?.toString() ?? '--',
          breakevens: breakevens.map((e) => e.toDouble()).toList(),
        );

        log('[StrategyBuilder] Parsed ${_payoffData.length} payoff points, metrics: maxProfit=$maxProfit, maxLoss=$maxLoss, pop=$pop');
      } else {
        log('[StrategyBuilder] API response invalid');
      }
    } catch (e) {
      log('[StrategyBuilder] Payoff API Error: $e');
    } finally {
      _isPayoffLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Greeks from API for a basket item
  Future<void> _fetchGreeksForAllLegs() async {
    if (_spotPrice <= 0 || _daysToExpiry < 0 || _basket.isEmpty) return;

    try {
      final optionsList = _basket.map((item) => <String, dynamic>{
        "exch": item.exch,
        "token": item.token,
        "tsym": item.tsym,
        "optt": item.optt,
        "pp": "2",
        "ls": item.lotSize.toString(),
        "ti": "0.05",
        "strprc": item.strprc,
        "instname": "OPTIDX",
        "cname": "${_selectedSymbol} ${item.expdate} ${item.strprc} ${item.optt} ",
        "dname": "${_selectedSymbol} ${item.expdate} ${item.strprc} ${item.optt} ",
        "bar": item.optt == 'CE' ? "#FF1717" : "#17FF17",
        "p": "",
        "ltp": item.ltp,
        "ask": item.ltp,
        "bid": item.ltp.toString(),
        "ch": "0",
        "chp": "0",
        "coi": 0,
        "oi": "0",
        "oich": "0",
        "vol": "0",
        "buySell": item.buySell,
        "expdate": _expiryDates,
        "ordvai": "MKT",
        "ordlot": (item.ordlot * _lotMultiplier).toString(),
        "ordprc": item.entryPrice.toString(),
        "checkbox": item.checkbox,
        "ser": item.expdate,
        "tsyms": _selectedSymbol,
        "inx": DateTime.now().millisecondsSinceEpoch.toDouble(),
        "exp": "${item.strprc} ${item.optt}",
      }).toList();

      final response = await api.getOptionGreeks(
        spotPrice: _spotPrice.toStringAsFixed(2),
        expiryDay: _daysToExpiry,
        options: optionsList,
      );

      log('[StrategyBuilder] Greeks API Response: $response');

      // Parse response — API returns "GreekValues" list matching basket order
      final greeksList = response['GreekValues'];
      if (greeksList is List && greeksList.length == _basket.length) {
        for (int i = 0; i < _basket.length; i++) {
          final item = _basket[i];
          final greeks = greeksList[i] as Map<String, dynamic>? ?? {};
          final multiplier = item.buySell == 'SELL' ? -1.0 : 1.0;

          item.iv = (greeks['IV'] as num?)?.toDouble() ?? 0;
          item.delta = ((greeks['delta'] as num?)?.toDouble() ?? 0) * multiplier;
          item.gamma = (greeks['gamma'] as num?)?.toDouble() ?? 0;
          item.theta = ((greeks['theta'] as num?)?.toDouble() ?? 0) * multiplier;
          item.vega = ((greeks['vega'] as num?)?.toDouble() ?? 0) * multiplier;

          log('[StrategyBuilder] Updated Greeks for ${item.tsym}');
        }
      } else {
        log('[StrategyBuilder] Greeks API response format mismatch, resetting Greeks');
        _resetGreeksToZero();
      }
    } catch (e) {
      log('[StrategyBuilder] Greeks API Error: $e');
      _resetGreeksToZero();
    }
  }

  // ============ End API-based Calculation ============

  /// Calculate margin using GetBasketMargin API
  Future<void> _calculateMargin(BuildContext context) async {
    if (_basket.isEmpty) {
      _basketMarginModel = null;
      return;
    }

    final selectedItems = _basket.where((item) => item.checkbox).toList();
    if (selectedItems.isEmpty) {
      _basketMarginModel = null;
      return;
    }

    try {
      // Build basket list for API
      final basketList = <Map<String, dynamic>>[];

      for (int i = 1; i < selectedItems.length; i++) {
        final item = selectedItems[i];
        final qty = item.ordlot * item.lotSize * _lotMultiplier;
        basketList.add({
          "exch": item.exch,
          "tsym": item.tsym,
          "qty": qty.toString(),
          "prc": item.entryPrice.toString(),
          "prd": "M", // NRML - matches order placement
          "trantype": item.buySell == 'BUY' ? 'B' : 'S',
          "prctyp": "MKT",
          "trgprc": "0",
        });
      }

      // First item is the main order
      final firstItem = selectedItems.first;
      final firstQty = firstItem.ordlot * firstItem.lotSize * _lotMultiplier;

      final input = OrderMarginInput(
        exch: firstItem.exch,
        tsym: firstItem.tsym,
        qty: firstQty.toString(),
        prc: firstItem.entryPrice.toString(),
        prd: 'M', // NRML - matches order placement
        trantype: firstItem.buySell == 'BUY' ? 'B' : 'S',
        prctyp: 'MKT',
        blprc: '',
        bpprc: '',
        trgprc: '0',
        rorgqty: '',
        rorgprc: '',
      );

      final response = await api.getBasketMargin(input, basketList);

      log('[StrategyBuilder] Margin API Response: ${response.stat}');

      if (response.stat == 'Ok') {
        _basketMarginModel = response;
      } else {
        _basketMarginModel = null;
        log('[StrategyBuilder] Margin API Error: ${response.emsg}');
        if (response.emsg == "Session Expired :  Invalid Session Key" &&
            response.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
      }
    } catch (e) {
      log('[StrategyBuilder] Margin API Error: $e');
      _basketMarginModel = null;
    }
  }

  /// Place order
  Future<void> placeOrder(BuildContext context) async {
    if (_basket.isEmpty) {
      ResponsiveSnackBar.showError(context, 'Basket is empty');
      return;
    }

    final selectedItems = _basket.where((item) => item.checkbox).toList();
    if (selectedItems.isEmpty) {
      ResponsiveSnackBar.showError(context, 'No items selected');
      return;
    }

    _isOrderLoading = true;
    notifyListeners();

    try {
      int successCount = 0;
      int failCount = 0;

      for (var item in selectedItems) {
        final qty = item.ordlot * item.lotSize * _lotMultiplier;

        final orderPayload = PlaceOrderInput(
          exch: item.exch,
          tsym: item.tsym,
          qty: qty.toString(),
          prc: item.entryPrice.toString(),
          prd: 'M', // NRML
          trantype: item.buySell == 'BUY' ? 'B' : 'S',
          prctype: 'LMT',
          ret: 'DAY',
          amo: '',
          trgprc: '',
          trailprc: '',
          blprc: '',
          bpprc: '',
          dscqty: '',
          mktProt: '',
          channel: 'WEB',
        );

        final result = await api.getPlaceOrder(orderPayload, '');
        if (result.stat == 'Ok') {
          successCount++;
        } else {
          failCount++;
          log('[StrategyBuilder] Order failed: ${item.tsym} - ${result.emsg}');
        }
      }

      if (successCount > 0) {
        ResponsiveSnackBar.showSuccess(context, '$successCount order(s) triggered successfully');
      }
      if (failCount > 0) {
        ResponsiveSnackBar.showError(context, '$failCount order(s) failed');
      }
    } catch (e) {
      ResponsiveSnackBar.showError(context, 'Failed to place orders');
      log('[StrategyBuilder] Place order error: $e');
    } finally {
      _isOrderLoading = false;
      notifyListeners();
    }
  }

  /// Get available strikes for expiry
  /// Normalize strike string to a canonical format to avoid mismatches
  /// between different API responses (e.g., "24000" vs "24000.00" vs "24000.0")
  static String normalizeStrike(String strike) {
    final num = double.tryParse(strike);
    if (num == null) return strike;
    return num == num.truncateToDouble()
        ? num.toInt().toString()
        : num.toString();
  }

  List<String> getStrikesForExpiry(String expiry, {String? currentStrike}) {
    final strikes = <String>{};

    for (var option in _optionChain) {
      if (option.strprc != null) {
        strikes.add(normalizeStrike(option.strprc!));
      }
    }
    // Also include strikes from basket items that may be outside the loaded range
    for (var item in _basket) {
      if (item.strprc.isNotEmpty) {
        strikes.add(normalizeStrike(item.strprc));
      }
    }
    // Ensure the current strike is always in the list
    if (currentStrike != null && currentStrike.isNotEmpty) {
      strikes.add(normalizeStrike(currentStrike));
    }

    final sortedStrikes = strikes.toList()
      ..sort((a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));
    return sortedStrikes;
  }

  /// Calculate Greeks total for the entire position
  /// Returns sum of per-option Greeks for all selected items
  double greeksTotal(String column) {
    double total = 0;
    for (var item in _basket) {
      if (!item.checkbox) continue;
      double? value;
      // For single lot positions, Total = Individual values
      // All Greeks are stored as per-option values
      final positionMultiplier = item.ordlot * _lotMultiplier;

      switch (column) {
        case 'delta':
          // Per-option delta summed across lots
          value = (item.delta ?? 0) * positionMultiplier;
          break;
        case 'gamma':
          // Per-option gamma summed across lots
          value = (item.gamma ?? 0) * positionMultiplier;
          break;
        case 'theta':
          // Per-option theta summed across lots
          value = (item.theta ?? 0) * positionMultiplier;
          break;
        case 'vega':
          // Per-option vega summed across lots
          value = (item.vega ?? 0) * positionMultiplier;
          break;
      }
      total += value ?? 0;
    }
    return total;
  }

  /// WebSocket subscriptions
  void _subscribeToIndex() {
    final websocketProv = ref.read(websocketProvider);
    final subscriptionKey = '$_selectedExch|$_selectedToken';

    websocketProv.connectTouchLine(
      input: subscriptionKey,
      task: 't',
      context: WidgetsBinding.instance.rootElement!,
    );
  }

  void _subscribeToOptions() {
    final websocketProv = ref.read(websocketProvider);

    // Unsubscribe from previous
    if (_subscribedTokens.isNotEmpty) {
      websocketProv.connectTouchLine(
        input: _subscribedTokens.join('#'),
        task: 'u',
        context: WidgetsBinding.instance.rootElement!,
      );
      _subscribedTokens.clear();
    }

    // Subscribe to new
    final keys = <String>[];
    for (var option in _optionChain) {
      if (option.exch != null && option.token != null) {
        keys.add('${option.exch}|${option.token}');
        _subscribedTokens.add('${option.exch}|${option.token}');
      }
    }

    if (keys.isNotEmpty) {
      websocketProv.connectTouchLine(
        input: keys.join('#'),
        task: 't',
        context: WidgetsBinding.instance.rootElement!,
      );
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshFromWebSocket();
    });
  }

  void _refreshFromWebSocket() {
    final websocketProv = ref.read(websocketProvider);
    final socketData = websocketProv.socketDatas;

    bool hasUpdates = false;

    // Update spot price - try both key formats
    final spotTokenKey = _selectedToken;
    final spotExchTokenKey = '$_selectedExch|$_selectedToken';
    final indexData = socketData[spotTokenKey] ?? socketData[spotExchTokenKey];
    if (indexData != null && indexData['lp'] != null) {
      final newPrice = double.tryParse(indexData['lp'].toString()) ?? 0;
      if (newPrice > 0 && newPrice != _spotPrice) {
        _spotPrice = newPrice;
        // Update percent change from websocket data
        final pc = double.tryParse(indexData['pc']?.toString() ?? '');
        if (pc != null) {
          _spotPriceChangePercent = pc;
        } else {
          // Fallback: calculate from change value
          final chng = double.tryParse(indexData['c']?.toString() ?? indexData['chng']?.toString() ?? '0') ?? 0;
          final prevClose = newPrice - chng;
          if (prevClose > 0) {
            _spotPriceChangePercent = (chng / prevClose) * 100;
          }
        }
        // Keep target slider in sync with live spot when not actively set by user
        if (!_isTargetSpotActive) {
          _targetSpotPrice = newPrice;
        }
        hasUpdates = true;
      }
    }

    // Update basket items LTP
    for (int i = 0; i < _basket.length; i++) {
      final item = _basket[i];
      // Try both formats: just token and exch|token
      final tokenKey = item.token;
      final exchTokenKey = '${item.exch}|${item.token}';
      final data = socketData[tokenKey] ?? socketData[exchTokenKey];
      if (data != null && data['lp'] != null) {
        final newLtp = double.tryParse(data['lp'].toString()) ?? 0;
        if (newLtp != item.ltp) {
          _basket[i] = item.copyWith(ltp: newLtp);
          hasUpdates = true;
        }
      }
    }

    // Update option chain
    for (int i = 0; i < _optionChain.length; i++) {
      final option = _optionChain[i];
      if (option.token == null) continue;

      // Try both formats: just token and exch|token
      final tokenKey = option.token!;
      final exchTokenKey = '${option.exch}|${option.token}';
      final data = socketData[tokenKey] ?? socketData[exchTokenKey];

      if (data != null && data['lp'] != null) {
        _optionChain[i] = OptionValues(
          exch: option.exch,
          token: option.token,
          tsym: option.tsym,
          optt: option.optt,
          pp: option.pp,
          ls: option.ls,
          ti: option.ti,
          lp: data['lp'].toString(),
          perChange: data['pc']?.toString() ?? option.perChange,
          close: option.close,
          oi: data['oi']?.toString() ?? option.oi,
          poi: option.poi,
          strprc: option.strprc,
        );
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      // Note: Greeks are NOT updated live - they are calculated once when option is added
      // Only LTP and option chain prices are updated via WebSocket
      notifyListeners();
    }
  }

  /// Load positions into the strategy builder for analysis
  Future<void> loadFromPositions(List<PositionBookModel> positions, BuildContext context) async {
    _isAnalyzeMode = true;
    _lotMultiplier = 1;
    _basket.clear();
    _payoffData = [];
    _targetPayoffData = [];
    _metrics = PayoffMetrics();
    _activePredefinedStrategy = null;
    _isLoading = true;
    notifyListeners();

    try {
      if (positions.isEmpty) return;

      // Resolve underlying symbol from first position's tsym
      final firstPos = positions.first;
      // Extract underlying symbol (e.g., "NIFTY" from "NIFTY28FEB25C24500")
      final tsym = firstPos.tsym ?? '';
      final symbol = firstPos.symbol ?? firstPos.dname ?? tsym;
      _selectedSymbol = symbol;
      _selectedExch = firstPos.exch ?? 'NFO';

      // Fetch spot price for the underlying
      // Try to find underlying token - use the symbol to search
      try {
        final results = await api.searchScripForStrategyBuilder(
          searchText: symbol,
          exchanges: ["NSE", "NFO", "BSE"],
        );
        if (results.stat == 'Ok' && results.values != null) {
          final underlying = results.values!.firstWhere(
            (r) => r.instname == 'UNDIND' || r.instname == 'INDEX',
            orElse: () => results.values!.first,
          );
          _selectedToken = underlying.token ?? '';
          _selectedExch = underlying.exch ?? 'NSE';

          final quote = await api.getScripQuote(_selectedToken, _selectedExch);
          if (quote.stat == 'Ok') {
            _spotPrice = double.tryParse(quote.lp ?? '0') ?? 0;
            _targetSpotPrice = _spotPrice;
          }
        }
      } catch (e) {
        log('[StrategyBuilder] Error fetching underlying for analyze: $e');
      }

      // Load expiry dates
      await _loadExpiryDates(context);

      // Map each position to a basket item
      for (var pos in positions) {
        final netqty = int.tryParse(pos.netqty ?? '0') ?? 0;
        if (netqty == 0) continue;

        final buySell = netqty > 0 ? 'BUY' : 'SELL';
        final lotSize = int.tryParse(pos.ls ?? '1') ?? 1;
        final ordlot = lotSize > 0 ? (netqty.abs() / lotSize).round() : 1;
        final avgPrc = double.tryParse(pos.avgPrc ?? '0') ?? 0;
        final ltp = double.tryParse(pos.lp ?? '0') ?? 0;

        // Parse option type and strike from option field (format: "CE 24500" or "PE 25000")
        String optt = 'CE';
        String strprc = '0';
        final optionField = pos.option ?? '';
        if (optionField.contains('CE')) {
          optt = 'CE';
          strprc = optionField.replaceAll('CE', '').trim();
        } else if (optionField.contains('PE')) {
          optt = 'PE';
          strprc = optionField.replaceAll('PE', '').trim();
        }

        // Convert position expDate (space-separated "24 FEB 26") to
        // API format (dash-separated "24-FEB-26") for matching
        final posExpDate = pos.expDate ?? '';
        final apiExpDate = posExpDate.replaceAll(' ', '-');

        // Find matching expiry from loaded expiry dates, fallback to converted format
        String matchedExpiry = _selectedExpiry;
        if (_expiryDates.contains(apiExpDate)) {
          matchedExpiry = apiExpDate;
        } else {
          // Try to find a match by comparing parsed dates
          for (final exp in _expiryDates) {
            if (exp.replaceAll('-', ' ') == posExpDate || exp == apiExpDate) {
              matchedExpiry = exp;
              break;
            }
          }
          // If still no match, use converted format
          if (matchedExpiry == _selectedExpiry && apiExpDate.isNotEmpty) {
            matchedExpiry = apiExpDate;
          }
        }

        final item = StrategyBasketItem(
          tsym: pos.tsym ?? '',
          token: pos.token ?? '',
          exch: pos.exch ?? 'NFO',
          strprc: normalizeStrike(strprc),
          optt: optt,
          expdate: matchedExpiry,
          buySell: buySell,
          ordlot: ordlot,
          entryPrice: avgPrc,
          ltp: ltp,
          lotSize: lotSize,
          checkbox: true,
        );

        _basket.add(item);
      }

      // Calculate days to expiry from nearest basket leg's expiry
      if (_basket.isNotEmpty) {
        _selectedExpiry = _basket.first.expdate;
        _updateDaysToExpiryFromBasket();
      }

      // Subscribe to updates
      _subscribeToIndex();
      _startRefreshTimer();

      // Try to fetch API payoff, greeks, and margin
      await Future.wait([
        _fetchPayoffFromAPI(),
        _calculateMargin(context),
        _fetchGreeksForAllLegs(),
      ]);
    } catch (e) {
      log('[StrategyBuilder] loadFromPositions error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Exit analyze mode and reset state
  void exitAnalyzeMode() {
    _isAnalyzeMode = false;
    _lotMultiplier = 1;
    _basket.clear();
    _payoffData = [];
    _targetPayoffData = [];
    _metrics = PayoffMetrics();
    _activePredefinedStrategy = null;
    _basketMarginModel = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _payoffDebounceTimer?.cancel();

    // Unsubscribe
    if (_subscribedTokens.isNotEmpty) {
      try {
        final websocketProv = ref.read(websocketProvider);
        websocketProv.connectTouchLine(
          input: _subscribedTokens.join('#'),
          task: 'u',
          context: WidgetsBinding.instance.rootElement!,
        );
      } catch (e) {
        // Ignore if already disposed
      }
    }

    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/core/api_export.dart';
import '../../../locator/constant.dart';
import '../../../locator/locator.dart';
import '../../../locator/preference.dart';
import '../../../models/marketwatch_model/linked_scrips.dart';
import '../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../models/marketwatch_model/search_scrip_model.dart';
import '../../../models/order_book_model/gtt_order_book.dart';
import '../../../models/order_book_model/place_gtt_order.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/websocket_provider.dart';

final scalperProvider = ChangeNotifierProvider<ScalperProvider>((ref) {
  return ScalperProvider(ref);
});

/// Maps an underlying's exchange to the exchange its option chain lives on.
/// NSE equities/indices -> NFO, BSE -> BFO, MCX commodities -> MCX (commodity
/// options trade on MCX itself, not on a separate F&O segment), CDS -> CDS.
/// Used as a fallback only — when the linked-scrip response carries an explicit
/// `OptionExp.exch`, that value wins (see `optionExchangeForExpiry`).
String optionExchangeForUnderlying(String? underlyingExch) {
  switch ((underlyingExch ?? '').toUpperCase()) {
    case 'BSE':
    case 'BFO':
      return 'BFO';
    case 'MCX':
      return 'MCX';
    case 'NCO':
    case 'NCOM':
      return 'NCO';
    case 'BCO':
    case 'BCOM':
      return 'BCO';
    case 'CDS':
      return 'CDS';
    case 'BCD':
      return 'BCD';
    default:
      return 'NFO';
  }
}

/// The exchange to send to `GetOptionChain` for [expiry].
/// The linked-scrip response tags every expiry with its own exchange, which is
/// authoritative (this is what the main option-chain screen uses). Falls back to
/// [fallbackExch] when the field is missing.
String optionExchangeForExpiry(OptionExp? expiry, String fallbackExch) {
  final exch = expiry?.exch;
  if (exch != null && exch.trim().isNotEmpty) return exch.trim();
  return fallbackExch;
}

/// Index configuration for scalper screen
class ScalperIndex {
  final String name;
  final String token;
  final String exch;
  final String tsym;
  final String optExch; // Exchange for options (NFO for NSE, BFO for BSE, MCX for commodities)

  const ScalperIndex({
    required this.name,
    required this.token,
    required this.exch,
    required this.tsym,
    required this.optExch,
  });
}

/// State management for the Scalper Screen
class ScalperProvider extends ChangeNotifier {
  final Ref ref;
  final ApiExporter _api = locator<ApiExporter>();
  final Preferences _pref = locator<Preferences>();

  ScalperProvider(this.ref) {
    _loadSavedSettings();
  }

  String get _userId => _pref.clientId ?? '';

  /// Load saved scalper settings from SharedPreferences on startup.
  void _loadSavedSettings() {
    final uid = _userId;
    _strikeSelectionMode = _pref.getScalperStrikeMode(uid);
    _defaultCallOffset = _pref.getScalperCallOffset(uid);
    _defaultPutOffset = _pref.getScalperPutOffset(uid);
    _callPremiumTarget = _pref.getScalperCallPremium(uid);
    _putPremiumTarget = _pref.getScalperPutPremium(uid);
    _defaultSymbolIndex = _pref.getScalperDefaultSymbol(uid);
    _selectedIndexType = _defaultSymbolIndex; // Start on the saved default symbol
    _isMktProtectionEnabled = _pref.getScalperMktProtEnabled(uid);
    _mktProtectionPoints = _pref.getScalperMktProtPoints(uid);
    _positionFilter = _pref.getScalperPosFilter(uid);
  }

  /// Reload settings for the current user (call after login to pick up the new user's prefs).
  /// Also clears all runtime state from the previous session so stale data is never shown.
  void reloadUserSettings() {
    _loadSavedSettings();
    _isShortcutsEnabled = true;

    // Clear runtime state from previous user's session
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _selectedStrike = '';
    _callStrike = '';
    _putStrike = '';
    _selectedCall = null;
    _selectedPut = null;
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    _customIndex = null;
    _lotSize = '1';
    _lotQuantity = 1;
    _limitPrices.clear();
    _loadGeneration++;

    notifyListeners();
  }

  // Index configurations (stable tokens)
  static const List<ScalperIndex> indices = [
    ScalperIndex(
      name: 'NIFTY',
      token: '26000',
      exch: 'NSE',
      tsym: 'Nifty 50',
      optExch: 'NFO',
    ),
    ScalperIndex(
      name: 'BANKNIFTY',
      token: '26009',
      exch: 'NSE',
      tsym: 'Nifty Bank',
      optExch: 'NFO',
    ),
    ScalperIndex(
      name: 'SENSEX',
      token: '1',
      exch: 'BSE',
      tsym: 'SENSEX',
      optExch: 'BFO',
    ),
  ];

  // Selected index (0: Nifty 50, 1: Nifty Bank, 2: Sensex, or custom)
  int _selectedIndexType = 0;
  int get selectedIndexType => _selectedIndexType;
  ScalperIndex? _customIndex; // Non-null when a custom symbol was selected (4th tab)
  ScalperIndex? get customIndex => _customIndex;
  ScalperIndex get selectedIndex {
    if (_selectedIndexType == 3 && _customIndex != null) {
      return _customIndex!;
    }
    return indices[_selectedIndexType.clamp(0, 2)];
  }

  // Current index LTP (for ATM calculation)
  double _currentIndexLTP = 0.0;
  double get currentIndexLTP => _currentIndexLTP;

  // LTPs for all indices (for display in tabs)
  final Map<String, Map<String, String>> _indicesData = {};
  Map<String, Map<String, String>> get indicesData => _indicesData;

  // ATM strike price
  String _atmStrike = '';
  String get atmStrike => _atmStrike;

  // Selected strike for call/put charts
  String _selectedStrike = '';
  String get selectedStrike => _selectedStrike;

  // Independent strike selection for call and put charts
  String _callStrike = '';
  String get callStrike => _callStrike;

  String _putStrike = '';
  String get putStrike => _putStrike;

  // Selected call option (for left chart)
  OptionValues? _selectedCall;
  OptionValues? get selectedCall => _selectedCall;

  // Selected put option (for right chart)
  OptionValues? _selectedPut;
  OptionValues? get selectedPut => _selectedPut;

  // Available expiry dates
  List<OptionExp> _expiryDates = [];
  List<OptionExp> get expiryDates => _expiryDates;

  // Selected expiry
  OptionExp? _selectedExpiry;
  OptionExp? get selectedExpiry => _selectedExpiry;

  // Option chain data
  List<OptionValues> _callOptions = [];
  List<OptionValues> get callOptions => _callOptions;

  List<OptionValues> _putOptions = [];
  List<OptionValues> get putOptions => _putOptions;

  // All unique strike prices sorted
  List<String> _sortedStrikes = [];
  List<String> get sortedStrikes => _sortedStrikes;

  // Loading states
  bool _isLoadingExpiries = false;
  bool get isLoadingExpiries => _isLoadingExpiries;

  bool _isLoadingOptionChain = false;
  bool get isLoadingOptionChain => _isLoadingOptionChain;

  // Last option-chain failure message (null when the last load succeeded).
  // The screen reads this once after a failed load so it can tell the user why
  // the chain is empty instead of silently re-requesting.
  String? _optionChainError;
  String? get optionChainError => _optionChainError;

  // Lot size for the current index
  String _lotSize = '1';
  String get lotSize => _lotSize;

  // Order settings
  int _lotQuantity = 1;
  int get lotQuantity => _lotQuantity;

  bool _isIntraday = true;
  bool get isIntraday => _isIntraday;

  bool _isMarketOrder = true;
  bool get isMarketOrder => _isMarketOrder;

  // Option chain overlay visibility
  bool _showOptionChainOverlay = false;
  bool get showOptionChainOverlay => _showOptionChainOverlay;

  // Expanded chart state (null = none, 'call' = call chart, 'index' = index chart, 'put' = put chart)
  String? _expandedChart;
  String? get expandedChart => _expandedChart;

  // Positions panel state
  bool _isPositionsPanelCollapsed = false;
  bool get isPositionsPanelCollapsed => _isPositionsPanelCollapsed;

  double _positionsPanelHeight = 250.0; // Default height in pixels
  double get positionsPanelHeight => _positionsPanelHeight;

  static const double minPanelHeight = 80.0;
  static const double maxPanelHeight = 500.0;

  // Generation counter for async cancellation (race condition prevention)
  int _loadGeneration = 0;
  int get loadGeneration => _loadGeneration;

  // Keyboard shortcuts
  bool _isShortcutsEnabled = false;
  bool get isShortcutsEnabled => _isShortcutsEnabled;

  void setShortcutsEnabled(bool enabled) {
    _isShortcutsEnabled = enabled;
    notifyListeners();
  }

  // ─── Settings ──────────────────────────────────────────────────

  // Default symbol index (0=NIFTY, 1=BANKNIFTY, 2=SENSEX)
  int _defaultSymbolIndex = 0;
  int get defaultSymbolIndex => _defaultSymbolIndex;
  void setDefaultSymbolIndex(int index) {
    _defaultSymbolIndex = index.clamp(0, indices.length - 1);
    notifyListeners();
  }

  // Strike selection mode: 'offset' (ATM Offset) or 'premium'
  String _strikeSelectionMode = 'offset';
  String get strikeSelectionMode => _strikeSelectionMode;
  void setStrikeSelectionMode(String mode) {
    _strikeSelectionMode = mode;
    if (_atmStrike.isNotEmpty) {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  // Default strike offset from ATM (0=ATM, -1..-5 = ITM 1..5, 1..5 = OTM 1..5)
  // Separate offsets for CE and PE
  int _defaultCallOffset = 0;
  int get defaultCallOffset => _defaultCallOffset;
  void setDefaultCallOffset(int offset) {
    _defaultCallOffset = offset.clamp(-5, 5);
    if (_atmStrike.isNotEmpty && _strikeSelectionMode == 'offset') {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  int _defaultPutOffset = 0;
  int get defaultPutOffset => _defaultPutOffset;
  void setDefaultPutOffset(int offset) {
    _defaultPutOffset = offset.clamp(-5, 5);
    if (_atmStrike.isNotEmpty && _strikeSelectionMode == 'offset') {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  // Legacy getter for backward compat
  int get defaultStrikeOffset => _defaultCallOffset;
  String get defaultStrikeLabel {
    if (_defaultCallOffset == 0) return 'ATM';
    if (_defaultCallOffset < 0) return 'ITM ${-_defaultCallOffset}';
    return 'OTM $_defaultCallOffset';
  }
  void setDefaultStrikeOffset(int offset) {
    _defaultCallOffset = offset.clamp(-5, 5);
    _defaultPutOffset = offset.clamp(-5, 5);
    if (_atmStrike.isNotEmpty) {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  // Premium-based strike selection (target LTP for CE and PE)
  double _callPremiumTarget = 100.0;
  double get callPremiumTarget => _callPremiumTarget;
  void setCallPremiumTarget(double target) {
    _callPremiumTarget = target.clamp(1, 99999);
    if (_strikeSelectionMode == 'premium' && _callOptions.isNotEmpty) {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  double _putPremiumTarget = 100.0;
  double get putPremiumTarget => _putPremiumTarget;
  void setPutPremiumTarget(double target) {
    _putPremiumTarget = target.clamp(1, 99999);
    if (_strikeSelectionMode == 'premium' && _putOptions.isNotEmpty) {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  // Market protection (for MKT orders — number of points added as price buffer)
  bool _isMktProtectionEnabled = false;
  bool get isMktProtectionEnabled => _isMktProtectionEnabled;
  int _mktProtectionPoints = 5;
  int get mktProtectionPoints => _mktProtectionPoints;

  void setMktProtection(bool enabled) {
    _isMktProtectionEnabled = enabled;
    notifyListeners();
  }
  void setMktProtectionPoints(int points) {
    _mktProtectionPoints = points.clamp(1, 20);
    notifyListeners();
  }

  // Position filter: 'all' or 'fno'
  String _positionFilter = 'all';
  String get positionFilter => _positionFilter;
  void setPositionFilter(String filter) {
    _positionFilter = filter;
    notifyListeners();
  }

  /// Apply all settings at once (called from the Apply button in the settings dialog).
  /// This batches all changes into a single notifyListeners + one strike re-selection.
  void applyAllSettings({
    required String strikeSelectionMode,
    required int defaultCallOffset,
    required int defaultPutOffset,
    required double callPremiumTarget,
    required double putPremiumTarget,
    required int defaultSymbolIndex,
    required bool isMktProtectionEnabled,
    required int mktProtectionPoints,
    required String positionFilter,
    required bool isShortcutsEnabled,
  }) {
    _strikeSelectionMode = strikeSelectionMode;
    _defaultCallOffset = defaultCallOffset.clamp(-5, 5);
    _defaultPutOffset = defaultPutOffset.clamp(-5, 5);
    _callPremiumTarget = callPremiumTarget.clamp(1, 99999);
    _putPremiumTarget = putPremiumTarget.clamp(1, 99999);
    _defaultSymbolIndex = defaultSymbolIndex.clamp(0, indices.length - 1);
    _isMktProtectionEnabled = isMktProtectionEnabled;
    _mktProtectionPoints = mktProtectionPoints.clamp(1, 20);
    _positionFilter = positionFilter;
    _isShortcutsEnabled = isShortcutsEnabled;

    // Persist all settings to SharedPreferences (per-user)
    final uid = _userId;
    _pref.setScalperStrikeMode(uid, _strikeSelectionMode);
    _pref.setScalperCallOffset(uid, _defaultCallOffset);
    _pref.setScalperPutOffset(uid, _defaultPutOffset);
    _pref.setScalperCallPremium(uid, _callPremiumTarget);
    _pref.setScalperPutPremium(uid, _putPremiumTarget);
    _pref.setScalperDefaultSymbol(uid, _defaultSymbolIndex);
    _pref.setScalperMktProtEnabled(uid, _isMktProtectionEnabled);
    _pref.setScalperMktProtPoints(uid, _mktProtectionPoints);
    _pref.setScalperPosFilter(uid, _positionFilter);

    if (_atmStrike.isNotEmpty) {
      _applyStrikeSelection();
    }
    notifyListeners();
  }

  // Limit prices (set by order bar, read by keyboard shortcuts — no notifyListeners)
  final Map<String, String> _limitPrices = {};

  void setLimitPrice(String key, String price) {
    _limitPrices[key] = price;
  }

  String getLimitPrice(String key) => _limitPrices[key] ?? '';

  // Available option symbols (fetched once, cached)
  List<ScripValue> _availableSymbols = [];
  List<ScripValue> get availableSymbols => _availableSymbols;
  bool _isLoadingSymbols = false;
  bool get isLoadingSymbols => _isLoadingSymbols;

  /// Fetch all available option symbols (called once, cached)
  Future<void> fetchAvailableSymbols() async {
    if (_availableSymbols.isNotEmpty || _isLoadingSymbols) return;

    _isLoadingSymbols = true;
    notifyListeners();

    try {
      final result = await _api.fetchAllOptScripts();
      if (result.stat == 'Ok' && result.values != null) {
        _availableSymbols = result.values!;
      }
    } catch (e) {
    } finally {
      _isLoadingSymbols = false;
      notifyListeners();
    }
  }

  // Subscribed option tokens (for cleanup)
  Set<String> _subscribedOptionTokens = {};

  /// Change selected index (0-2 for defaults, keeps 4th tab intact)
  Future<void> setSelectedIndex(int index, BuildContext context) async {
    if (_selectedIndexType == index) return;

    // Unsubscribe old option tokens before switching
    unsubscribeFromWebSocket(context);

    _loadGeneration++; // Cancel any in-flight async work

    // Don't clear _customIndex — keep the 4th tab visible
    _selectedIndexType = index;
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _selectedStrike = '';
    _callStrike = '';
    _putStrike = '';
    _selectedCall = null;
    _selectedPut = null;
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    notifyListeners();

    await loadIndexData(context);
  }

  /// Select a symbol from the search results
  Future<void> setSelectedSymbol(ScripValue symbol, BuildContext context) async {
    // Check if it matches a predefined index — select that tab, keep 4th tab intact
    for (int i = 0; i < indices.length; i++) {
      if (indices[i].token == symbol.token) {
        await setSelectedIndex(i, context);
        return;
      }
    }

    // Custom symbol — becomes/replaces the 4th tab.
    // MCX commodities keep MCX as their option exchange; sending NFO makes
    // GetOptionChain reject the request with a 400.
    final optExch = optionExchangeForUnderlying(symbol.exch);

    // Unsubscribe old option tokens before switching
    unsubscribeFromWebSocket(context);

    _loadGeneration++; // Cancel any in-flight async work

    _customIndex = ScalperIndex(
      name: symbol.tsym ?? symbol.cname ?? '',
      token: symbol.token ?? '',
      exch: symbol.exch ?? 'NSE',
      tsym: symbol.tsym ?? '',
      optExch: optExch,
    );
    _selectedIndexType = 3; // 4th tab (custom symbol)
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _selectedStrike = '';
    _callStrike = '';
    _putStrike = '';
    _selectedCall = null;
    _selectedPut = null;
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    notifyListeners();

    await loadIndexData(context);
  }

  /// Select the custom (4th) tab — used when tapping on it
  Future<void> selectCustomIndex(BuildContext context) async {
    if (_customIndex == null || _selectedIndexType == 3) return;

    unsubscribeFromWebSocket(context);

    _loadGeneration++; // Cancel any in-flight async work

    _selectedIndexType = 3;
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _selectedStrike = '';
    _callStrike = '';
    _putStrike = '';
    _selectedCall = null;
    _selectedPut = null;
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    notifyListeners();

    await loadIndexData(context);
  }

  /// Fetch initial quotes for all indices
  Future<void> fetchAllIndicesQuotes(BuildContext context) async {
    for (final index in indices) {
      try {
        final quote = await _api.getScripQuote(index.token, index.exch);
        if (quote.stat == 'Ok' && quote.lp != null) {
          final ltp = double.tryParse(quote.lp!) ?? 0.0;

          // Store data for all indices
          _indicesData[index.token] = {
            'lp': quote.lp ?? '0.00',
            'chng': quote.chng ?? '0.00',
            'pc': quote.pc ?? '0.00',
          };

          if (index.token == selectedIndex.token) {
            _currentIndexLTP = ltp;
          }
        }
      } catch (e) {
      }
    }
    notifyListeners();
  }

  /// Load index data - fetch linked scripts for expiry dates using direct API calls
  Future<void> loadIndexData(BuildContext context) async {
    final gen = _loadGeneration;

    _isLoadingExpiries = true;
    notifyListeners();

    try {
      final index = selectedIndex;


      // First, fetch the initial quote for the selected index
      try {
        final quote = await _api.getScripQuote(index.token, index.exch);
        if (_loadGeneration != gen) return; // Stale — a newer switch happened

        if (quote.stat == 'Ok' && quote.lp != null) {
          _currentIndexLTP = double.tryParse(quote.lp!) ?? 0.0;
          // Store in indicesData so tab can display LTP even when not selected
          _indicesData[index.token] = {
            'lp': quote.lp ?? '0.00',
            'chng': quote.chng ?? '0.00',
            'pc': quote.pc ?? '0.00',
          };
        }
      } catch (e) {
      }

      if (_loadGeneration != gen) return; // Stale — a newer switch happened

      // Fetch linked scripts to get expiry dates using direct API call
      final linkedScrips = await _api.getLinkedScrip(index.token, index.exch);

      if (_loadGeneration != gen) return; // Stale — a newer switch happened

      if (linkedScrips.stat == "Ok" &&
          linkedScrips.optExp != null &&
          linkedScrips.optExp!.isNotEmpty) {

        // Sort expiries by date
        final sortedExpiries = [...linkedScrips.optExp!];
        sortedExpiries.sort((a, b) {
          final dateA = _parseExpiryDate(a.exd ?? '');
          final dateB = _parseExpiryDate(b.exd ?? '');
          return dateA.compareTo(dateB);
        });

        _expiryDates = sortedExpiries;
        // Preserve user's previous expiry selection if it still exists in the list
        final previousExd = _selectedExpiry?.exd;
        final matchingExpiry = previousExd != null
            ? sortedExpiries.cast<OptionExp?>().firstWhere(
                (e) => e?.exd == previousExd,
                orElse: () => null,
              )
            : null;
        _selectedExpiry = matchingExpiry ?? sortedExpiries.first;
      }
    } catch (e) {
    } finally {
      _isLoadingExpiries = false;
      if (_loadGeneration == gen) {
        notifyListeners();
      }
    }
  }

  /// Parse expiry date string to DateTime for sorting
  DateTime _parseExpiryDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        const monthMap = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
          'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
          'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
        };
        final month = monthMap[parts[1].toUpperCase()] ?? 1;
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return DateTime.now();
  }

  /// Set selected expiry and load option chain
  Future<void> setSelectedExpiry(OptionExp expiry, BuildContext context) async {
    if (_selectedExpiry?.exd == expiry.exd) return;

    // Unsubscribe old option tokens before loading new chain
    unsubscribeFromWebSocket(context);

    _loadGeneration++; // Cancel any in-flight async work

    _selectedExpiry = expiry;
    notifyListeners();

    await loadOptionChain(context);
  }

  /// Update index LTP from WebSocket
  void updateIndexLTP(double ltp) {
    if (ltp == _currentIndexLTP) return;
    _currentIndexLTP = ltp;
    _calculateATM();
    notifyListeners();
  }

  /// Load option chain for selected index and expiry using direct API calls
  Future<void> loadOptionChain(BuildContext context) async {
    if (_selectedExpiry == null) {
      return;
    }

    final gen = _loadGeneration;

    _isLoadingOptionChain = true;
    _optionChainError = null;
    notifyListeners();

    try {
      final index = selectedIndex;

      // Use current LTP or a default strike price
      final strPrc = _currentIndexLTP > 0
          ? _currentIndexLTP.toStringAsFixed(2)
          : '0';


      // The expiry from getLinkedScrip carries its own exchange (NFO/BFO/MCX);
      // that is authoritative. index.optExch is only a fallback.
      final optExchange =
          optionExchangeForExpiry(_selectedExpiry, index.optExch);

      // Fetch option chain using direct API call - 35 strikes to ensure we have 15 above and below ATM
      final chainData = await _api.getOptionChain(
        strPrc: strPrc,
        tradeSym: _selectedExpiry!.tsym ?? '',
        exchange: optExchange,
        context: context,
        numofStrike: '35',
      );

      if (_loadGeneration != gen) return; // Stale — a newer switch happened

      if (chainData != null &&
          chainData.stat == 'Ok' &&
          chainData.optValue != null) {

        // Separate calls and puts
        _callOptions = chainData.optValue!
            .where((o) => o.optt == 'CE')
            .toList();
        _putOptions = chainData.optValue!
            .where((o) => o.optt == 'PE')
            .toList();


        // Get lot size from first option
        if (_callOptions.isNotEmpty) {
          _lotSize = _callOptions.first.ls ?? '1';
        }

        // Build sorted strikes list
        _buildSortedStrikes();

        // Calculate ATM
        _calculateATM();


        // Auto-select strike based on default offset if not already selected
        if (_selectedStrike.isEmpty && _atmStrike.isNotEmpty) {
          _applyDefaultStrikeOffset();
        } else if (_callStrike.isNotEmpty || _putStrike.isNotEmpty) {
          // Re-lookup call/put from the new chain data (e.g. after expiry change).
          // The strike number may be the same but the OptionValues objects
          // (with different tokens/tsyms) belong to the new expiry.
          if (_callStrike.isNotEmpty) {
            _selectedCall = getCallForStrike(_callStrike);
          }
          if (_putStrike.isNotEmpty) {
            _selectedPut = getPutForStrike(_putStrike);
          }
        }
      } else {
        if (chainData?.emsg == "Session Expired :  Invalid Session Key" &&
            chainData?.stat == "Not_Ok") {
          ref.read(authProvider).ifSessionExpired(context);
        }
        _optionChainError = (chainData?.emsg?.isNotEmpty ?? false)
            ? chainData!.emsg!
            : 'Option chain unavailable for ${index.name} ($optExchange)';
      }
    } catch (e) {
      _optionChainError = 'Option chain request failed: $e';
    } finally {
      // Always reset loading flag — even on generation mismatch, so the UI doesn't stay stuck.
      // The newer load call will set it back to true when it starts.
      _isLoadingOptionChain = false;
      if (_loadGeneration == gen) {
        notifyListeners();
      }
    }
  }

  /// Build sorted list of unique strike prices
  void _buildSortedStrikes() {
    final strikeSet = <String>{};

    for (final call in _callOptions) {
      if (call.strprc != null && call.strprc!.isNotEmpty) {
        strikeSet.add(call.strprc!);
      }
    }

    for (final put in _putOptions) {
      if (put.strprc != null && put.strprc!.isNotEmpty) {
        strikeSet.add(put.strprc!);
      }
    }

    _sortedStrikes = strikeSet.toList()
      ..sort((a, b) =>
          (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));
  }

  /// Calculate ATM strike based on current index LTP
  void _calculateATM() {
    if (_sortedStrikes.isEmpty || _currentIndexLTP <= 0) {
      _atmStrike = '';
      return;
    }

    String closestStrike = _sortedStrikes.first;
    double minDiff = double.infinity;

    for (final strike in _sortedStrikes) {
      final strikePrice = double.tryParse(strike) ?? 0;
      final diff = (strikePrice - _currentIndexLTP).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestStrike = strike;
      }
    }

    _atmStrike = closestStrike;
  }

  /// Set selected strike and update both call/put options (used for initial ATM selection)
  void setSelectedStrike(String strike) {
    _selectedStrike = strike;
    _callStrike = strike;
    _putStrike = strike;
    _selectedCall = getCallForStrike(strike);
    _selectedPut = getPutForStrike(strike);
    notifyListeners();
  }

  /// Apply strike selection based on current mode (offset or premium)
  void _applyStrikeSelection() {
    if (_strikeSelectionMode == 'premium') {
      _applyPremiumSelection();
    } else {
      _applyOffsetSelection();
    }
  }

  /// Apply default strike offset relative to ATM (separate for CE and PE)
  void _applyOffsetSelection() {
    if (_sortedStrikes.isEmpty || _atmStrike.isEmpty) return;

    final atmIndex = _sortedStrikes.indexOf(_atmStrike);
    if (atmIndex == -1) return;

    _selectedStrike = _atmStrike;

    // CE offset: positive = above ATM (OTM), negative = below ATM (ITM)
    final callIdx = (atmIndex + _defaultCallOffset).clamp(0, _sortedStrikes.length - 1);
    _callStrike = _sortedStrikes[callIdx];
    _selectedCall = getCallForStrike(_callStrike);

    // PE offset: reversed — positive OTM for PE is below ATM
    final putIdx = (atmIndex - _defaultPutOffset).clamp(0, _sortedStrikes.length - 1);
    _putStrike = _sortedStrikes[putIdx];
    _selectedPut = getPutForStrike(_putStrike);
  }

  /// Apply premium-based strike selection — find strike whose LTP is closest to the target.
  /// Uses real-time websocket LTP data (falling back to API data) for accurate matching.
  void _applyPremiumSelection() {
    if (_callOptions.isEmpty && _putOptions.isEmpty) return;

    final socketDatas = ref.read(websocketProvider).socketDatas;

    // Find CE with LTP closest to target
    OptionValues? bestCall;
    double bestCallDiff = double.infinity;
    for (final call in _callOptions) {
      final wsLtp = socketDatas[call.token]?['lp']?.toString();
      final ltp = double.tryParse(wsLtp ?? call.lp ?? '0') ?? 0;
      if (ltp <= 0) continue;
      final diff = (ltp - _callPremiumTarget).abs();
      if (diff < bestCallDiff) {
        bestCallDiff = diff;
        bestCall = call;
      }
    }

    // Find PE with LTP closest to target
    OptionValues? bestPut;
    double bestPutDiff = double.infinity;
    for (final put in _putOptions) {
      final wsLtp = socketDatas[put.token]?['lp']?.toString();
      final ltp = double.tryParse(wsLtp ?? put.lp ?? '0') ?? 0;
      if (ltp <= 0) continue;
      final diff = (ltp - _putPremiumTarget).abs();
      if (diff < bestPutDiff) {
        bestPutDiff = diff;
        bestPut = put;
      }
    }

    _selectedStrike = _atmStrike;
    if (bestCall != null) {
      _callStrike = bestCall.strprc ?? _atmStrike;
      _selectedCall = bestCall;
    }
    if (bestPut != null) {
      _putStrike = bestPut.strprc ?? _atmStrike;
      _selectedPut = bestPut;
    }
  }

  // Legacy alias
  void _applyDefaultStrikeOffset() => _applyStrikeSelection();

  /// Re-apply preference-based strike selection (called on refresh to reset manual picks).
  void reapplyPreferenceStrikes() {
    if (_atmStrike.isNotEmpty) {
      _applyStrikeSelection();
      notifyListeners();
    }
  }

  /// Set call chart to a specific strike (independent of put chart)
  void setCallStrike(String strike) {
    _callStrike = strike;
    _selectedCall = getCallForStrike(strike);
    notifyListeners();
  }

  /// Set put chart to a specific strike (independent of call chart)
  void setPutStrike(String strike) {
    _putStrike = strike;
    _selectedPut = getPutForStrike(strike);
    notifyListeners();
  }

  /// Set left chart to any option (CE or PE)
  void setLeftChartOption(OptionValues option) {
    _callStrike = option.strprc ?? '';
    _selectedCall = option;
    notifyListeners();
  }

  /// Set right chart to any option (CE or PE)
  void setRightChartOption(OptionValues option) {
    _putStrike = option.strprc ?? '';
    _selectedPut = option;
    notifyListeners();
  }

  /// Set lot quantity
  void setLotQuantity(int qty) {
    if (qty < 1) qty = 1;
    _lotQuantity = qty;
    notifyListeners();
  }

  /// Increment lot quantity
  void incrementLotQuantity() {
    _lotQuantity++;
    notifyListeners();
  }

  /// Decrement lot quantity
  void decrementLotQuantity() {
    if (_lotQuantity > 1) {
      _lotQuantity--;
      notifyListeners();
    }
  }

  /// Set product type (Intraday/Delivery)
  void setProductType(bool isIntraday) {
    _isIntraday = isIntraday;
    notifyListeners();
  }

  /// Set order type (Market/Limit)
  void setOrderType(bool isMarket) {
    _isMarketOrder = isMarket;
    notifyListeners();
  }

  /// Toggle option chain overlay
  void toggleOptionChainOverlay() {
    _showOptionChainOverlay = !_showOptionChainOverlay;
    notifyListeners();
  }

  /// Show option chain overlay
  void showOptionChain() {
    _showOptionChainOverlay = true;
    notifyListeners();
  }

  /// Hide option chain overlay
  void hideOptionChain() {
    _showOptionChainOverlay = false;
    notifyListeners();
  }

  /// Expand a chart to full width (call, index, or put)
  void expandChart(String chartType) {
    _expandedChart = chartType;
    notifyListeners();
  }

  /// Collapse expanded chart back to normal view
  void collapseChart() {
    _expandedChart = null;
    notifyListeners();
  }

  /// Toggle chart expansion
  void toggleChartExpansion(String chartType) {
    if (_expandedChart == chartType) {
      _expandedChart = null;
    } else {
      _expandedChart = chartType;
    }
    notifyListeners();
  }

  /// Toggle positions panel collapsed state
  void togglePositionsPanel() {
    _isPositionsPanelCollapsed = !_isPositionsPanelCollapsed;
    notifyListeners();
  }

  /// Set positions panel height (for drag resize)
  void setPositionsPanelHeight(double height) {
    _positionsPanelHeight = height.clamp(minPanelHeight, maxPanelHeight);
    notifyListeners();
  }

  /// Expand positions panel
  void expandPositionsPanel() {
    _isPositionsPanelCollapsed = false;
    notifyListeners();
  }

  /// Collapse positions panel
  void collapsePositionsPanel() {
    _isPositionsPanelCollapsed = true;
    notifyListeners();
  }

  // ─── GTT (Stoploss / Target) ────────────────────────────────────

  List<GttOrderBookModel> _gttOrders = [];
  List<GttOrderBookModel> get gttOrders => _gttOrders;

  final Set<String> _expandedPositionTokens = {};
  Set<String> get expandedPositionTokens => _expandedPositionTokens;

  // Debounce state for inline +/- modify buttons
  final Map<String, Timer> _gttDebounceTimers = {};
  final Map<String, double> _gttPendingPrices = {};
  static const int _gttDebounceDelay = 300;

  /// Fetch pending GTT orders from the order provider
  Future<void> fetchGttOrders(BuildContext context) async {
    try {
      await ref.read(orderProvider).fetchGTTOrderBook(context, 'initLoad');
      final orders = ref.read(orderProvider).gttOrderBookModel;
      _gttOrders = orders != null ? List.from(orders) : [];
      notifyListeners();
    } catch (e) {
    }
  }

  /// Toggle position row expansion
  void toggleExpandPosition(String token) {
    if (_expandedPositionTokens.contains(token)) {
      _expandedPositionTokens.remove(token);
    } else {
      _expandedPositionTokens.add(token);
    }
    notifyListeners();
  }

  /// Get a specific GTT order for a position by type ('SL' or 'Target')
  /// [netqty] is the position's net quantity (positive = long, negative = short)
  GttOrderBookModel? getGttByType(String token, String type, int netqty) {
    final isLong = netqty > 0;
    return _gttOrders.cast<GttOrderBookModel?>().firstWhere(
      (gtt) {
        if (gtt == null || gtt.token != token) return false;
        if (type == 'SL') {
          return isLong
              ? (gtt.trantype == 'S' && gtt.aiT == 'LTP_B_O')
              : (gtt.trantype == 'B' && gtt.aiT == 'LTP_A_O');
        } else {
          // Target
          return isLong
              ? (gtt.trantype == 'S' && gtt.aiT == 'LTP_A_O')
              : (gtt.trantype == 'B' && gtt.aiT == 'LTP_B_O');
        }
      },
      orElse: () => null,
    );
  }

  /// Get stoploss trigger price for a position (or null)
  String? getPositionStoploss(String token, int netqty) {
    final gtt = getGttByType(token, 'SL', netqty);
    return gtt?.d;
  }

  /// Get target trigger price for a position (or null)
  String? getPositionTarget(String token, int netqty) {
    final gtt = getGttByType(token, 'Target', netqty);
    return gtt?.d;
  }

  /// Get all GTT orders for a specific position token
  List<GttOrderBookModel> getPositionGttOrders(String token) {
    return _gttOrders.where((g) => g.token == token).toList();
  }

  /// Modify a GTT order's trigger price with debouncing (for +/- buttons)
  /// Each click updates the UI instantly; the API call fires once after 300ms of no clicks.
  void modifyGttPrice(GttOrderBookModel gtt, double adjustment, BuildContext context) {
    final alId = gtt.alId ?? '';
    if (alId.isEmpty) return;

    // Read current price from pending (accumulated) or from gtt.d
    final currentPrice = _gttPendingPrices[alId] ?? (double.tryParse(gtt.d ?? '0') ?? 0);
    final newPrice = currentPrice + adjustment;

    // Guard: never send 0 or negative
    if (newPrice <= 0) return;

    // Store the accumulated price
    _gttPendingPrices[alId] = newPrice;

    // Optimistic UI update
    final idx = _gttOrders.indexWhere((g) => g.alId == alId);
    if (idx >= 0) {
      _gttOrders[idx].d = newPrice.toStringAsFixed(2);
      _gttOrders = List.from(_gttOrders); // New reference for select() equality
      notifyListeners();
    }

    // Cancel existing timer, set new debounced call
    _gttDebounceTimers[alId]?.cancel();
    _gttDebounceTimers[alId] = Timer(Duration(milliseconds: _gttDebounceDelay), () async {
      final finalPrice = _gttPendingPrices[alId];
      _gttPendingPrices.remove(alId);
      _gttDebounceTimers.remove(alId);

      if (finalPrice == null || finalPrice <= 0) return;

      try {
        final input = PlaceGTTOrderInput(
          tsym: gtt.tsym ?? '',
          exch: gtt.exch ?? '',
          ait: gtt.aiT ?? '',
          validity: 'GTT',
          d: finalPrice.toStringAsFixed(2),
          remarks: '',
          trantype: gtt.trantype ?? '',
          prctyp: gtt.prctyp ?? 'MKT',
          prd: gtt.prd ?? 'I',
          ret: 'DAY',
          qty: (gtt.qty ?? 0).toString(),
          prc: gtt.prc ?? '0',
          alid: alId,
          trgprc: '0',
        );

        await ref.read(orderProvider).modifyGTTOrder(input, context);
        await fetchGttOrders(context);
      } catch (e) {
        await fetchGttOrders(context);
      }
    });
  }

  /// Cancel a GTT order silently (no snackbar — used for auto-cancel on exit)
  Future<bool> cancelGttOrderSilent(String alId, BuildContext context) async {
    try {
      final api = locator<ApiExporter>();
      final result = await api.cancelGTTOrderAPI(alId);
      if (result.stat == 'OI deleted' || result.stat == 'Invalid Oi') {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel all GTT orders for a position (used when exiting position)
  Future<int> cancelAllGttForPosition(String token, BuildContext context) async {
    final posGtts = getPositionGttOrders(token);
    if (posGtts.isEmpty) return 0;

    int cancelledCount = 0;
    for (final gtt in posGtts) {
      if (gtt.alId != null && gtt.alId!.isNotEmpty) {
        final success = await cancelGttOrderSilent(gtt.alId!, context);
        if (success) cancelledCount++;
      }
    }

    if (cancelledCount > 0) {
      await fetchGttOrders(context);
    }
    return cancelledCount;
  }

  /// Get call option for a strike price
  OptionValues? getCallForStrike(String strike) {
    try {
      return _callOptions.firstWhere(
        (o) => o.strprc == strike,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get put option for a strike price
  OptionValues? getPutForStrike(String strike) {
    try {
      return _putOptions.firstWhere(
        (o) => o.strprc == strike,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get strikes to display (15 above + ATM + 15 below)
  List<String> getDisplayStrikes() {
    if (_sortedStrikes.isEmpty) return [];

    final atmIndex = _sortedStrikes.indexOf(_atmStrike);
    if (atmIndex == -1) return _sortedStrikes;

    final startIndex = (atmIndex - 15).clamp(0, _sortedStrikes.length - 1);
    final endIndex = (atmIndex + 16).clamp(0, _sortedStrikes.length);

    return _sortedStrikes.sublist(startIndex, endIndex);
  }

  /// Calculate total order quantity (lots * lot size)
  int get totalOrderQuantity {
    final ls = int.tryParse(_lotSize) ?? 1;
    return _lotQuantity * ls;
  }

  /// Subscribe to WebSocket for index and options.
  ///
  /// Scalper uses the touchline feed (`t`), not depth (`d`): the option chain
  /// exceeds the websocket depth limit, which stalled PE prices. The order bar's
  /// ASK/BID read `sp1`/`bp1` and fall back to the chain's `lp` until a touchline
  /// delta carrying the book arrives (`_updateSocketData` merges every field
  /// present in a delta, so no scalper-specific provider change is needed).
  Future<void> subscribeToWebSocket(BuildContext context) async {
    final websocket = ref.read(websocketProvider);
    final index = selectedIndex;

    // Subscribe to index token
    websocket.acquireTouchline(
        'scalper', ["${index.exch}|${index.token}"], context);

    // Build option tokens string
    final optionTokens = <String>{};
    for (final call in _callOptions) {
      if (call.exch != null && call.token != null) {
        optionTokens.add("${call.exch}|${call.token}");
      }
    }
    for (final put in _putOptions) {
      if (put.exch != null && put.token != null) {
        optionTokens.add("${put.exch}|${put.token}");
      }
    }

    if (optionTokens.isNotEmpty) {
      _subscribedOptionTokens = optionTokens;

      // Keep the chain out of ConstantName.lastSubscribe. establishConnection
      // stashes every "t" channel in that global, and on reconnect
      // network_state_provider._restoreLegacySubscriptions replays it as *depth*
      // on web — which would put all ~64 tokens back on the depth feed and
      // re-create the limit overflow this screen switched to touchline to avoid.
      // Restoring right after the call is enough: the write is synchronous.
      final savedLastSubscribe = ConstantName.lastSubscribe;
      websocket.acquireTouchline('scalper', optionTokens, context);
      ConstantName.lastSubscribe = savedLastSubscribe;
    }
  }

  /// Unsubscribe option tokens from WebSocket
  void unsubscribeFromWebSocket(BuildContext context) {
    final websocket = ref.read(websocketProvider);
    // Release the index and every option through the touchline owner registry
    // ("u", never "ud" — this screen subscribes touchline only). A raw "u"
    // here used to cut any of these scrips the watchlist or a chart still
    // showed; the registry only unsubscribes what nothing else needs.
    websocket.releaseAllTouchline('scalper', context);
    _subscribedOptionTokens.clear();
  }

  /// Reset state
  void reset() {
    _customIndex = null;
    _selectedIndexType = 0;
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _selectedStrike = '';
    _callStrike = '';
    _putStrike = '';
    _selectedCall = null;
    _selectedPut = null;
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    _lotQuantity = 1;
    _isIntraday = true;
    _isMarketOrder = true;
    _showOptionChainOverlay = false;
    _expandedChart = null;
    _isPositionsPanelCollapsed = false;
    _positionsPanelHeight = 250.0;
    _isShortcutsEnabled = false;
    _positionFilter = 'all';
    _subscribedOptionTokens.clear();
    _indicesData.clear();
    _gttOrders.clear();
    _expandedPositionTokens.clear();
    for (final timer in _gttDebounceTimers.values) {
      timer.cancel();
    }
    _gttDebounceTimers.clear();
    _gttPendingPrices.clear();
    notifyListeners();
  }
}

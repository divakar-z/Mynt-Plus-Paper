import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/core/api_export.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../models/marketwatch_model/linked_scrips.dart';
import '../models/marketwatch_model/opt_chain_model.dart';
import '../models/marketwatch_model/search_scrip_model.dart';
import 'websocket_provider.dart';
import '../screens/web/scalper/scalper_provider.dart';

final watchlistOCProvider =
    ChangeNotifierProvider<WatchlistOCProvider>((ref) {
  return WatchlistOCProvider(ref);
});

/// State management for the Option Chain panel in the watchlist sidebar.
/// Modeled on ScalperProvider but simplified: no index tabs, fixed 15 strikes.
class WatchlistOCProvider extends ChangeNotifier {
  final Ref ref;
  final ApiExporter _api = locator<ApiExporter>();
  final Preferences _prefs = locator<Preferences>();

  WatchlistOCProvider(this.ref);

  // ─── Expand / Collapse ──────────────────────────────────────

  bool _isExpanded = false;
  bool get isExpanded => _isExpanded;

  bool _hasLoadedOnce = false; // first-expand guard

  void toggleExpanded(BuildContext context) {
    _isExpanded = !_isExpanded;
    notifyListeners();

    if (_isExpanded && !_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _initializeFromPrefs(context);
    } else if (_isExpanded && _hasLoadedOnce) {
      // Re-expanding after collapse: re-subscribe with existing data
      if (_callOptions.isNotEmpty || _putOptions.isNotEmpty) {
        subscribeToWebSocket(context);
      }
    }
  }

  void collapse(BuildContext context) {
    if (!_isExpanded) return;
    // Don't send "ud" — it can unsubscribe tokens shared with the watchlist.
    // Just clear our tracking set; the websocket keeps connections alive.
    _subscribedOptionTokens.clear();
    _indexLtpSubscription?.cancel();
    _indexLtpSubscription = null;
    _isExpanded = false;
    notifyListeners();
  }

  // ─── Selected Symbol ────────────────────────────────────────

  ScalperIndex _selectedSymbol = ScalperProvider.indices[0]; // NIFTY 50
  ScalperIndex get selectedSymbol => _selectedSymbol;

  double _currentIndexLTP = 0.0;
  double get currentIndexLTP => _currentIndexLTP;

  // ─── Expiry ──────────────────────────────────────────────────

  List<OptionExp> _expiryDates = [];
  List<OptionExp> get expiryDates => _expiryDates;

  OptionExp? _selectedExpiry;
  OptionExp? get selectedExpiry => _selectedExpiry;

  // ─── Option Chain Data ──────────────────────────────────────

  List<OptionValues> _callOptions = [];
  List<OptionValues> get callOptions => _callOptions;

  List<OptionValues> _putOptions = [];
  List<OptionValues> get putOptions => _putOptions;

  List<String> _sortedStrikes = [];
  List<String> get sortedStrikes => _sortedStrikes;

  String _atmStrike = '';
  String get atmStrike => _atmStrike;

  // ─── Loading States ─────────────────────────────────────────

  bool _isLoadingExpiries = false;
  bool get isLoadingExpiries => _isLoadingExpiries;

  bool _isLoadingOptionChain = false;
  bool get isLoadingOptionChain => _isLoadingOptionChain;

  // ─── Available Symbols (search) ─────────────────────────────

  List<ScripValue> _availableSymbols = [];
  List<ScripValue> get availableSymbols => _availableSymbols;

  bool _isLoadingSymbols = false;
  bool get isLoadingSymbols => _isLoadingSymbols;

  // ─── Async race-condition guard ─────────────────────────────

  int _loadGeneration = 0;

  // ─── WebSocket tokens ───────────────────────────────────────

  Set<String> _subscribedOptionTokens = {};
  StreamSubscription? _indexLtpSubscription;

  // ─── Initialization ─────────────────────────────────────────

  /// Called on first expand: restore persisted symbol, then load data.
  Future<void> _initializeFromPrefs(BuildContext context) async {
    final saved = _prefs.watchlistOCSymbol;
    // Format: token:exch:name:optExch
    final parts = saved.split(':');
    if (parts.length == 4) {
      _selectedSymbol = ScalperIndex(
        name: parts[2],
        token: parts[0],
        exch: parts[1],
        tsym: parts[2],
        optExch: parts[3],
      );
    }
    await loadSymbolData(context);
  }

  /// Persist current symbol to SharedPreferences.
  void _persistSymbol() {
    final s = _selectedSymbol;
    _prefs.setWatchlistOCSymbol('${s.token}:${s.exch}:${s.name}:${s.optExch}');
  }

  // ─── Symbol Selection ────────────────────────────────────────

  /// Select a symbol from the search dropdown.
  Future<void> setSelectedSymbol(
      ScripValue symbol, BuildContext context) async {
    unsubscribeFromWebSocket(context);
    _loadGeneration++;

    // MCX commodities keep MCX as their option exchange; sending NFO makes
    // GetOptionChain reject the request with a 400.
    final optExch = optionExchangeForUnderlying(symbol.exch);
    _selectedSymbol = ScalperIndex(
      name: symbol.tsym ?? symbol.cname ?? '',
      token: symbol.token ?? '',
      exch: symbol.exch ?? 'NSE',
      tsym: symbol.tsym ?? '',
      optExch: optExch,
    );

    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    notifyListeners();

    _persistSymbol();
    await loadSymbolData(context);
  }

  /// Change selected expiry and reload option chain.
  Future<void> setSelectedExpiry(
      OptionExp expiry, BuildContext context) async {
    if (_selectedExpiry?.exd == expiry.exd) return;

    unsubscribeFromWebSocket(context);
    _loadGeneration++;

    _selectedExpiry = expiry;
    notifyListeners();

    await loadOptionChain(context);
  }

  // ─── Data Loading ────────────────────────────────────────────

  /// Fetch quote + linked scrips (expiry dates), then load option chain.
  Future<void> loadSymbolData(BuildContext context) async {
    final gen = _loadGeneration;

    _isLoadingExpiries = true;
    notifyListeners();

    try {
      final sym = _selectedSymbol;

      // Fetch initial quote for LTP
      try {
        final quote = await _api.getScripQuote(sym.token, sym.exch);
        if (_loadGeneration != gen) return;
        if (quote.stat == 'Ok' && quote.lp != null) {
          _currentIndexLTP = double.tryParse(quote.lp!) ?? 0.0;
        }
      } catch (e) {
      }

      if (_loadGeneration != gen) return;

      // Fetch linked scrips for expiry dates
      final linkedScrips =
          await _api.getLinkedScrip(sym.token, sym.exch);

      if (_loadGeneration != gen) return;

      if (linkedScrips.stat == "Ok" &&
          linkedScrips.optExp != null &&
          linkedScrips.optExp!.isNotEmpty) {
        final sorted = [...linkedScrips.optExp!];
        sorted.sort((a, b) {
          final da = _parseExpiryDate(a.exd ?? '');
          final db = _parseExpiryDate(b.exd ?? '');
          return da.compareTo(db);
        });

        _expiryDates = sorted;
        _selectedExpiry = sorted.first;
      }
    } catch (e) {
    } finally {
      _isLoadingExpiries = false;
      if (_loadGeneration == gen) notifyListeners();
    }

    // Now load option chain
    if (_loadGeneration == gen) {
      await loadOptionChain(context);
    }
  }

  /// Fetch option chain with fixed 15 strikes.
  Future<void> loadOptionChain(BuildContext context) async {
    if (_selectedExpiry == null) return;

    final gen = _loadGeneration;

    _isLoadingOptionChain = true;
    notifyListeners();

    try {
      final strPrc = _currentIndexLTP > 0
          ? _currentIndexLTP.toStringAsFixed(2)
          : '0';

      // The expiry from getLinkedScrip carries its own exchange (NFO/BFO/MCX);
      // that is authoritative. _selectedSymbol.optExch is only a fallback (and
      // may be stale for symbols persisted before MCX support existed).
      final optExchange = optionExchangeForExpiry(
          _selectedExpiry, optionExchangeForUnderlying(_selectedSymbol.exch));

      final chainData = await _api.getOptionChain(
        strPrc: strPrc,
        tradeSym: _selectedExpiry!.tsym ?? '',
        exchange: optExchange,
        context: context,
        numofStrike: '15',
      );

      if (_loadGeneration != gen) return;

      if (chainData != null &&
          chainData.stat == 'Ok' &&
          chainData.optValue != null) {
        _callOptions =
            chainData.optValue!.where((o) => o.optt == 'CE').toList();
        _putOptions =
            chainData.optValue!.where((o) => o.optt == 'PE').toList();

        _buildSortedStrikes();
        _calculateATM();

        // Subscribe to WebSocket for live data
        subscribeToWebSocket(context);
      }
    } catch (e) {
    } finally {
      _isLoadingOptionChain = false;
      if (_loadGeneration == gen) notifyListeners();
    }
  }

  // ─── Strike Helpers ──────────────────────────────────────────

  void _buildSortedStrikes() {
    final strikeSet = <String>{};
    for (final c in _callOptions) {
      if (c.strprc != null && c.strprc!.isNotEmpty) strikeSet.add(c.strprc!);
    }
    for (final p in _putOptions) {
      if (p.strprc != null && p.strprc!.isNotEmpty) strikeSet.add(p.strprc!);
    }
    _sortedStrikes = strikeSet.toList()
      ..sort((a, b) =>
          (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));
  }

  void _calculateATM() {
    if (_sortedStrikes.isEmpty || _currentIndexLTP <= 0) {
      _atmStrike = '';
      return;
    }
    String closest = _sortedStrikes.first;
    double minDiff = double.infinity;
    for (final strike in _sortedStrikes) {
      final diff = ((double.tryParse(strike) ?? 0) - _currentIndexLTP).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = strike;
      }
    }
    _atmStrike = closest;
  }

  /// Get call option for a given strike price.
  OptionValues? getCallForStrike(String strike) {
    try {
      return _callOptions.firstWhere((o) => o.strprc == strike);
    } catch (_) {
      return null;
    }
  }

  /// Get put option for a given strike price.
  OptionValues? getPutForStrike(String strike) {
    try {
      return _putOptions.firstWhere((o) => o.strprc == strike);
    } catch (_) {
      return null;
    }
  }

  // ─── Search / Available Symbols ─────────────────────────────

  /// Fetch all available option symbols (called once, cached).
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

  // ─── WebSocket ──────────────────────────────────────────────

  /// Update index LTP from WebSocket (matches ScalperProvider.updateIndexLTP)
  void updateIndexLTP(double ltp) {
    if (ltp == _currentIndexLTP) return;
    _currentIndexLTP = ltp;
    _calculateATM();
    notifyListeners();
  }

  void subscribeToWebSocket(BuildContext context) {
    final websocket = ref.read(websocketProvider);
    final indexToken = _selectedSymbol.token;

    // Subscribe to index token (touchline feed — option chain only needs LTP)
    websocket.acquireTouchline(
        'watchlist-oc', ["${_selectedSymbol.exch}|$indexToken"], context);

    // Listen for index LTP updates to keep the blue line position in sync
    _indexLtpSubscription?.cancel();
    _indexLtpSubscription =
        websocket.socketDataStream.listen((socketDatas) {
      if (socketDatas.containsKey(indexToken)) {
        final wsLtp = socketDatas[indexToken]['lp']?.toString();
        if (wsLtp != null && wsLtp != "null" && wsLtp != "0") {
          final newLtp = double.tryParse(wsLtp) ?? 0.0;
          if (newLtp > 0) {
            updateIndexLTP(newLtp);
          }
        }
      }
    });

    // Build option tokens
    final tokens = <String>{};
    for (final c in _callOptions) {
      if (c.exch != null && c.token != null) tokens.add("${c.exch}|${c.token}");
    }
    for (final p in _putOptions) {
      if (p.exch != null && p.token != null) tokens.add("${p.exch}|${p.token}");
    }

    if (tokens.isNotEmpty) {
      _subscribedOptionTokens = tokens;
      websocket.acquireTouchline('watchlist-oc', tokens, context);
    }
  }

  void unsubscribeFromWebSocket(BuildContext context) {
    _indexLtpSubscription?.cancel();
    _indexLtpSubscription = null;

    final websocket = ref.read(websocketProvider);
    // Index and options alike; anything still shown elsewhere stays live.
    websocket.releaseAllTouchline('watchlist-oc', context);
    _subscribedOptionTokens.clear();
  }

  // ─── Helpers ────────────────────────────────────────────────

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
    } catch (_) {}
    return DateTime.now();
  }

  /// Reset all state (e.g. on logout).
  void reset() {
    _indexLtpSubscription?.cancel();
    _indexLtpSubscription = null;
    _isExpanded = false;
    _hasLoadedOnce = false;
    _selectedSymbol = ScalperProvider.indices[0];
    _currentIndexLTP = 0.0;
    _atmStrike = '';
    _expiryDates = [];
    _selectedExpiry = null;
    _callOptions = [];
    _putOptions = [];
    _sortedStrikes = [];
    _subscribedOptionTokens.clear();
    _availableSymbols = [];
    notifyListeners();
  }
}

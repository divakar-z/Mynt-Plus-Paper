import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/api/core/api_export.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/models/marketwatch_model/linked_scrips.dart';
import 'package:mynt_plus/models/marketwatch_model/opt_chain_model.dart';
import 'package:mynt_plus/models/order_book_model/place_order_model.dart';
import 'package:mynt_plus/models/portfolio_model/position_book_model.dart';
import 'package:mynt_plus/provider/auth_provider.dart';
import 'package:mynt_plus/provider/core/default_change_notifier.dart';
import 'package:mynt_plus/provider/portfolio_provider.dart';
import 'package:mynt_plus/provider/websocket_provider.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';

final optionFlashProvider =
    ChangeNotifierProvider((ref) => OptionFlashProvider(ref));

/// Symbol data for Option Flash panel
class OptionFlashSymbol {
  final String cname;
  final String display;
  final String tsym;
  final String token;
  final String exch;
  final String expiry;
  final String symname;

  OptionFlashSymbol({
    required this.cname,
    required this.display,
    required this.tsym,
    required this.token,
    required this.exch,
    required this.expiry,
    required this.symname,
  });
}

/// Formatted strike for dropdown
class FormattedStrike {
  final String label;
  final OptionValues option;
  final bool isATM;
  final double strike;
  final String optionType;
  final String moneyness;
  final int moneynessDepth; // How many strikes away from ATM (0 for ATM)
  final double ltp;

  FormattedStrike({
    required this.label,
    required this.option,
    required this.isATM,
    required this.strike,
    required this.optionType,
    required this.moneyness,
    this.moneynessDepth = 0,
    required this.ltp,
  });

  /// Moneyness with depth number (e.g., "ITM 2", "OTM 3", "ATM")
  String get moneynessLabel => isATM ? moneyness : '$moneyness $moneynessDepth';

  FormattedStrike copyWith({
    String? label,
    OptionValues? option,
    bool? isATM,
    double? strike,
    String? optionType,
    String? moneyness,
    int? moneynessDepth,
    double? ltp,
  }) {
    return FormattedStrike(
      label: label ?? this.label,
      option: option ?? this.option,
      isATM: isATM ?? this.isATM,
      strike: strike ?? this.strike,
      optionType: optionType ?? this.optionType,
      moneyness: moneyness ?? this.moneyness,
      moneynessDepth: moneynessDepth ?? this.moneynessDepth,
      ltp: ltp ?? this.ltp,
    );
  }
}

class OptionFlashProvider extends DefaultChangeNotifier {
  final Ref ref;
  final api = locator<ApiExporter>();
  final Preferences pref = locator<Preferences>();

  OptionFlashProvider(this.ref);

  // Callback to re-enable chart iframes — set by the panel widget
  VoidCallback? onPanelClosed;

  // Portfolio provider listener — re-syncs positions when portfolio updates
  ProviderSubscription? _portfolioSubscription;

  // Throttle WebSocket UI updates to ~4 per second
  int _lastNotifyTimeMs = 0;
  static const _minNotifyIntervalMs = 250;
  bool _hasPendingNotify = false;

  // Strike dropdown open state — skip option chain updates when closed
  bool _isStrikeDropdownOpen = false;

  // Dialog visibility
  bool _isVisible = false;
  bool get isVisible => _isVisible;

  // Panel loading state
  bool _isPanelLoading = false;
  bool get isPanelLoading => _isPanelLoading;

  // Order loading state
  bool _orderLoading = false;
  bool get orderLoading => _orderLoading;

  // Symbols list
  final List<OptionFlashSymbol> _symbolsList = [
    OptionFlashSymbol(
      cname: "Nifty 50",
      display: "NIFTY",
      tsym: "NIFTY 50",
      token: "26000",
      exch: "NSE",
      expiry: "Weekly",
      symname: "NIFTY",
    ),
    OptionFlashSymbol(
      cname: "NIFTY FIN SERVICE",
      display: "FINNIFTY",
      tsym: "NIFTY FIN SERVICE",
      token: "26037",
      exch: "NSE",
      expiry: "Weekly",
      symname: "FINNIFTY",
    ),
    OptionFlashSymbol(
      cname: "Nifty Bank",
      display: "BANKNIFTY",
      tsym: "NIFTY BANK",
      token: "26009",
      exch: "NSE",
      expiry: "Monthly",
      symname: "BANKNIFTY",
    ),
    OptionFlashSymbol(
      cname: "NIFTY MID SELECT",
      display: "MIDCPNIFTY",
      tsym: "NIFTY MID SELECT",
      token: "26074",
      exch: "NSE",
      expiry: "Monthly",
      symname: "MIDCPNIFTY",
    ),
    OptionFlashSymbol(
      cname: "SENSEX",
      display: "SENSEX",
      tsym: "SENSEX",
      token: "1",
      exch: "BSE",
      expiry: "Monthly",
      symname: "SENSEX",
    ),
  ];
  List<OptionFlashSymbol> get symbolsList => _symbolsList;

  // Selected data
  OptionFlashSymbol? _selectedSymbol;
  OptionFlashSymbol? get selectedSymbol => _selectedSymbol;

  String _selectedExpiry = '';
  String get selectedExpiry => _selectedExpiry;

  FormattedStrike? _selectedStrike;
  FormattedStrike? get selectedStrike => _selectedStrike;

  // Index data
  String _indexLTP = '0.00';
  String get indexLTP => _indexLTP;

  double _indexChange = 0;
  double get indexChange => _indexChange;

  String _indexChangePer = '0.00';
  String get indexChangePer => _indexChangePer;

  // Strike data
  String _strikeLTP = '0.00';
  String get strikeLTP => _strikeLTP;

  double _strikeChange = 0;
  double get strikeChange => _strikeChange;

  String _strikeChangePer = '0.00';
  String get strikeChangePer => _strikeChangePer;

  // Expiry and option chain
  List<String> _expiryList = [];
  List<String> get expiryList => _expiryList;

  List<OptionExp> _expiryDataRaw = [];
  List<OptionExp> get expiryDataRaw => _expiryDataRaw;

  List<OptionValues> _optionChainData = [];
  List<OptionValues> get optionChainData => _optionChainData;

  List<FormattedStrike> _formattedStrikes = [];
  List<FormattedStrike> get formattedStrikes => _formattedStrikes;

  // Order parameters
  String _productType = 'I'; // Default MIS (I = Intraday/MIS, M = NRML)
  String get productType => _productType;

  String _priceType = 'MKT';
  String get priceType => _priceType;

  double _price = 0;
  double get price => _price;

  int _qtyLots = 1;
  int get qtyLots => _qtyLots;

  int _lotSize = 1;
  int get lotSize => _lotSize;

  // Validation fields
  int _freezeQty = 0;
  int get freezeQty => _freezeQty;

  double _tickSize = 0.05;
  double get tickSize => _tickSize;

  double _upperCircuit = 0;
  double get upperCircuit => _upperCircuit;

  double _lowerCircuit = 0;
  double get lowerCircuit => _lowerCircuit;

  // Validation error messages
  String? _qtyError;
  String? get qtyError => _qtyError;

  String? _priceError;
  String? get priceError => _priceError;

  bool _isBuy = true;
  bool get isBuy => _isBuy;

  // Option type (CE/PE)
  String _selectedOptionType = 'CE';
  String get selectedOptionType => _selectedOptionType;

  // Positions data
  List<PositionBookModel> _positionsData = [];
  List<PositionBookModel> get positionsData => _positionsData;

  String _indexPnL = '0.00';
  String get indexPnL => _indexPnL;

  // Debug info for P&L calculation
  List<String> _pnlDebugInfo = [];
  List<String> get pnlDebugInfo => _pnlDebugInfo;

  /// Check if there are open positions for the currently selected symbol
  bool get hasSymbolPositions {
    if (_selectedSymbol == null || _positionsData.isEmpty) return false;
    return _positionsData.any((pos) {
      final matchesSymbol = _matchesSymbol(pos.tsym, _selectedSymbol!.symname);
      final netqtyVal = int.tryParse(pos.netqty ?? '0') ?? 0;
      final isOpen = netqtyVal != 0;
      return matchesSymbol && isOpen;
    });
  }

  /// Check if there is an open position for the currently selected strike
  bool get hasStrikePosition {
    if (_selectedStrike == null || _positionsData.isEmpty) return false;
    final strikeToken = _selectedStrike!.option.token;
    return _positionsData.any((pos) {
      final netqtyVal = int.tryParse(pos.netqty ?? '0') ?? 0;
      return pos.token == strikeToken && netqtyVal != 0;
    });
  }

  /// Get net quantity for the currently selected strike (raw qty)
  int get strikeNetQty {
    if (_selectedStrike == null || _positionsData.isEmpty) return 0;
    final strikeToken = _selectedStrike!.option.token;
    int total = 0;
    for (var pos in _positionsData) {
      if (pos.token == strikeToken) {
        total += int.tryParse(pos.netqty ?? '0') ?? 0;
      }
    }
    return total;
  }

  /// Get net quantity in lots for display (consistent with order input)
  int get strikeNetQtyLots {
    final raw = strikeNetQty;
    if (_lotSize <= 0) return raw;
    return raw ~/ _lotSize;
  }

  /// Get total net quantity across all positions for the selected symbol
  int get symbolNetQty {
    if (_selectedSymbol == null || _positionsData.isEmpty) return 0;
    int total = 0;
    for (var pos in _positionsData) {
      if (_matchesSymbol(pos.tsym, _selectedSymbol!.symname)) {
        total += int.tryParse(pos.netqty ?? '0') ?? 0;
      }
    }
    return total;
  }

  // WebSocket subscription tracking
  final List<Map<String, String>> _subscribedOptions = [];
  Map<String, String>? _subscribedIndex;
  final List<Map<String, String>> _subscribedPositions = [];

  /// Helper to check if a trading symbol belongs to a specific index symbol
  /// e.g., "NIFTY25FEB25650CE" belongs to "NIFTY" but not to "BANKNIFTY"
  /// This prevents "NIFTY" from matching "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"
  bool _matchesSymbol(String? tsym, String symname) {
    if (tsym == null || tsym.isEmpty) return false;
    // Check if tsym starts with symname followed by a digit (year like 25, 26)
    if (!tsym.startsWith(symname)) return false;
    if (tsym.length <= symname.length) return false;
    // Next character after symname should be a digit (start of year)
    return tsym[symname.length].contains(RegExp(r'[0-9]'));
  }

  // Computed
  int get totalQty => _qtyLots * _lotSize;

  // Dialog position (for dragging)
  Offset _dialogPosition = Offset.zero;
  Offset get dialogPosition => _dialogPosition;

  bool _positionInitialized = false;

  // ============== SESSION EXPIRY HELPERS ==============

  /// Check if the API response indicates session expiry
  bool _isSessionExpired(String? stat, String? emsg) {
    return stat == "Not_Ok" &&
        emsg == "Session Expired :  Invalid Session Key";
  }

  /// Handle session expiry by closing panel and redirecting to login
  void _handleSessionExpiry(BuildContext context) {
    // Close the option flash panel
    closePanel();
    // Trigger session expiry handling
    ref.read(authProvider).ifSessionExpired(context);
  }

  // ============== METHODS ==============

  /// Show the Option Flash panel
  void showPanel(BuildContext context) {
    _selectedSymbol = _symbolsList[0];

    // Initialize position BEFORE making visible to avoid flash at (0,0)
    final screenSize = MediaQuery.of(context).size;
    _dialogPosition = Offset(
      (screenSize.width - 840) / 2,  // Center horizontally (840 is panel width)
      screenSize.height - 200,        // Near bottom
    );
    _positionInitialized = true;

    _isVisible = true;
    notifyListeners();

    // Listen to portfolio provider — re-sync positions when they change
    // (e.g. when order fills, position screen refreshes, etc.)
    _startPortfolioListener();

    // Load initial data
    loadSymbolData(context);
    fetchPositions(context);
  }

  /// Listen to portfolio provider changes and re-sync _positionsData
  void _startPortfolioListener() {
    _portfolioSubscription?.close();
    _portfolioSubscription = ref.listen(portfolioProvider, (previous, next) {
      if (!_isVisible) return;
      final newPositions = next.postionBookModel;
      if (newPositions != null && newPositions != _positionsData) {
        _positionsData = newPositions;
        _readStrikePnL();
        notifyListeners();
      }
    });
  }

  /// Close the Option Flash panel and reset all values
  void closePanel() {
    _isVisible = false;
    _isStrikeDropdownOpen = false;
    _portfolioSubscription?.close();
    _portfolioSubscription = null;
    unsubscribeFromAllOptions();
    unsubscribeFromIndex();
    unsubscribeFromPositions();

    // Re-enable chart iframes via callback set by panel widget
    onPanelClosed?.call();

    // Reset all state values
    _isPanelLoading = false;
    _orderLoading = false;
    _selectedSymbol = null;
    _selectedExpiry = '';
    _selectedStrike = null;

    // Reset index data
    _indexLTP = '0.00';
    _indexChange = 0;
    _indexChangePer = '0.00';

    // Reset strike data
    _strikeLTP = '0.00';
    _strikeChange = 0;
    _strikeChangePer = '0.00';

    // Reset expiry and option chain
    _expiryList = [];
    _expiryDataRaw = [];
    _optionChainData = [];
    _formattedStrikes = [];

    // Reset order parameters
    _productType = 'I';
    _priceType = 'MKT';
    _price = 0;
    _qtyLots = 1;
    _lotSize = 1;
    _tickSize = 0.05;

    // Reset validation fields
    _freezeQty = 0;
    _upperCircuit = 0;
    _lowerCircuit = 0;
    _qtyError = null;
    _priceError = null;

    // Reset buy/sell
    _isBuy = true;

    // Reset positions data
    _positionsData = [];
    _indexPnL = '0.00';

    // Reset dialog position
    _dialogPosition = Offset.zero;
    _positionInitialized = false;

    notifyListeners();
  }

  /// Set strike dropdown open state — controls whether option chain updates run
  void setStrikeDropdownOpen(bool open) {
    _isStrikeDropdownOpen = open;
    if (open) {
      // Bring dropdown data up-to-date immediately before showing
      _refreshLTPFromWebSocket();
    }
  }

  /// Toggle buy/sell
  void toggleBuySell() {
    _isBuy = !_isBuy;
    notifyListeners();
  }

  /// Toggle option type (CE/PE) — keep same strike price, switch option type
  void toggleOptionType(BuildContext context) {
    _selectedOptionType = _selectedOptionType == 'CE' ? 'PE' : 'CE';
    _selectMatchingStrike(context);
    notifyListeners();
  }

  /// Set option type directly — keep same strike price, switch option type
  void setOptionType(String type, BuildContext context) {
    if (_selectedOptionType == type) return;
    _selectedOptionType = type;
    _selectMatchingStrike(context);
    notifyListeners();
  }

  /// Select the strike with the same price in the new option type, fallback to ATM
  void _selectMatchingStrike(BuildContext context) {
    final filtered = filteredStrikes;
    if (filtered.isEmpty) return;

    // Try to find same strike price in the new option type
    if (_selectedStrike != null) {
      final match = filtered.cast<FormattedStrike?>().firstWhere(
        (s) => s!.strike == _selectedStrike!.strike,
        orElse: () => null,
      );
      if (match != null) {
        _selectedStrike = match;
        _onStrikeChangeInternal(context);
        return;
      }
    }

    // Fallback to ATM if no matching strike found
    _autoSelectOptionTypeATM(context);
  }

  /// Get formatted strikes filtered by current option type
  List<FormattedStrike> get filteredStrikes =>
      _formattedStrikes.where((s) => s.optionType == _selectedOptionType).toList();

  /// Auto-select ATM strike for current option type
  void _autoSelectOptionTypeATM(BuildContext context) {
    final filtered = filteredStrikes;
    if (filtered.isEmpty) return;

    final atm = filtered.cast<FormattedStrike?>().firstWhere(
      (s) => s!.isATM,
      orElse: () => filtered[filtered.length ~/ 2],
    );

    if (atm != null) {
      _selectedStrike = atm;
      _onStrikeChangeInternal(context);
    }
  }

  /// Toggle product type (MIS/NRML)
  void toggleProduct() {
    _productType = _productType == 'I' ? 'M' : 'I';
    notifyListeners();
  }

  /// Toggle price type (MKT/LMT)
  void togglePriceType() {
    _priceType = _priceType == 'MKT' ? 'LMT' : 'MKT';

    // If switching to LMT, set price to current strike LTP (use live strikeLTP value)
    if (_priceType == 'LMT' && _selectedStrike != null) {
      _price = double.tryParse(_strikeLTP) ?? 0;
      _validatePrice();
    } else {
      // Clear price error when switching to MKT
      _priceError = null;
    }
    notifyListeners();
  }

  /// Set quantity in lots with freeze qty validation
  void setQtyLots(int qty) {
    _qtyLots = qty;
    _validateQty();
    notifyListeners();
  }

  /// Validate quantity against freeze qty limit and empty check
  void _validateQty() {
    _qtyError = null;
    if (_qtyLots <= 0) {
      _qtyError = 'Qty cannot be empty or zero';
    } else if (_freezeQty > 0 && totalQty > _freezeQty) {
      _qtyError = 'Qty exceeds freeze limit (${_freezeQty ~/ _lotSize} lots)';
    }
  }

  /// Check if qty is valid (for submit button)
  bool get isQtyValid => _qtyError == null;

  /// Set limit price with circuit level validation
  void setPrice(double newPrice) {
    _price = newPrice;
    _validatePrice();
    notifyListeners();
  }

  /// Validate price against circuit limits and zero/negative check for LMT
  void _validatePrice() {
    _priceError = null;
    if (_priceType == 'LMT') {
      if (_price <= 0) {
        _priceError = 'Price cannot be zero or negative for Limit order';
      } else if (_upperCircuit > 0 && _price > _upperCircuit) {
        _priceError = 'Price exceeds upper circuit (₹${_upperCircuit.toStringAsFixed(2)})';
      } else if (_lowerCircuit > 0 && _price < _lowerCircuit) {
        _priceError = 'Price below lower circuit (₹${_lowerCircuit.toStringAsFixed(2)})';
      } else if (_tickSize > 0) {
        final rounded = _roundToTickSize(_price);
        if ((_price - rounded).abs() > 0.001) {
          _priceError = 'Price must be multiple of tick size $_tickSize (nearest: ${rounded.toStringAsFixed(2)})';
        }
      }
    }
  }

  /// Round price to nearest tick size multiple
  double _roundToTickSize(double price) {
    if (_tickSize <= 0) return price;
    return (price / _tickSize).round() * _tickSize;
  }

  /// Check if price is valid (for submit button)
  bool get isPriceValid => _priceError == null;

  /// Update dialog position
  void updateDialogPosition(Offset position) {
    _dialogPosition = position;
    _positionInitialized = true;
  }

  bool get isPositionInitialized => _positionInitialized;

  /// Change selected symbol
  Future<void> onSymbolChange(OptionFlashSymbol symbol, BuildContext context) async {
    _selectedSymbol = symbol;

    // Unsubscribe from previous symbol's index
    unsubscribeFromIndex();

    // Reset data
    _expiryList = [];
    _optionChainData = [];
    _formattedStrikes = [];
    _selectedExpiry = '';
    _selectedStrike = null;

    notifyListeners();

    // Load symbol data
    await loadSymbolData(context);
  }

  /// Load symbol data (quotes, linked scrips, option chain)
  Future<void> loadSymbolData(BuildContext context) async {
    if (_selectedSymbol == null) return;

    _isPanelLoading = true;
    notifyListeners();

    try {
      // Fetch quote and linked scrips in parallel (they are independent)
      final quoteFuture = api.getScripQuote(_selectedSymbol!.token, _selectedSymbol!.exch);
      final linkedFuture = api.getLinkedScrip(_selectedSymbol!.token, _selectedSymbol!.exch);
      final quote = await quoteFuture;
      final linkedData = await linkedFuture;

      // Check for session expiry
      if (_isSessionExpired(quote.stat, quote.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (quote.stat == 'Ok') {
        _indexLTP = (double.tryParse(quote.lp ?? '0') ?? 0).toStringAsFixed(2);
        _indexChange = double.tryParse(quote.chng ?? '0') ?? 0;
        _indexChangePer = (double.tryParse(quote.pc ?? '0') ?? 0).toStringAsFixed(2);
      }

      // Subscribe to index for live updates
      _subscribeToIndex();

      if (linkedData.stat == "Ok" &&
          linkedData.optExp != null &&
          linkedData.optExp!.isNotEmpty) {
        // Sort expiries by date
        final sortedExpiries = [...linkedData.optExp!];
        sortedExpiries.sort((a, b) {
          final dateA = _parseExpiryDate(a.exd ?? '');
          final dateB = _parseExpiryDate(b.exd ?? '');
          return dateA.compareTo(dateB);
        });

        _expiryDataRaw = sortedExpiries;
        _expiryList = sortedExpiries.map((e) => e.exd ?? '').toList();

        if (_expiryList.isNotEmpty) {
          _selectedExpiry = _expiryList[0];
          await loadOptionChain(context);
        }
      }
    } catch (error) {
      log('[OptionFlash] Error loading symbol data: $error');
    } finally {
      _isPanelLoading = false;
      notifyListeners();
    }
  }

  DateTime _parseExpiryDate(String dateStr) {
    try {
      // Format: "15-JAN-2025" or similar
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final monthMap = {
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

  /// Change selected expiry
  Future<void> onExpiryChange(String expiry, BuildContext context) async {
    _selectedExpiry = expiry;
    notifyListeners();
    await loadOptionChain(context);
  }

  /// Load option chain data
  Future<void> loadOptionChain(BuildContext context) async {
    if (_selectedExpiry.isEmpty) return;

    _isPanelLoading = true;
    notifyListeners();

    try {
      final selectedExpiryData = _expiryDataRaw.firstWhere(
        (e) => e.exd == _selectedExpiry,
        orElse: () => OptionExp(),
      );

      if (selectedExpiryData.tsym == null) return;

      final chainData = await api.getOptionChain(
        strPrc: _indexLTP,
        tradeSym: selectedExpiryData.tsym!,
        exchange: selectedExpiryData.exch ?? 'NFO',
        context: context,
        numofStrike: '10',
      );

      // Check for session expiry
      if (chainData != null && _isSessionExpired(chainData.stat, chainData.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (chainData != null &&
          chainData.stat == 'Ok' &&
          chainData.optValue != null) {
        _optionChainData = chainData.optValue!;
        _formatStrikesForDropdown();
        await _autoSelectATM(context);

        // Subscribe to all options for live updates
        _subscribeToAllOptions();
      }
    } catch (error) {
      log('[OptionFlash] Error loading option chain: $error');
    } finally {
      _isPanelLoading = false;
      notifyListeners();
    }
  }

  /// Format strikes for dropdown display
  void _formatStrikesForDropdown() {
    final spotPrice = double.tryParse(_indexLTP) ?? 0;
    final strikes = <FormattedStrike>[];

    final sortedOptions = [..._optionChainData];
    sortedOptions.sort((a, b) =>
        (double.tryParse(a.strprc ?? '0') ?? 0)
            .compareTo(double.tryParse(b.strprc ?? '0') ?? 0));

    // Get unique sorted strike prices to compute depth
    final uniqueStrikes = sortedOptions
        .map((o) => double.tryParse(o.strprc ?? '0') ?? 0)
        .toSet()
        .toList()
      ..sort();

    // Find ATM strike index (closest to spot)
    int atmIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < uniqueStrikes.length; i++) {
      final diff = (uniqueStrikes[i] - spotPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmIndex = i;
      }
    }

    // Dynamic ATM threshold — half the gap between consecutive strikes
    final strikeGap = uniqueStrikes.length >= 2
        ? (uniqueStrikes[1] - uniqueStrikes[0]).abs()
        : 50.0;
    final atmThreshold = strikeGap / 2;

    for (var option in sortedOptions) {
      final strike = double.tryParse(option.strprc ?? '0') ?? 0;
      final diff = (strike - spotPrice).abs();
      String moneyness = '';
      bool isATM = false;

      // Find this strike's index in unique strikes to compute depth
      final strikeIndex = uniqueStrikes.indexOf(strike);
      final depth = (strikeIndex - atmIndex).abs();

      if (diff < atmThreshold) {
        moneyness = 'ATM';
        isATM = true;
      } else if (option.optt == 'CE') {
        moneyness = strike > spotPrice ? 'OTM' : 'ITM';
      } else {
        moneyness = strike < spotPrice ? 'OTM' : 'ITM';
      }

      final moneynessLabel = isATM ? moneyness : '$moneyness $depth';
      final currentLTP = double.tryParse(option.lp ?? '0') ?? 0;
      final label =
          '${option.strprc} | ${option.optt == 'CE' ? 'CALL' : 'PUT'} | $moneynessLabel | ₹${currentLTP.toStringAsFixed(2)}';

      strikes.add(FormattedStrike(
        label: label,
        option: option,
        isATM: isATM,
        strike: strike,
        optionType: option.optt ?? 'CE',
        moneyness: moneyness,
        moneynessDepth: depth,
        ltp: currentLTP,
      ));
    }

    _formattedStrikes = strikes;
  }

  /// Update LTP and moneyness in formatted strikes from option chain data (for WebSocket updates)
  void _updateFormattedStrikesLTP() {
    if (_formattedStrikes.isEmpty || _optionChainData.isEmpty) return;

    final spotPrice = double.tryParse(_indexLTP) ?? 0;
    final selectedToken = _selectedStrike?.option.token;

    // Recompute ATM index based on current spot
    final uniqueStrikes = _formattedStrikes
        .map((s) => s.strike)
        .toSet()
        .toList()
      ..sort();

    int atmIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < uniqueStrikes.length; i++) {
      final diff = (uniqueStrikes[i] - spotPrice).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmIndex = i;
      }
    }

    // Dynamic ATM threshold — half the gap between consecutive strikes
    final strikeGap = uniqueStrikes.length >= 2
        ? (uniqueStrikes[1] - uniqueStrikes[0]).abs()
        : 50.0;
    final atmThreshold = strikeGap / 2;

    for (int i = 0; i < _formattedStrikes.length; i++) {
      final strike = _formattedStrikes[i];
      final optionData = _optionChainData.firstWhere(
        (opt) => opt.token == strike.option.token,
        orElse: () => strike.option,
      );

      final newLTP = double.tryParse(optionData.lp ?? '0') ?? 0;

      // Recalculate moneyness based on current spot price
      final diff = (strike.strike - spotPrice).abs();
      String moneyness;
      bool isATM;
      if (diff < atmThreshold) {
        moneyness = 'ATM';
        isATM = true;
      } else if (strike.optionType == 'CE') {
        moneyness = strike.strike > spotPrice ? 'OTM' : 'ITM';
        isATM = false;
      } else {
        moneyness = strike.strike < spotPrice ? 'OTM' : 'ITM';
        isATM = false;
      }

      final strikeIndex = uniqueStrikes.indexOf(strike.strike);
      final depth = (strikeIndex - atmIndex).abs();

      if (newLTP != strike.ltp || moneyness != strike.moneyness || isATM != strike.isATM) {
        final moneynessLabel = isATM ? moneyness : '$moneyness $depth';
        final label =
            '${optionData.strprc} | ${strike.optionType == 'CE' ? 'CALL' : 'PUT'} | $moneynessLabel | ₹${newLTP.toStringAsFixed(2)}';

        _formattedStrikes[i] = strike.copyWith(
          ltp: newLTP,
          option: optionData,
          moneyness: moneyness,
          isATM: isATM,
          moneynessDepth: depth,
          label: label,
        );

        // Update selected strike if it matches
        if (selectedToken != null && strike.option.token == selectedToken) {
          _selectedStrike = _formattedStrikes[i];
        }
      }
    }
  }

  /// Auto select ATM strike based on selected option type
  Future<void> _autoSelectATM(BuildContext context) async {
    final filtered = _formattedStrikes.where((s) => s.optionType == _selectedOptionType).toList();
    final atmStrike = filtered.cast<FormattedStrike?>().firstWhere(
      (s) => s!.isATM,
      orElse: () {
        if (filtered.isNotEmpty) {
          return filtered[filtered.length ~/ 2];
        }
        return _formattedStrikes.isNotEmpty ? _formattedStrikes.first : null;
      },
    );

    if (atmStrike != null && atmStrike.label.isNotEmpty) {
      _selectedStrike = atmStrike;
      await _onStrikeChangeInternal(context);
    }
  }

  /// Change selected strike
  Future<void> onStrikeChange(FormattedStrike strike, BuildContext context) async {
    _selectedStrike = strike;
    await _onStrikeChangeInternal(context);
    notifyListeners();
  }

  Future<void> _onStrikeChangeInternal(BuildContext context) async {
    if (_selectedStrike == null) return;

    final option = _selectedStrike!.option;
    // Use the live LTP from FormattedStrike (updated via WebSocket), fallback to option.lp
    final liveLtp = _selectedStrike!.ltp > 0 ? _selectedStrike!.ltp : (double.tryParse(option.lp ?? '0') ?? 0);
    _strikeLTP = liveLtp.toStringAsFixed(2);
    _price = liveLtp;

    // Reset validation errors
    _qtyError = null;
    _priceError = null;

    // Fetch quote and scrip info in parallel (they are independent)
    final quoteFuture = api.getScripQuote(option.token ?? '', option.exch ?? 'NFO');
    final scripInfoFuture = api.getScripInfo(option.token ?? '', option.exch ?? 'NFO');

    try {
      final quote = await quoteFuture;

      if (_isSessionExpired(quote.stat, quote.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (quote.stat == 'Ok') {
        _lotSize = int.tryParse(quote.ls ?? '1') ?? 1;
        if (quote.lp != null) {
          final quoteLtp = double.tryParse(quote.lp!) ?? 0;
          _strikeLTP = quoteLtp.toStringAsFixed(2);
          _price = quoteLtp;
        }
        _strikeChange = double.tryParse(quote.chng ?? '0') ?? 0;
        _strikeChangePer = (double.tryParse(quote.pc ?? '0') ?? 0).toStringAsFixed(2);
      }
    } catch (error) {
      _lotSize = 1;
    }

    try {
      final scripInfo = await scripInfoFuture;

      if (_isSessionExpired(scripInfo.stat, scripInfo.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (scripInfo.stat == 'Ok') {
        _tickSize = double.tryParse(scripInfo.ti ?? '0.05') ?? 0.05;

        // Normalize freeze qty to match place_order_screen_web logic
        final rawFreezeQty = int.tryParse(scripInfo.frzqty ?? '0') ?? 0;
        if (rawFreezeQty > 1 && _lotSize > 0) {
          _freezeQty = (rawFreezeQty ~/ _lotSize) * _lotSize;
        } else {
          _freezeQty = _lotSize;
        }

        _upperCircuit = double.tryParse(scripInfo.uc ?? '0') ?? 0;
        _lowerCircuit = double.tryParse(scripInfo.lc ?? '0') ?? 0;

        _validateQty();
        _validatePrice();
      }
    } catch (error) {
      _freezeQty = 0;
      _upperCircuit = 0;
      _lowerCircuit = 0;
    }

    notifyListeners();
  }

  /// Place quick order
  Future<void> placeQuickOrder(BuildContext context) async {
    if (_selectedStrike == null) {
      _showSnackbar(context, 'Please select a strike', isError: true);
      return;
    }
    if (_priceType == 'LMT' && _price <= 0) {
      _showSnackbar(context, 'Please enter a valid price', isError: true);
      return;
    }

    // Validate qty against freeze limit
    _validateQty();
    if (!isQtyValid) {
      _showSnackbar(context, _qtyError ?? 'Invalid quantity', isError: true);
      return;
    }

    // Validate price against circuit limits
    _validatePrice();
    if (!isPriceValid) {
      _showSnackbar(context, _priceError ?? 'Invalid price', isError: true);
      return;
    }

    _orderLoading = true;
    notifyListeners();

    try {
      final option = _selectedStrike!.option;

      final orderPayload = PlaceOrderInput(
        exch: option.exch ?? 'NFO',
        tsym: option.tsym ?? '',
        qty: totalQty.toString(),
        prc: _priceType == 'MKT' ? '0' : _price.toString(),
        prd: _productType,
        trantype: _isBuy ? 'B' : 'S',
        prctype: _priceType,
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

      // Check for session expiry
      if (_isSessionExpired(result.stat, result.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (result.stat == 'Ok') {
        _orderLoading = false;
        notifyListeners();
        // Positions will auto-update via portfolio provider listener
        // when the order fills and WebSocket triggers _refreshData
        return;
      } else {
        _showSnackbar(context, result.emsg ?? 'Order failed', isError: true);
      }
    } catch (error) {
      _showSnackbar(context, 'Failed to place order', isError: true);
    } finally {
      _orderLoading = false;
      notifyListeners();
    }
  }

  /// Fetch positions
  Future<void> fetchPositions(BuildContext context) async {
    try {
      // Use portfolio provider's position data
      final portfolioProv = ref.read(portfolioProvider);
      await portfolioProv.fetchPositionBook(context, false);

      if (portfolioProv.postionBookModel != null) {
        _positionsData = portfolioProv.postionBookModel!;
        _subscribeToPositions();
        _readStrikePnL();
        notifyListeners();
      }
    } catch (error) {
      log('[OptionFlash] Error fetching positions: $error');
    }
  }

  /// Subscribe to position tokens for live P&L updates
  void _subscribeToPositions() {
    // Unsubscribe from previous positions
    unsubscribeFromPositions();

    if (_positionsData.isEmpty || _selectedSymbol == null) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKeys = <String>[];

    for (var pos in _positionsData) {
      // Only subscribe to positions matching the selected symbol
      if (_matchesSymbol(pos.tsym, _selectedSymbol!.symname) &&
          pos.exch != null &&
          pos.token != null) {
        subscriptionKeys.add('${pos.exch}|${pos.token}');
        _subscribedPositions.add({
          'exch': pos.exch!,
          'token': pos.token!,
          'tsym': pos.tsym ?? '',
        });
      }
    }

    if (subscriptionKeys.isNotEmpty) {
      websocketProv.acquireTouchline(
          'option-flash', subscriptionKeys, WidgetsBinding.instance.rootElement!);
    }
  }

  /// Unsubscribe from position tokens
  void unsubscribeFromPositions() {
    if (_subscribedPositions.isEmpty) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKeys = _subscribedPositions
        .map((pos) => '${pos['exch']}|${pos['token']}')
        .join('#');

    websocketProv.releaseTouchline(
        'option-flash', subscriptionKeys.split('#'), WidgetsBinding.instance.rootElement!);

    _subscribedPositions.clear();
  }

  /// Read P&L for selected strike from portfolio provider's already-calculated values.
  /// The portfolio provider updates position.profitNloss via updatePositionValues()
  /// on every WebSocket tick, so we just read the result — no duplicate calculation.
  void _readStrikePnL() {
    if (_selectedStrike == null || _positionsData.isEmpty) {
      _indexPnL = '0.00';
      return;
    }

    final strikeToken = _selectedStrike!.option.token;
    double totalPnL = 0;

    for (var pos in _positionsData) {
      if (pos.token == strikeToken) {
        totalPnL += double.tryParse(pos.profitNloss ?? '0') ?? 0;
      }
    }

    _indexPnL = totalPnL.toStringAsFixed(2);
  }

  /// Exit position for the currently selected strike
  Future<void> exitStrikePosition(BuildContext context) async {
    if (_selectedStrike == null || _positionsData.isEmpty) {
      _showSnackbar(context, 'No open position to exit', isError: true);
      return;
    }

    final strikeToken = _selectedStrike!.option.token;
    final position = _positionsData.cast<PositionBookModel?>().firstWhere(
      (pos) {
        final netqtyVal = int.tryParse(pos!.netqty ?? '0') ?? 0;
        return pos.token == strikeToken && netqtyVal != 0;
      },
      orElse: () => null,
    );

    if (position == null) {
      _showSnackbar(context, 'No open position to exit', isError: true);
      return;
    }

    try {
      final netqtyVal = int.tryParse(position.netqty ?? '0') ?? 0;
      final exitTransType = netqtyVal > 0 ? 'S' : 'B';
      final exitQty = netqtyVal.abs();

      final orderPayload = PlaceOrderInput(
        exch: position.exch ?? 'NFO',
        tsym: position.tsym ?? '',
        qty: exitQty.toString(),
        prc: '0',
        prd: position.prd ?? 'M',
        trantype: exitTransType,
        prctype: 'MKT',
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

      // Check for session expiry
      if (_isSessionExpired(result.stat, result.emsg)) {
        _handleSessionExpiry(context);
        return;
      }

      if (result.stat == 'Ok') {
        _showSnackbar(context, 'Exit order placed for ${position.tsym}', isError: false);
        // Positions will auto-update via portfolio provider listener
      } else {
        _showSnackbar(context, 'Exit failed: ${result.emsg}', isError: true);
        log('[OptionFlash] Exit order failed: ${position.tsym} - ${result.emsg}');
      }
    } catch (error) {
      _showSnackbar(context, 'Exit order error', isError: true);
      log('[OptionFlash] Exit order error: ${position.tsym} - $error');
    }
  }

  /// Refresh all data
  Future<void> refreshData(BuildContext context) async {
    await loadSymbolData(context);
    await fetchPositions(context);
    // _showSnackbar(context, 'Data refreshed', isError: false);
  }

  // ============== WEBSOCKET SUBSCRIPTIONS ==============

  void _subscribeToIndex() {
    if (_selectedSymbol == null) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKey = '${_selectedSymbol!.exch}|${_selectedSymbol!.token}';

    websocketProv.acquireTouchline(
        'option-flash', [subscriptionKey], WidgetsBinding.instance.rootElement!);

    _subscribedIndex = {
      'exch': _selectedSymbol!.exch,
      'token': _selectedSymbol!.token,
      'tsym': _selectedSymbol!.tsym,
    };
  }

  void unsubscribeFromIndex() {
    if (_subscribedIndex == null) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKey = '${_subscribedIndex!['exch']}|${_subscribedIndex!['token']}';

    websocketProv.releaseTouchline(
        'option-flash', [subscriptionKey], WidgetsBinding.instance.rootElement!);

    _subscribedIndex = null;
  }

  void _subscribeToAllOptions() {
    // Unsubscribe from previous options
    unsubscribeFromAllOptions();

    if (_optionChainData.isEmpty) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKeys = <String>[];

    for (var option in _optionChainData) {
      if (option.exch != null && option.token != null) {
        subscriptionKeys.add('${option.exch}|${option.token}');
        _subscribedOptions.add({
          'exch': option.exch!,
          'token': option.token!,
          'tsym': option.tsym ?? '',
        });
      }
    }

    if (subscriptionKeys.isNotEmpty) {
      websocketProv.acquireTouchline(
          'option-flash', subscriptionKeys, WidgetsBinding.instance.rootElement!);
    }
  }

  /// Refresh LTP values from current websocket data
  void _refreshLTPFromWebSocket() {
    final websocketProv = ref.read(websocketProvider);
    final socketData = websocketProv.socketDatas;

    bool hasUpdates = false;
    for (int i = 0; i < _optionChainData.length; i++) {
      final token = _optionChainData[i].token;
      if (token != null && socketData.containsKey(token)) {
        final optData = socketData[token];
        if (optData != null && optData['lp'] != null) {
          _optionChainData[i].lp = optData['lp'].toString();
          if (optData['pc'] != null) {
            _optionChainData[i].perChange = optData['pc'].toString();
          }
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      _updateFormattedStrikesLTP();
      notifyListeners();
    }
  }

  void unsubscribeFromAllOptions() {
    if (_subscribedOptions.isEmpty) return;

    final websocketProv = ref.read(websocketProvider);
    final subscriptionKeys = _subscribedOptions
        .map((opt) => '${opt['exch']}|${opt['token']}')
        .join('#');

    websocketProv.releaseTouchline(
        'option-flash', subscriptionKeys.split('#'), WidgetsBinding.instance.rootElement!);

    _subscribedOptions.clear();
  }

  /// Update prices from WebSocket data
  void updateFromWebSocket(Map<String, dynamic> socketData) {
    if (!_isVisible) return;

    // Update index LTP
    if (_selectedSymbol != null) {
      final indexData = socketData[_selectedSymbol!.token];
      if (indexData != null) {
        if (indexData['lp'] != null) {
          _indexLTP = (double.tryParse(indexData['lp'].toString()) ?? 0).toStringAsFixed(2);
        }
        if (indexData['chng'] != null) {
          _indexChange = double.tryParse(indexData['chng'].toString()) ?? 0;
        }
        if (indexData['pc'] != null) {
          _indexChangePer = (double.tryParse(indexData['pc'].toString()) ?? 0).toStringAsFixed(2);
        }
      }
    }

    // Update selected strike LTP
    if (_selectedStrike != null) {
      final strikeData = socketData[_selectedStrike!.option.token];
      if (strikeData != null) {
        if (strikeData['lp'] != null) {
          _strikeLTP = (double.tryParse(strikeData['lp'].toString()) ?? 0).toStringAsFixed(2);
        }
        if (strikeData['chng'] != null) {
          _strikeChange = double.tryParse(strikeData['chng'].toString()) ?? 0;
        }
        if (strikeData['pc'] != null) {
          _strikeChangePer = (double.tryParse(strikeData['pc'].toString()) ?? 0).toStringAsFixed(2);
        }
      }
    }

    // Update option chain data only when strike dropdown is open
    if (_isStrikeDropdownOpen) {
      bool hasUpdates = false;
      for (int i = 0; i < _optionChainData.length; i++) {
        final optData = socketData[_optionChainData[i].token];
        if (optData != null && optData['lp'] != null) {
          _optionChainData[i].lp = optData['lp'].toString();
          if (optData['pc'] != null) {
            _optionChainData[i].perChange = optData['pc'].toString();
          }
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        _updateFormattedStrikesLTP();
      }
    }

    // Recalculate P&L
    _readStrikePnL();

    // Throttled notify — limit UI rebuilds to ~4 per second
    _throttledNotify();
  }

  /// Throttle notifyListeners to avoid excessive UI rebuilds
  void _throttledNotify() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _lastNotifyTimeMs;
    if (elapsed >= _minNotifyIntervalMs) {
      _lastNotifyTimeMs = nowMs;
      _hasPendingNotify = false;
      notifyListeners();
    } else if (!_hasPendingNotify) {
      _hasPendingNotify = true;
      Future.delayed(Duration(milliseconds: _minNotifyIntervalMs - elapsed), () {
        if (_isVisible && !disposed) {
          _hasPendingNotify = false;
          _lastNotifyTimeMs = DateTime.now().millisecondsSinceEpoch;
          notifyListeners();
        }
      });
    }
  }

  void _showSnackbar(BuildContext context, String message, {required bool isError}) {
    if (isError) {
      ResponsiveSnackBar.showError(context, message);
    } else {
      ResponsiveSnackBar.showSuccess(context, message);
    }
  }

  @override
  void dispose() {
    _portfolioSubscription?.close();
    unsubscribeFromAllOptions();
    unsubscribeFromIndex();
    unsubscribeFromPositions();
    super.dispose();
  }
}

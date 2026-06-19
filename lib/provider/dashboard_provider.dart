import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mynt_plus/models/explore_model/basket_backtest_analysis_model.dart';
import 'package:mynt_plus/models/explore_model/basketcollection_model.dart';
import 'package:mynt_plus/models/mf_model/mutual_fundmodel.dart';
import 'package:mynt_plus/models/trading_personality_model.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/sharedWidget/snack_bar.dart';
import '../locator/locator.dart';
import '../locator/preference.dart';
import '../api/core/api_export.dart';
import '../models/explore_model/referral_rewards_model.dart';
import '../provider/core/default_change_notifier.dart';
import '../models/explore_model/portfolioanalisys_models.dart';

final dashboardProvider =
    ChangeNotifierProvider((ref) => DashboardProvider(ref));

class DashboardProvider extends DefaultChangeNotifier {
  final Preferences pref = locator<Preferences>();
  final ApiExporter api = locator<ApiExporter>();
  final Ref ref;

  DashboardProvider(this.ref);

  final TextEditingController _brokerageController =
      TextEditingController(text: '0.03');
  TextEditingController get brokerageController => _brokerageController;

  // Brokerage type persistence
  bool _isPercentageBrokerage = true;
  bool get isPercentageBrokerage => _isPercentageBrokerage;

  // Method to update brokerage type
  void updateBrokerageType(bool isPercentage) {
    _isPercentageBrokerage = isPercentage;
    // Also update the controller text based on type
    if (isPercentage) {
      _brokerageController.text = '0.03';
    } else {
      _brokerageController.text = '20';
    }
    notifyListeners();
  }

  // Method to get current brokerage type as string
  String get brokerageTypeText =>
      _isPercentageBrokerage ? 'Percentage' : 'Flat';

  @override
  void dispose() {
    _brokerageController.dispose();
    _portfolioSearchController.dispose();

    // Dispose of all percentage controllers
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    _percentageControllers.clear();

    super.dispose();
  }

  // Portfolio Analysis State

  PortfolioResponse? _portfolioAnalysis;
  PortfolioResponse? get portfolioAnalysis => _portfolioAnalysis;

  bool _isPortfolioLoading = false;
  bool get isPortfolioLoading => _isPortfolioLoading;

  portfolioloader(bool value) {
    _isPortfolioLoading = value;
    notifyListeners();
  }

  String? _portfolioError;

  // Portfolio getters
  String? get portfolioError => _portfolioError;

  Future getPortfolioAnalysis() async {
    try {
      portfolioloader(true);
      final portfolioAnalysis = await api.fetchPortfolioAnalysis(
          "${pref.clientId}", "${pref.clientSession}");
    if(portfolioAnalysis.message == "No data found"){
      _portfolioAnalysis = null;
      return;
    }
      _portfolioAnalysis = portfolioAnalysis;
      _portfolioError = null;
    } catch (e) {
      _portfolioError = e.toString();
      rethrow;
    } finally {
      portfolioloader(false);
      notifyListeners();
    }
  }

  clearPortfolioAnalysis() {
    _portfolioAnalysis = null;
    notifyListeners();
  }

  ReferralRewards? _referralRewards;
  ReferralRewards? get referralRewards => _referralRewards;

  bool _isReferralRewardsLoading = false;
  bool get isReferralRewardsLoading => _isReferralRewardsLoading;

  referralRewardsloder(bool value) {
    _isReferralRewardsLoading = value;
    notifyListeners();
  } 

  Future getReferralRewards() async {
    try {
      referralRewardsloder(true);
      final referralRewards = await api.fetchReferralBonus('ZC91');
      _referralRewards = referralRewards;
      notifyListeners();
    } catch (e) {
      _referralRewards = null;
      rethrow;
    } finally {
      referralRewardsloder(false);
      notifyListeners();
    }
  }

  // Portfolio Analysis Methods
  String getMonthAbbreviation(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }

  // // Update selected time period
  // void updateSelectedPeriod(String newPeriod) {
  //   selectedPeriod = newPeriod;
  //   notifyListeners();
  // }

  // Format amount for display
  String formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  // Get account type color
  Color getAccountTypeColor(String accountType) {
    switch (accountType.toLowerCase()) {
      case 'equity':
        return const Color(0xFF60A5FA); // Light blue
      case 'mutual funds':
        return const Color(0xFF3B82F6); // Medium blue
      case 'bonds':
        return const Color(0xFF1D4ED8); // Darker blue
      case 'cash':
        return const Color(0xFF1E3A8A); // Darkest blue
      case 'commodities':
        return const Color(0xFF0F172A); // Very dark blue
      default:
        // Use a blue color palette for other account types
        List<Color> blueColors = [
          const Color(0xFF60A5FA), // Light blue
          const Color(0xFF3B82F6), // Medium blue
          const Color(0xFF1D4ED8), // Darker blue
          const Color(0xFF1E3A8A), // Darkest blue
          const Color(0xFF0F172A), // Very dark blue
        ];
        return blueColors[accountType.hashCode % blueColors.length];
    }
  }

  // Get account type icon
  IconData getAccountTypeIcon(String accountType) {
    switch (accountType.toLowerCase()) {
      case 'equity':
        return Icons.trending_up;
      case 'mutual funds':
        return Icons.account_balance;
      case 'bonds':
        return Icons.security;
      case 'cash':
        return Icons.account_balance_wallet;
      case 'commodities':
        return Icons.inventory;
      default:
        return Icons.account_balance;
    }
  }

  final Map<String, Color> _sectorColorMap = {};

Color getSectorAllocationColor(String sector) {
 List<Color> uniqueColors = [
  const Color(0xFF4F46E5), // Indigo - professional
  const Color(0xFF059669), // Emerald - growth
  const Color(0xFFDC2626), // Red - energy
  const Color(0xFF7C3AED), // Purple - unique
  const Color(0xFFEA580C), // Orange - warm
  const Color(0xFF0891B2), // Cyan - tech
  const Color(0xFFCA8A04), // Amber - stable
  const Color(0xFFBE185D), // Pink - creative
  const Color(0xFF0D9488), // Teal - balance
  const Color(0xFF9333EA), // Violet - premium
  const Color(0xFF16A34A), // Green - nature
  const Color(0xFFDC2626), // Red - finance
  const Color(0xFF2563EB), // Blue - trust
  const Color(0xFF7C2D12), // Brown - industrial
  const Color(0xFF1F2937), // Gray - neutral
  const Color(0xFF059669), // Green - healthcare
];


    // If already assigned, return it
    if (_sectorColorMap.containsKey(sector)) {
      return _sectorColorMap[sector]!;
    }

    // Assign next available color
    final color = uniqueColors[_sectorColorMap.length % uniqueColors.length];
    _sectorColorMap[sector] = color;

    return color;
  }

  // Get market cap allocation color
  Color getMarketCapAllocationColor(String marketCapType) {
    switch (marketCapType.toLowerCase()) {
      case 'large cap':
        return const Color(0xFF4F46E5); // Indigo - professional and trustworthy
      case 'mid cap':
        return const Color(0xFF059669); // Emerald - growth and stability
      case 'small cap':
        return const Color(0xFFDC2626); // Red - energy and potential
      case 'others':
        return const Color(0xFF7C3AED); // Purple - unique and diverse
      default:
        return const Color(0xFF6B7280); // Gray - neutral fallback
    }
  }

  // Get market cap color
  Color getMarketCapColor(String capType) {
    final theme = ref.watch(themeProvider);
    switch (capType.toLowerCase()) {
      case 'large cap':
        return theme.isDarkMode ? colors.successDark : colors.successLight;
      case 'mid cap':
        return const Color(0xFF1976D2);
      case 'small cap':
        return const Color(0xFFFF7043);
      default:
        return const Color(0xFF6C7B93);
    }
  }

  // Get sector color

  // Portfolio Search State Management
  bool _showPortfolioSearch = false;
  bool get showPortfolioSearch => _showPortfolioSearch;

  final TextEditingController _portfolioSearchController =
      TextEditingController();
  TextEditingController get portfolioSearchController =>
      _portfolioSearchController;

  List<TopStocks> _portfolioSearchItems = [];
  List<TopStocks> get portfolioSearchItems => _portfolioSearchItems;

  // Show/hide portfolio search
  showPortfolioAnalysisSearch(bool value) {
    _showPortfolioSearch = value;
    if (!_showPortfolioSearch) {
      _portfolioSearchItems = [];
    }
    _portfolioSearchController.clear();
    notifyListeners();
  }

  // Clear portfolio search
  clearPortfolioSearch() {
    _portfolioSearchController.clear();
    _portfolioSearchItems = [];
    // Don't automatically hide search - let the UI handle it
    notifyListeners();
  }

  // Search portfolio holdings
  void searchPortfolioHoldings(String query, List<TopStocks> allHoldings) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _portfolioSearchItems = [];
    } else {
      _portfolioSearchItems = allHoldings.where((holding) {
        final name = holding.name?.toLowerCase() ?? '';
        final tsym = holding.tsym?.toLowerCase() ?? '';
        final queryLower = trimmedQuery.toLowerCase();

        return name.contains(queryLower) || tsym.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  // Portfolio Filter State Management
  bool _showAll = true; // Default: show all data
  bool get showAll => _showAll;

  // Quick PnL sign filter for Top Gainers / Top Losers
  // Values: 'all' | 'gainers' | 'losers'
  String _selectedPnLSignFilter = 'all';
  String get selectedPnLSignFilter => _selectedPnLSignFilter;
  void setPnLSignFilter(String value) {
    if (value == _selectedPnLSignFilter) {
      // Toggle off when pressing the same filter again
      _selectedPnLSignFilter = 'all';
    } else {
      _selectedPnLSignFilter = value;
    }
    notifyListeners();
  }

  Set<String> _selectedAccountTypes = {};
  Set<String> get selectedAccountTypes => _selectedAccountTypes;

  Set<String> _selectedMarketCaps = {};
  Set<String> get selectedMarketCaps => _selectedMarketCaps;

  Set<String> _selectedSectors = {};
  Set<String> get selectedSectors => _selectedSectors;

  // Update filter states
  void updateShowAll(bool value) {
    _showAll = value;
    if (_showAll) {
      _selectedAccountTypes.clear();
      _selectedMarketCaps.clear();
      _selectedSectors.clear();
    }
    notifyListeners();
  }

  void updateSelectedAccountTypes(Set<String> accountTypes) {
    _selectedAccountTypes = accountTypes;
    if (_selectedAccountTypes.isNotEmpty ||
        _selectedMarketCaps.isNotEmpty ||
        _selectedSectors.isNotEmpty) {
      _showAll = false;
    } else {
      _showAll = true;
    }
    notifyListeners();
  }

  void updateSelectedMarketCaps(Set<String> marketCaps) {
    _selectedMarketCaps = marketCaps;
    if (_selectedAccountTypes.isNotEmpty ||
        _selectedMarketCaps.isNotEmpty ||
        _selectedSectors.isNotEmpty) {
      _showAll = false;
    } else {
      _showAll = true;
    }
    notifyListeners();
  }

  void updateSelectedSectors(Set<String> sectors) {
    _selectedSectors = sectors;
    if (_selectedAccountTypes.isNotEmpty ||
        _selectedMarketCaps.isNotEmpty ||
        _selectedSectors.isNotEmpty) {
      _showAll = false;
    } else {
      _showAll = true;
    }
    notifyListeners();
  }

  // Clear all filters
  void clearAllFilters() {
    _showAll = true;
    _selectedAccountTypes.clear();
    _selectedMarketCaps.clear();
    _selectedSectors.clear();
    _selectedPnLSignFilter = 'all';
    notifyListeners();
  }

  // Apply all filters at once (used by filter dialog)
  void applyFilters({
    required bool showAll,
    required Set<String> accountTypes,
    required Set<String> marketCaps,
    required Set<String> sectors,
  }) {
    _showAll = showAll;
    _selectedAccountTypes = Set<String>.from(accountTypes);
    _selectedMarketCaps = Set<String>.from(marketCaps);
    _selectedSectors = Set<String>.from(sectors);

    // Auto-set showAll if no filters are selected
    if (_selectedAccountTypes.isEmpty &&
        _selectedMarketCaps.isEmpty &&
        _selectedSectors.isEmpty) {
      _showAll = true;
    }
    notifyListeners();
  }

  // Get filtered holdings based on selected filters
  List<TopStocks> getFilteredHoldings(List<TopStocks> allHoldings) {
    if (_showAll ||
        (_selectedAccountTypes.isEmpty &&
            _selectedMarketCaps.isEmpty &&
            _selectedSectors.isEmpty)) {
      return allHoldings; // Show all when "All" is selected or no filters applied
    }

    // Build a quick lookup from tsym -> sector from fundamentals
    final fundamentals = _portfolioAnalysis?.fundamentals ?? [];
    final Map<String, String> tsymToSector = {
      for (final f in fundamentals)
        if ((f.tsym ?? '').isNotEmpty && (f.sector ?? '').isNotEmpty)
          f.tsym!: f.sector!
    };

    return allHoldings.where((holding) {
      // Filter by category (account type) with normalization so
      // 'Gold' matches categories like 'Gold_Bond', 'Gold ETF', etc.
      final holdingCategoryNorm = _normalize(holding.category);
      bool matchesAccountType = _selectedAccountTypes.isEmpty ||
          _selectedAccountTypes.any(
            (seg) => holdingCategoryNorm.contains(_normalize(seg)),
          );

      // Filter by market cap type
      bool matchesMarketCap = _selectedMarketCaps.isEmpty ||
          _selectedMarketCaps.contains(holding.marketCapType);

      // Sector filtering: infer sector via fundamentals using tsym
      final holdingSector = tsymToSector[holding.tsym ?? ''];
      final holdingSectorNorm = _normalize(holdingSector);
      bool matchesSector = _selectedSectors.isEmpty ||
          _selectedSectors.any(
            (s) => holdingSectorNorm.contains(_normalize(s)),
          );

      return matchesAccountType && matchesMarketCap && matchesSector;
    }).toList();
  }

  // Normalizes strings for robust comparisons (case-insensitive, ignore spaces/underscores/hyphens)
  String _normalize(String? input) {
    return (input ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Helper methods for filter state checking
  bool isAccountTypeSelected(String accountType) {
    return _selectedAccountTypes.contains(accountType);
  }

  bool isMarketCapSelected(String marketCap) {
    return _selectedMarketCaps.contains(marketCap);
  }

  bool isSectorSelected(String sector) {
    return _selectedSectors.contains(sector);
  }

  // Toggle filter methods
  void toggleAccountType(String accountType) {
    if (_selectedAccountTypes.contains(accountType)) {
      _selectedAccountTypes.remove(accountType);
    } else {
      _selectedAccountTypes.add(accountType);
    }
    _updateShowAllState();
    notifyListeners();
  }

  void toggleMarketCap(String marketCap) {
    if (_selectedMarketCaps.contains(marketCap)) {
      _selectedMarketCaps.remove(marketCap);
    } else {
      _selectedMarketCaps.add(marketCap);
    }
    _updateShowAllState();
    notifyListeners();
  }

  void toggleSector(String sector) {
    if (_selectedSectors.contains(sector)) {
      _selectedSectors.remove(sector);
    } else {
      _selectedSectors.add(sector);
    }
    _updateShowAllState();
    notifyListeners();
  }

  // Remove specific filter
  void removeFilter(String label, String filterType) {
    switch (filterType) {
      case 'accountType':
        _selectedAccountTypes.remove(label);
        break;
      case 'marketCap':
        _selectedMarketCaps.remove(label);
        break;
      case 'sector':
        _selectedSectors.remove(label);
        break;
    }
    _updateShowAllState();
    notifyListeners();
  }

  // Apply portfolio filters (placeholder method for screen compatibility)
  void applyPortfolioFilters() {
    // This method is called from the screen but doesn't need to do anything
    // as the filtering is handled automatically through the getFilteredHoldings method
    notifyListeners();
  }

  // Check if a holding passes the current filters
  bool isHoldingFiltered(TopStocks holding) {
    if (_showAll ||
        (_selectedAccountTypes.isEmpty &&
            _selectedMarketCaps.isEmpty &&
            _selectedSectors.isEmpty)) {
      return true; // Show all when no filters applied
    }

    // Build a quick lookup from tsym -> sector from fundamentals
    final fundamentals = _portfolioAnalysis?.fundamentals ?? [];
    final Map<String, String> tsymToSector = {
      for (final f in fundamentals)
        if ((f.tsym ?? '').isNotEmpty && (f.sector ?? '').isNotEmpty)
          f.tsym!: f.sector!
    };

    // Filter by category (account type) with normalization
    final holdingCategoryNorm = _normalize(holding.category);
    bool matchesAccountType = _selectedAccountTypes.isEmpty ||
        _selectedAccountTypes.any(
          (seg) => holdingCategoryNorm.contains(_normalize(seg)),
        );

    // Filter by market cap type
    bool matchesMarketCap = _selectedMarketCaps.isEmpty ||
        _selectedMarketCaps.contains(holding.marketCapType);

    // Sector filtering: infer sector via fundamentals using tsym
    final holdingSector = tsymToSector[holding.tsym ?? ''];
    final holdingSectorNorm = _normalize(holdingSector);
    bool matchesSector = _selectedSectors.isEmpty ||
        _selectedSectors.any(
          (s) => holdingSectorNorm.contains(_normalize(s)),
        );

    return matchesAccountType && matchesMarketCap && matchesSector;
  }

  // Helper method to update showAll state based on other filters
  void _updateShowAllState() {
    if (_selectedAccountTypes.isEmpty &&
        _selectedMarketCaps.isEmpty &&
        _selectedSectors.isEmpty) {
      _showAll = true;
    } else {
      _showAll = false;
    }
  }

  // Brokerage Calculator Methods
  Map<String, double> calculateBrokerageCharges({
    required int segment,
    required int subSegment,
    required double quantity,
    required double buyPrice,
    required double sellPrice,
  }) {
    final brokerageRate = double.tryParse(_brokerageController.text) ?? 0;
    final turnover = (buyPrice + sellPrice) * quantity;

    return _getChargesForSegment(
      segment,
      subSegment,
      quantity,
      buyPrice,
      sellPrice,
      turnover,
      brokerageRate,
    );
  }

  Map<String, double> _getChargesForSegment(
      int segment,
      int subSegment,
      double quantity,
      double buyPrice,
      double sellPrice,
      double turnover,
      double brokerageRate) {
    double brokerage = _isPercentageBrokerage
        ? (turnover * brokerageRate) / 100
        : brokerageRate;

    double stt = 0, ctt = 0, transactionCharges = 0, stampDuty = 0;

    switch (segment) {
      case 0: // Equity
        if (subSegment == 0) {
          // Intraday
          stt = (sellPrice * quantity * 0.025) / 100;
          transactionCharges = (turnover * 0.00297) / 100;
          stampDuty = (buyPrice * quantity * 0.003) / 100;
        } else {
          // Delivery
          stt = (turnover * 0.1) / 100;
          transactionCharges = (turnover * 0.00297) / 100;
          stampDuty = (buyPrice * quantity * 0.015) / 100;
        }
        break;
      case 1: // F&O
        if (subSegment == 0) {
          // Futures
          stt = (sellPrice * quantity * 0.02) / 100;
          transactionCharges = (turnover * 0.00173) / 100;
          stampDuty = (buyPrice * quantity * 0.002) / 100;
        } else {
          // Options
          stt = (sellPrice * quantity * 0.1) / 100;
          transactionCharges = (turnover * 0.035) / 100;
          stampDuty = (buyPrice * quantity * 0.003) / 100;
        }
        break;
      case 2: // Currency
        transactionCharges = subSegment == 0
            ? (turnover * 0.00035) / 100
            : (turnover * 0.03110) / 100;
        stampDuty = (buyPrice * quantity * 0.0001) / 100;
        break;
      case 3: // Commodity
        if (subSegment == 0) {
          // Non-Agri
          ctt = (sellPrice * quantity * 0.01) / 100;
          transactionCharges = (turnover * 0.0021) / 100;
          stampDuty = (buyPrice * quantity * 0.002) / 100;
        } else if (subSegment == 1) {
          // Agri
          transactionCharges = (turnover * 0.0021) / 100;
          stampDuty = (buyPrice * quantity * 0.003) / 100;
        } else {
          // Options
          ctt = (sellPrice * quantity * 0.041) / 100;
          transactionCharges = (turnover * 0.04180) / 100;
          stampDuty = (buyPrice * quantity * 0.003) / 100;
        }
        break;
    }

    double sebiCharges = (turnover * 0.0001) / 100;
    double gst = ((brokerage + transactionCharges + sebiCharges) * 18) / 100;
    double totalTaxes =
        brokerage + stt + ctt + transactionCharges + sebiCharges + gst;
    double totalCharges = totalTaxes + stampDuty;
    double netProfit =
        (sellPrice * quantity) - (buyPrice * quantity) - totalCharges;
    double breakEven = totalCharges / quantity;

    return {
      'turnover': turnover,
      'brokerage': brokerage,
      'stt': stt,
      'ctt': ctt,
      'transactionCharges': transactionCharges,
      'sebiCharges': sebiCharges,
      'gst': gst,
      'stampDuty': stampDuty,
      'totalCharges': totalCharges,
      'netProfit': netProfit,
      'breakEven': breakEven,
    };
  }

// MF Basket Collection

  final TextEditingController _investmentController = TextEditingController(text: '100000');
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _strategyNameController = TextEditingController();
  TextEditingController get investmentController => _investmentController;
  TextEditingController get searchController => _searchController;
  TextEditingController get strategyNameController => _strategyNameController;
  // Strategy State basket
  final List<FundListModel> _selectedFunds = [];
  List<FundListModel> get selectedFunds => _selectedFunds;

  // Trading Personality Selection
  TradingPersonalityType _selectedPersonality = TradingPersonalityType.aurora;
  TradingPersonalityType get selectedPersonality => _selectedPersonality;

  void updateSelectedPersonality(TradingPersonalityType personality) {
    _selectedPersonality = personality;
    notifyListeners();
  }

  // Weighting scheme
  String _weightingScheme = 'Equi-Weighted';
  String get weightingScheme => _weightingScheme;

  void updateWeightingScheme(String scheme) {
    _weightingScheme = scheme;
    notifyListeners();
  }

  // Strategy Name Error Management
  String? _strategyNameError;
  String? get strategyNameError => _strategyNameError;
  
  void setStrategyNameError(String? error) {
    _strategyNameError = error;
    notifyListeners();
  }
  
  void clearStrategyNameError() {
    _strategyNameError = null;
    notifyListeners();
  }

  // Pending strategy name (set before first fund is added, used to create strategy on first add)
  String _pendingStrategyName = '';
  String get pendingStrategyName => _pendingStrategyName;

  void setPendingStrategyName(String name) {
    _pendingStrategyName = name;
    notifyListeners();
  }

  bool _isAutoSaving = false;
  bool get isAutoSaving => _isAutoSaving;
  bool _pendingAutoSave = false;

  // Saved Strategies
  SavedStrategyModel? _savedStrategies;
  SavedStrategyModel? get savedStrategies => _savedStrategies;

  // Edit mode tracking
  SavedStrategyModel? _editingStrategy;
  SavedStrategyModel? get editingStrategy => _editingStrategy;
  bool get isEditingMode => _editingStrategy != null;

  // Text controllers for percentage input fields
  final Map<String, TextEditingController> _percentageControllers = {};
  Map<String, TextEditingController> get percentageControllers {
    _initializeControllers();
    return _percentageControllers;
  }

  // Initialize controllers for existing funds
  void _initializeControllers() {
    for (final fund in _selectedFunds) {
      if (!_percentageControllers.containsKey(fund.name)) {
        _percentageControllers[fund.name] = TextEditingController(
          text: fund.percentage.round().toString(),
        );
      }
    }
  }

  String _selectedFilter = 'All';
  String get selectedFilter => _selectedFilter;

  String _selectedInvestmentType = 'One-time';
  String get selectedInvestmentType => _selectedInvestmentType;

  String _selectedDuration = '3Y';
  String get selectedDuration => _selectedDuration;

  String _selectedStrategyType = 'Buy and Hold';
  String get selectedStrategyType => _selectedStrategyType;

  bool _isStrategyLoading = false;
  bool get isStrategyLoading => _isStrategyLoading;

  String? _strategyError;
  String? get strategyError => _strategyError;

  // Loading state management
  strategyLoader(bool value) {
    _isStrategyLoading = value;
    notifyListeners();
  }

  Future<void> saveStrategy(String strategyName, BuildContext context) async {
    await createStrategy(strategyName, context);
  }

  Future<SavedStrategyModel> fetchbasketlist() async {
    try {
      strategyLoader(true);
      final responese = await api.fetchbasketlist();
      _savedStrategies = responese;
      return responese;
    } catch (e) {
      rethrow;
    } finally {
      strategyLoader(false);
      notifyListeners();
    }
  }

  Future<void> updateStrategy(BuildContext context) async {
    if (_editingStrategy == null || _selectedFunds.isEmpty ) 
    {
      error(context, "Please add funds to the strategy");
      return;
    }

    try {
      strategyLoader(true);

      final uuid = _editingStrategy?.data?.firstOrNull?.uuid ?? '';
      final schemaValues = _convertFundsToSchemaValues(_selectedFunds);

      await api.updatebasketsStrategy(
        uuid: uuid,
        yearIn: _getYearInFromDuration(_selectedDuration),
        schemeValues: schemaValues,
        basketName: strategyNameController.text ?? '',
        investmentAmount: double.tryParse(_investmentController.text) ?? 0.0,
        invesmentdetail: 'Updated Strategy|personality:${_selectedPersonality.name}|weighting:$_weightingScheme',
      );

      // Update _editingStrategy in-place — no need to re-fetch all strategies
      _editingStrategy = SavedStrategyModel(data: [
        Data(
          uuid: uuid,
          basketName: strategyNameController.text,
          investAmount: double.tryParse(_investmentController.text) ?? 0.0,
          years: _getYearInFromDuration(_selectedDuration),
          schemaValues: _selectedFunds.map((f) => SchemaValues(
            name: f.name,
            schemaName: f.schemeName,
            schemeType: f.type,
            isin: f.isin,
            percentage: f.percentage.round(),
            schemeCode: f.schemeCode,
            minimumPurchaseAmount: f.minimumPurchaseAmount,
          )).toList(),
        )
      ]);
      _strategyError = null;
    } catch (e) {
      // error(context, "Failed to update strategy. Please try again.");
      // _strategyError = e.toString();
      rethrow;
    } finally {
      strategyLoader(false);
      notifyListeners();
    }
  }

  Future<void> createStrategy(String basketName, BuildContext context) async {
    if (_selectedFunds.isEmpty || basketName.isEmpty) 
    {
      error(context, "Please add funds to the strategy");
      return;
    }

    try {
      strategyLoader(true);

      final schemaValues = _convertFundsToSchemaValues(_selectedFunds);

      await api.createbasketsStrategy(
        yearIn: _getYearInFromDuration(_selectedDuration),
        schemeValues: schemaValues,
        basketName: basketName,
        investmentAmount: double.tryParse(_investmentController.text) ?? 0.0,
        invesmentdetail: 'Created Strategy|personality:${_selectedPersonality.name}|weighting:$_weightingScheme',
      );

      await fetchbasketlist();

      // Set editing mode to the newly created strategy
      if (_savedStrategies != null) {
        final match = _savedStrategies!.data?.where(
            (s) => s.basketName?.toLowerCase() == basketName.toLowerCase());
        if (match != null && match.isNotEmpty) {
          _editingStrategy = SavedStrategyModel(data: [match.first]);
          strategyNameController.text = basketName;
        }
      }
      _strategyError = null;
    } catch (e) {
      rethrow;
    } finally {
      strategyLoader(false);
      notifyListeners();
    }
  }

  /// Called from fund search screen on each add/remove.
  /// Creates strategy on first fund add, updates on subsequent changes.
  Future<void> autoSaveFundChange(BuildContext context) async {
    if (_selectedFunds.isEmpty) return;
    if (_isAutoSaving) {
      _pendingAutoSave = true;
      return;
    }
    _isAutoSaving = true;
    notifyListeners();
    try {
      if (_editingStrategy == null && _pendingStrategyName.isNotEmpty) {
        await createStrategy(_pendingStrategyName, context);
      } else if (_editingStrategy != null) {
        await updateStrategy(context);
      }
    } catch (e) {
    } finally {
      _isAutoSaving = false;
      final needsAnotherSave = _pendingAutoSave;
      _pendingAutoSave = false;
      notifyListeners();
      if (needsAnotherSave && _selectedFunds.isNotEmpty) {
        await autoSaveFundChange(context);
      }
    }
  }

  List<Map<String, dynamic>> _convertFundsToSchemaValues(
      List<FundListModel> funds) {
    for (final fund in funds) {
    }
    return funds
        .map((fund) => {
              'name': fund.name,
              'schema_name': fund.schemeName,
              'scheme_type': _normalizeSchemeType(fund.type),
              'percentage': fund.percentage.round(),
              'isin': fund.isin ?? '',
              'aMCCode': fund.aMCCode ?? '',
              'scheme_code': fund.schemeCode ?? '',
              'minimum_purchase_amount': fund.minimumPurchaseAmount,
            })
        .toList();
  }

  /// Save type as-is from the API — no hardcoded mapping
  String _normalizeSchemeType(String type) {
    final trimmed = type.trim();
    return trimmed.isNotEmpty ? trimmed : 'Equity';
  }

  int _getYearInFromDuration(String duration) {
    switch (duration) {
      case '1Y':
        return 1;
      case '3Y':
        return 3;
      case '5Y':
        return 5;
      case '10Y':
        return 10;
      case 'Custom':
        return 3; // Default to 3 years for custom
      default:
        return 3;
    }
  }

  Future<void> deleteStrategy(String strategyId, BuildContext context) async {
    if (_isAutoSaving) {
      warningMessage(context, "Please wait, saving in progress...");
      return;
    }
    try {
      strategyLoader(true);
      final response = await api.deletebasketsStrategy(strategyId);
      if (response.statusCode == 200) {
        successMessage(context, "Strategy deleted successfully");
        await fetchbasketlist();
      } else {
        warningMessage(context, "Strategy deletion failed");
      }
      _editingStrategy = null;
      _strategyError = null;
      notifyListeners();
    } catch (e) {
    } finally {
      strategyLoader(false);
    }
  }

  Future<void> loadStrategy(Data strategyData) async {
    clearStrategy();

    _editingStrategy = SavedStrategyModel(
      msg: "Loading strategy",
      data: [strategyData],
    );

    // Convert schema values to FundListModel
    _selectedFunds.clear();
    if (strategyData.schemaValues != null) {
      for (final schema in strategyData.schemaValues!) {
        final fund = FundListModel(
          name: schema.name ?? '',
          schemeName: schema.schemaName ?? '',
          type: schema.schemeType ?? '',
          fiveYearCAGR: 0.0,
          threeYearCAGR: 0.0,
          aum: schema.aum?.toDouble() ?? 0.0,
          sharpe: 0.0,
          percentage: schema.percentage?.toDouble() ?? 0.0,
          isin: schema.isin ?? '',
          aMCCode: schema.aMCCode ?? '',
          schemeCode: schema.schemeCode,
          minimumPurchaseAmount: schema.minimumPurchaseAmount ?? 100.0,
        );
        _selectedFunds.add(fund);
      }
    }
    _strategyNameController.text = strategyData.basketName ?? '';
    _investmentController.text = strategyData.investAmount?.toString() ?? '0';

    // Load trading personality and weighting scheme from investment details
    _selectedPersonality = getPersonalityFromInvestmentDetails(strategyData.investmentDetails);
    _weightingScheme = _getWeightingFromInvestmentDetails(strategyData.investmentDetails);

    if (strategyData.years != null) {
      if (strategyData.years! <= 1) {
        _selectedDuration = '1Y';
      } else if (strategyData.years! <= 3) {
        _selectedDuration = '3Y';
      } else if (strategyData.years! <= 5) {
        _selectedDuration = '5Y';
      } else {
        _selectedDuration = '10Y';
      }
    }

    _initializeControllers();

    // Enrich funds with all data (NAV, AUM, CAGR, min purchase) in a single API call
    await _enrichFundsByIsins();

    notifyListeners();
  }

  /// Enrich all selected funds in a single API call using get_schemes_by_isins
  Future<void> enrichFundsByIsins() => _enrichFundsByIsins();

  Future<void> _enrichFundsByIsins() async {
    final isins = _selectedFunds
        .where((f) => f.isin != null && f.isin!.isNotEmpty)
        .map((f) => f.isin!)
        .toList();
    if (isins.isEmpty) return;

    _isFetchingNav = true;
    notifyListeners();

    try {
      final schemes = await api.getSchemesByIsins(isins);

      // Build a lookup map by ISIN for O(1) matching
      final schemeMap = <String, Map<String, dynamic>>{};
      for (final scheme in schemes) {
        final isin = scheme['ISIN']?.toString() ?? '';
        if (isin.isNotEmpty) schemeMap[isin] = scheme;
      }

      for (int i = 0; i < _selectedFunds.length; i++) {
        final fund = _selectedFunds[i];
        final scheme = schemeMap[fund.isin];
        if (scheme == null) continue;

        _selectedFunds[i] = FundListModel(
          name: fund.name,
          schemeName: scheme['schemename']?.toString() ?? fund.schemeName,
          type: fund.type,
          oneYearCAGR: double.tryParse(scheme['1Year']?.toString() ?? '0') ?? fund.oneYearCAGR,
          fiveYearCAGR: double.tryParse(scheme['5Year']?.toString() ?? '0') ?? fund.fiveYearCAGR,
          threeYearCAGR: double.tryParse(scheme['3Year']?.toString() ?? '0') ?? fund.threeYearCAGR,
          aum: double.tryParse(scheme['AUM']?.toString() ?? '0') ?? fund.aum,
          sharpe: fund.sharpe,
          aMCCode: scheme['AMC_Code']?.toString() ?? fund.aMCCode,
          isin: fund.isin,
          schemeCode: scheme['Scheme_Code']?.toString() ?? fund.schemeCode,
          minimumPurchaseAmount: double.tryParse(scheme['Minimum_Purchase_Amount']?.toString() ?? '100') ?? fund.minimumPurchaseAmount,
          nav: (scheme['Cur_Nav'] is num) ? (scheme['Cur_Nav'] as num).toDouble() : (double.tryParse(scheme['Cur_Nav']?.toString() ?? '0') ?? fund.nav),
          percentage: fund.percentage,
          isLocked: fund.isLocked,
        );
      }

      _updateAllControllerValues();
    } catch (e) {
      // Fallback: try old individual calls if bulk API fails
      await _enrichFundsWithCAGRFallback();
    }

    _isFetchingNav = false;
    // Recalculate allocations if amount is already entered
    final amount = double.tryParse(_basketInvestAmountController.text);
    if (amount != null && amount > 0) {
      calculateBasketAllocations(amount);
    }
    notifyListeners();
  }

  /// Fallback: enrich funds individually if bulk API fails
  Future<void> _enrichFundsWithCAGRFallback() async {
    try {
      for (int i = 0; i < _selectedFunds.length; i++) {
        final fund = _selectedFunds[i];
        if (fund.fiveYearCAGR > 0 && fund.threeYearCAGR > 0 && fund.nav > 0) continue;

        final searchResult = await api.getSearchMf(fund.name);
        final items = searchResult.data ?? [];

        final match = items.where((item) => item.iSIN == fund.isin).firstOrNull;
        if (match != null) {
          _selectedFunds[i] = FundListModel(
            name: fund.name,
            schemeName: fund.schemeName,
            type: fund.type,
            oneYearCAGR: double.tryParse(match.oneYearData ?? "0") ?? 0.0,
            fiveYearCAGR: double.tryParse(match.fIVEYEARDATA ?? "0") ?? 0.0,
            threeYearCAGR: double.tryParse(match.tHREEYEARDATA ?? "0") ?? 0.0,
            aum: fund.aum > 0 ? fund.aum : (double.tryParse(match.aUM ?? "0") ?? 0.0),
            sharpe: fund.sharpe,
            aMCCode: fund.aMCCode,
            isin: fund.isin,
            schemeCode: fund.schemeCode,
            minimumPurchaseAmount: fund.minimumPurchaseAmount,
            nav: fund.nav > 0 ? fund.nav : (double.tryParse(match.nETASSETVALUE ?? "0") ?? 0.0),
            percentage: fund.percentage,
            isLocked: fund.isLocked,
          );
        }
      }
    } catch (e) {
    }
  }

  void addFundToStrategy(FundListModel fund) {
    if (!_selectedFunds.any((f) => f.name == fund.name)) {
      final newFund = FundListModel(
        name: fund.name,
        schemeName: fund.schemeName,
        type: fund.type,
        oneYearCAGR: fund.oneYearCAGR,
        fiveYearCAGR: fund.fiveYearCAGR,
        threeYearCAGR: fund.threeYearCAGR,
        aum: fund.aum,
        sharpe: fund.sharpe,
        aMCCode: fund.aMCCode,
        isin: fund.isin,
        schemeCode: fund.schemeCode,
        minimumPurchaseAmount: fund.minimumPurchaseAmount,
        nav: fund.nav,
      );
      _selectedFunds.add(newFund);

      _percentageControllers[newFund.name] = TextEditingController(
        text: newFund.percentage.round().toString(),
      );

      _redistributePercentages();
      _updateAllControllerValues();
      final amount = double.tryParse(_basketInvestAmountController.text) ?? 100000;
      calculateBasketAllocations(amount > 0 ? amount : 100000);
      notifyListeners();
    }
  }

  void removeFundFromStrategy(FundListModel fund) {
    _selectedFunds.removeWhere((f) => f.name == fund.name);

    _percentageControllers.remove(fund.name)?.dispose();

    _redistributePercentages();
    _updateAllControllerValues();
    final amount = double.tryParse(_basketInvestAmountController.text) ?? 100000;
    calculateBasketAllocations(amount > 0 ? amount : 100000);
    notifyListeners();
  }

  void toggleFundLock(FundListModel fund, BuildContext context) {
    final index = _selectedFunds.indexWhere((f) => f.name == fund.name);
    if (index != -1) {
      // Check if trying to lock and there's only one fund
      if (!_selectedFunds[index].isLocked && _selectedFunds.length == 1) {
        error(context, "You need at least 2 funds to lock percentages");
        return;
      }
      
      // Check if trying to lock and all other funds are already locked
      if (!_selectedFunds[index].isLocked) {
        final lockedCount = _selectedFunds.where((f) => f.isLocked).length;
        if (lockedCount >= _selectedFunds.length - 1) {
          error(context, "Cannot lock all funds");
         
          return;
        }
      }
      
      _selectedFunds[index].isLocked = !_selectedFunds[index].isLocked;
      notifyListeners();
    }
  }

  /// Returns true if the user is allowed to change [fund]'s weight in the
  /// current strategy. When every other fund is locked, redistribution has
  /// no target and the total would drift away from 100 — block at the call
  /// site instead.
  bool canChangeWeightOf(FundListModel fund) {
    final index = _selectedFunds.indexWhere((f) => f.name == fund.name);
    if (index == -1) return false;
    if (_selectedFunds.length <= 1) return true;
    for (int i = 0; i < _selectedFunds.length; i++) {
      if (i != index && !_selectedFunds[i].isLocked) return true;
    }
    return false;
  }

  void updateFundPercentage(FundListModel fund, double percentage) {
    final index = _selectedFunds.indexWhere((f) => f.name == fund.name);
    if (index != -1) {
      // Safety guard: if every other fund is locked, redistribution can't
      // bring the total back to 100. Reject silently — the UI calls
      // [canChangeWeightOf] beforehand and surfaces a toast.
      if (!canChangeWeightOf(fund)) return;
      final roundedPercentage = percentage.round().clamp(0, 100).toDouble();
      _selectedFunds[index].percentage = roundedPercentage;
      // Do NOT set controller.text here — _autoRedistributePercentages will
      // call _updateAllControllerValues, which only updates when text changes,
      // preserving the cursor for the field currently being typed in.
      _autoRedistributePercentages(index);
      // Recalculate per-fund allocations so Amount/Units/errors update live
      final amount = double.tryParse(_basketInvestAmountController.text);
      if (amount != null && amount > 0) {
        calculateBasketAllocations(amount);
      }
      notifyListeners();
    }
  }

  void _autoRedistributePercentages(int changedIndex) {
    if (_selectedFunds.length <= 1) return;

    final changedFund = _selectedFunds[changedIndex];
    
    // Get locked funds total percentage (excluding the changed fund if it's locked)
    double lockedPercentage = 0.0;
    for (int i = 0; i < _selectedFunds.length; i++) {
      if (i != changedIndex && _selectedFunds[i].isLocked) {
        lockedPercentage += _selectedFunds[i].percentage;
      }
    }

    final remainingPercentage = 100.0 - changedFund.percentage - lockedPercentage;

    // Get unlocked funds (excluding the changed fund)
    List<int> unlockedIndices = [];
    for (int i = 0; i < _selectedFunds.length; i++) {
      if (i != changedIndex && !_selectedFunds[i].isLocked) {
        unlockedIndices.add(i);
      }
    }

    if (remainingPercentage <= 0) {
      // Set all unlocked funds to 0
      for (int i in unlockedIndices) {
        _selectedFunds[i].percentage = 0.0;
      }
      _updateAllControllerValues();
      return;
    }

    if (unlockedIndices.isEmpty) {
      _updateAllControllerValues();
      return;
    }

    final equalPercentage = remainingPercentage / unlockedIndices.length;

    for (int i in unlockedIndices) {
      _selectedFunds[i].percentage = equalPercentage.round().toDouble();
    }

    // Handle rounding differences
    final currentTotal =
        _selectedFunds.fold(0.0, (sum, fund) => sum + fund.percentage);
    final difference = 100.0 - currentTotal;

    if (difference != 0 && unlockedIndices.isNotEmpty) {
      int maxIndex = unlockedIndices.first;
      double maxPercentage = _selectedFunds[maxIndex].percentage;
      
      for (int i in unlockedIndices) {
        if (_selectedFunds[i].percentage > maxPercentage) {
          maxIndex = i;
          maxPercentage = _selectedFunds[i].percentage;
        }
      }

      _selectedFunds[maxIndex].percentage += difference;
      _selectedFunds[maxIndex].percentage =
          _selectedFunds[maxIndex].percentage.clamp(0, 100);
    }
    _updateAllControllerValues();
  }

  void _updateAllControllerValues() {
    for (final fund in _selectedFunds) {
      final controller = _percentageControllers[fund.name];
      if (controller != null) {
        final newText = fund.percentage.round().toString();
        // Only update if the text actually changed — this preserves the cursor
        // position for whichever field the user is currently editing.
        if (controller.text != newText) {
          controller.text = newText;
        }
      }
    }
  }

  /// Public method to sync controllers after external weight changes
  void updateAllControllers() {
    _updateAllControllerValues();
    // Recalculate per-fund allocations so Amount/Units update when scheme changes
    final amount = double.tryParse(_basketInvestAmountController.text);
    if (amount != null && amount > 0) {
      calculateBasketAllocations(amount);
    }
    notifyListeners();
  }

  void _redistributePercentages() {
    if (_selectedFunds.isEmpty) return;

    // Get locked funds and their total percentage
    double lockedPercentage = 0.0;
    List<int> unlockedIndices = [];
    
    for (int i = 0; i < _selectedFunds.length; i++) {
      if (_selectedFunds[i].isLocked) {
        lockedPercentage += _selectedFunds[i].percentage;
      } else {
        unlockedIndices.add(i);
      }
    }

    // If no unlocked funds, nothing to redistribute
    if (unlockedIndices.isEmpty) {
      _updateAllControllerValues();
      return;
    }

    final remainingPercentage = 100.0 - lockedPercentage;
    final equalPercentage = remainingPercentage / unlockedIndices.length;

    // Distribute remaining percentage equally among unlocked funds
    for (int i = 0; i < unlockedIndices.length; i++) {
      final index = unlockedIndices[i];
      if (i == unlockedIndices.length - 1) {
        // Last unlocked fund gets the remaining percentage to ensure total = 100%
        final usedPercentage = lockedPercentage + 
            unlockedIndices.take(i).fold(0.0, (sum, idx) => sum + _selectedFunds[idx].percentage);
        _selectedFunds[index].percentage = (100.0 - usedPercentage).round().toDouble();
      } else {
        _selectedFunds[index].percentage = equalPercentage.round().toDouble();
      }
    }

    _updateAllControllerValues();
  }

  validatepercentage(BuildContext context) {
    if (totalPercentage != 100) {
     error(context, "Total percentage must be 100%");
    } else if(_selectedFunds.any((fund) => fund.percentage == 0) && totalPercentage == 100) {
      error(context, "All funds must have valid percentage values (greater than 0%)");
  }
  }

  void clearStrategy() {
    for (final controller in _percentageControllers.values) {
      controller.dispose();
    }
    _percentageControllers.clear();
    _strategyNameController.clear();
    _investmentController.text = '100000';

    _selectedFunds.clear();
    _searchController.clear();
    _selectedFilter = 'All';
    _selectedDuration = '3Y';
    _editingStrategy = null;
    _investmentError = null;
    _analysisData = null;
    _pendingStrategyName = '';
    _selectedPersonality = TradingPersonalityType.aurora;
    _weightingScheme = 'Equi-Weighted';
    notifyListeners();
  }

  bool _showcustomButton = false;
  bool get showcustomButton => _showcustomButton;
  void shocustomButton(bool value) {
    _showcustomButton = value;
    notifyListeners();
  }

  // Method to preload strategy data for editing
  void preloadStrategyData({
    required String strategyName,
    required List<FundListModel> funds,
  }) {
    _strategyNameController.text = strategyName;
    _selectedFunds.clear();
    _selectedFunds.addAll(funds);
    _selectedDuration = '3Y'; // Default duration for predefined strategies
    _initializeControllers();
    notifyListeners();
  }

  // Filter and Search Methods
  void updateSelectedFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  bool isFundSelected(FundListModel fund) {
    return _selectedFunds.any((f) => f.name == fund.name);
  }

  // Group selected funds by type
  Map<String, List<FundListModel>> get groupedSelectedFunds {
    Map<String, List<FundListModel>> grouped = {};
    
    for (final fund in _selectedFunds) {
      String category = _getCategoryFromType(fund.type);
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(fund);
    }
    
    // Sort categories in preferred order
    Map<String, List<FundListModel>> sortedGrouped = {};
    const order = ['Equity', 'Hybrid', 'Debt', 'Fixed Income', 'Liquid', 'Solution Oriented', 'Index', 'FoF'];
    
    for (String category in order) {
      if (grouped.containsKey(category)) {
        sortedGrouped[category] = grouped[category]!;
      }
    }
    
    // Add any other categories not in the predefined order
    for (String category in grouped.keys) {
      if (!order.contains(category)) {
        sortedGrouped[category] = grouped[category]!;
      }
    }
    
    return sortedGrouped;
  }

  String _getCategoryFromType(String type) {
    final trimmed = type.trim();
    if (trimmed.isEmpty) return 'Other';
    // Handle old uppercase-normalized values from previously saved strategies
    final lower = trimmed.toLowerCase();
    if (lower == 'equity') return 'Equity';
    if (lower == 'debt') return 'Debt';
    if (lower == 'hybrid') return 'Hybrid';
    // All other types (Liquid, Solution Oriented, Index, FoF, etc.) — use as-is
    return trimmed;
  }

  // Helper method to extract trading personality from investment details
  TradingPersonalityType getPersonalityFromInvestmentDetails(String? investmentDetails) {
    if (investmentDetails == null || !investmentDetails.contains('personality:')) {
      return TradingPersonalityType.aurora; // Default to Earth if no personality info found
    }
    
    try {
      final personalityPart = investmentDetails.split('personality:')[1];
      final personalityName = personalityPart.split('|')[0]; // In case there are more parts
      
      // Find the matching personality type by name
      final personality = TradingPersonalities.getPersonalityByName(personalityName);
      if (personality != null) {
        return personality.type;
      }
    } catch (e) {
      // If parsing fails, return default
    }
    
    return TradingPersonalityType.aurora; // Default fallback
  }

  String _getWeightingFromInvestmentDetails(String? investmentDetails) {
    if (investmentDetails == null || !investmentDetails.contains('weighting:')) {
      return 'Equi-Weighted';
    }
    try {
      final part = investmentDetails.split('weighting:')[1];
      return part.split('|')[0];
    } catch (e) {
      return 'Equi-Weighted';
    }
  }

  // Investment Configuration Methods
  void updateInvestmentType(String type) {
    _selectedInvestmentType = type;
    notifyListeners();
  }

  void updateDuration(String duration) {
    _selectedDuration = duration;
    notifyListeners();
  }

  void updateStrategyType(String type) {
    _selectedStrategyType = type;
    notifyListeners();
  }

  // Getters
  double get totalPercentage =>
      _selectedFunds.fold(0.0, (sum, fund) => sum + fund.percentage);

  bool _isStrategyValid = false;
  
  bool get isStrategyValid {
    final investmentAmount = double.tryParse(_investmentController.text);
    final isValidInvestment = investmentAmount != null && investmentAmount >= 10000 && investmentAmount <= 1000000000000;
    final isValidPercentage = totalPercentage.round() == 100;
    final hasSelectedFunds = _selectedFunds.isNotEmpty;
    final hasNoZeroPercentages = _selectedFunds.every((fund) => fund.percentage > 0);
    
    _isStrategyValid = isValidInvestment && isValidPercentage && hasSelectedFunds && hasNoZeroPercentages;
    return _isStrategyValid;
  }

  String? getStrategyValidationError() {
    if (_selectedFunds.isEmpty) return 'Please add at least one fund';
    if (totalPercentage.round() != 100) return 'Total weight must equal 100%';
    if (_selectedFunds.any((fund) => fund.percentage <= 0)) {
      final zeroFund = _selectedFunds.firstWhere((f) => f.percentage <= 0);
      return '${zeroFund.name} has 0% weight. Please assign a weight or remove it';
    }
    final investmentAmount = double.tryParse(_investmentController.text);
    if (investmentAmount == null || investmentAmount < 10000) return 'Minimum investment amount is ₹10,000';
    if (investmentAmount > 1000000000000) return 'Investment amount is too high';
    return null;
  }

  String? _investmentError;
  String? get investmentError => _investmentError;

  String? validateInvestmentAmount(String value) {
    if (value.isEmpty) {
      _isStrategyValid = false;
      _investmentError = "Please enter Investment amount";
      notifyListeners();
      return _investmentError;
    }
    
    final parsedValue = double.tryParse(value);
    if (parsedValue == null) {
      _isStrategyValid = false;
      _investmentError = "Please enter valid Investment amount";
      notifyListeners();
      return _investmentError;
    } 
    
    if (parsedValue <= 0) {
      _isStrategyValid = false;
      _investmentError = "Investment amount must be greater than 0";
      notifyListeners();
      return _investmentError;
    } 
    
    if (parsedValue < 10000) {
      _isStrategyValid = false;
      _investmentError = "Minimum investment amount is ₹10,000";
      notifyListeners();
      return _investmentError;
    }
    
    if (parsedValue > 1000000000000) {
      _isStrategyValid = false;
      _investmentError = "Investment amount cannot exceed ₹1,00,00,00,000";
      notifyListeners();
      return _investmentError;
    } 
    
    _isStrategyValid = true;
    _investmentError = null;
    notifyListeners();
    return null;
  }


  // Check if there are meaningful changes in a new strategy
  bool _hasNewStrategyChanges() {
    if (_selectedFunds.isNotEmpty) return true;
    final investmentAmount = double.tryParse(_investmentController.text);
    if (investmentAmount != null && investmentAmount > 0 && investmentAmount != 100000) return true;
    if (_strategyNameController.text.trim().isNotEmpty) return true;
    if (_selectedInvestmentType != 'One-time') return true;
    
    return false;
  }

  bool _stratergysavebackbutton = false;
  bool get stratergysavebackbutton => _stratergysavebackbutton;
  void stratergySavebackbutton(bool value) {
    _stratergysavebackbutton = value;
    notifyListeners();
  }

  // Change detection methods
  bool get hasStrategyChanged {
    if (!isEditingMode || _editingStrategy == null) {
      return _hasNewStrategyChanges();
    }

    final originalStrategy = _editingStrategy!.data?.first;
    if (originalStrategy == null) return true;

    final currentAmount = double.tryParse(_investmentController.text) ?? 0.0;
    final originalAmount = originalStrategy.investAmount ?? 0.0;
    if (currentAmount != originalAmount) return true;

    final currentName = _strategyNameController.text.trim();
    final originalName = originalStrategy.basketName ?? '';
    if (currentName != originalName) return true;

    final originalFunds = originalStrategy.schemaValues ?? [];
    if (_selectedFunds.length != originalFunds.length) return true;

    final originalDuration = originalStrategy.years ?? 0;
    final currentDuration = _getYearInFromDuration(_selectedDuration);
    if (currentDuration != originalDuration) return true;

    for (final currentFund in _selectedFunds) {
      final originalFund = originalFunds.firstWhere(
        (f) => f.name == currentFund.name,
        orElse: () => SchemaValues(name: '', percentage: 0),
      );
      if ((originalFund.name?.isEmpty ?? true) || 
          (currentFund.percentage - (originalFund.percentage ?? 0)).abs() > 0.01) {
        return true;
      }
    }

    return false;
  }

  // Get button text based on current state
  String get backtestButtonText {
    if (!isEditingMode) {
      return 'Save & Backtest';
    } else if (hasStrategyChanged) {
      return 'Update & Backtest';
    } else {
      return 'Backtest';
    }
  }

  // Format amount for display (following your pattern)
  // String formatAmount(double amount) {
  //   if (amount >= 10000000) {
  //     return '${(amount / 10000000).toStringAsFixed(2)}Cr';
  //   } else if (amount >= 100000) {
  //     return '${(amount / 100000).toStringAsFixed(2)}L';
  //   } else if (amount >= 1000) {
  //     return '${(amount / 1000).toStringAsFixed(2)}K';
  //   } else {
  //     return amount.toStringAsFixed(2);
  //   }
  // }

  // Fund Type Helpers
  Color getFundTypeColor(String type, {bool isDarkMode = false}) {
    switch (type.toLowerCase()) {
      case 'equity':
        return isDarkMode ? colors.successDark : colors.successLight;
      case 'debt':
        return isDarkMode
            ? colors.kColorRedDarkTheme
            : colors.kColorRedDarkTheme;
      case 'hybrid':
        return isDarkMode ? colors.lossDark : colors.lossLight;
      case 'commodities':
        return isDarkMode ? colors.pending : colors.pending;
      default:
        return isDarkMode
            ? colors.textSecondaryDark
            : colors.textSecondaryLight;
    }
  }

  IconData getFundTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'equity':
        return Icons.trending_up;
      case 'debt':
        return Icons.account_balance;
      case 'hybrid':
        return Icons.pie_chart;
      case 'commodities':
        return Icons.landscape;
      default:
        return Icons.monetization_on;
    }
  }

  List<MutualFundList>? _basketSearchItems = [];
  List<MutualFundList>? get basketSearchItems => _basketSearchItems;

  Future Basketsearch(String value) async {
    try {
      final basketsearch = await api.getSearchMf(value);

      _basketSearchItems = basketsearch.data ?? [];
      for (var masterMf in _basketSearchItems!) {
        _basketSearchItems!
            .where((m) => m.iSIN == masterMf.iSIN)
            .forEach((m) => m.isAdd = true);
      }
      // Search completed successfully
      notifyListeners();
    } catch (e) {
    }
  }

  void clearBasketSearchResults() {
    _basketSearchItems = [];
    notifyListeners();
  }


  PortfolioAnalysisModel? _analysisData;
  String? _error;

  // Snapshot of amount & duration used for the last backtest run
  String? _backtestAmount;
  String? _backtestDuration;
  String? get backtestAmount => _backtestAmount;
  String? get backtestDuration => _backtestDuration;
  
  // Chart selection states
  bool _showBenchmarkComparison = true;
  bool _showInflationAdjustment = false;
  String _selectedTimeFrame = '1Y'; // 1Y, 3Y, 5Y, All
  
  // Getters
  PortfolioAnalysisModel? get analysisData => _analysisData;
  // String? get error => _error;
  bool get showBenchmarkComparison => _showBenchmarkComparison;
  bool get showInflationAdjustment => _showInflationAdjustment;
  String get selectedTimeFrame => _selectedTimeFrame;
  
  // Calculate performance vs benchmark
  double get performanceVsBenchmark {
    if (_analysisData == null) return 0.0;
    return _analysisData!.total.xirr - _analysisData!.benchmark.xirr;
  }
  
  // Get total post-tax gains
  double get totalPostTaxGains {
    if (_analysisData == null) return 0.0;
    return _analysisData!.taxDetails.totalPostGainTotal;
  }
  
  // Get total tax liability
  double get totalTaxLiability {
    if (_analysisData == null) return 0.0;
    return _analysisData!.taxDetails.equity.tax + 
           _analysisData!.taxDetails.debt.tax;
  }

  
  
  // Toggle benchmark comparison
  void toggleBenchmarkComparison() {
    _showBenchmarkComparison = !_showBenchmarkComparison;
    notifyListeners();
  }
  
  // Toggle inflation adjustment
  void toggleInflationAdjustment() {
    _showInflationAdjustment = !_showInflationAdjustment;
    notifyListeners();
  }
  
  // Change time frame
  void changeTimeFrame(String timeFrame) {
    if (_selectedTimeFrame != timeFrame) {
      _selectedTimeFrame = timeFrame;
      notifyListeners();
    }
  }
  
  // Get filtered chart data based on time frame
  List<double> getFilteredChartData(List<double> originalData) {
    if (_selectedTimeFrame == 'All' || originalData.isEmpty) {
      return originalData;
    }
    
    int dataPoints;
    switch (_selectedTimeFrame) {
      case '1Y':
        dataPoints = 365;
        break;
      case '3Y':
        dataPoints = 365 * 3;
        break;
      case '5Y':
        dataPoints = 365 * 5;
        break;
      default:
        return originalData;
    }
    
    if (originalData.length <= dataPoints) {
      return originalData;
    }
    
    return originalData.sublist(originalData.length - dataPoints);
  }
  
  // Calculate portfolio allocation
  Map<String, double> get portfolioAllocation {
    if (_analysisData == null) return {};
    
    Map<String, double> allocation = {};
    
    // Add equity allocations
    for (var equity in _analysisData!.equity) {
      allocation['Equity'] = (allocation['Equity'] ?? 0) + equity.percentage;
    }
    
    // Add debt allocations
    for (var debt in _analysisData!.debt) {
      allocation['Debt'] = (allocation['Debt'] ?? 0) + debt.percentage;
    }
    
    return allocation;
  }
  
  // Get risk metrics
  Map<String, dynamic> get riskMetrics {
    if (_analysisData == null) return {};
    
    return {
      'volatility': _analysisData!.total.volatility,
      'sharpe_ratio': _analysisData!.total.sharpeRatio,
      'max_drawdown': _analysisData!.total.maxDrawdown,
      'var_95': calculateVaR(), // You can implement this
      'beta': calculateBeta(), // You can implement this
    };
  }
  
  // Calculate Value at Risk (placeholder)
  double calculateVaR() {
    // Implement VaR calculation logic
    return 0.0;
  }
  
  // Calculate Beta (placeholder)
  double calculateBeta() {
    // Implement Beta calculation logic
    return 0.0;
  }
 
  
  // Clear data
  void clearData() {
    _analysisData = null;
    _error = null;
    _isStrategyLoading = false;
    notifyListeners();
  }

  clearsearchcontroller() {
    _searchController.text = "";
    notifyListeners();
  }

 Future<void> backtestAnalysis({required String uuid}) async {
  try {
    strategyLoader(true);
    _error = null;
    // Snapshot the settings used for this backtest so the header stays accurate
    _backtestAmount = _investmentController.text;
    _backtestDuration = _selectedDuration;
    // Convert selected funds to schema values
    final schemaValues = _convertFundsToSchemaValues(_selectedFunds)
        .map((map) => SchemeValue(
              name: map['name'] ?? '',
              schemaName: map['schema_name'] ?? '',
              percentage: map['percentage'] ?? 0,
              schemeType: map['scheme_type'].toUpperCase() ?? '',
              isin: map['isin'] ?? '',
              aMCCode: map['aMCCode'] ?? '',
            ))
        .toList();

    // Create the backtest request
    final request = BacktestRequest(
      yearIn: _getYearInFromDuration(_selectedDuration),
      investmentAmount: double.tryParse(_investmentController.text) ?? 0.0,
      schemeValues: schemaValues,
      compareSymbol: "NSE:NIFTYBEES-EQ",
    );


    final portfolioAnalysis = await api.performBacktest(request, uuid);

    if (portfolioAnalysis != null) {
      _analysisData = portfolioAnalysis;
      _error = null;
    } else {
      _error = "Failed to get portfolio analysis data";
    }
  } catch (e) {
    _error = e.toString();
    rethrow;
  } finally {
    strategyLoader(false);
    notifyListeners();
  }
}

  
  // Fetch real mutual fund data for predefined strategies
  Future<List<Map<String, dynamic>>> getRealFundDataForCategory(String category) async {
    try {
      // Search for popular funds in each category
      String searchTerm = '';
      switch (category.toLowerCase()) {
        case 'equity':
          searchTerm = 'Parag Parikh Flexi Cap Fund';
          break;
        case 'debt':
          searchTerm = 'HDFC Money Market Fund';
          break;
        case 'hybrid':
          searchTerm = 'HDFC Balanced Advantage Fund';
          break;
        case 'commodities':
          searchTerm = 'Nippon India ETF Gold BeES';
          break;
        default:
          searchTerm = 'HDFC';
      }
      
      final searchResult = await api.getSearchMf(searchTerm);
      
      if (searchResult.data != null && searchResult.data!.isNotEmpty) {
        // Return the first fund from search results
        final fund = searchResult.data!.first;
        return [{
          'name': fund.schemeName ?? fund.fundname ?? 'Unknown Fund',
          'percentage': 0.0, // Will be set by caller
          'schemeType': fund.schemeType ?? 'EQUITY',
          'isin': fund.iSIN ?? '',
          'amcCode': fund.aMCCode ?? '',
          'schemeCode': fund.schemeCode ?? '',
          'fiveYearCAGR': 0.0, // Not available in MutualFundList
          'threeYearCAGR': 0.0, // Not available in MutualFundList
          'aum': double.tryParse(fund.aUM ?? '0') ?? 0.0,
          'sharpe': 0.0, // Not available in MutualFundList
        }];
      }
      
      // Fallback to default values if search fails
      return [{
        'name': '$category Fund',
        'percentage': 0.0,
        'schemeType': category.toUpperCase(),
        'isin': '',
        'amcCode': '',
        'schemeCode': '',
        'fiveYearCAGR': 0.0,
        'threeYearCAGR': 0.0,
        'aum': 0.0,
        'sharpe': 0.0,
      }];
    } catch (e) {
      // Return fallback data
      return [{
        'name': '$category Fund',
        'percentage': 0.0,
        'schemeType': category.toUpperCase(),
        'isin': '',
        'amcCode': '',
        'schemeCode': '',
        'fiveYearCAGR': 0.0,
        'threeYearCAGR': 0.0,
        'aum': 0.0,
        'sharpe': 0.0,
      }];
    }
  }

  // Perform backtest with predefined allocations
  Future<void> performBacktestWithAllocation({
    required String strategyName,
    required List<Map<String, dynamic>> fundAllocations,
    int years = 5,
    double investmentAmount = 100000.0,
    String compareSymbol = "NSE:NIFTYBEES-EQ",
  }) async {
    try {
      strategyLoader(true);
      _error = null;

      // Create scheme values from fund allocations
      final schemeValues = fundAllocations.map((fund) => SchemeValue(
        name: fund['name'] as String,
        schemaName: fund['schema_name'] as String,
        percentage: (fund['percentage'] as double).round(),
        schemeType: fund['schemeType'] as String,
        isin: fund['isin'] as String,
        aMCCode: fund['amcCode'] ?? ''
      )).toList();

      // Create backtest request
      final request = BacktestRequest(
        yearIn: years,
        investmentAmount: investmentAmount,
        schemeValues: schemeValues,
        compareSymbol: compareSymbol,
      );


      // Generate a unique UUID for this predefined strategy
      final uuid = 'predefined_${DateTime.now().millisecondsSinceEpoch}';

      final portfolioAnalysis = await api.performBacktest(request, uuid);

      if (portfolioAnalysis != null) {
        _analysisData = portfolioAnalysis;
        _error = null;
      } else {
        _error = "Failed to get portfolio analysis data";
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      strategyLoader(false);
      notifyListeners();
    }
  }

  // ─── BASKET INVEST ──────────────────────────────────────────────────

  final TextEditingController _basketInvestAmountController = TextEditingController();
  TextEditingController get basketInvestAmountController => _basketInvestAmountController;

  bool _isBasketOrdering = false;
  bool get isBasketOrdering => _isBasketOrdering;

  int _currentOrderIndex = -1;
  int get currentOrderIndex => _currentOrderIndex;

  String? _basketInvestError;
  String? get basketInvestError => _basketInvestError;

  List<BasketFundAllocation> _basketAllocations = [];
  List<BasketFundAllocation> get basketAllocations => _basketAllocations;

  List<BasketOrderResult> _basketOrderResults = [];
  List<BasketOrderResult> get basketOrderResults => _basketOrderResults;

  bool _basketOrderCompleted = false;
  bool get basketOrderCompleted => _basketOrderCompleted;

  /// Calculate per-fund allocation from total investment amount
  void calculateBasketAllocations(double totalAmount) {
    _basketInvestError = null;

    if (_selectedFunds.isEmpty) {
      _basketAllocations = [];
      _basketInvestError = 'No funds in basket';
      notifyListeners();
      return;
    }

    final totalPerc = _selectedFunds.fold(0.0, (sum, f) => sum + f.percentage);

    // Always compute allocations so the table stays visible
    List<BasketFundAllocation> allocations = [];
    double allocatedTotal = 0;

    for (int i = 0; i < _selectedFunds.length; i++) {
      final fund = _selectedFunds[i];
      double fundAmount;

      if (i == _selectedFunds.length - 1) {
        // Last fund gets the remainder to avoid rounding issues
        fundAmount = totalAmount - allocatedTotal;
      } else {
        fundAmount = (totalAmount * fund.percentage / 100).floorToDouble();
      }

      allocatedTotal += fundAmount;

      final isValid = fundAmount >= fund.minimumPurchaseAmount;
      final fundNav = fund.nav;
      final units = fundNav > 0 ? fundAmount / fundNav : 0.0;
      allocations.add(BasketFundAllocation(
        fund: fund,
        allocatedAmount: fundAmount,
        isValid: isValid,
        nav: fundNav,
        estimatedUnits: units,
        errorMessage: isValid
            ? null
            : 'Min ₹${fund.minimumPurchaseAmount.toStringAsFixed(0)} required, getting ₹${fundAmount.toStringAsFixed(0)}',
      ));
    }

    _basketAllocations = allocations;

    // Set error if percentages don't total 100%
    if (totalPerc.round() != 100) {
      _basketInvestError = 'Fund percentages must total 100% (currently ${totalPerc.round()}%)';
    } else {
      // Check if any fund fails minimum
      final invalidFunds = allocations.where((a) => !a.isValid).toList();
      if (invalidFunds.isNotEmpty) {
        _basketInvestError =
            '${invalidFunds.first.fund.name} needs min ₹${invalidFunds.first.fund.minimumPurchaseAmount.toStringAsFixed(0)} but gets ₹${invalidFunds.first.allocatedAmount.toStringAsFixed(0)}';
      }
    }

    notifyListeners();
  }

  /// Validate and recalculate when user changes percentage in invest dialog
  void updateBasketFundPercentage(int index, double newPercentage) {
    if (index < 0 || index >= _selectedFunds.length) return;

    // Don't allow editing locked funds
    if (_selectedFunds[index].isLocked) return;

    _selectedFunds[index].percentage = newPercentage.round().clamp(0, 100).toDouble();

    // Auto-redistribute remaining % to other funds
    _autoRedistributePercentages(index);

    // Recalculate if amount is entered
    final amount = double.tryParse(_basketInvestAmountController.text);
    if (amount != null && amount > 0) {
      calculateBasketAllocations(amount);
    }

    notifyListeners();
  }

  /// Check if basket is ready to place orders
  bool get isBasketReadyToOrder {
    if (_basketAllocations.isEmpty) return false;
    if (_basketInvestError != null) return false;
    final totalPerc = _selectedFunds.fold(0.0, (sum, f) => sum + f.percentage);
    if (totalPerc.round() != 100) return false;
    return _basketAllocations.every((a) => a.isValid);
  }

  /// Place lumpsum orders for all funds in basket sequentially
  Future<void> placeBasketLumpsumOrders() async {
    if (!isBasketReadyToOrder) return;

    _isBasketOrdering = true;
    _currentOrderIndex = 0;
    _basketOrderResults = [];
    _basketOrderCompleted = false;
    notifyListeners();

    for (int i = 0; i < _basketAllocations.length; i++) {
      _currentOrderIndex = i;
      notifyListeners();

      final allocation = _basketAllocations[i];
      final schemeCode = allocation.fund.schemeCode ?? '';


      // Skip funds without valid scheme code
      if (schemeCode.isEmpty) {
        _basketOrderResults.add(BasketOrderResult(
          fund: allocation.fund,
          amount: allocation.allocatedAmount,
          isSuccess: false,
          message: 'Invalid scheme code - fund cannot be ordered',
        ));
        notifyListeners();
        continue;
      }

      try {
        final response = await api.getLumpSumOrder(
          schemeCode,
          allocation.allocatedAmount.toStringAsFixed(0),
        );


        _basketOrderResults.add(BasketOrderResult(
          fund: allocation.fund,
          amount: allocation.allocatedAmount,
          isSuccess: response.stat == 'Ok',
          orderId: response.orderId,
          message: response.remarks ?? (response.stat == 'Ok' ? 'Order placed' : 'Order failed'),
        ));
      } catch (e) {
        _basketOrderResults.add(BasketOrderResult(
          fund: allocation.fund,
          amount: allocation.allocatedAmount,
          isSuccess: false,
          message: 'Error: ${e.toString()}',
        ));
      }
      notifyListeners();
    }

    _isBasketOrdering = false;
    _basketOrderCompleted = true;
    _currentOrderIndex = -1;
    notifyListeners();
  }

  /// Fetch current NAV for funds that don't have NAV data
  bool _isFetchingNav = false;
  bool get isFetchingNav => _isFetchingNav;

  Future<void> fetchNavForSelectedFunds() async {
    final fundsWithoutNav = _selectedFunds.where((f) => f.nav <= 0).toList();
    if (fundsWithoutNav.isEmpty) return;

    _isFetchingNav = true;
    notifyListeners();

    for (final fund in fundsWithoutNav) {
      try {
        if (fund.isin != null && fund.isin!.isNotEmpty) {
          final navGraph = await api.getMFNavGraph(fund.isin!);
          if (navGraph.data != null && navGraph.data!.isNotEmpty) {
            fund.nav = navGraph.data!.last.nav?.toDouble() ?? 0.0;
          }
        }
      } catch (e) {
      }
    }

    _isFetchingNav = false;
    // Recalculate allocations if amount is already entered
    final amount = double.tryParse(_basketInvestAmountController.text);
    if (amount != null && amount > 0) {
      calculateBasketAllocations(amount);
    }
    notifyListeners();
  }

  /// Reset basket invest state
  void resetBasketInvest() {
    _basketInvestAmountController.clear();
    _basketAllocations = [];
    _basketOrderResults = [];
    _basketInvestError = null;
    _isBasketOrdering = false;
    _basketOrderCompleted = false;
    _currentOrderIndex = -1;
    notifyListeners();
  }
}

// Helper extension for formatting
extension NumberFormatting on double {
  String toFormattedCurrency() {
    return '₹${toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match match) => '${match[1]},',
    )}';
  }
  
  String toFormattedPercentage() {
    return '${toStringAsFixed(2)}%';
  }

  // @override
  // void dispose() {
  //   _investmentController.dispose();
  //   _searchController.dispose();
  //   super.dispose();
  // }
}


 void handleSaveStrategy(DashboardProvider strategy, BuildContext context) {
    // Validate strategy name
    if (strategy.strategyNameController.text.trim().isEmpty) {
      strategy.setStrategyNameError('Strategy name is required');
      return;
    }
    
    if (strategy.strategyNameController.text.trim().length < 3) {
      strategy.setStrategyNameError('Strategy name must be at least 3 characters');
      return;
    }

    // Validate total percentage
    if (strategy.totalPercentage != 100) {
      strategy.setStrategyNameError('Total percentage must be 100%');
      return;
    }
    
    // Clear any existing error
    strategy.clearStrategyNameError();
    
    // Proceed with strategy creation/update
    if (strategy.isEditingMode) {
      strategy.updateStrategy(context);
    } else {
      strategy.createStrategy(strategy.strategyNameController.text, context);
    }
    
    // Navigate back after successful save
    Navigator.pop(context);
    Navigator.pop(context);
    if(!strategy.stratergysavebackbutton){
                      Navigator.of(context).pop();
                       strategy.backtestAnalysis(uuid: strategy.editingStrategy?.data?.first.uuid ?? '');
                     }
  }


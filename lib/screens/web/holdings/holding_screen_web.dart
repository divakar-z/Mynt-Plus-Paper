import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/provider/mf_provider.dart';
import 'package:mynt_plus/screens/web/holdings/hold_table.dart';
import 'package:mynt_plus/screens/web/holdings/mf_hold_table.dart';
import 'package:mynt_plus/screens/web/holdings/mf_demat_hold_table.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';
import 'package:mynt_plus/routes/route_names.dart';
import '../../../../provider/portfolio_provider.dart';
import '../../../../provider/privacy_provider.dart';
import '../../../../provider/profile_all_details_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/res.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../locator/locator.dart';
import '../../../../locator/preference.dart';
import '../../../../sharedWidget/common_search_fields_web.dart';
import '../../../../sharedWidget/mynt_loader.dart';
import '../../../../sharedWidget/snack_bar.dart';
import '../../../utils/rupee_convert_format.dart';
import 'holdings_download_helper.dart';

class HoldingScreenWeb extends ConsumerWidget {
  final List<dynamic> listofHolding;
  final int initialTabIndex;
  const HoldingScreenWeb(
      {super.key, required this.listofHolding, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch loading state
    final isLoading = ref.watch(portfolioProvider.select((p) => p.holdloader));

    if (isLoading) {
      return Center(child: MyntLoader.simple());
    }

    return _HoldingScreenContent(
        listofHolding: listofHolding, initialTabIndex: initialTabIndex);
  }
}

class _HoldingScreenContent extends ConsumerStatefulWidget {
  final List<dynamic> listofHolding;
  final int initialTabIndex;
  const _HoldingScreenContent(
      {required this.listofHolding, this.initialTabIndex = 0});

  @override
  ConsumerState<_HoldingScreenContent> createState() =>
      _HoldingScreenContentState();
}

class _HoldingScreenContentState extends ConsumerState<_HoldingScreenContent> {
  late int _selectedTabIndex;
  final ValueNotifier<String> _selectedFilter =
      ValueNotifier<String>('All'); // Filter options: All, Stocks, Bonds
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final ValueNotifier<String> _mtfSearchQuery = ValueNotifier<String>('');
  final ValueNotifier<String> _mfSearchQuery = ValueNotifier<String>('');
  final ValueNotifier<String> _mfDematSearchQuery = ValueNotifier<String>('');
  final TextEditingController _stocksSearchController = TextEditingController();
  final TextEditingController _mtfSearchController = TextEditingController();
  final TextEditingController _mfSearchController = TextEditingController();
  final TextEditingController _mfDematSearchController = TextEditingController();

  final ValueNotifier<String?> _hoveredRowToken = ValueNotifier<String?>(null);
  final ValueNotifier<int?> _hoveredColumnIndex = ValueNotifier<int?>(null);

  // WebSocket subscription for live holdings updates
  StreamSubscription? _holdingsSocketSubscription;
  DateTime _lastUpdate = DateTime.now();
  static const Duration _updateInterval = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;

    // Sync controllers with ValueNotifiers
    _stocksSearchController.addListener(() {
      if (_stocksSearchController.text != _searchQuery.value) {
        _searchQuery.value = _stocksSearchController.text;
      }
    });

    _mtfSearchController.addListener(() {
      if (_mtfSearchController.text != _mtfSearchQuery.value) {
        _mtfSearchQuery.value = _mtfSearchController.text;
      }
    });

    _mfSearchController.addListener(() {
      if (_mfSearchController.text != _mfSearchQuery.value) {
        _mfSearchQuery.value = _mfSearchController.text;
      }
    });

    _mfDematSearchController.addListener(() {
      if (_mfDematSearchController.text != _mfDematSearchQuery.value) {
        _mfDematSearchQuery.value = _mfDematSearchController.text;
      }
    });

    // Set up WebSocket subscription for live holdings updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupHoldingsSocketSubscription();
        // Load MTF (prd:"F") holdings and subscribe their scrips for live data.
        // Equity holdings are already fetched before this screen is shown.
        _loadMtfHoldings();
      }
    });
  }

  // Fetch MTF holdings once on entry. Passing "Refresh" also subscribes their
  // scrips to the live feed from inside fetchMtfHoldings.
  Future<void> _loadMtfHoldings() async {
    await ref.read(portfolioProvider).fetchMtfHoldings(context, "Refresh");
  }

  void _setupHoldingsSocketSubscription() {
    final websocket = ref.read(websocketProvider);
    final portfolio = ref.read(portfolioProvider);

    _holdingsSocketSubscription = websocket.socketDataStream.listen((socketDatas) {
      if (!mounted || socketDatas.isEmpty) return;

      // Throttle updates (shared across equity + MTF)
      final now = DateTime.now();
      if (now.difference(_lastUpdate) < _updateInterval) return;

      bool anyUpdate = false;

      // --- Equity holdings: per-row values are updated by the shared WebSocket
      //     provider; here we only recompute the headline totals. ---
      final holdings = portfolio.holdingsModel ?? [];
      if (holdings.isNotEmpty) {
        bool equityNeedsUpdate = false;
        for (var holding in holdings) {
          if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
            final token = holding.exchTsym![0].token;
            if (token != null && socketDatas.containsKey(token)) {
              equityNeedsUpdate = true;
              break;
            }
          }
        }
        if (equityNeedsUpdate) {
          portfolio.pnlHoldCal();
          anyUpdate = true;
        }
      }

      // --- MTF holdings: the shared WebSocket provider does NOT touch the MTF
      //     list, so update its rows AND totals here from the same stream. ---
      final mtfHoldings = portfolio.mtfHoldingsModel ?? [];
      if (mtfHoldings.isNotEmpty) {
        bool mtfNeedsUpdate = false;
        for (var holding in mtfHoldings) {
          if (holding.exchTsym != null && holding.exchTsym!.isNotEmpty) {
            final token = holding.exchTsym![0].token;
            if (token != null && socketDatas.containsKey(token)) {
              portfolio.updateMtfHoldingValues(token, socketDatas[token]);
              mtfNeedsUpdate = true;
            }
          }
        }
        if (mtfNeedsUpdate) {
          portfolio.mtfPnlHoldCal();
          anyUpdate = true;
        }
      }

      if (anyUpdate) {
        _lastUpdate = now;
      }
    });
  }

  @override
  void dispose() {
    _holdingsSocketSubscription?.cancel();
    _hoveredRowToken.dispose();
    _hoveredColumnIndex.dispose();
    _searchQuery.dispose();
    _mtfSearchQuery.dispose();
    _mfSearchQuery.dispose();
    _mfDematSearchQuery.dispose();
    _stocksSearchController.dispose();
    _mtfSearchController.dispose();
    _mfSearchController.dispose();
    _mfDematSearchController.dispose();
    _selectedFilter.dispose();

    super.dispose();
  }

  // Manual refresh method for button click
  Future<void> _handleManualRefresh() async {
    final portfolioData = ref.read(portfolioProvider);
    if (_selectedTabIndex == 0) {
      await portfolioData.fetchHoldings(context, "Refresh", isRefresh: true);
    } else if (_selectedTabIndex == 1) {
      await portfolioData.fetchMtfHoldings(context, "Refresh", isRefresh: true);
    } else if (_selectedTabIndex == 2) {
      await ref.read(mfProvider).fetchmfholdingnew();
    } else {
      await ref.read(mfProvider).fetchmfdematholding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(portfolioProvider.select((p) => p.holdloader));
    final theme = ref.read(themeProvider);

    if (isLoading) {
      return Center(child: MyntLoader.simple());
    }

    // Use ref.watch to rebuild when provider values update (from pnlHoldCal)
    final portfolioData = ref.watch(portfolioProvider);

    // DrawerOverlay is now at app level in main.dart
    // Using same scroll pattern as Positions page - no outer scroll, Expanded for table
    return SizedBox.expand(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: resolveThemeColor(context,
            dark: MyntColors.backgroundColorDark,
            light: MyntColors.backgroundColor),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards Section
                _buildSummaryCards(
                    context, theme, portfolioData, _selectedTabIndex),
                const SizedBox(height: 20),

                // Main Content Area - use Expanded to fill remaining space (like Positions page)
                Expanded(
                  child: _buildMainContent(theme, portfolioData),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, ThemesProvider theme,
      PortfolioProvider portfolioData, int selectedTab) {
    if (selectedTab == 0) {
      // Equity tab - show stocks summary
      return _buildStocksSummaryCards(context, theme, portfolioData);
    } else if (selectedTab == 1) {
      // MTF tab - show MTF holdings summary
      return _buildMtfSummaryCards(context, theme, portfolioData);
    } else if (selectedTab == 2) {
      // Mutual Funds tab - show mutual funds summary
      return _buildMutualFundsSummaryCards(theme);
    } else {
      // Mutual Fund Beta tab - show demat holdings summary
      return _buildMfDematSummaryCards(theme);
    }
  }

  Widget _buildStocksSummaryCards(BuildContext context, ThemesProvider theme,
      PortfolioProvider portfolioData) {
    // Use provider's pre-calculated values from pnlHoldCal()
    final invested = portfolioData.totInvesHold;
    final currentValue = portfolioData.totalCurrentVal.toStringAsFixed(2);
    final totalPnL = portfolioData.totalPnlHolding.toStringAsFixed(2);
    final totalPnLPercent = portfolioData.totPnlPercHolding;
    final dayChange = portfolioData.oneDayChng.toStringAsFixed(2);
    final dayChangePercent = portfolioData.oneDayChngPer.toStringAsFixed(2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final cards = [
          _buildStatCard(
            label: 'Invested',
            value: invested.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Current Value',
            value: currentValue.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Profit/Loss',
            value: totalPnL.toIndianRupee(),
            percentage: totalPnLPercent,
            valueColor: getValueColor(context, totalPnL),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Day Change',
            value: dayChange.toIndianRupee(),
            percentage: dayChangePercent,
            valueColor: getValueColor(context, dayChange),
            theme: theme,
          ),
        ];

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  // MTF summary cards — mirrors the equity stat cards but uses the MTF totals.
  Widget _buildMtfSummaryCards(BuildContext context, ThemesProvider theme,
      PortfolioProvider portfolioData) {
    final invested = portfolioData.totMtfInvest;
    final currentValue = portfolioData.totalMtfCurrentVal.toStringAsFixed(2);
    final totalPnL = portfolioData.totalMtfPnl.toStringAsFixed(2);
    final totalPnLPercent = portfolioData.totMtfPnlPerc;
    final dayChange = portfolioData.mtfOneDayChng.toStringAsFixed(2);
    final dayChangePercent = portfolioData.mtfOneDayChngPer.toStringAsFixed(2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final cards = [
          _buildStatCard(
            label: 'Invested',
            value: invested.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Current Value',
            value: currentValue.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Profit/Loss',
            value: totalPnL.toIndianRupee(),
            percentage: totalPnLPercent,
            valueColor: getValueColor(context, totalPnL),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Day Change',
            value: dayChange.toIndianRupee(),
            percentage: dayChangePercent,
            valueColor: getValueColor(context, dayChange),
            theme: theme,
          ),
        ];

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        } else {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard({
    // IconData? icon,
    required String label,
    required String value,
    String? percentage,
    required Color valueColor,
    required ThemesProvider theme,
  }) {
    // Privacy Mode: hide the amount (and its sign/colour); the ₹ and (%)
    // shells stay so the layout doesn't shift.
    final privacy = ref.watch(privacyProvider);
    if (privacy.isPrivate) {
      value = value.contains('₹') ? '₹$kPrivacyMask' : kPrivacyMask;
      percentage = percentage == null ? null : kPrivacyMask;
      valueColor = resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    }
    return shadcn.Theme(
        data: shadcn.Theme.of(context).copyWith(radius: () => 0.3),
        child: shadcn.Card(
          padding: EdgeInsets.all(10),
          child: Container(
            child: Row(
              children: [
                // Icon in circle
                // if (icon != null)
                //   Container(
                //     width: 45,
                //     height: 45,
                //     decoration: BoxDecoration(
                //       color: resolveThemeColor(
                //         context,
                //         dark: MyntColors.primaryDark,
                //         light: MyntColors.primary,
                //       ).withOpacity(0.1),
                //       shape: BoxShape.circle,
                //     ),
                //     child: Center(
                //       child: Icon(
                //         icon,
                //         size: 20,
                //         color: resolveThemeColor(
                //           context,
                //           dark: MyntColors.primaryDark,
                //           light: MyntColors.primary,
                //         ),
                //       ),
                //     ),
                //   ),
                const SizedBox(width: 1),
                // Label and value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: MyntWebTextStyles.bodySmall(
                          context,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                          fontWeight: MyntFonts.medium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Use Wrap to move percentage to next line when space is limited
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            value,
                            style: MyntWebTextStyles.head(
                              context,
                              color: valueColor,
                              fontWeight: MyntFonts.medium,
                            ).copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (percentage != null)
                            Text(
                              '($percentage%)',
                              style: MyntWebTextStyles.bodySmall(
                                context,
                                color: valueColor,
                                fontWeight: MyntFonts.medium,
                              ).copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
  }


  Widget _buildMutualFundsSummaryCards(ThemesProvider theme) {
    return Consumer(
      builder: (context, ref, _) {
        final mfData = ref.watch(mfProvider);
        final summary = mfData.mfholdingnew?.summary;
        final investedValue = _formatValue(summary?.invested);
        final currentValue = _formatValue(summary?.currentValue);
        final absReturnValue = _formatValue(summary?.absReturnValue);
        final absReturnPercent =
            _formatValue(summary?.absReturnPercent?.toString());

        final cards = [
          _buildStatCard(
            label: 'Invested',
            value: investedValue.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Current Value',
            value: currentValue.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Returns',
            value: absReturnValue.toIndianRupee(),
            percentage: absReturnPercent,
            valueColor: getValueColor(context, absReturnValue),
            theme: theme,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            } else {
              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[2]),
                        const SizedBox(width: 12),
                        Expanded(child: Container()),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }

  Widget _buildMfDematSummaryCards(ThemesProvider theme) {
    return Consumer(
      builder: (context, ref, _) {
        final mfData = ref.watch(mfProvider);
        final summary = mfData.mfDematHolding?.summary;
        final holdings = mfData.mfDematHolding?.data ?? [];

        // Prefer the API summary when present; otherwise compute totals from
        // the demat holdings rows (the demat endpoint may omit a summary block).
        double invested;
        double currentValue;
        double returns;
        if (summary != null) {
          invested = double.tryParse(summary.invested ?? '0') ?? 0.0;
          currentValue = double.tryParse(summary.currentValue ?? '0') ?? 0.0;
          returns = double.tryParse(summary.absReturnValue ?? '0') ??
              (currentValue - invested);
        } else {
          invested = 0.0;
          currentValue = 0.0;
          for (final h in holdings) {
            invested += double.tryParse(h.investedValue ?? '0') ?? 0.0;
            currentValue += double.tryParse(h.currentValue ?? '0') ?? 0.0;
          }
          returns = currentValue - invested;
        }

        final returnsPercent =
            invested != 0 ? (returns / invested) * 100 : 0.0;

        final investedStr = invested.toStringAsFixed(2);
        final currentStr = currentValue.toStringAsFixed(2);
        final returnsStr = returns.toStringAsFixed(2);
        final returnsPercentStr = returnsPercent.toStringAsFixed(2);

        final cards = [
          _buildStatCard(
            label: 'Invested',
            value: investedStr.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Current Value',
            value: currentStr.toIndianRupee(),
            valueColor: resolveThemeColor(
              context,
              dark: MyntColors.textPrimaryDark,
              light: MyntColors.textPrimary,
            ),
            theme: theme,
          ),
          _buildStatCard(
            label: 'Returns',
            value: returnsStr.toIndianRupee(),
            percentage: returnsPercentStr,
            valueColor: getValueColor(context, returnsStr),
            theme: theme,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                ),
              );
            } else {
              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[2]),
                        const SizedBox(width: 12),
                        Expanded(child: Container()),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }

  Widget _buildMainContent(
      ThemesProvider theme, PortfolioProvider portfolioData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs and Action Bar in same row
        _buildTabsAndActionBar(theme, portfolioData),
        const SizedBox(height: 16),
        // Content based on selected tab - Using IndexedStack for better performance
        Expanded(
          child: (_selectedTabIndex == 1
                  ? (portfolioData.mtfHoldLoader ||
                      portfolioData.isRefreshingMtf)
                  : (portfolioData.holdloader ||
                      portfolioData.isRefreshingHoldings))
              ? Center(child: MyntLoader.simple())
              : IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    // Equity tab - Using TableExample1 from hold_table.dart with search
                    ValueListenableBuilder<String>(
                      valueListenable: _searchQuery,
                      builder: (context, searchQuery, child) {
                        return ValueListenableBuilder<String>(
                          valueListenable: _selectedFilter,
                          builder: (context, filterType, child) {
                            return TableExample1(
                              searchQuery: searchQuery,
                              filterType: filterType,
                            );
                          },
                        );
                      },
                    ),
                    // MTF tab - reuse TableExample1 with the MTF data source
                    ValueListenableBuilder<String>(
                      valueListenable: _mtfSearchQuery,
                      builder: (context, searchQuery, child) {
                        return TableExample1(
                          searchQuery: searchQuery,
                          isMtf: true,
                        );
                      },
                    ),
                    // Mutual Funds tab - Using MfTableExample from mf_hold_table.dart with search
                    ValueListenableBuilder<String>(
                      valueListenable: _mfSearchQuery,
                      builder: (context, searchQuery, child) {
                        return MfTableExample(searchQuery: searchQuery);
                      },
                    ),
                    // Mutual Fund Beta tab - Using MfDematTableExample from mf_demat_hold_table.dart with search
                    ValueListenableBuilder<String>(
                      valueListenable: _mfDematSearchQuery,
                      builder: (context, searchQuery, child) {
                        return MfDematTableExample(searchQuery: searchQuery);
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabsAndActionBar(
      ThemesProvider theme, PortfolioProvider portfolioData) {
    // Calculate counts for tabs
    final stocksCount = widget.listofHolding.length;
    final mtfCount = portfolioData.mtfHoldingsModel?.length ?? 0;
    final mutualFundsCount =
        ref.read(mfProvider).mfholdingnew?.data?.length ?? 0;
    final mfDematCount =
        ref.read(mfProvider).mfDematHolding?.data?.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use compact layout when width is less than 800
        final useCompactLayout = constraints.maxWidth < 800;

        // Build tabs widget (reused in both layouts)
        // Switch to [index] and reset every tab's search so only the active
        // tab ever shows a query (matches the prior per-tab clearing).
        void selectTab(int index) {
          if (mounted && _selectedTabIndex != index) {
            setState(() {
              _selectedTabIndex = index;
              _stocksSearchController.clear();
              _searchQuery.value = '';
              _mtfSearchController.clear();
              _mtfSearchQuery.value = '';
              _mfSearchController.clear();
              _mfSearchQuery.value = '';
              _mfDematSearchController.clear();
              _mfDematSearchQuery.value = '';
            });
          }
        }

        // Simple text label for a tab (Equity / MTF / Mutual Fund).
        Widget tabTextLabel(String text, int index) {
          final selected = _selectedTabIndex == index;
          return Text(
            text,
            style: MyntWebTextStyles.body(
              context,
              fontWeight: selected ? MyntFonts.semiBold : MyntFonts.medium,
            ).copyWith(
              color: selected
                  ? shadcn.Theme.of(context).colorScheme.foreground
                  : shadcn.Theme.of(context).colorScheme.mutedForeground,
            ),
          );
        }

        // One tab "chip": selected-state background + label + optional count badge.
        Widget tabChip({
          required int index,
          required Widget label,
          required int count,
        }) {
          final selected = _selectedTabIndex == index;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => selectTab(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? (theme.isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Text(
                          '$count',
                          style: MyntWebTextStyles.bodySmall(
                            context,
                            fontWeight: selected
                                ? MyntFonts.semiBold
                                : MyntFonts.medium,
                          ).copyWith(
                            fontSize: 13,
                            color: selected
                                ? shadcn.Theme.of(context)
                                    .colorScheme
                                    .foreground
                                : shadcn.Theme.of(context)
                                    .colorScheme
                                    .mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        Widget buildTabs() {
          final betaSelected = _selectedTabIndex == 3;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equity tab
              tabChip(
                index: 0,
                count: stocksCount,
                label: tabTextLabel('Equity', 0),
              ),
              const SizedBox(width: 8),
              // MTF tab
              tabChip(
                index: 1,
                count: mtfCount,
                label: tabTextLabel('MTF', 1),
              ),
              const SizedBox(width: 8),
              // Mutual Fund tab
              tabChip(
                index: 2,
                count: mutualFundsCount,
                label: tabTextLabel('Mutual Fund', 2),
              ),
              const SizedBox(width: 8),
              // Mutual Fund Beta tab
              tabChip(
                index: 3,
                count: mfDematCount,
                label: Text.rich(
                  TextSpan(
                    style: MyntWebTextStyles.body(
                      context,
                      fontWeight: betaSelected
                          ? MyntFonts.semiBold
                          : MyntFonts.medium,
                    ).copyWith(
                      color: betaSelected
                          ? shadcn.Theme.of(context).colorScheme.foreground
                          : shadcn.Theme.of(context)
                              .colorScheme
                              .mutedForeground,
                    ),
                    children: [
                      const TextSpan(text: 'Mutual Fund '),
                      TextSpan(
                        text: 'BETA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: MyntFonts.bold,
                          color: resolveThemeColor(
                            context,
                            dark: MyntColors.primaryDark,
                            light: MyntColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Build search widget
        Widget buildSearch() {
          final screenWidth = MediaQuery.of(context).size.width;
          double searchWidth;
          if (useCompactLayout) {
            // In compact layout, search takes remaining space
            searchWidth = double.infinity;
          } else if (screenWidth >= 1200) {
            searchWidth = 400;
          } else if (screenWidth >= 800) {
            searchWidth = 300;
          } else {
            searchWidth = 200;
          }

          if (_selectedTabIndex == 0) {
            return SizedBox(
              width: useCompactLayout ? null : searchWidth,
              child: MyntSearchTextField.withSmartClear(
                controller: _stocksSearchController,
                placeholder: 'Search on holdings',
                leadingIcon: assets.searchIcon,
                onClear: () => _stocksSearchController.clear(),
              ),
            );
          } else if (_selectedTabIndex == 1) {
            return SizedBox(
              width: useCompactLayout ? null : searchWidth,
              child: MyntSearchTextField.withSmartClear(
                controller: _mtfSearchController,
                placeholder: 'Search on MTF holdings',
                leadingIcon: assets.searchIcon,
                onClear: () => _mtfSearchController.clear(),
              ),
            );
          } else if (_selectedTabIndex == 2) {
            return SizedBox(
              width: useCompactLayout ? null : searchWidth,
              child: MyntSearchTextField.withSmartClear(
                controller: _mfSearchController,
                placeholder: 'Search on mutual funds',
                leadingIcon: assets.searchIcon,
                onClear: () => _mfSearchController.clear(),
              ),
            );
          } else {
            return SizedBox(
              width: useCompactLayout ? null : searchWidth,
              child: MyntSearchTextField.withSmartClear(
                controller: _mfDematSearchController,
                placeholder: 'Search on mutual funds',
                leadingIcon: assets.searchIcon,
                onClear: () => _mfDematSearchController.clear(),
              ),
            );
          }
        }

        // Build action buttons
        Widget buildActionButtons() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filter dropdown button (only for Equity tab)
              if (_selectedTabIndex == 0) ...[
                _buildFilterButton(theme),
                const SizedBox(width: 12),
              ],
              // E-DIS button (only for Stocks tab when showEdis is true)
              if (_selectedTabIndex == 0 && portfolioData.showEdis) ...[
                _buildEdisButton(theme, portfolioData),
                const SizedBox(width: 12),
              ],
              // MF E-DIS button (only show on Mutual Fund tab when POA is not active)
              if (_selectedTabIndex == 2 &&
                  ref.read(profileAllDetailsProvider).clientAllDetailsSafe?.clientData?.pOA != 'Y') ...[
                _buildMfEdisButton(theme),
                const SizedBox(width: 12),
              ],
              // Download button (Equity + MTF tabs)
              if (_selectedTabIndex == 0 || _selectedTabIndex == 1) ...[
                _buildDownloadButton(theme, portfolioData,
                    isMtf: _selectedTabIndex == 1),
                const SizedBox(width: 12),
              ],
              // Reload button - triggers manual refresh
              _buildIconButton(
                icon: Icons.refresh,
                onPressed: () {
                  _handleManualRefresh();

                },
                theme: theme,
              ),
            ],
          );
        }

        if (useCompactLayout) {
          // Compact layout: Tabs on first row, Search + Actions on second row
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Tabs
                buildTabs(),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    // Insights button (only for Equity tab)
                    if (_selectedTabIndex == 0) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (WebNavigationHelper.isAvailable) {
                              WebNavigationHelper.navigateTo(Routes.portfolioDashboard);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          hoverColor: resolveThemeColor(
                            context,
                            dark: MyntColors.primaryDark.withValues(alpha: 0.1),
                            light: MyntColors.primary.withValues(alpha: 0.1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              'Insights',
                              style: MyntWebTextStyles.symbol(
                                context,
                                fontWeight: MyntFonts.bold,
                                color: resolveThemeColor(
                                  context,
                                  dark: MyntColors.primaryDark,
                                  light: MyntColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: buildSearch()),
                    const SizedBox(width: 12),
                    buildActionButtons(),
                  ],
                ),
              ],
            ),
          );
        }

        // Default layout: All in one row
        return Row(
          children: [
            buildTabs(),
            const Spacer(),
            // Insights button (only for Equity tab)
            if (_selectedTabIndex == 0) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (WebNavigationHelper.isAvailable) {
                      WebNavigationHelper.navigateTo(Routes.portfolioDashboard);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  hoverColor: resolveThemeColor(
                    context,
                    dark: MyntColors.primaryDark.withValues(alpha: 0.1),
                    light: MyntColors.primary.withValues(alpha: 0.1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Insights',
                      style: MyntWebTextStyles.symbol(
                        context,
                        fontWeight: MyntFonts.bold,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.primaryDark,
                          light: MyntColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            buildSearch(),
            const SizedBox(width: 12),
            buildActionButtons(),
          ],
        );
      },
    );
  }

  // Icon button helper (for filter and reload buttons)
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemesProvider theme,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: theme.isDarkMode
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.15),
          highlightColor: theme.isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 28,
                color: theme.isDarkMode
                    ? MyntColors.textWhite
                    : MyntColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Download button (PDF / Excel). When [isMtf] is true it exports the MTF
  // holdings + totals instead of the equity ones.
  Widget _buildDownloadButton(
      ThemesProvider theme, PortfolioProvider portfolioData,
      {bool isMtf = false}) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.download,
        size: 24,
        color: theme.isDarkMode
            ? MyntColors.textWhite
            : MyntColors.textPrimary,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Download',
      color: resolveThemeColor(context,
          dark: MyntColors.cardDark, light: MyntColors.card),
      onSelected: (value) {
        final pref = locator<Preferences>();
        final clientId = pref.clientId ?? '';
        final clientName = pref.clientName ?? '';
        // Pick the equity or MTF data set based on the active tab.
        final holdings = isMtf
            ? (portfolioData.mtfHoldingsModel ?? [])
            : (portfolioData.holdingsModel ?? []);
        final totalInvested = double.tryParse(isMtf
                ? portfolioData.totMtfInvest
                : portfolioData.totInvesHold) ??
            0;
        final totalCurrentValue = isMtf
            ? portfolioData.totalMtfCurrentVal
            : portfolioData.totalCurrentVal;
        final totalPnl =
            isMtf ? portfolioData.totalMtfPnl : portfolioData.totalPnlHolding;
        final totalDayChange =
            isMtf ? portfolioData.mtfOneDayChng : portfolioData.oneDayChng;
        final socketData = ref.read(websocketProvider).socketDatas;

        if (holdings.isEmpty) {
          warningMessage(context, 'No holdings to download');
          return;
        }

        if (value == 'pdf') {
          HoldingsDownloadHelper.downloadPdf(
            holdings: holdings,
            clientId: clientId,
            clientName: clientName,
            totalInvested: totalInvested,
            totalCurrentValue: totalCurrentValue,
            totalPnl: totalPnl,
            totalDayChange: totalDayChange,
            socketData: socketData,
          );
        } else if (value == 'excel') {
          HoldingsDownloadHelper.downloadExcel(
            holdings: holdings,
            clientId: clientId,
            clientName: clientName,
            totalInvested: totalInvested,
            totalCurrentValue: totalCurrentValue,
            totalPnl: totalPnl,
            totalDayChange: totalDayChange,
            socketData: socketData,
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Download PDF'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text('Download Excel'),
            ],
          ),
        ),
      ],
    );
  }

  // E-DIS button
  Widget _buildEdisButton(
      ThemesProvider theme, PortfolioProvider portfolioData) {
    return SizedBox(
      height: 35,
      child: ElevatedButton(
        onPressed: () async {
          await ref.read(fundProvider).fetchHstoken(context);
          // Use web-specific E-DIS that opens in new browser tab
          await ref.read(fundProvider).eDisWeb();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.secondary,
            light: MyntColors.primary,
          ),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
        ),
        child: Text(
          'E-DIS',
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.semiBold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // MF E-DIS button
  Widget _buildMfEdisButton(ThemesProvider theme) {
    return SizedBox(
      height: 35,
      child: ElevatedButton(
        onPressed: () async {
          await ref.read(fundProvider).fetchHstoken(context);
          await ref.read(fundProvider).eDisMfWeb();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: resolveThemeColor(
            context,
            dark: MyntColors.secondary,
            light: MyntColors.primary,
          ),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
        ),
        child: Text(
          'E-DIS',
          style: MyntWebTextStyles.body(
            context,
            fontWeight: MyntFonts.semiBold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Filter dropdown button
  Widget _buildFilterButton(ThemesProvider theme) {
    return Builder(
      builder: (buttonContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showFilterPopup(buttonContext, theme),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assets.searchFilter,
                  width: 20,
                  color: resolveThemeColor(
                    context,
                    dark: MyntColors.iconDark,
                    light: MyntColors.icon,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFilterPopup(BuildContext context, ThemesProvider theme) {
    shadcn.showPopover(
      context: context,
      alignment: Alignment.topCenter,
      offset: const Offset(0, 8),
      overlayBarrier: shadcn.OverlayBarrier(
        borderRadius: shadcn.Theme.of(context).borderRadiusLg,
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: shadcn.Theme.of(context).borderRadiusLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: shadcn.ModalContainer(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 160, // Adjusted width
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterMenuItem('All', theme),
                  _buildFilterMenuItem('Stocks', theme),
                  _buildFilterMenuItem('Bonds', theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Filter menu item helper
  Widget _buildFilterMenuItem(String value, ThemesProvider theme) {
    return ValueListenableBuilder<String>(
      valueListenable: _selectedFilter,
      builder: (context, currentFilter, child) {
        final isSelected = currentFilter == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _selectedFilter.value = value;
              shadcn.closeOverlay(context);
            },
            splashColor: resolveThemeColor(
              context,
              dark: MyntColors.rippleDark,
              light: MyntColors.rippleLight,
            ),
            highlightColor: resolveThemeColor(
              context,
              dark: MyntColors.highlightDark,
              light: MyntColors.highlightLight,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isSelected
                    ? resolveThemeColor(
                        context,
                        dark: MyntColors.primaryDark.withOpacity(0.12),
                        light:
                            const Color(0xFFE8F0FE), // Light blue like in image
                      )
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: MyntWebTextStyles.body(
                        context,
                        fontWeight:
                            isSelected ? MyntFonts.semiBold : MyntFonts.medium,
                        color: isSelected
                            ? resolveThemeColor(
                                context,
                                dark: MyntColors.primaryDark,
                                light: MyntColors.primary,
                              )
                            : resolveThemeColor(
                                context,
                                dark: MyntColors.textPrimaryDark,
                                light: MyntColors.textPrimary,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for value color
  Color getValueColor(BuildContext context, String value) {
    final numValue = double.tryParse(value) ?? 0.0;

    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    }
  }

  String _formatValue(String? value) {
    if (value == null || value.isEmpty) return "0.00";
    final numValue = double.tryParse(value);
    if (numValue == null) return "0.00";
    return numValue.toStringAsFixed(2);
  }

  Color _getStatValueColor(String value, ThemesProvider theme) {
    // Extract numeric value from string (remove any text like percentages)
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    final numValue = double.tryParse(cleanValue) ?? 0.0;

    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textPrimaryDark,
        light: MyntColors.textPrimary,
      );
    }
  }
}

// Isolated widget for LTP - only this rebuilds when LTP changes
class _LTPCell extends ConsumerStatefulWidget {
  final String token;
  final String initialLtp;

  const _LTPCell({required this.token, required this.initialLtp});

  @override
  ConsumerState<_LTPCell> createState() => _LTPCellState();
}

class _LTPCellState extends ConsumerState<_LTPCell> {
  late String ltp;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    ltp = widget.initialLtp;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null &&
          newLtp != ltp &&
          newLtp != '0.00' &&
          newLtp != 'null') {
        setState(() => ltp = newLtp);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(ltp, textAlign: TextAlign.right);
  }
}

// Isolated widget for Current Value
class _CurrentValueCell extends ConsumerStatefulWidget {
  final String token;
  final int qty;
  final String initialValue;

  const _CurrentValueCell({
    required this.token,
    required this.qty,
    required this.initialValue,
  });

  @override
  ConsumerState<_CurrentValueCell> createState() => _CurrentValueCellState();
}

class _CurrentValueCellState extends ConsumerState<_CurrentValueCell> {
  late String currentValue;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        final newValue = (ltp * widget.qty).toStringAsFixed(2);
        if (newValue != currentValue) {
          setState(() => currentValue = newValue);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(currentValue, textAlign: TextAlign.right);
  }
}

// Isolated widget for Day P&L
class _DayPnLCell extends ConsumerStatefulWidget {
  final String token;
  final String initialValue;
  final ThemesProvider theme;

  const _DayPnLCell({
    required this.token,
    required this.initialValue,
    required this.theme,
  });

  @override
  ConsumerState<_DayPnLCell> createState() => _DayPnLCellState();
}

class _DayPnLCellState extends ConsumerState<_DayPnLCell> {
  late String dayPnL;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    dayPnL = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newValue = data[widget.token]['chng']?.toString();
      if (newValue != null && newValue != dayPnL && newValue != 'null') {
        setState(() => dayPnL = newValue);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      dayPnL,
      style: MyntWebTextStyles.bodySmall(
        context,
        color: _getValueColor(dayPnL, widget.theme),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

// Isolated widget for Day %
class _DayPercentCell extends ConsumerStatefulWidget {
  final String token;
  final String initialValue;
  final ThemesProvider theme;

  const _DayPercentCell({
    required this.token,
    required this.initialValue,
    required this.theme,
  });

  @override
  ConsumerState<_DayPercentCell> createState() => _DayPercentCellState();
}

class _DayPercentCellState extends ConsumerState<_DayPercentCell> {
  late String dayPercent;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    dayPercent = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newValue = data[widget.token]['pc']?.toString();
      if (newValue != null && newValue != dayPercent && newValue != 'null') {
        setState(() => dayPercent = newValue);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$dayPercent%',
      style: MyntWebTextStyles.bodySmall(
        context,
        color: _getValueColor(dayPercent, widget.theme),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

// Isolated widget for Overall P&L
class _OverallPnLCell extends ConsumerStatefulWidget {
  final String token;
  final int qty;
  final double avgPrice;
  final String initialValue;
  final ThemesProvider theme;

  const _OverallPnLCell({
    required this.token,
    required this.qty,
    required this.avgPrice,
    required this.initialValue,
    required this.theme,
  });

  @override
  ConsumerState<_OverallPnLCell> createState() => _OverallPnLCellState();
}

class _OverallPnLCellState extends ConsumerState<_OverallPnLCell> {
  late String overallPnL;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    overallPnL = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        final newPnL =
            ((ltp - widget.avgPrice) * widget.qty).toStringAsFixed(2);
        if (newPnL != overallPnL) {
          setState(() => overallPnL = newPnL);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      overallPnL,
      style: MyntWebTextStyles.bodySmall(
        context,
        color: _getValueColor(overallPnL, widget.theme),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

// Isolated widget for Overall %
class _OverallPercentCell extends ConsumerStatefulWidget {
  final String token;
  final double avgPrice;
  final String initialValue;
  final ThemesProvider theme;

  const _OverallPercentCell({
    required this.token,
    required this.avgPrice,
    required this.initialValue,
    required this.theme,
  });

  @override
  ConsumerState<_OverallPercentCell> createState() =>
      _OverallPercentCellState();
}

class _OverallPercentCellState extends ConsumerState<_OverallPercentCell> {
  late String overallPercent;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    overallPercent = widget.initialValue;

    _subscription = ref.read(websocketProvider).socketDataStream.listen((data) {
      if (!mounted || !data.containsKey(widget.token)) return;

      final newLtp = data[widget.token]['lp']?.toString();
      if (newLtp != null && newLtp != '0.00' && newLtp != 'null') {
        final ltp = double.tryParse(newLtp) ?? 0.0;
        final newPercent = widget.avgPrice > 0
            ? (((ltp - widget.avgPrice) / widget.avgPrice) * 100)
                .toStringAsFixed(2)
            : '0.00';
        if (newPercent != overallPercent) {
          setState(() => overallPercent = newPercent);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color _getValueColor(String value, ThemesProvider theme) {
    final numValue = double.tryParse(value) ?? 0.0;
    if (numValue > 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.profitDark,
        light: MyntColors.profit,
      );
    } else if (numValue < 0) {
      return resolveThemeColor(
        context,
        dark: MyntColors.lossDark,
        light: MyntColors.loss,
      );
    } else {
      return resolveThemeColor(
        context,
        dark: MyntColors.textSecondaryDark,
        light: MyntColors.textSecondary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$overallPercent%',
      style: MyntWebTextStyles.bodySmall(
        context,
        color: _getValueColor(overallPercent, widget.theme),
        fontWeight: MyntFonts.medium,
      ),
      textAlign: TextAlign.right,
    );
  }
}

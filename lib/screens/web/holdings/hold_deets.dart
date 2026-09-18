import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import '../../../models/portfolio_model/holdings_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../provider/ledger_provider.dart';
import '../../../res/res.dart';
import '../../../res/global_state_text.dart';
import '../../../res/web_colors.dart';
import '../../../res/global_font_web.dart' hide WebTextStyles;
import '../../../utils/responsive_navigation.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../routes/route_names.dart';
import '../../../sharedWidget/alert_dialogue.dart';

class HoldingDetailScreenWeb extends ConsumerStatefulWidget {
  final dynamic holding;
  final ExchTsym exchTsym;

  const HoldingDetailScreenWeb({
    super.key,
    required this.holding,
    required this.exchTsym,
  });

  @override
  ConsumerState<HoldingDetailScreenWeb> createState() => _HoldingDetailScreenWebState();
}

class _HoldingDetailScreenWebState extends ConsumerState<HoldingDetailScreenWeb> {
  StreamSubscription? _socketSubscription;
  late ExchTsym _exchTsym;
  late dynamic _holdingData;

  // Track touch events to prevent multiple button presses
  bool _isProcessingBuy = false;
  bool _isProcessingSell = false;

  @override
  void initState() {
    super.initState();
    // Make copies of the data to avoid modifying the original objects
    _exchTsym = _copyExchTsym(widget.exchTsym);
    _holdingData = widget.holding;

    // Don't pre-load data here - moved to didChangeDependencies
  }

  bool _didInitDependencies = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only run this once
    if (!_didInitDependencies) {
      _didInitDependencies = true;

      // Use a microtask to ensure widget is fully mounted
      Future.microtask(() {
        if (mounted) {
          _preLoadData();
        }
      });
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    // NOTE: Do NOT close WebSocket here - this is just a detail screen
    // The shared WebSocket should stay connected for the main app
    // Only the main home screen should close WebSocket on full app exit
    super.dispose();
  }

  // Create a copy of the ExchTsym to avoid modifying the original
  ExchTsym _copyExchTsym(ExchTsym original) {
    final copy = ExchTsym();
    copy.token = original.token;
    copy.exch = original.exch;
    copy.tsym = original.tsym;
    copy.lp = original.lp;
    copy.perChange = original.perChange;
    copy.change = original.change;
    copy.close = original.close;
    copy.profitNloss = original.profitNloss;
    copy.pNlChng = original.pNlChng;
    copy.ls = original.ls;
    return copy;
  }

  // Pre-load data to avoid flickering
  Future<void> _preLoadData() async {
    if (!mounted) return;

    // Get the latest socket data for this token immediately
    final wsProvider = ref.read(websocketProvider);
    final socketData = wsProvider.socketDatas[_exchTsym.token];

    if (socketData != null) {
      // Update with initial socket data — strict guards match the listener
      // body below so broker zero defaults can never overwrite valid API data.
      final lp = socketData['lp']?.toString();
      final pc = socketData['pc']?.toString();
      final chng = socketData['chng']?.toString();
      final c = socketData['c']?.toString();

      if (_isValidValue(lp)) _exchTsym.lp = lp;
      if (_isValidValue(pc)) _exchTsym.perChange = pc;
      if (_isValidValue(chng)) _exchTsym.change = chng;
      if (_isValidValue(c)) _exchTsym.close = c;

      _updateProfitLossValues();
    }

    // Set up socket subscription only after initial data is set
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _setupSocketSubscription();
        setState(() {});
      }
    });
  }

  // Set up the socket subscription
  void _setupSocketSubscription() {
    if (!mounted) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      _socketSubscription = wsProvider.socketDataStream.listen((socketData) {
        if (!mounted) return;

        final data = socketData[_exchTsym.token];
        if (data != null) {
          // Update with incremental socket data
          setState(() {
            final lp = data['lp']?.toString();
            final pc = data['pc']?.toString();
            final chng = data['chng']?.toString();

            if (_isValidValue(lp)) _exchTsym.lp = lp;
            if (_isValidValue(pc)) _exchTsym.perChange = pc;
            if (_isValidValue(chng)) _exchTsym.change = chng;

            _updateProfitLossValues();
          });
        }
      });
    } catch (e) {
    }
  }

  // Helper method to check if a value is valid
  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  // Calculate profit and loss values
  void _updateProfitLossValues() {
    final ltp = double.tryParse(_exchTsym.lp ?? "0.0") ?? 0.0;
    // currentQty already includes T1 (max of btstqty/npoadt1qty) from the provider.
    final int totalQty = _holdingData.currentQty ?? 0;
    final avgPrice = double.tryParse(_holdingData.upldprc ?? "0.0") ?? 0.0;

    if (ltp > 0 && totalQty > 0 && avgPrice > 0) {
      // Current value
      _holdingData.currentValue = (ltp * totalQty).toStringAsFixed(2);

      // Profit/Loss
      final pnl = (ltp - avgPrice) * totalQty;
      _exchTsym.profitNloss = pnl.toStringAsFixed(2);

      // P&L Percentage
      if (avgPrice > 0) {
        final pnlPerc = (pnl / (avgPrice * totalQty)) * 100;
        _exchTsym.pNlChng = pnlPerc.toStringAsFixed(2);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final scripInfo = ref.watch(marketWatchProvider);

    DepthInputArgs depthArgs = DepthInputArgs(
        exch: _exchTsym.exch ?? "",
        token: _exchTsym.token ?? "",
        tsym: scripInfo.getQuotes?.tsym ?? '',
        instname: scripInfo.getQuotes?.instname ?? "",
        symbol: scripInfo.getQuotes?.symbol ?? '',
        expDate: scripInfo.getQuotes?.expDate ?? '',
        option: scripInfo.getQuotes?.option ?? '');

    return Material(
      color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
      child: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.isDarkMode
                        ? WebDarkColors.divider
                        : WebColors.divider,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSymbolSection(theme, scripInfo, depthArgs)),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: theme.isDarkMode
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15),
                      highlightColor: theme.isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      onTap: () {
                        // Close drawer - try root navigator first, then regular
                        final navigator = Navigator.of(context, rootNavigator: true);
                        if (navigator.canPop()) {
                          navigator.pop();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          size: 24,
                          color: theme.isDarkMode
                              ? WebDarkColors.iconSecondary
                              : WebColors.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // P&L Section
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _buildPnLSection(theme),
                    ),

                    // Details Section
                    _buildDetailsSection(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolSection(ThemesProvider theme, MarketWatchProvider scripInfo, DepthInputArgs depthArgs) {
    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(),
        borderRadius: BorderRadius.circular(0),
        splashColor: theme.isDarkMode ? colors.primaryDark.withValues(alpha: 0.1) : colors.primaryLight.withValues(alpha: 0.1),
        highlightColor: theme.isDarkMode ? colors.primaryDark.withValues(alpha: 0.2) : colors.primaryLight.withValues(alpha: 0.2),
        onTap: () async {
          Navigator.pop(context);
          await scripInfo.scripdepthsize(false);
          await scripInfo.calldepthApis(context, depthArgs, "");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Symbol and Exchange
            Row(
              children: [
                Text(
                  "${_exchTsym.displayName} ",
                  style: WebTextStyles.dialogTitle(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${_exchTsym.exch}",
                  style: WebTextStyles.dialogTitle(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Price and Change
            Row(
              children: [
                Text(
                  "${_exchTsym.lp != "null" ? _exchTsym.lp ?? _exchTsym.close ?? 0.00 : '0.00'}",
                  style: WebTextStyles.title(
                    isDarkTheme: theme.isDarkMode,
                    color: (_exchTsym.change == "null" || _exchTsym.change == null) ||
                            _exchTsym.change == "0.00"
                        ? theme.isDarkMode
                            ? colors.textSecondaryDark
                            : colors.textSecondaryLight
                        : (_exchTsym.change?.startsWith("-") == true || _exchTsym.perChange?.startsWith("-") == true)
                            ? theme.isDarkMode
                                ? colors.lossDark
                                : colors.lossLight
                            : theme.isDarkMode
                                ? colors.profitDark
                                : colors.profitLight,
                    fontWeight: WebFonts.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${(double.tryParse(_exchTsym.change ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${(double.tryParse(_exchTsym.perChange ?? '0.00') ?? 0.00).toStringAsFixed(2)}%)",
                  style: WebTextStyles.sub(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
                    fontWeight: WebFonts.medium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemesProvider theme, MarketWatchProvider scripInfo) {
    // Check if there's saleable quantity for Exit button
    final hasSaleableQty = (_holdingData.saleableQty ?? 0) > 0;
    // Check if there's current quantity for Add button
    final hasCurrentQty = (_holdingData.currentQty ?? 0) > 0;
    
    // If no quantity at all, don't show buttons
    if (!hasSaleableQty && !hasCurrentQty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Show Exit button only if there's saleable quantity
        if (hasSaleableQty) ...[
          Expanded(
            child: _buildActionButton(
              "Exit",
              false,
              theme,
              _isProcessingSell ? null : _handleSell,
              _isProcessingSell,
            ),
          ),
          if (hasCurrentQty) const SizedBox(width: 12),
        ],
        // Show Add button only if there's current quantity
        if (hasCurrentQty) ...[
          Expanded(
            child: _buildActionButton(
              "Add",
              true,
              theme,
              _isProcessingBuy ? null : _handleBuy,
              _isProcessingBuy,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(String text, bool isPrimary, ThemesProvider theme, VoidCallback? onPressed, bool isLoading) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? colors.primaryLight
              : (theme.isDarkMode
                  ? colors.textSecondaryDark.withValues(alpha: 0.6)
                  : colors.btnBg),
          foregroundColor: isPrimary
              ? colors.colorWhite
              : (theme.isDarkMode ? colors.colorWhite : colors.primaryLight),
          side: isPrimary
              ? null
              : BorderSide(
                  color: colors.primaryLight,
                  width: 1,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        onPressed: onPressed,
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPrimary ? colors.colorWhite : (theme.isDarkMode ? colors.colorWhite : colors.primaryLight),
                  ),
                ),
              )
            : Text(
                text,
                style: TextWidget.textStyle(
                  fontSize: 14,
                  theme: false,
                  color: isPrimary ? colors.colorWhite : (theme.isDarkMode ? colors.colorWhite : colors.primaryLight),
                  fw: 2,
                ),
              ),
      ),
    );
  }

  Widget _buildPledgeUnpledgeButton(ThemesProvider theme, LDProvider ledgerdate) {
    return Center(
      child: InkWell(
        onTap: () async {
          if (ledgerdate.pledgeandunpledge == null) {
            await ledgerdate.getCurrentDate("pandu");
            ledgerdate.fetchpledgeandunpledge(context);
          }
          Navigator.pushNamed(context, Routes.pledgeandun, arguments: "DDDDD");
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: colors.btnOutlinedBorder),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Pledge-Unpledge",
                style: TextWidget.textStyle(
                  fontSize: 14,
                  theme: false,
                  color: colors.btnOutlinedBorder,
                  fw: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPnLSection(ThemesProvider theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              "P&L",
              style: WebTextStyles.title(
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode ? WebDarkColors.textSecondary : WebColors.textSecondary,
                fontWeight: WebFonts.medium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _exchTsym.profitNloss ?? "0.00",
              style: WebTextStyles.head(
                isDarkTheme: theme.isDarkMode,
                color: _getPnLColor(theme),
                fontWeight: WebFonts.medium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPnLColor(ThemesProvider theme) {
    final pnl = _exchTsym.profitNloss ?? "0.00";
    if (pnl.startsWith("-")) {
      return theme.isDarkMode ? colors.lossDark : colors.lossLight;
    } else if (pnl == "0.00") {
      return theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight;
    } else {
      return theme.isDarkMode ? colors.profitDark : colors.profitLight;
    }
  }

  Widget _buildDetailsSection(ThemesProvider theme) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    "Net Qty",
                    "${_holdingData.currentQty ?? 0}",
                    theme,
                  ),
                  _buildInfoRow(
                    "Avg Price",
                    "${_holdingData.upldprc ?? 0}",
                    theme,
                  ),
                  _buildInfoRow(
                    "Product",
                    _holdingData.sPrdtAli != "null" ? "${_holdingData.sPrdtAli}" : "",
                    theme,
                  ),
                  _buildInfoRow(
                    "Non POA / Sell",
                    "${_holdingData.saleableQty ?? 0}/${_holdingData.npoadqty ?? 0}",
                    theme,
                  ),
                ],
              ),
            ),
            // Vertical divider
            Container(
              width: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: theme.isDarkMode
                  ? WebDarkColors.divider
                  : WebColors.divider,
            ),
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    "Invested",
                    "${_holdingData.invested == "0.00" ? _exchTsym.close ?? 0.00 : _holdingData.invested ?? 0.00}",
                    theme,
                  ),
                  _buildInfoRow(
                    "Current Value",
                    (int.parse("${_holdingData.currentQty ?? 0}") *
                            double.parse(_exchTsym.lp?.toString() ?? "0.0"))
                        .toStringAsFixed(2),
                    theme,
                  ),
                  if (_holdingData.btstqty != "0" ||
                      int.parse(_holdingData.npoadt1qty ?? "0") > 0) ...[
                    _buildInfoRow(
                      "T1 Qty",
                      "${math.max(int.parse(_holdingData.btstqty ?? "0"), int.parse(_holdingData.npoadt1qty ?? "0"))}",
                      theme,
                    ),
                  ],
                  if (_holdingData.rpnl != null && _holdingData.rpnl != "0") ...[
                    _buildInfoRow(
                      "Realised P&L",
                      "${_holdingData.rpnl ?? 0}",
                      theme,
                    ),
                  ],
                  _buildInfoRow(
                    "Pledged Qty",
                    "${_holdingData.brkcolqty ?? 0}",
                    theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: WebTextStyles.dialogContent(
              isDarkTheme: theme.isDarkMode,
              color: theme.isDarkMode ? WebDarkColors.textPrimary : WebColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Handle buy button click
  Future<void> _handleBuy() async {
    if (_isProcessingBuy) return;

    try {
      setState(() {
        _isProcessingBuy = true;
      });

      final wsProvider = ref.read(websocketProvider);
      final mwProvider = ref.read(marketWatchProvider);

      wsProvider.establishConnection(
          channelInput: "${_exchTsym.exch}|${_exchTsym.token}#",
          task: "t",  // Touchline for web (place-order screen needs only LTP)
          context: context);

      await mwProvider.fetchScripInfo(
          "${_exchTsym.token}", '${_exchTsym.exch}', context, true);

      if (!mounted) return;

      Navigator.of(context).pop();

      final OrderScreenArgs orderArgs = OrderScreenArgs(
          exchange: '${_exchTsym.exch}',
          tSym: '${_exchTsym.tsym}',
          token: '',
          transType: true,
          prd: '${_holdingData.prd}',
          lotSize: '${_exchTsym.ls}',
          orderTpye: "${_holdingData.sPrdtAli}",
          isExit: false,
          ltp: '${_exchTsym.lp}',
          perChange: '${_exchTsym.perChange}',
          holdQty: '',
          isModify: false,
          raw: {});

      if (mwProvider.scripInfoModel != null) {
        ResponsiveNavigation.toPlaceOrderScreen(context: context, arguments: {
          "orderArg": orderArgs,
          "scripInfo": mwProvider.scripInfoModel!,
          "isBskt": ""
        }).then((_) {
          if (mounted) {
            setState(() {
              _isProcessingBuy = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingBuy = false;
        });
      }
    }
  }

  // Handle sell button click
  Future<void> _handleSell() async {
    if (_isProcessingSell) return;

    try {
      setState(() {
        _isProcessingSell = true;
      });


      if (_holdingData.saleableQty == 0) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialogue(
                scripName: "${_exchTsym.tsym}",
                exch: "${_exchTsym.exch}",
                content:
                    'You are unable to exit because there are no sellable quantity.',
              );
            }).then((_) {
          if (mounted) {
            setState(() {
              _isProcessingSell = false;
            });
          }
        });
        return;
      }

      final wsProvider = ref.read(websocketProvider);
      final mwProvider = ref.read(marketWatchProvider);

      wsProvider.establishConnection(
          channelInput: "${_exchTsym.exch}|${_exchTsym.token}#",
          task: "t",  // Touchline for web (place-order screen needs only LTP)
          context: context);

      await mwProvider.fetchScripInfo(
          "${_exchTsym.token}", '${_exchTsym.exch}', context, true);

      if (!mounted) return;
      Navigator.of(context).pop();

      final OrderScreenArgs orderArgs = OrderScreenArgs(
          exchange: '${_exchTsym.exch}',
          tSym: '${_exchTsym.tsym}',
          token: '',
          transType: false,
          lotSize: '${_exchTsym.ls}',
          isExit: true,
          ltp: '${_exchTsym.lp}',
          perChange: '${_exchTsym.perChange}',
          orderTpye: "${_holdingData.sPrdtAli}",
          holdQty: "${_holdingData.saleableQty ?? 0}",
          isModify: false,
          raw: {});

      if (mwProvider.scripInfoModel != null) {
        ResponsiveNavigation.toPlaceOrderScreen(context: context, arguments: {
          "orderArg": orderArgs,
          "scripInfo": mwProvider.scripInfoModel!,
          "isBskt": ""
        }).then((_) {
          if (mounted) {
            setState(() {
              _isProcessingSell = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingSell = false;
        });
      }
    }
  }

}

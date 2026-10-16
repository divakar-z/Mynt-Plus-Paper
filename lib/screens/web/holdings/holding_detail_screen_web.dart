import '../../../locator/locator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../models/portfolio_model/holdings_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/privacy_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../provider/ledger_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../routes/route_names.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../main.dart' show getNavigatorContext;

class HoldingDetailScreenWeb extends ConsumerStatefulWidget {
  final dynamic holding;
  final ExchTsym exchTsym;
  final BuildContext? parentContext;

  const HoldingDetailScreenWeb({
    super.key,
    required this.holding,
    required this.exchTsym,
    this.parentContext,
  });

  @override
  ConsumerState<HoldingDetailScreenWeb> createState() =>
      _HoldingDetailScreenWebState();
}

class _HoldingDetailScreenWebState
    extends ConsumerState<HoldingDetailScreenWeb> {
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

    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Close icon and "Holding Details" title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolveThemeColor(context,
                      dark: MyntColors.dividerDark, light: MyntColors.divider),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                shadcn.IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => shadcn.closeSheet(context),
                  variance: shadcn.ButtonVariance.ghost,
                  size: shadcn.ButtonSize.small,
                ),
                const SizedBox(width: 12),
                Text(
                  "Holding Details",
                  style: MyntWebTextStyles.title(
                    context,
                    color: resolveThemeColor(context,
                        dark: MyntColors.textPrimaryDark,
                        light: MyntColors.textPrimary),
                    fontWeight: MyntFonts.medium,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Symbol and Price Section
                  _buildSymbolSection(theme, scripInfo, depthArgs),
                  const SizedBox(height: 24),

                  // Action Buttons: Exit and Add
                  _buildActionButtons(theme, scripInfo),
                  const SizedBox(height: 24),

                  // Details Section with Dividers
                  _buildDetailsSection(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolSection(ThemesProvider theme,
      MarketWatchProvider scripInfo, DepthInputArgs depthArgs) {
    // Format instrument text same as hold_table.dart - remove -EQ, show exchange separately
    final symbolText = (_exchTsym.tsym ?? 'N/A').replaceAll("-EQ", "").trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Symbol and Exchange
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              symbolText,
              style: MyntWebTextStyles.head(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.semiBold,
              ),
            ),
            if (_exchTsym.exch != null && _exchTsym.exch!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _exchTsym.exch!,
                style: MyntWebTextStyles.para(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textSecondaryDark,
                      light: MyntColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),

        // Price and Change
        Row(
          children: [
            Text(
              "${_exchTsym.lp != "null" ? _exchTsym.lp ?? _exchTsym.close ?? 0.00 : '0.00'}",
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${(double.tryParse(_exchTsym.change ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${(double.tryParse(_exchTsym.perChange ?? '0.00') ?? 0.00).toStringAsFixed(2)}%)",
              style: MyntWebTextStyles.body(
                context,
                color: (_exchTsym.change?.startsWith("-") == true ||
                        _exchTsym.perChange?.startsWith("-") == true)
                    ? resolveThemeColor(context,
                        dark: MyntColors.lossDark, light: MyntColors.loss)
                    : resolveThemeColor(context,
                        dark: MyntColors.profitDark, light: MyntColors.profit),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      ThemesProvider theme, MarketWatchProvider scripInfo) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: MyntOutlinedButton(
              label: "Exit",
              onPressed: _isProcessingSell ? () {} : _handleSell,
              isFullWidth: true,
              textColor: resolveThemeColor(context,
                  dark: MyntColors.textWhite, light: MyntColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Add button (right) - Styled as primary filled
        Expanded(
          child: SizedBox(
            height: 44,
            child: MyntPrimaryButton(
              label: "Add",
              onPressed: _isProcessingBuy ? () {} : _handleBuy,
              isLoading: _isProcessingBuy,
              isFullWidth: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    bool isPrimary,
    ThemesProvider theme,
    VoidCallback onPressed, {
    bool isLoading = false,
  }) {
    if (isPrimary) {
      return MyntPrimaryButton(
        label: text,
        onPressed: onPressed,
        isLoading: isLoading,
        isFullWidth: true,
      );
    } else {
      return MyntOutlinedButton(
        label: text,
        onPressed: onPressed,
        isLoading: isLoading,
        isFullWidth: true,
      );
    }
  }

  Widget _buildPledgeUnpledgeButton(
      ThemesProvider theme, LDProvider ledgerdate) {
    // Paper-only platform: no real pledge.
    if (isPaperTrading) return const SizedBox.shrink();
    return Center(
      child: MyntOutlinedButton(
        label: "Pledge-Unpledge",
        onPressed: () async {
          if (ledgerdate.pledgeandunpledge == null) {
            await ledgerdate.getCurrentDate("pandu");
            ledgerdate.fetchpledgeandunpledge(context);
          }
          Navigator.pushNamed(context, Routes.pledgeandun, arguments: "DDDDD");
        },
      ),
    );
  }

  Widget _buildPnLSection(ThemesProvider theme) {
    final privacy = ref.watch(privacyProvider);
    final displayValue = privacy.mask(_exchTsym.profitNloss ?? "0.00");

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              "P&L",
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                fontWeight: MyntFonts.medium,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              displayValue,
              style: MyntWebTextStyles.hero(
                context,
                color: _getPnLColor(displayValue),
              ).copyWith(
                fontSize: 24, // High emphasis for P&L
                fontWeight: MyntFonts.semiBold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPnLColor(String value) {
    final numValue = double.tryParse(value) ?? 0.0;

    if (numValue > 0) {
      return resolveThemeColor(context,
          dark: MyntColors.profitDark, light: MyntColors.profit);
    } else if (numValue < 0) {
      return resolveThemeColor(context,
          dark: MyntColors.lossDark, light: MyntColors.loss);
    } else {
      return resolveThemeColor(context,
          dark: MyntColors.textSecondaryDark, light: MyntColors.textSecondary);
    }
  }

  Widget _buildDetailsSection(ThemesProvider theme) {
    final privacy = ref.watch(privacyProvider);
    final pnlValue = privacy.mask(_exchTsym.profitNloss ?? "0.00");
    final pnlPercent = privacy.mask(_exchTsym.pNlChng ?? "0.00");
    final pnlColor = _getPnLColor(pnlValue);

    return Column(
      children: [
        // P&L item
        _rowOfInfoData(
          "P&L",
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pnlValue,
                style: MyntWebTextStyles.body(context,
                    color: pnlColor, fontWeight: MyntFonts.medium),
              ),
              Text(
                "($pnlPercent%)",
                style: MyntWebTextStyles.para(context,
                    color: pnlColor, fontWeight: MyntFonts.medium),
              ),
            ],
          ),
          theme,
        ),
        _rowOfInfoData(
          "Non POA / Sell",
          Text(
            privacy.mask(
                "${_holdingData.npoadqty ?? 0} / ${_holdingData.saleableQty ?? 0}"),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        if (_holdingData.btstqty != "0" ||
            int.parse(_holdingData.npoadt1qty ?? "0") > 0) ...[
          _rowOfInfoData(
            "T1 Qty",
            Text(
              privacy.mask(
                  "${math.max(int.parse(_holdingData.btstqty ?? "0"), int.parse(_holdingData.npoadt1qty ?? "0"))}"),
              style:
                  MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
            ),
            theme,
          ),
        ],
        _rowOfInfoData(
          "Avg price",
          Text(
            privacy.mask("${_holdingData.upldprc ?? 0}"),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        _rowOfInfoData(
          "Product",
        Text(
            (_holdingData.sPrdtAli == null ||
                    _holdingData.sPrdtAli!.isEmpty ||
                    _holdingData.sPrdtAli == "null")
                ? ""
                : _holdingData.sPrdtAli!,
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        _rowOfInfoData(
          "Invested",
          Text(
            privacy.mask(
                "${_holdingData.invested == "0.00" ? _exchTsym.close ?? 0.00 : _holdingData.invested ?? 0.00}"),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        _rowOfInfoData(
          "Current",
          Text(
            privacy.mask((int.parse("${_holdingData.currentQty ?? 0}") *
                    double.parse(_exchTsym.lp?.toString() ?? "0.0"))
                .toStringAsFixed(2)),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        if (_holdingData.rpnl != null && _holdingData.rpnl != "0") ...[
          _rowOfInfoData(
            "Realised P&L",
            Text(
              privacy.mask("${_holdingData.rpnl ?? 0}"),
              style:
                  MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
            ),
            theme,
          ),
        ],
        _rowOfInfoData(
          "Pledged Qty",
          Text(
            privacy.mask("${_holdingData.brkcolqty ?? 0}"),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
        ),
        _rowOfInfoData(
          "Buy / Sell Value",
          Text(
            privacy.mask(
                "${(double.tryParse(_holdingData.invested?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)} / ${(double.tryParse(_holdingData.sellAmt?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}"),
            style:
                MyntWebTextStyles.body(context, fontWeight: MyntFonts.medium),
          ),
          theme,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _rowOfInfoData(String title1, Widget valueWidget, ThemesProvider theme,
      {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title1,
                style: MyntWebTextStyles.body(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                  fontWeight: MyntFonts.medium,
                ),
              ),
              valueWidget,
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: resolveThemeColor(context,
                dark: MyntColors.dividerDark, light: MyntColors.divider),
          ),
      ],
    );
  }

  // Handle buy button click
  Future<void> _handleBuy() async {
    if (_isProcessingBuy) return;


    try {
      setState(() {
        _isProcessingBuy = true;
      });

      // Get root navigator context - this is crucial for overlay access
      final rootContext = getNavigatorContext();
      if (rootContext == null) {
        if (mounted) {
          setState(() {
            _isProcessingBuy = false;
          });
          showResponsiveWarningMessage(
              context, "Unable to access root context");
        }
        return;
      }

      final scripData = ref.read(marketWatchProvider);

      // Add timeout to prevent hanging
      await scripData
          .fetchScripInfo(
        _exchTsym.token ?? "",
        _exchTsym.exch ?? "",
        rootContext,
        true,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Request timed out");
        },
      );


      if (!mounted) {
        return;
      }

      if (scripData.scripInfoModel == null) {
        if (mounted) {
          setState(() {
            _isProcessingBuy = false;
          });
          showResponsiveWarningMessage(
              rootContext, "Unable to fetch scrip information");
        }
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";

      final OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: _exchTsym.exch ?? "",
        tSym: _exchTsym.tsym ?? "",
        isExit: false,
        token: _exchTsym.token ?? "",
        transType: true,
        prd: _holdingData.prd ?? "",
        lotSize: lotSize,
        ltp: _exchTsym.lp ?? "0.00",
        perChange: _exchTsym.perChange ?? "0.00",
        orderTpye: _holdingData.sPrdtAli ?? '',
        holdQty: _holdingData.currentQty?.toString() ?? '',
        isModify: false,
        raw: {},
      );

      // Use parent context (from hold_table) if available, otherwise use root context
      final targetContext = widget.parentContext ?? rootContext;

      if (targetContext.mounted) {
        ResponsiveNavigation.toPlaceOrderScreen(
          context: targetContext,
          arguments: {
            "orderArg": orderArgs,
            "scripInfo": scripData.scripInfoModel!,
            "isBskt": "",
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _isProcessingBuy = false;
          });
        }
        return;
      }

      // Close the sheet AFTER opening the order screen
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      if (mounted) {
        setState(() {
          _isProcessingBuy = false;
        });
      }
    } catch (e, stackTrace) {

      // Try to close sheet on error
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (_) {
          // Ignore sheet close errors
        }
      }

      // Show error using root context
      if (mounted) {
        setState(() {
          _isProcessingBuy = false;
        });

        final rootCtx = getNavigatorContext();
        if (rootCtx != null) {
          try {
            showResponsiveWarningMessage(
                rootCtx, "Error adding holding: ${e.toString()}");
          } catch (displayError) {
          }
        }
      }
    }
  }

  // Handle chart button click (Show market depth)
  Future<void> _handleChartTap() async {
    final scripData = ref.read(marketWatchProvider);
    await scripData.fetchScripQuoteIndex(
      _exchTsym.token ?? "",
      _exchTsym.exch ?? "",
      context,
    );

    final quots = scripData.getQuotes;
    if (quots != null) {
      DepthInputArgs depthArgs = DepthInputArgs(
        exch: quots.exch?.toString() ?? "",
        token: quots.token?.toString() ?? "",
        tsym: quots.tsym?.toString() ?? "",
        instname: quots.instname?.toString() ?? "",
        symbol: quots.symbol?.toString() ?? "",
        expDate: quots.expDate?.toString() ?? "",
        option: quots.option?.toString() ?? "",
      );
      scripData.scripdepthsize(false);
      await scripData.calldepthApis(context, depthArgs, "");
    }
  }

  // Handle sell button click
  Future<void> _handleSell() async {
    if (_isProcessingSell) return;


    try {
      setState(() {
        _isProcessingSell = true;
      });

      // Get root navigator context - this is crucial for overlay access
      final rootContext = getNavigatorContext();
      if (rootContext == null) {
        if (mounted) {
          setState(() {
            _isProcessingSell = false;
          });
          showResponsiveWarningMessage(
              context, "Unable to access root context");
        }
        return;
      }

      if (_holdingData.saleableQty == null || _holdingData.saleableQty == 0) {
        if (mounted) {
          setState(() {
            _isProcessingSell = false;
          });

          // Close the sheet FIRST before showing the dialog
          try {
            shadcn.closeSheet(context);
          } catch (e) {
          }

          // Small delay to ensure sheet is closed before showing dialog
          await Future.delayed(const Duration(milliseconds: 100));

          if (rootContext.mounted) {
            showGeneralDialog(
              context: rootContext,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(rootContext).modalBarrierDismissLabel,
              barrierColor: Colors.black.withValues(alpha: 0.3),
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (dialogContext, animation, secondaryAnimation) {
                return Center(
                  child: shadcn.Card(
                    borderRadius: BorderRadius.circular(8),
                    padding: EdgeInsets.zero,
                    child: Container(
                      width: 400,
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: shadcn.Theme.of(dialogContext)
                                      .colorScheme
                                      .border,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Exit',
                                  style: MyntWebTextStyles.title(
                                    dialogContext,
                                    color: resolveThemeColor(
                                      dialogContext,
                                      dark: MyntColors.textPrimaryDark,
                                      light: MyntColors.textPrimary,
                                    ),
                                  ),
                                ),
                                MyntCloseButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                ),
                              ],
                            ),
                          ),
                          // Content
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'You are unable to exit because there are no sellable quantity.',
                                    textAlign: TextAlign.center,
                                    style: MyntWebTextStyles.body(
                                      dialogContext,
                                      fontWeight: FontWeight.w500,
                                      color: resolveThemeColor(
                                        dialogContext,
                                        dark: MyntColors.textPrimaryDark,
                                        light: MyntColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  MyntPrimaryButton(
                                    size: MyntButtonSize.large,
                                    label: 'Ok',
                                    isFullWidth: true,
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              transitionBuilder:
                  (dialogContext, animation, secondaryAnimation, child) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );

                return FadeTransition(
                  opacity: curvedAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0)
                        .animate(curvedAnimation),
                    child: child,
                  ),
                );
              },
            );
          }
        }
        return;
      }

      final scripData = ref.read(marketWatchProvider);

      // Add timeout to prevent hanging
      await scripData
          .fetchScripInfo(
        _exchTsym.token ?? "",
        _exchTsym.exch ?? "",
        rootContext,
        true,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Request timed out");
        },
      );


      if (!mounted) {
        return;
      }

      if (scripData.scripInfoModel == null) {
        if (mounted) {
          setState(() {
            _isProcessingSell = false;
          });
          showResponsiveWarningMessage(
              rootContext, "Unable to fetch scrip information");
        }
        return;
      }

      final lotSize = scripData.scripInfoModel!.ls?.toString() ?? "1";

      final OrderScreenArgs orderArgs = OrderScreenArgs(
        exchange: _exchTsym.exch ?? "",
        tSym: _exchTsym.tsym ?? "",
        isExit: true,
        token: _exchTsym.token ?? "",
        transType: false,
        prd: _holdingData.prd ?? "",
        lotSize: lotSize,
        ltp: _exchTsym.lp ?? "0.00",
        perChange: _exchTsym.perChange ?? "0.00",
        orderTpye: _holdingData.sPrdtAli ?? '',
        holdQty: _holdingData.saleableQty?.toString() ?? '0',
        isModify: false,
        raw: {},
      );

      // Use parent context (from hold_table) if available, otherwise use root context
      final targetContext = widget.parentContext ?? rootContext;

      if (targetContext.mounted) {
        ResponsiveNavigation.toPlaceOrderScreen(
          context: targetContext,
          arguments: {
            "orderArg": orderArgs,
            "scripInfo": scripData.scripInfoModel!,
            "isBskt": "",
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _isProcessingSell = false;
          });
        }
        return;
      }

      // Close the sheet AFTER opening the order screen
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      if (mounted) {
        setState(() {
          _isProcessingSell = false;
        });
      }
    } catch (e, stackTrace) {

      // Try to close sheet on error
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (_) {
          // Ignore sheet close errors
        }
      }

      // Show error using root context
      if (mounted) {
        setState(() {
          _isProcessingSell = false;
        });

        final rootCtx = getNavigatorContext();
        if (rootCtx != null) {
          try {
            showResponsiveWarningMessage(
                rootCtx, "Error exiting holding: ${e.toString()}");
          } catch (displayError) {
          }
        }
      }
    }
  }
}

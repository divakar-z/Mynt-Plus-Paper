import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../../../models/order_book_model/trade_book_model.dart';
import '../../../../models/order_book_model/order_book_model.dart';
import '../../../../provider/thems.dart';
import '../../../../provider/websocket_provider.dart';
import '../../../../res/mynt_web_text_styles.dart';
import '../../../../res/mynt_web_color_styles.dart';
import '../../../../sharedWidget/functions.dart';
import '../refactored/utils/cell_formatters.dart';
import '../../../../sharedWidget/common_buttons_web.dart';
import '../../../../provider/market_watch_provider.dart';
import '../../../../utils/responsive_navigation.dart';
import '../../../../utils/responsive_snackbar.dart';
import '../../../../main.dart' show getNavigatorContext;

class TradeDetailScreenWeb extends ConsumerStatefulWidget {
  final TradeBookModel trade;
  final BuildContext? parentContext;

  const TradeDetailScreenWeb({
    super.key,
    required this.trade,
    this.parentContext,
  });

  @override
  ConsumerState<TradeDetailScreenWeb> createState() =>
      _TradeDetailScreenWebState();
}

class _TradeDetailScreenWebState extends ConsumerState<TradeDetailScreenWeb> {
  bool _isProcessingRepeat = false;
  StreamSubscription? _socketSubscription;

  // Live market data from WebSocket
  String? _ltp;
  String? _change;
  String? _perChange;

  @override
  void initState() {
    super.initState();
    // Initialize with trade data values
    _ltp = widget.trade.ltp;
    _change = widget.trade.change;
    _perChange = widget.trade.perChange;
  }

  bool _didInitDependencies = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didInitDependencies) {
      _didInitDependencies = true;
      Future.microtask(() {
        if (mounted) {
          _setupSocketSubscription();
        }
      });
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  // Set up socket subscription for real-time LTP, change, percentage updates
  void _setupSocketSubscription() {
    if (!mounted) return;

    final token = widget.trade.token;
    if (token == null || token.isEmpty) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      _socketSubscription = wsProvider.socketDataStream.listen((socketData) {
        if (!mounted) return;

        final data = socketData[token];
        if (data != null) {
          setState(() {
            final lp = data['lp']?.toString();
            final pc = data['pc']?.toString();
            final chng = data['chng']?.toString();

            if (_isValidValue(lp)) _ltp = lp;
            if (_isPresent(pc)) _perChange = pc;
            if (_isPresent(chng)) _change = chng;
          });
        }
      });
    } catch (e) {
    }
  }

  // Helper method to check if a value is valid
  // Change / % change may legitimately be 0.00 (back to flat); only a zero
  // LTP is a placeholder. Rejecting "0.00" left the last non-zero change.
  bool _isPresent(String? value) =>
      value != null && value != "null" && value.isNotEmpty;

  bool _isValidValue(String? value) {
    return value != null &&
        value != "null" &&
        value != "0" &&
        value != "0.0" &&
        value != "0.00";
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Trade Details title
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: resolveThemeColor(
                        context,
                        dark: MyntColors.dividerDark,
                        light: MyntColors.divider,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        shadcn.closeSheet(context);
                      },
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Trade Details',
                      style: MyntWebTextStyles.title(
                        context,
                        color: resolveThemeColor(
                          context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSymbolSection(theme),
                        const SizedBox(height: 16),
                        // Action Buttons (Repeat Order)
                        _buildActionButtons(theme),
                        // Details Section
                        _buildDetailsSection(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSymbolSection(ThemesProvider theme) {
    // Prefer the backend display name (DerivativeMaster) for derivatives.
    final master = widget.trade.masterName;
    final symbol = widget.trade.symbol?.replaceAll("-EQ", "") ??
        widget.trade.tsym?.replaceAll("-EQ", "") ??
        '';
    final expDate = widget.trade.expDate ?? '';
    final option = widget.trade.option ?? '';
    final displayText = master ?? '$symbol $expDate $option'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Symbol
        Row(
          children: [
            Flexible(
              child: Text(
                displayText.isNotEmpty
                    ? displayText
                    : (widget.trade.tsym ?? 'N/A'),
                style: MyntWebTextStyles.title(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.trade.exch ?? '',
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),

        // Price - show live LTP from WebSocket, fallback to trade price (avgprc)
        Row(
          children: [
            Text(
              _ltp ?? widget.trade.avgprc?.toString() ?? '0.00',
              style: MyntWebTextStyles.title(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                fontWeight: MyntFonts.medium,
              ),
            ),
            // Show live change and percentage from WebSocket
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final change = double.tryParse(_change ?? '0') ?? 0.0;
                final perChange = double.tryParse(_perChange ?? '0') ?? 0.0;
                final isPositive = change >= 0;
                final changeText = "${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${perChange >= 0 ? '+' : ''}${perChange.toStringAsFixed(2)}%)";

                return Text(
                  changeText,
                  style: MyntWebTextStyles.bodySmall(
                    context,
                    color: change == 0
                        ? resolveThemeColor(context,
                            dark: MyntColors.textSecondaryDark,
                            light: MyntColors.textSecondary)
                        : isPositive
                            ? resolveThemeColor(context,
                                dark: MyntColors.profitDark,
                                light: MyntColors.profit)
                            : resolveThemeColor(context,
                                dark: MyntColors.lossDark,
                                light: MyntColors.loss),
                    fontWeight: MyntFonts.medium,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Repeat Order button (matching order detail pattern)
          Row(
            children: [
              Expanded(
                child: MyntOutlinedButton(
                  label: "Repeat Order",
                  isLoading: _isProcessingRepeat,
                  isFullWidth: true,
                  onPressed: _handleRepeatOrder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(ThemesProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowOfInfoDataWithColor(
              "Status",
              "COMPLETE",
              theme,
              resolveThemeColor(context,
                  dark: MyntColors.profitDark,
                  light: MyntColors
                      .profit)), // Trade usually means complete/filled

          _rowOfInfoData(
              "Type", widget.trade.trantype == "S" ? "Sell" : "Buy", theme),

          _rowOfInfoData(
            "Qty",
            _formatTradeQty(),
            theme,
          ),
          _rowOfInfoData(
            "Price",
            widget.trade.flprc?.toString() ??
                widget.trade.avgprc?.toString() ??
                '0.00',
            theme,
          ),
          _rowOfInfoData(
            "Trade Value",
            CellFormatters.calculateTradeValue(widget.trade),
            theme,
          ),
          _rowOfInfoData(
            "Product / Type",
            "${widget.trade.sPrdtAli ?? '-'} / ${widget.trade.prctyp ?? '-'}",
            theme,
          ),
          // One order can fill in several trades that share an Order Id, so
          // show the Trade ID (same label as the Trade table column).
          _rowOfInfoData(
            "Trade ID",
            widget.trade.flid?.toString() ?? '-',
            theme,
          ),
          _rowOfInfoData(
            "Order Id",
            widget.trade.norenordno?.toString() ?? '-',
            theme,
          ),
          /*
          _rowOfInfoData(
            "Fill ID",
            widget.trade.flid?.toString() ?? '-',
            theme,
          ),
          */
          _rowOfInfoData(
            "Date & Time",
            formatDateTime(value: widget.trade.norentm ?? '-'),
            theme,
          ),
          /*
          _rowOfInfoData(
            "Status",
            widget.trade.stat ?? '-',
            theme,
          ),
          */
        ],
      ),
    );
  }

  // TC_327.6: Qty shown as "filled / total" LOTS for MCX (raw units / lot size),
  // matching the Trade list and the Executed popup. Non-MCX uses lot size 1, so
  // it shows raw filled / total. Mirrors trade_book_screen._formatTradeQty.
  // (Trade Value is left as-is — it is money, not a quantity.)
  String _formatTradeQty() {
    final rawFilled = int.tryParse(widget.trade.fillshares?.toString() ??
            widget.trade.flqty?.toString() ??
            '0') ??
        0;
    final rawQty = int.tryParse(widget.trade.qty?.toString() ?? '0') ?? 0;
    final lotSize = widget.trade.exch == 'MCX'
        ? (int.tryParse(widget.trade.ls?.toString() ?? '1') ?? 1)
        : 1;
    final safeLot = lotSize > 0 ? lotSize : 1;
    return '${rawFilled ~/ safeLot} / ${rawQty ~/ safeLot}';
  }

  Widget _rowOfInfoData(String title1, String value1, ThemesProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title1,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value1,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowOfInfoDataWithColor(
      String title, String value, ThemesProvider theme, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: resolveThemeColor(
              context,
              dark: MyntColors.dividerDark,
              light: MyntColors.divider,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: MyntWebTextStyles.body(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: valueColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: MyntWebTextStyles.body(
                  context,
                  color: valueColor,
                  fontWeight: MyntFonts.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRepeatOrder() async {
    if (_isProcessingRepeat) return;

    try {
      setState(() {
        _isProcessingRepeat = true;
      });

      final targetContext = widget.parentContext ??
          getNavigatorContext(); // Use widget.parentContext which works in this screen or fallback

      // If widget.parentContext is null (it's optional in widget), we need a valid context.
      // Usually passed in or we can try 'context' if available, but repeat order often needs root or scaffold context.
      final safeContext = targetContext ?? context;

      await ref.read(marketWatchProvider).fetchScripInfo(
            "${widget.trade.token}",
            "${widget.trade.exch}",
            safeContext,
            true,
          );

      if (!mounted) return;

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        if (mounted) {
          setState(() {
            _isProcessingRepeat = false;
          });
          ResponsiveSnackBar.showError(
              safeContext, 'Unable to fetch scrip information');
        }
        return;
      }

      // Close the sheet first
      if (mounted) {
        shadcn.closeSheet(context);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to place order screen
      if (safeContext.mounted) {
        ResponsiveNavigation.toPlaceOrderScreen(
          context: safeContext,
          arguments: {
            "orderArg": _createOrderArgs(widget.trade),
            "scripInfo": scripInfo,
            "isBskt": '',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to open place order: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRepeat = false;
        });
      }
    }
  }

  OrderScreenArgs _createOrderArgs(TradeBookModel tradeData) {
    // Get LTP, fallback to trade info if available or "0.00"
    String ltpValue = "0.00";
    if (tradeData.ltp != null && tradeData.ltp.toString() != "null") {
      ltpValue = tradeData.ltp.toString();
    } else if (tradeData.avgprc != null &&
        tradeData.avgprc.toString() != "null") {
      ltpValue = tradeData.avgprc.toString();
    }

    return OrderScreenArgs(
      exchange: tradeData.exch ?? '',
      tSym: tradeData.tsym ?? '',
      isExit: false,
      token: tradeData.token ?? '',
      transType: tradeData.trantype == 'B' ? true : false,
      prd: tradeData.prd ?? tradeData.sPrdtAli ?? 'CNC',
      lotSize: tradeData.ls ?? '1',
      ltp: ltpValue,
      perChange: tradeData.change ?? "0.00",
      orderTpye: '',
      holdQty: '',
      isModify: false,
      raw: tradeData.toJson(),
    );
  }
}

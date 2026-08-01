import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../../../models/order_book_model/order_book_model.dart';
import '../../../models/marketwatch_model/get_quotes.dart';
import '../../../provider/market_watch_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../provider/websocket_provider.dart';
import '../../../res/mynt_web_text_styles.dart';
import '../../../res/mynt_web_color_styles.dart';
import '../../../sharedWidget/functions.dart';
import '../../../utils/responsive_navigation.dart';
import '../../../utils/responsive_snackbar.dart';
import '../../../sharedWidget/common_buttons_web.dart';
import '../../../main.dart' show getNavigatorContext;
import '../order/modify_place_order_web_screen.dart';

class OrderBookDetailScreenWeb extends ConsumerStatefulWidget {
  final OrderBookModel orderBookData;
  final BuildContext? parentContext;

  const OrderBookDetailScreenWeb({
    super.key,
    required this.orderBookData,
    this.parentContext,
  });

  @override
  ConsumerState<OrderBookDetailScreenWeb> createState() =>
      _OrderBookDetailScreenWebState();
}

class _OrderBookDetailScreenWebState
    extends ConsumerState<OrderBookDetailScreenWeb> {
  late OrderBookModel _orderData;
  StreamSubscription? _socketSubscription;

  // Track processing states
  bool _isProcessingCancel = false;
  bool _isProcessingModify = false;
  bool _isProcessingRepeat = false;
  bool _isProcessingExit = false;
  bool _hasFetchedOrderHistory = false;

  @override
  void initState() {
    super.initState();
    _orderData = _copyOrderData(widget.orderBookData);
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
          _fetchOrderHistory();
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

  // Create a copy of the OrderBookModel to avoid modifying the original
  OrderBookModel _copyOrderData(OrderBookModel original) {
    final copy = OrderBookModel();
    copy.token = original.token;
    copy.exch = original.exch;
    copy.tsym = original.tsym;
    copy.symbol = original.symbol;
    copy.expDate = original.expDate;
    copy.option = original.option;
    copy.ltp = original.ltp;
    copy.perChange = original.perChange;
    copy.change = original.change;
    copy.close = original.close;
    copy.c = original.c;
    copy.status = original.status;
    copy.trantype = original.trantype;
    copy.qty = original.qty;
    copy.prc = original.prc;
    copy.avgprc = original.avgprc;
    copy.trgprc = original.trgprc;
    copy.sPrdtAli = original.sPrdtAli;
    copy.prctyp = original.prctyp;
    copy.norenordno = original.norenordno;
    copy.exchordid = original.exchordid;
    copy.norentm = original.norentm;
    copy.rejreason = original.rejreason;
    copy.fillshares = original.fillshares;
    copy.rqty = original.rqty;
    copy.dscqty = original.dscqty;
    copy.ls = original.ls;
    copy.mktProtection = original.mktProtection;
    copy.amo = original.amo;
    copy.snonum = original.snonum;
    copy.prd = original.prd;
    copy.ret = original.ret;
    // BO/CO order fields for Target and Stop Loss
    copy.blprc = original.blprc;
    copy.bpprc = original.bpprc;
    return copy;
  }

  // Set up socket subscription for real-time updates
  void _setupSocketSubscription() {
    if (!mounted) return;

    try {
      final wsProvider = ref.read(websocketProvider);

      _socketSubscription = wsProvider.socketDataStream.listen((socketData) {
        if (!mounted) return;

        final data = socketData[_orderData.token];
        if (data != null) {
          setState(() {
            final lp = data['lp']?.toString();
            final pc = data['pc']?.toString();
            final chng = data['chng']?.toString();

            if (_isValidValue(lp)) _orderData.ltp = lp;
            if (_isValidValue(pc)) _orderData.perChange = pc;
            if (_isValidValue(chng)) _orderData.change = chng;
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

  // Fetch order history
  void _fetchOrderHistory() {
    if (_hasFetchedOrderHistory) return;

    _hasFetchedOrderHistory = true;
    final orderNumber = widget.orderBookData.norenordno?.toString() ?? '';
    if (orderNumber.isNotEmpty && mounted) {
      ref.read(orderProvider).fetchOrderHistory(orderNumber, context);
      ref.read(orderProvider).showorderHistory(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    final scripInfo = ref.watch(marketWatchProvider);
    final orderHistory = ref.watch(orderProvider).orderHistoryModel;

    DepthInputArgs depthArgs = DepthInputArgs(
      exch: _orderData.exch ?? "",
      token: _orderData.token ?? "",
      tsym: scripInfo.getQuotes?.tsym ?? '',
      instname: scripInfo.getQuotes?.instname ?? "",
      symbol: scripInfo.getQuotes?.symbol ?? '',
      expDate: scripInfo.getQuotes?.expDate ?? '',
      option: scripInfo.getQuotes?.option ?? '',
    );

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
              // Header with Order Details title
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                      'Order Details',
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
                        // Symbol Info Section
                        _buildSymbolSection(theme, scripInfo, depthArgs),
                        const SizedBox(height: 16),
                        // Action Buttons
                        _buildActionButtons(theme),
                        // Order History Button Stub (Visual only if needed, keeping functionality simple for now)
                        // If user wants exactly like image, we might need to hide the full list and show a button.
                        // For now keeping the full list at the bottom but checking if we need the button visually.

                        // Details Section
                        _buildDetailsSection(theme),

                        // Reason Section
                        if (_orderData.rejreason != null &&
                            _orderData.rejreason!.isNotEmpty) ...[
                          _buildReasonWidget(theme, _orderData.rejreason!),
                        ],

                        // Order History Header & Section
                        if (orderHistory != null &&
                            orderHistory.isNotEmpty &&
                            orderHistory[0].stat != "Not_Ok") ...[
                          const SizedBox(height: 24),
                          // Center(
                          //     child: TextButton.icon(
                          //   onPressed: () {
                          //     // Optional: Toggle history visibility or scroll to it
                          //   },
                          //   icon: Icon(Icons.list, color: MyntColors.primary),
                          //   label: Text(
                          //     'Order History',
                          //     style: MyntWebTextStyles.bodySmall(
                          //       context,
                          //       color: MyntColors.primary,
                          //       fontWeight: MyntFonts.semiBold,
                          //     ),
                          //   ),
                          // )),
                          const SizedBox(height: 12),
                          _buildOrderHistorySection(theme, orderHistory),
                        ],
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

  Widget _buildSymbolSection(ThemesProvider theme,
      MarketWatchProvider scripInfo, DepthInputArgs depthArgs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Symbol and Exchange
        Row(
          children: [
            Flexible(
              child: Text(
                "${_orderData.displayName} ",
                style: MyntWebTextStyles.title(
                  context,
                  color: resolveThemeColor(context,
                      dark: MyntColors.textPrimaryDark,
                      light: MyntColors.textPrimary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // const SizedBox(width: 4),
            // Text(
            //   "${_orderData.exch}",
            //   style: WebTextStyles.dialogTitle(
            //     isDarkTheme: theme.isDarkMode,
            //     color: colorScheme.mutedForeground,
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 8),

        // Price and Change
        Row(
          children: [
            Text(
              _orderData.ltp ?? _orderData.close ?? '0.00',
              style: MyntWebTextStyles.title(
                context,
                color: (_orderData.change == "null" ||
                            _orderData.change == null) ||
                        _orderData.change == "0.00"
                    ? resolveThemeColor(context,
                        dark: MyntColors.textSecondaryDark,
                        light: MyntColors.textSecondary)
                    : (_orderData.change?.startsWith("-") == true ||
                            _orderData.perChange?.startsWith("-") == true)
                        ? resolveThemeColor(context,
                            dark: MyntColors.lossDark, light: MyntColors.loss)
                        : resolveThemeColor(context,
                            dark: MyntColors.profitDark,
                            light: MyntColors.profit),
                fontWeight: MyntFonts.medium,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "${(double.tryParse(_orderData.change ?? '0.00') ?? 0.00).toStringAsFixed(2)} (${_orderData.perChange ?? '0.00'}%)",
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemesProvider theme) {
    final isPending = _orderData.status == "PENDING" ||
        _orderData.status == "OPEN" ||
        _orderData.status == "TRIGGER_PENDING";

    // Check if this is a BO/CO order with snonum
    final isBOCOWithSnonum = (_orderData.sPrdtAli == "BO" || _orderData.sPrdtAli == "CO") &&
        _orderData.snonum != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPending) ...[
            // Modify + Exit/Cancel buttons
            Row(
              children: [
                // Modify button on the left
                Expanded(
                  child: _buildActionButton(
                    "Modify",
                    true,
                    theme,
                    _handleModifyOrder,
                    isLoading: _isProcessingModify,
                  ),
                ),
                const SizedBox(width: 12),
                // Exit/Cancel button on the right
                if (isBOCOWithSnonum) ...[
                  Expanded(
                    child: _buildActionButton(
                      "Exit",
                      false,
                      theme,
                      _handleExitOrder,
                      isLoading: _isProcessingExit,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _buildActionButton(
                      "Cancel",
                      false,
                      theme,
                      _handleCancelOrder,
                      isLoading: _isProcessingCancel,
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            // Repeat Order button
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "Repeat Order",
                    false,
                    theme,
                    _handleRepeatOrder,
                    isLoading: _isProcessingRepeat,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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

  Widget _buildDetailsSection(ThemesProvider theme) {
    final statusText = _getStatusText(_orderData.status);
    final statusColor = _orderData.status == "COMPLETE"
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : _orderData.status == "OPEN"
            ? resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary)
            : (_orderData.status == "CANCELED" ||
                    _orderData.status == "REJECTED")
                ? resolveThemeColor(context,
                    dark: MyntColors.lossDark, light: MyntColors.loss)
                : resolveThemeColor(context,
                    dark: MyntColors.textSecondaryDark,
                    light: MyntColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowOfInfoDataWithColor("Status", statusText, theme, statusColor),
          _rowOfInfoData(
              "Type", _orderData.trantype == "B" ? "Buy" : "Sell", theme),
          _rowOfInfoData("Qty", _getQuantityDisplay(_orderData), theme),
          _rowOfInfoData("Price", _orderData.prc ?? "-", theme),
          _rowOfInfoData("Avg Price", _orderData.avgprc ?? "0.00", theme),
          _rowOfInfoData("Trigger Price", _orderData.trgprc ?? "0.00", theme),
          _rowOfInfoData("Product / Type",
              "${_orderData.sPrdtAli} / ${_orderData.prctyp ?? "-"}", theme),
          _rowOfInfoData(
              "Market Protection", _orderData.mktProtection ?? "-", theme),
          _rowOfInfoData("AMO", _orderData.amo ?? "-", theme),
          _rowOfInfoData("Order Id", _orderData.norenordno ?? "-", theme),
          _rowOfInfoData("Exchange", _orderData.exchordid ?? "-", theme),
          _rowOfInfoData("Date & Time",
              formatDateTime(value: _orderData.norentm ?? "-"), theme),
        ],
      ),
    );
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
                    dark: MyntColors
                        .textPrimaryDark, // Changed to Primary as per image usually labels are dark/visible
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
                color: valueColor.withOpacity(0.1),
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

  Widget _buildReasonWidget(ThemesProvider theme, String reason) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Reason",
            style: MyntWebTextStyles.bodySmall(
              context,
              color: resolveThemeColor(context,
                  dark: MyntColors.textPrimaryDark,
                  light: MyntColors.textPrimary),
              fontWeight: MyntFonts.medium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              reason,
              textAlign: TextAlign.end,
              style: MyntWebTextStyles.bodySmall(
                context,
                color: resolveThemeColor(context,
                    dark: MyntColors.textPrimaryDark,
                    light: MyntColors.textPrimary),
                fontWeight: MyntFonts.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistorySection(ThemesProvider theme, List orderHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          reverse: true,
          itemCount: orderHistory.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int index) {
            return _buildOrderHistoryTimelineItem(
              theme,
              orderHistory[index],
              orderHistory.length - 1 == index,
              index == 0,
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderHistoryTimelineItem(
    ThemesProvider theme,
    dynamic orderHistoryData,
    bool isFirst,
    bool isLast,
  ) {
    final status = orderHistoryData.status ?? '';
    final lineColor = status == "COMPLETE"
        ? resolveThemeColor(context,
            dark: MyntColors.profitDark, light: MyntColors.profit)
        : (status == "CANCELED" || status == "REJECTED")
            ? resolveThemeColor(context,
                dark: MyntColors.lossDark, light: MyntColors.loss)
            : resolveThemeColor(context,
                dark: MyntColors.primaryDark, light: MyntColors.primary);

    final statusText = orderHistoryData.stIntrn != null
        ? "${orderHistoryData.stIntrn![0].toUpperCase()}${orderHistoryData.stIntrn!.substring(1).toLowerCase().replaceAll("_", " ")}"
        : 'Unknown';
    final timeText = orderHistoryData.norentm != null
        ? formatDateTime(value: orderHistoryData.norentm!)
        : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 65,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Spacer to align indicator with text
              const SizedBox(height: 0),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: lineColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == "COMPLETE"
                      ? Icons.done
                      : (status == "CANCELED" || status == "REJECTED")
                          ? Icons.clear
                          : Icons.more_horiz_outlined,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 45,
                  color: lineColor,
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content - aligned with indicator
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    style: MyntWebTextStyles.bodySmall(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textPrimaryDark,
                          light: MyntColors.textPrimary),
                      fontWeight: MyntFonts.regular,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: MyntWebTextStyles.para(
                      context,
                      color: resolveThemeColor(context,
                          dark: MyntColors.textSecondaryDark,
                          light: MyntColors.textSecondary),
                      fontWeight: MyntFonts.regular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Unknown';
    return '${status[0].toUpperCase()}${status.replaceAll("_", " ").substring(1)}';
  }

  String _getQuantityDisplay(OrderBookModel order) {
    try {
      int filledQty = 0;
      if (order.status != "COMPLETE" &&
          (order.fillshares?.isNotEmpty ?? false)) {
        filledQty = int.tryParse(order.fillshares.toString()) ?? 0;
      } else if (order.status == "COMPLETE") {
        filledQty = int.tryParse(order.rqty.toString()) ?? 0;
      } else {
        filledQty = int.tryParse(order.dscqty.toString()) ?? 0;
      }

      int lotSize =
          order.exch == 'MCX' ? (int.tryParse(order.ls.toString()) ?? 1) : 1;
      int displayFilledQty = filledQty ~/ lotSize;
      int displayTotalQty =
          (int.tryParse(order.qty.toString()) ?? 0) ~/ lotSize;

      return "$displayFilledQty / $displayTotalQty";
    } catch (e) {
      return order.qty?.toString() ?? '0';
    }
  }

  // Action handlers
  Future<void> _handleCancelOrder() async {
    if (_isProcessingCancel) return;

    try {
      setState(() {
        _isProcessingCancel = true;
      });

      final targetContext =
          widget.parentContext ?? getNavigatorContext();
      if (targetContext == null) {
        if (mounted) {
          setState(() {
            _isProcessingCancel = false;
          });
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }

      // Save provider reference and order data BEFORE closing sheet
      // (widget might be disposed after sheet closes)
      final orderProviderRef = ref.read(orderProvider);
      final theme = ref.read(themeProvider);
      final orderNo = _orderData.norenordno;

      // Close the sheet first
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      // Wait for sheet to close, then show dialog
      await Future.delayed(const Duration(milliseconds: 150));

      // Show dialog after sheet closes
      final shouldCancel = await _showCancelOrderDialog(theme, targetContext);

      if (shouldCancel != true) {
        return;
      }

      // Use saved provider reference instead of ref.read()
      await orderProviderRef.fetchOrderCancel(
            "$orderNo",
            targetContext,
            true,
          );
    } catch (e) {
      final rootCtx = getNavigatorContext();
      if (rootCtx != null && rootCtx.mounted) {
        ResponsiveSnackBar.showError(rootCtx, 'Failed to cancel order');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCancel = false;
        });
      }
    }
  }

  Future<void> _handleExitOrder() async {
    if (_isProcessingExit) return;

    try {
      setState(() {
        _isProcessingExit = true;
      });

      final targetContext = widget.parentContext ?? getNavigatorContext();
      if (targetContext == null) {
        if (mounted) {
          setState(() {
            _isProcessingExit = false;
          });
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }

      // Save provider reference and order data BEFORE closing sheet
      final orderProviderRef = ref.read(orderProvider);
      final theme = ref.read(themeProvider);
      final snonum = _orderData.snonum;
      final prd = _orderData.prd;

      // Close the sheet first
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      // Wait for sheet to close, then show dialog
      await Future.delayed(const Duration(milliseconds: 150));

      // Show exit confirmation dialog after sheet closes
      final shouldExit = await _showExitPositionDialog(theme, targetContext);

      if (shouldExit != true) {
        return;
      }

      // Use saved provider reference instead of ref.read()
      await orderProviderRef.fetchExitSNOOrd(
        "$snonum",
        "$prd",
        targetContext,
        true,
      );
    } catch (e) {
      final rootCtx = getNavigatorContext();
      if (rootCtx != null && rootCtx.mounted) {
        ResponsiveSnackBar.showError(rootCtx, 'Failed to exit order');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingExit = false;
        });
      }
    }
  }

  Future<void> _handleModifyOrder() async {
    if (_isProcessingModify) return;

    try {
      setState(() {
        _isProcessingModify = true;
      });


      // Use same pattern as repeat order - fallback to rootNavigatorKey if parentContext is null
      final targetContext =
          widget.parentContext ?? getNavigatorContext();
      if (targetContext == null || !targetContext.mounted) {
        if (mounted) {
          setState(() {
            _isProcessingModify = false;
          });
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }


      await ref.read(marketWatchProvider).fetchScripInfo(
            "${_orderData.token}",
            '${_orderData.exch}',
            targetContext,
            true,
          );

      if (!mounted) {
        return;
      }

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        if (mounted) {
          setState(() {
            _isProcessingModify = false;
          });
          ResponsiveSnackBar.showError(
              targetContext, 'Unable to fetch scrip information');
        }
        return;
      }


      // Create orderArgs before closing sheet (while we still have valid context)
      final orderArgs = _createOrderArgs(_orderData);

      // Close the sheet first (like repeat order does)
      if (mounted) {
        try {
          shadcn.closeSheet(context);
        } catch (e) {
          // Ignore sheet close errors
        }
      }

      // Wait for sheet to close - use same delay as repeat order
      await Future.delayed(const Duration(milliseconds: 100));

      // Check targetContext is still valid after sheet close
      // Use targetContext (parent context from table) - same as hover modify uses
      // The hover modify uses 'context' which is the table context, same as targetContext here
      if (!targetContext.mounted) {
        if (mounted) {
          setState(() {
            _isProcessingModify = false;
          });
        }
        return;
      }


      // Use targetContext for overlay - same as hover modify button uses 'context'
      // This is the table context which has the overlay
      ModifyPlaceOrderScreenWeb.showDraggable(
        context: targetContext,
        modifyOrderArgs: _orderData,
        orderArg: orderArgs,
        scripInfo: scripInfo,
      );

    } catch (e) {
      final rootCtx = getNavigatorContext();
      if (rootCtx != null && rootCtx.mounted) {
        ResponsiveSnackBar.showError(
            rootCtx, 'Failed to open modify order: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingModify = false;
        });
      }
    }
  }

  Future<void> _handleRepeatOrder() async {
    if (_isProcessingRepeat) return;

    try {
      setState(() {
        _isProcessingRepeat = true;
      });

      final targetContext =
          widget.parentContext ?? getNavigatorContext();
      if (targetContext == null) {
        if (mounted) {
          setState(() {
            _isProcessingRepeat = false;
          });
          ResponsiveSnackBar.showError(
              context, "Unable to access target context");
        }
        return;
      }

      await ref.read(marketWatchProvider).fetchScripInfo(
            "${_orderData.token}",
            "${_orderData.exch}",
            targetContext,
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
              targetContext, 'Unable to fetch scrip information');
        }
        return;
      }

      // Close the sheet first
      if (mounted) {
        shadcn.closeSheet(context);
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to place order screen
      if (targetContext.mounted) {
        ResponsiveNavigation.toPlaceOrderScreen(
          context: targetContext,
          arguments: {
            "orderArg": _createOrderArgs(_orderData),
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

  Future<bool?> _showCancelOrderDialog(
      ThemesProvider theme, BuildContext targetContext) async {
    final symbol = _orderData.displayName.trim();

    return showDialog<bool>(
      context: targetContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                dialogContext,
                dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(
                          dialogContext,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cancel Order',
                        style: MyntWebTextStyles.title(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(
                                dialogContext,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Confirmation text with symbol in quotes
                      Text(
                        'Are you sure you want to cancel "$symbol"?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),

                      // Red Cancel button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(dialogContext,
                                dark: MyntColors.errorDark,
                                light: MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: MyntWebTextStyles.buttonMd(
                              dialogContext,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showExitPositionDialog(
      ThemesProvider theme, BuildContext targetContext) async {
    final symbol = _orderData.displayName.trim();

    return showDialog<bool>(
      context: targetContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(
                dialogContext,
                dark: Colors.black,
                light: Colors.white,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row with title and close button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: resolveThemeColor(
                          dialogContext,
                          dark: MyntColors.dividerDark,
                          light: MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exit Position',
                        style: MyntWebTextStyles.title(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: resolveThemeColor(
                                dialogContext,
                                dark: MyntColors.textSecondaryDark,
                                light: MyntColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Confirmation text with symbol in quotes
                      Text(
                        'Are you sure you want to exit "$symbol" position?',
                        textAlign: TextAlign.center,
                        style: MyntWebTextStyles.body(
                          dialogContext,
                          color: resolveThemeColor(
                            dialogContext,
                            dark: MyntColors.textPrimaryDark,
                            light: MyntColors.textPrimary,
                          ),
                        ),
                      ),

                      // Exit button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: resolveThemeColor(
                              dialogContext,
                              dark: MyntColors.primary,
                              light: MyntColors.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Exit',
                            style: MyntWebTextStyles.buttonMd(
                              dialogContext,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  OrderScreenArgs _createOrderArgs(OrderBookModel orderData) {
    // Get LTP, fallback to close price if numeric, otherwise use 0.00
    // Match exactly with order_action_handler.dart
    String ltpValue = "0.00";
    if (orderData.ltp != null && orderData.ltp.toString() != "null") {
      ltpValue = orderData.ltp.toString();
    } else if (orderData.c != null && orderData.c.toString() != "null") {
      final closePrice = double.tryParse(orderData.c.toString());
      if (closePrice != null) {
        ltpValue = closePrice.toString();
      }
    }

    return OrderScreenArgs(
      exchange: orderData.exch ?? '',
      tSym: orderData.tsym ?? '',
      isExit: false,
      token: orderData.token ?? '',
      transType: orderData.trantype == 'B' ? true : false,
      prd: orderData.prd ?? orderData.sPrdtAli ?? 'CNC',
      lotSize: orderData.ls ?? '1',
      ltp: ltpValue,
      perChange: orderData.change ?? "0.00",
      orderTpye: '',
      holdQty: '',
      isModify: false,
      raw: orderData.toJson(),
    );
  }
}

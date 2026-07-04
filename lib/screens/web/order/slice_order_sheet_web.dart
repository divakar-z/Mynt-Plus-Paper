import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:html' as html;

import '../../../models/marketwatch_model/scrip_info.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';
import '../../../models/order_book_model/place_order_model.dart';
import '../../../provider/order_input_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/web_colors.dart' hide WebColors;
import '../../../res/global_font_web.dart';
import '../../../sharedWidget/custom_exch_badge.dart';
import '../../../utils/responsive_snackbar.dart';

class SliceOrderSheetWeb extends StatefulWidget {
  final ScripInfoModel scripInfo;
  final bool isBuy;
  final int quantity;
  final int frezQty;
  final int reminder;
  final bool isAmo;
  final String orderType;
  final String priceType;
  final String ordPrice;
  final String validityType;
  final TextEditingController stopLossCtrl;
  final TextEditingController targetCtrl;
  final TextEditingController discQtyCtrl;
  final TextEditingController triggerPriceCtrl;
  final TextEditingController mktProtCtrl;
  final int lotSize;
  final bool isBracketOrderEnabled;
  final VoidCallback? onClose;
  // Closes the parent Place Order window after slices are placed (web only).
  final VoidCallback? onParentClose;

  const SliceOrderSheetWeb({
    super.key,
    required this.scripInfo,
    required this.isBuy,
    required this.quantity,
    required this.frezQty,
    required this.reminder,
    required this.isAmo,
    required this.orderType,
    required this.priceType,
    required this.ordPrice,
    required this.validityType,
    required this.stopLossCtrl,
    required this.targetCtrl,
    required this.discQtyCtrl,
    required this.triggerPriceCtrl,
    required this.mktProtCtrl,
    required this.lotSize,
    required this.isBracketOrderEnabled,
    this.onClose,
    this.onParentClose,
  });

  // Static overlay entry to track current slice order overlay
  static OverlayEntry? _currentOverlayEntry;

  /// Shows the slice order sheet as an overlay (above place order screen)
  static void showAsOverlay({
    required BuildContext context,
    required ScripInfoModel scripInfo,
    required bool isBuy,
    required int quantity,
    required int frezQty,
    required int reminder,
    required bool isAmo,
    required String orderType,
    required String priceType,
    required String ordPrice,
    required String validityType,
    required TextEditingController stopLossCtrl,
    required TextEditingController targetCtrl,
    required TextEditingController discQtyCtrl,
    required TextEditingController triggerPriceCtrl,
    required TextEditingController mktProtCtrl,
    required int lotSize,
    required bool isBracketOrderEnabled,
    VoidCallback? onParentClose,
  }) {
    // Close existing slice order overlay if one is already open
    if (_currentOverlayEntry != null) {
      try {
        _currentOverlayEntry!.remove();
      } catch (e) {
        // Entry might already be removed
      }
      _currentOverlayEntry = null;
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Semi-transparent barrier
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // Prevent tap from dismissing
                child: Container(color: const Color(0x80000000)),
              ),
            ),
            // Dialog content centered
            Center(
              child: SliceOrderSheetWeb(
                scripInfo: scripInfo,
                isBuy: isBuy,
                quantity: quantity,
                frezQty: frezQty,
                reminder: reminder,
                isAmo: isAmo,
                orderType: orderType,
                priceType: priceType,
                ordPrice: ordPrice,
                validityType: validityType,
                stopLossCtrl: stopLossCtrl,
                targetCtrl: targetCtrl,
                discQtyCtrl: discQtyCtrl,
                triggerPriceCtrl: triggerPriceCtrl,
                mktProtCtrl: mktProtCtrl,
                lotSize: lotSize,
                isBracketOrderEnabled: isBracketOrderEnabled,
                onParentClose: onParentClose,
                onClose: () {
                  overlayEntry.remove();
                  _currentOverlayEntry = null;
                },
              ),
            ),
          ],
        ),
      ),
    );

    _currentOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);
  }

  /// Closes the current slice order overlay if open
  static void closeOverlay() {
    if (_currentOverlayEntry != null) {
      try {
        _currentOverlayEntry!.remove();
      } catch (e) {
        // Entry might already be removed
      }
      _currentOverlayEntry = null;
    }
  }

  @override
  State<SliceOrderSheetWeb> createState() => _SliceOrderSheetWebState();
}

class _SliceOrderSheetWebState extends State<SliceOrderSheetWeb> {
  // Disable all chart iframes to prevent cursor bleeding
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
          iframe.style.cursor = 'default';
        }
      }
      html.document.body?.style.cursor = 'default';
    } catch (e) {
    }
  }

  void _enableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'auto';
          iframe.style.cursor = '';
        }
      }
      html.document.body?.style.cursor = '';
    } catch (e) {
    }
  }

  @override
  void dispose() {
    ChartIframeGuard.release();
    _enableAllChartIframes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, WidgetRef ref, _) {
      final theme = ref.watch(themeProvider);
      final orders = ref.watch(orderProvider);
      final orderInput = ref.watch(ordInputProvider);

      return Dialog(
        backgroundColor: theme.isDarkMode
            ? MyntColors.dialogDark
            : MyntColors.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        child: PointerInterceptor(
          child: MouseRegion(
            cursor: SystemMouseCursors.basic,
            onEnter: (_) {
              ChartIframeGuard.acquire();
              _disableAllChartIframes();
            },
            onHover: (_) {
              _disableAllChartIframes();
            },
            onExit: (_) {
              ChartIframeGuard.release();
              _enableAllChartIframes();
            },
            child: Listener(
              onPointerMove: (_) {
                _disableAllChartIframes();
              },
              child: GestureDetector(
                onTap: () {},
                child: PopScope(
                  canPop: !orders.orderloader,
                  onPopInvoked: (didPop) {
                    if (!didPop && orders.orderloader) {
                      return;
                    }
                  },
                  child: Container(
            width: 450,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
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
                      Text(
                        "Slice Order",
                        style: WebTextStyles.custom(
                          fontSize: 13,
                          isDarkTheme: theme.isDarkMode,
                          color: theme.isDarkMode
                              ? WebDarkColors.textPrimary
                              : WebColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          splashColor: theme.isDarkMode
                              ? theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textWhite.withOpacity(.15)
                              : Colors.black.withOpacity(.15),
                          highlightColor: theme.isDarkMode
                              ? theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textWhite.withOpacity(.08)
                              : Colors.black.withOpacity(.08),
                          onTap: orders.orderloader
                              ? null
                              : () {
                                  if (widget.onClose != null) {
                                    widget.onClose!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              size: 20,
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Scrip Info Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.isDarkMode 
                                  ? MyntColors.dashboardCarColor : MyntColors.overlayBg,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: theme.isDarkMode
                                    ? MyntColors.dividerDark
                                    : MyntColors.divider,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildScripInfo(theme),
                                Row(
                                  children: [
                                    Text(
                                      "Qty: ${widget.frezQty} ",
                                      style: WebTextStyles.custom(
                                        fontSize: 13,
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? MyntColors.textPrimaryDark
                                            : MyntColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      " X ${widget.quantity >= orders.frezQtyOrderSliceMaxLimit ? orders.frezQtyOrderSliceMaxLimit : widget.quantity}",
                                      style: WebTextStyles.custom(
                                        fontSize: 12,
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? MyntColors.textSecondaryDark
                                            : MyntColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Reminder Section (if applicable)
                          if (widget.reminder != 0) _buildReminderSection(theme, orders),
                          
                          const SizedBox(height: 16),
                          
                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: orders.orderloader
                                  ? null
                                  : () async {
                                      try {
                                        orders.setOrderloader(true);
                                        
                                        // Prepare order inputs for slice orders
                                        List<PlaceOrderInput> placeOrderInputs = [];
                                        placeOrderInputs.add(_buildOrderInput(orderInput, widget.isBracketOrderEnabled));

                                        if (widget.reminder != 0) {
                                          placeOrderInputs.add(_buildOrderInput(orderInput, widget.isBracketOrderEnabled, qtyOverride: widget.reminder));
                                        }

                                        // Use the slice order with confirmation function
                                        orders.slicePlaceOrderWithConfirmation(context, placeOrderInputs, widget.quantity, widget.reminder, onWebParentClose: widget.onParentClose);

                                      } catch (e) {
                                        // Handle any unexpected errors
                                        if (context.mounted) {
                                          ResponsiveSnackBar.showError(
                                            context, "Error: ${e.toString()}");
                                        }
                                      } finally {
                                        if (mounted) {
                                          orders.setOrderloader(false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: widget.isBuy
                                    ? (theme.isDarkMode ? MyntColors.secondary : MyntColors.primary)
                                    : (theme.isDarkMode ? MyntColors.errorDark : MyntColors.tertiary),
                                disabledBackgroundColor: (theme.isDarkMode ? MyntColors.secondary : MyntColors.primary).withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: orders.orderloader
                                  ?  SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.isDarkMode ? MyntColors.textPrimaryDark : MyntColors.textWhite,
                                      ),
                                    )
                                  : Text(
                                      widget.isBuy ? 'Buy' : "Sell",
                                      style: WebTextStyles.custom(
                                        fontSize: 14,
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode ? MyntColors.textWhite : MyntColors.textWhite,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildScripInfo(ThemesProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "${widget.scripInfo.symbol} ",
              style: WebTextStyles.custom(
                fontSize: 13,
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? WebDarkColors.textPrimary
                    : WebColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              "${widget.scripInfo.option}",
              style: WebTextStyles.custom(
                fontSize: 13,
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? WebDarkColors.textPrimary
                    : WebColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            CustomExchBadge(exch: "${widget.scripInfo.exch}"),
            const SizedBox(width: 8),
            Text(
              "${widget.scripInfo.expDate}",
              style: WebTextStyles.custom(
                fontSize: 12,
                isDarkTheme: theme.isDarkMode,
                color: theme.isDarkMode
                    ? WebDarkColors.textSecondary
                    : WebColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReminderSection(ThemesProvider theme, OrderProvider orders) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.isDarkMode 
           ? MyntColors.dashboardCarColor : MyntColors.overlayBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: theme.isDarkMode
               ? MyntColors.dividerDark
               : MyntColors.divider,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildScripInfo(theme),
          Row(
            children: [
              Text(
                "Qty: ${widget.reminder} ",
                style: WebTextStyles.custom(
                  fontSize: 13,
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? WebDarkColors.textPrimary
                      : WebColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                " X 1",
                style: WebTextStyles.custom(
                  fontSize: 12,
                  isDarkTheme: theme.isDarkMode,
                  color: theme.isDarkMode
                      ? WebDarkColors.textSecondary
                      : WebColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PlaceOrderInput _buildOrderInput(OrderInputProvider orderInput, bool isBracketOrderEnabled, {int? qtyOverride}) {
    return PlaceOrderInput(
      amo: widget.isAmo ? "Yes" : "",
      blprc: widget.orderType == "CO - BO" ? widget.stopLossCtrl.text : '',
      bpprc: widget.orderType == "CO - BO" && isBracketOrderEnabled ? widget.targetCtrl.text : '',
      dscqty: widget.discQtyCtrl.text,
      exch: widget.scripInfo.exch!,
      prc: widget.ordPrice,
      prctype: orderInput.prcType,
      prd: orderInput.orderType,
      qty: widget.scripInfo.exch! == "MCX" 
          ? (qtyOverride != null ? qtyOverride * widget.lotSize : null)?.toString() ?? (widget.frezQty * widget.lotSize).toString()
          : qtyOverride?.toString() ?? widget.frezQty.toString(),
      ret: widget.validityType,
      trailprc: '',
      trantype: widget.isBuy ? 'B' : 'S',
      trgprc: widget.priceType == "SL Limit" || widget.priceType == "SL MKT" ? widget.triggerPriceCtrl.text : "",
      tsym: widget.scripInfo.tsym!,
      mktProt: widget.priceType == "Market" || widget.priceType == "SL MKT" ? widget.mktProtCtrl.text : '',
      channel: '',
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:mynt_plus/models/order_book_model/order_book_model.dart';
import 'package:mynt_plus/models/order_book_model/gtt_order_book.dart';
import 'package:mynt_plus/provider/order_provider.dart';
import 'package:mynt_plus/provider/market_watch_provider.dart';
import 'package:mynt_plus/provider/thems.dart';
import 'package:mynt_plus/utils/responsive_navigation.dart';
import 'package:mynt_plus/utils/responsive_snackbar.dart';
import 'package:mynt_plus/screens/web/ordersbook/modify_gtt_web.dart';
import 'package:mynt_plus/screens/web/ordersbook/order_book_detail_screen_web.dart';
import 'package:mynt_plus/screens/web/ordersbook/trade_book_detail_screen_web.dart';
import 'package:mynt_plus/screens/web/ordersbook/gtt_order_book_detail_screen_web.dart';
import 'package:mynt_plus/screens/web/order/modify_place_order_web_screen.dart';
import 'package:mynt_plus/res/res.dart';
import 'package:mynt_plus/res/web_colors.dart';
import 'package:mynt_plus/res/global_font_web.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart' as NewColors;
import 'package:mynt_plus/res/mynt_web_text_styles.dart';

/// Service class to handle order actions (Cancel, Modify, Repeat)
/// Separated from UI to improve maintainability
class OrderActionHandler {
  final WidgetRef ref;
  final BuildContext context;

  // Static flag to prevent double-click from opening sheet twice
  // Static so it's shared across all instances
  static bool _isSheetOpening = false;

  OrderActionHandler({
    required this.ref,
    required this.context,
  });

  /// Open order detail sheet
  void openOrderDetail(OrderBookModel order) {
    // Prevent double-click from opening sheet twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    final parentCtx = context; // Capture the parent context
    shadcn.openSheet(
      context: context,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 1300 ? screenWidth * 0.3 : 480.0;
        return Container(
          width: sheetWidth,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: NewColors.MyntColors.backgroundColorDark,
              light: NewColors.MyntColors.backgroundColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: OrderBookDetailScreenWeb(
            orderBookData: order,
            parentContext: parentCtx, // Pass the parent context
          ),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    ).then((_) {
      _isSheetOpening = false;
    });
  }

  /// Open trade detail dialog
  void openTradeDetail(dynamic trade) {
    // Prevent double-click from opening sheet twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    shadcn.openSheet(
      context: context,
      builder: (sheetContext) {
        final screenWidth = MediaQuery.of(sheetContext).size.width;
        final sheetWidth = screenWidth < 500 ? screenWidth * 0.3 : 480.0;
        return Container(
          width: sheetWidth,
          decoration: BoxDecoration(
            color: resolveThemeColor(
              context,
              dark: NewColors.MyntColors.backgroundColorDark,
              light: NewColors.MyntColors.backgroundColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: TradeBookDetailScreenWeb(tradeData: trade),
        );
      },
      position: shadcn.OverlayPosition.end,
      barrierColor: Colors.transparent,
    ).then((_) {
      _isSheetOpening = false;
    });
  }

  /// Open GTT order detail dialog
  void openGttOrderDetail(GttOrderBookModel gttOrder) {
    // Prevent double-click from opening dialog twice
    if (_isSheetOpening) return;
    _isSheetOpening = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GttOrderBookDetailScreenWeb(gttOrder: gttOrder);
      },
    ).then((_) {
      _isSheetOpening = false;
    });
  }

  /// Cancel order with confirmation
  Future<bool> cancelOrder(
    OrderBookModel orderData, {
    required Function(bool) onProcessingStateChanged,
  }) async {
    try {
      onProcessingStateChanged(true);

      // Check if context is mounted before showing dialog
      if (!context.mounted) {
        return false;
      }

      // Show confirmation dialog
      final shouldCancel = await _showCancelOrderDialog(orderData);

      if (shouldCancel != true) {
        return false;
      }

      // Check context is still valid after dialog
      if (!context.mounted) {
        return false;
      }

      // Proceed with cancel
      await ref.read(orderProvider).fetchOrderCancel(
            "${orderData.norenordno}",
            context,
            true,
          );

     return true;
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, 'Failed to cancel order');
      }
      return false;
    } finally {
      onProcessingStateChanged(false);
    }
  }

  /// Modify order
  Future<void> modifyOrder(
    OrderBookModel orderData, {
    required Function(bool) onProcessingStateChanged,
    required Offset modifyDialogPosition,
    required Function(Offset) onPositionChanged,
  }) async {
    try {
      onProcessingStateChanged(true);

      // Check if context is mounted before starting
      if (!context.mounted) {
        return;
      }


      await ref.read(marketWatchProvider).fetchScripInfo(
            "${orderData.token}",
            '${orderData.exch}',
            context,
            true,
          );

      if (!context.mounted) {
        return;
      }

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        ResponsiveSnackBar.showError(
            context, 'Unable to fetch scrip information');
        return;
      }


      final orderArgs = _createOrderArgs(orderData);

      // Show draggable modify order dialog
      ModifyPlaceOrderScreenWeb.showDraggable(
        context: context,
        modifyOrderArgs: orderData,
        scripInfo: scripInfo,
        orderArg: orderArgs,
        initialPosition: modifyDialogPosition,
      );


      // NOTE: Order book refresh is handled by ModifyPlaceOrderScreenWeb after successful modification
      // Do not refresh here as user hasn't submitted the modify yet
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to open modify order');
      }
    } finally {
      onProcessingStateChanged(false);
    }
  }

  /// Exit BO/CO order with confirmation
  Future<bool> exitBOCOOrder(
    OrderBookModel orderData, {
    required Function(bool) onProcessingStateChanged,
  }) async {
    try {
      onProcessingStateChanged(true);

      // Check if context is mounted before showing dialog
      if (!context.mounted) {
        return false;
      }

      // Show confirmation dialog
      final shouldExit = await _showExitPositionDialog(orderData);

      if (shouldExit != true) {
        return false;
      }

      // Check context is still valid after dialog
      if (!context.mounted) {
        return false;
      }

      // Proceed with exit - pass false to handle result manually
      await ref.read(orderProvider).fetchExitSNOOrd(
            "${orderData.snonum}",
            "${orderData.prd}",
            context,
            true,
          );

      return true;
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, 'Failed to exit order');
      }
      return false;
    } finally {
      onProcessingStateChanged(false);
    }
  }

  /// Repeat order
  Future<void> repeatOrder(OrderBookModel orderData) async {
    try {
      await ref.read(marketWatchProvider).fetchScripInfo(
            "${orderData.token}",
            "${orderData.exch}",
            context,
            true,
          );

      if (!context.mounted) return;

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        ResponsiveSnackBar.showError(
            context, 'Unable to fetch scrip information');
        return;
      }

      // Create OrderScreenArgs for repeat order
      final orderArgs = _createOrderArgs(orderData);

      // Use ResponsiveNavigation instead of draggable dialog
      await ResponsiveNavigation.toPlaceOrderScreen(
        context: context,
        arguments: {
          "orderArg": orderArgs,
          "scripInfo": scripInfo,
          "isBskt": "",
        },
      );
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to open place order');
      }
    }
  }

  /// Cancel GTT order
  Future<bool> cancelGttOrder(
    GttOrderBookModel gttOrderData, {
    required Function(bool) onProcessingStateChanged,
  }) async {
    try {
      onProcessingStateChanged(true);

      // Show confirmation dialog
      final shouldCancel = await _showCancelGttOrderDialog(gttOrderData);

      if (shouldCancel != true) {
        onProcessingStateChanged(false);
        return false;
      }

      // Cancel the GTT order
      await ref.read(orderProvider).cancelGttOrder(
            "${gttOrderData.alId}",
            context,
            isOco: gttOrderData.placeOrderParamsLeg2 != null,
          );

      // Refresh GTT order book after successful cancel
      await ref.read(orderProvider).fetchGTTOrderBook(context, "");
      return true;
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(context, 'Failed to cancel GTT order');
      }
      return false;
    } finally {
      onProcessingStateChanged(false);
    }
  }

  /// Modify GTT order
  Future<void> modifyGttOrder(
    GttOrderBookModel gttOrderData, {
    required Function(bool) onProcessingStateChanged,
  }) async {
    try {
      onProcessingStateChanged(true);

      await ref.read(marketWatchProvider).fetchScripInfo(
            "${gttOrderData.token}",
            '${gttOrderData.exch}',
            context,
            true,
          );

      if (!context.mounted) return;

      final scripInfo = ref.read(marketWatchProvider).scripInfoModel;
      if (scripInfo == null) {
        ResponsiveSnackBar.showError(
            context, 'Unable to fetch scrip information');
        return;
      }

      // Show modify GTT order screen as draggable dialog
      ModifyGttWeb.showDraggable(
        context: context,
        gttOrderBook: gttOrderData,
        scripInfo: scripInfo,
      );
    } catch (e) {
      if (context.mounted) {
        ResponsiveSnackBar.showError(
            context, 'Failed to open modify GTT order: ${e.toString()}');
      }
    } finally {
      onProcessingStateChanged(false);
    }
  }

  // Private helper methods

  Future<bool?> _showCancelOrderDialog(OrderBookModel orderData) async {
    final symbol = orderData.displayName.trim();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(dialogContext,
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
                          dark: NewColors.MyntColors.dividerDark,
                          light: NewColors.MyntColors.divider,
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
                          color: resolveThemeColor(dialogContext,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                              color: resolveThemeColor(dialogContext,
                                  dark: NewColors.MyntColors.textSecondaryDark,
                                  light: NewColors.MyntColors.textSecondary),
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
                          color: resolveThemeColor(dialogContext,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                                dark: NewColors.MyntColors.errorDark,
                                light: NewColors.MyntColors.tertiary),
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

  Future<bool?> _showExitPositionDialog(OrderBookModel orderData) async {
    final symbol = orderData.displayName.trim();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(dialogContext,
                  dark: colors.colorBlack, light: colors.colorWhite),
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
                          dark: NewColors.MyntColors.dividerDark,
                          light: NewColors.MyntColors.divider,
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
                          color: resolveThemeColor(dialogContext,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                              color: resolveThemeColor(dialogContext,
                                  dark: NewColors.MyntColors.textSecondaryDark,
                                  light: NewColors.MyntColors.textSecondary),
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
                          color: resolveThemeColor(dialogContext,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                              dark: NewColors.MyntColors.primaryDark,
                              light: NewColors.MyntColors.primary,
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

  Future<bool?> _showCancelGttOrderDialog(
      GttOrderBookModel gttOrderData) async {
    final symbol = gttOrderData.displayName.trim();

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: resolveThemeColor(context,
                  dark: colors.colorBlack, light: colors.colorWhite),
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
                          context,
                          dark: NewColors.MyntColors.dividerDark,
                          light: NewColors.MyntColors.divider,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cancel GTT Order',
                        style: MyntWebTextStyles.title(
                          context,
                          color: resolveThemeColor(context,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                              color: resolveThemeColor(context,
                                  dark: NewColors.MyntColors.textSecondaryDark,
                                  light: NewColors.MyntColors.textSecondary),
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
                          context,
                          color: resolveThemeColor(context,
                              dark: NewColors.MyntColors.textPrimaryDark,
                              light: NewColors.MyntColors.textPrimary),
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
                            backgroundColor: resolveThemeColor(context,
                                dark: NewColors.MyntColors.errorDark,
                                light: NewColors.MyntColors.tertiary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: MyntWebTextStyles.buttonMd(
                              context,
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

  dynamic _createOrderArgs(OrderBookModel orderData) {
    // Get LTP, fallback to close price if numeric, otherwise use 0.00
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
      // TC_64.1: the place-order screen maps a passed prd only to
      // Delivery/Intraday/MTF, so H/B repeated as Delivery. Leave prd empty for
      // CO-BO so the screen reads the raw order, which maps H/B to CO - BO.
      // prd: orderData.prd ?? orderData.sPrdtAli ?? 'CNC',
      prd: (orderData.prd == 'H' || orderData.prd == 'B')
          ? ''
          : orderData.prd ?? orderData.sPrdtAli ?? 'CNC',
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

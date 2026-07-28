import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mynt_plus/res/dyslexia_font.dart';
import 'package:mynt_plus/locator/locator.dart';
import 'package:mynt_plus/locator/preference.dart';
import 'package:mynt_plus/provider/fund_provider.dart';
import 'package:mynt_plus/provider/transcation_provider.dart';
import 'package:mynt_plus/res/global_state_text.dart';
import 'package:mynt_plus/routes/route_names.dart';
import 'package:mynt_plus/res/mynt_web_color_styles.dart';
import 'package:mynt_plus/res/mynt_web_text_styles.dart' show resolveThemeColor;
import 'package:mynt_plus/utils/safe_parse.dart';
import '../../../../res/res.dart';
import '../../../models/marketwatch_model/scrip_info.dart';
import '../../../models/order_book_model/modify_order_model.dart';
import '../../../models/order_book_model/order_book_model.dart';
import '../../../models/order_book_model/order_margin_model.dart';
import '../../../provider/network_state_provider.dart';
import '../../../provider/order_provider.dart';
import '../../../provider/thems.dart';
import '../../../res/global_font_web.dart';
import '../../../sharedWidget/common_text_fields_web.dart';
import '../../../sharedWidget/custom_widget_button.dart';
import '../../../sharedWidget/no_internet_widget.dart';
import '../../../sharedWidget/snack_bar.dart';
import '../../../utils/responsive_snackbar.dart';
import 'margin_details_dialog_web.dart';
import 'orderscreen_header_web.dart';
import 'dart:html' as html;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../market_watch/tv_chart/chart_iframe_guard.dart';
import '../../../utils/overlay_manager.dart';
import 'package:mynt_plus/utils/custom_navigator.dart';


/// Rejects a keystroke that would make a numeric field invalid, keeping the
/// last valid value instead of clearing it. Empty is always allowed so the
/// user can still backspace the field clear. Replaces the earlier anchored
/// allow-filter, which wiped the whole field on any non-matching input
/// (a letter, or a 3rd decimal digit) and then fired a spurious
/// "cannot be empty" warning.
TextInputFormatter _rejectIfNoMatch(RegExp pattern) =>
    TextInputFormatter.withFunction((oldValue, newValue) =>
        (newValue.text.isEmpty || pattern.hasMatch(newValue.text))
            ? newValue
            : oldValue);


// InheritedWidget to pass close callback to child widgets
class _ModifyPlaceOrderDialogCloseNotifier extends InheritedWidget {
  final VoidCallback onClose;

  const _ModifyPlaceOrderDialogCloseNotifier({
    required this.onClose,
    required super.child,
  });

  static _ModifyPlaceOrderDialogCloseNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<
        _ModifyPlaceOrderDialogCloseNotifier>();
  }

  @override
  bool updateShouldNotify(_ModifyPlaceOrderDialogCloseNotifier oldWidget) {
    return onClose != oldWidget.onClose;
  }
}

// InheritedWidget to pass drag handlers to child widgets
class _ModifyPlaceOrderDialogDragNotifier extends InheritedWidget {
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final bool isDragging;

  const _ModifyPlaceOrderDialogDragNotifier({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.isDragging,
    required super.child,
  });

  static _ModifyPlaceOrderDialogDragNotifier? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<
        _ModifyPlaceOrderDialogDragNotifier>();
  }

  @override
  bool updateShouldNotify(_ModifyPlaceOrderDialogDragNotifier oldWidget) {
    return onPanStart != oldWidget.onPanStart ||
        onPanUpdate != oldWidget.onPanUpdate ||
        onPanEnd != oldWidget.onPanEnd ||
        isDragging != oldWidget.isDragging;
  }
}

class ModifyPlaceOrderScreenWeb extends ConsumerStatefulWidget {
  final OrderBookModel modifyOrderArgs;
  final ScripInfoModel scripInfo;
  final OrderScreenArgs orderArg;
  const ModifyPlaceOrderScreenWeb(
      {super.key,
      required this.scripInfo,
      required this.modifyOrderArgs,
      required this.orderArg});

  @override
  ConsumerState<ModifyPlaceOrderScreenWeb> createState() =>
      _ModifyPlaceOrderScreenState();

  // Static variable to track inner dialog overlay entries
  static OverlayEntry? _currentDialogOverlayEntry;

  // Static variable to remember the last position of the dialog
  static Offset? _lastSavedPosition;

  /// Static method to show a dialog on top of the modify place order overlay
  /// This ensures dialogs appear above the draggable order screen
  /// Dialog only closes when user explicitly clicks close (not on outside tap)
  static void showDialogOverlay({
    required BuildContext context,
    required Widget Function(BuildContext context, VoidCallback closeDialog) builder,
    Color barrierColor = const Color(0x80000000),
  }) {
    // Prevent multiple dialogs from opening
    if (_currentDialogOverlayEntry != null) {
      return;
    }

    // Check if context is still mounted/valid
    if (!context.mounted) {
      return;
    }

    OverlayState? overlay;
    try {
      overlay = Overlay.of(context, rootOverlay: true);
    } catch (e) {
      // Context is no longer valid
      return;
    }

    late OverlayEntry dialogOverlayEntry;

    void closeDialog() {
      try {
        dialogOverlayEntry.remove();
      } catch (e) {
        // Entry might already be removed
      }
      _currentDialogOverlayEntry = null;
    }

    dialogOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Barrier - does not dismiss on tap
            Positioned.fill(
              child: Container(color: barrierColor),
            ),
            // Dialog content
            Center(
              child: builder(overlayContext, closeDialog),
            ),
          ],
        ),
      ),
    );

    _currentDialogOverlayEntry = dialogOverlayEntry;
    overlay.insert(dialogOverlayEntry);
  }

  

  /// Static method to show ModifyPlaceOrderScreenWeb as a draggable dialog
  static void showDraggable({
    required BuildContext context,
    required OrderBookModel modifyOrderArgs,
    required ScripInfoModel scripInfo,
    required OrderScreenArgs orderArg,
    Offset? initialPosition,
  }) {
    
    try {
      // Use rootOverlay to ensure we can show dialog even after sheet closes
      final overlay = Overlay.of(context, rootOverlay: true);
      late OverlayEntry overlayEntry;

      // Get MediaQuery - use rootOverlay context to ensure it's available
      final mediaQuery = MediaQuery.of(context);
      // Dialog dimensions for centering calculation
      const dialogWidth = 450.0;
      const dialogHeight = 500.0;
      // Use saved position, then initialPosition parameter, then center of screen
      final position = _lastSavedPosition ??
          initialPosition ??
          Offset(
            (mediaQuery.size.width - dialogWidth) / 2,
            (mediaQuery.size.height - dialogHeight) / 2,
          );


    overlayEntry = OverlayEntry(
      builder: (context) => _DraggableModifyPlaceOrderScreenDialog(
        modifyOrderArgs: modifyOrderArgs,
        scripInfo: scripInfo,
        orderArg: orderArg,
        initialPosition: position,
        onPositionChanged: (newPosition) {
          // Save the position for next time
          _lastSavedPosition = newPosition;
        },
        onClose: () {
          overlayEntry.remove();
          // Unregister from overlay manager
          OverlayManager.unregister(overlayEntry);
        },
      ),
    );

      overlay.insert(overlayEntry);

      // Register with overlay manager for global control
      OverlayManager.register(overlayEntry);
    } catch (e, stackTrace) {
      rethrow;
    }
  }
}

class _ModifyPlaceOrderScreenState
    extends ConsumerState<ModifyPlaceOrderScreenWeb> {
  // bool addStoploss = false;
  bool isAgree = false;
  bool addValidity = false;
  bool isAmo = false;
  bool isBuy = false;
  TextEditingController priceCtrl = TextEditingController();
  TextEditingController triggerPriceCtrl = TextEditingController();
  TextEditingController mktProtCtrl = TextEditingController();
  TextEditingController qtyCtrl = TextEditingController();
  TextEditingController discQtyCtrl = TextEditingController();
  TextEditingController stopLossCtrl = TextEditingController();
  TextEditingController targetCtrl = TextEditingController();
  TextEditingController trailingTickCtrl = TextEditingController();
  List<String> priceType = ["Limit", "Market", "SL Limit", "SL MKT"];
  // List<bool> isActivePrice = [];
  List<String> validityType = ["Day", "IOC"];
  List<String> validityTypes = ["DAY", "IOC", "EOS"];
  // List<bool> isActiveValidity = [true, false];

  String prcType = "";

  int frezQty = 0;
  int lotSize = 0;
  int multiplayer = 0;
  bool _isStock = true;
  String price = "0.00";
  String validity = "DAY";
  bool _isMarketOrder = false;
  bool _isStoplossOrder = false;
  bool _isBOCOOrderEnabled = false;
  // The former "Advance" show/hide toggle was removed (same as the place
  // order screen) — the advanced fields are now always visible.
  // bool isAdvancedOptionClicked = false;
  bool _hasValidCircuitBreakerValues = false;
  // bool _afterMarketOrder = false;
  bool _addValidityAndDisclosedQty = false;
  // String orderType = "Delivery";

  double tik = 0.00;
  Timer? _marginUpdateDebounceTimer;
  double roundOffWithInterval(double input, double interval) {
    return ((input / interval).round() * interval);
  }

  void _debouncedMarginUpdate() {
    _marginUpdateDebounceTimer?.cancel();
    _marginUpdateDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        marginUpdate();
      }
    });
  }

  /// Handles keyboard up/down arrow to increment/decrement a price field by tick size.
  KeyEventResult _handlePriceArrowKey(KeyEvent event, TextEditingController ctrl) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tik <= 0) return KeyEventResult.ignored;

    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    // Skip if field contains non-numeric text (e.g. "Market"), but allow empty (treat as 0)
    if (ctrl.text.isNotEmpty && double.tryParse(ctrl.text) == null) return KeyEventResult.ignored;

    final current = double.tryParse(ctrl.text) ?? 0;
    double newVal = isUp ? current + tik : current - tik;
    if (newVal < 0) newVal = 0;
    newVal = roundOffWithInterval(newVal, tik);
    final formatted = newVal.toStringAsFixed(2);
    ctrl.text = formatted;
    ctrl.selection = TextSelection.collapsed(offset: formatted.length);
    setState(() {
      if (ctrl == priceCtrl) {
        price = formatted;
        _debouncedMarginUpdate();
      }
    });
    return KeyEventResult.handled;
  }

  /// Handles keyboard up/down arrow to increment/decrement qty by 1 (stocks) or lot size (F&O).
  KeyEventResult _handleQtyArrowKey(KeyEvent event, TextEditingController ctrl) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    final int step = _isStock ? 1 : (multiplayer > 0 ? multiplayer : 1);
    final int current = int.tryParse(ctrl.text) ?? 0;
    final int snapped =
        current >= step ? ((current / step).floor()) * step : step;

    setState(() {
      if (isUp) {
        if (ctrl.text.isEmpty) {
          ctrl.text = step.toString();
        } else if (current != snapped) {
          ctrl.text = snapped.toString();
        } else {
          ctrl.text = (current + step).toString();
        }
      } else {
        if (current != snapped) {
          ctrl.text = snapped.toString();
        } else if (current > step) {
          ctrl.text = (current - step).toString();
        } else {
          ctrl.text = step.toString();
        }
      }
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      marginUpdate();
    });
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    ref.read(fundProvider).fetchFunds(context);

    tik = double.parse(widget.scripInfo.ti.toString());

    prcType = widget.modifyOrderArgs.prctyp!;

    // Initialize circuit breaker validation flag
    _hasValidCircuitBreakerValues = widget.scripInfo.lc != null &&
        widget.scripInfo.uc != null &&
        widget.scripInfo.lc != "0.00" &&
        widget.scripInfo.uc != "0.00" &&
        widget.scripInfo.lc!.isNotEmpty &&
        widget.scripInfo.uc!.isNotEmpty;
    // isActivePrice = [
    //   prcType == 'LMT' ? true : false,
    //   prcType == 'MKT' ? true : false,
    //   prcType == 'SL-LMT' ? true : false,
    //   prcType == 'SL-MKT' ? true : false
    // ];
    int sfq = int.tryParse(widget.scripInfo.frzqty?.toString() ?? '1') ?? 1;
    lotSize = int.parse("${widget.scripInfo.ls ?? 0}");

    frezQty = sfq > 1 ? (sfq / lotSize).floor() * lotSize : lotSize;

    setState(() {
      multiplayer = int.parse((widget.orderArg.exchange == "MCX"
              ? widget.scripInfo.prcqqty
              : widget.orderArg.lotSize)
          .toString());
      _isStock = widget.scripInfo.exch == "NSE" || widget.scripInfo.exch == "BSE";
      isBuy = widget.modifyOrderArgs.trantype == "B" ? true : false;
      priceCtrl = TextEditingController(text: widget.modifyOrderArgs.prc);
      qtyCtrl = TextEditingController(text: widget.modifyOrderArgs.qty);

      if (widget.modifyOrderArgs.fillshares != null &&
          int.parse(widget.modifyOrderArgs.fillshares.toString()) > 0 &&
          widget.modifyOrderArgs.fillshares != widget.modifyOrderArgs.qty) {
        int fqty = (int.parse(widget.modifyOrderArgs.qty.toString()) -
            int.parse(widget.modifyOrderArgs.fillshares.toString()));
        if (fqty != 0) {
          qtyCtrl.text = fqty.toString();
        }
      }
      if (widget.orderArg.exchange == "MCX") {
        qtyCtrl.text = (int.parse(qtyCtrl.text) ~/ lotSize).toString();
      }
      mktProtCtrl = TextEditingController(
          text: widget.modifyOrderArgs.mktProtection == null
              ? "5"
              : widget.modifyOrderArgs.mktProtection!);

      stopLossCtrl =
          TextEditingController(text: "${widget.modifyOrderArgs.blprc ?? 0}");
      targetCtrl =
          TextEditingController(text: "${widget.modifyOrderArgs.bpprc ?? 0}");
      triggerPriceCtrl =
          TextEditingController(text: "${widget.modifyOrderArgs.trgprc ?? 0}");
      discQtyCtrl = TextEditingController(text: widget.modifyOrderArgs.dscqty);
      validity = (widget.modifyOrderArgs.ret ?? 'DAY').toUpperCase();

      // isActiveValidity = [
      //   validity == 'DAY' ? true : false,
      //   validity == 'IOC' ? true : false,
      // ];
      addValidity = validity.toUpperCase() == 'IOC' ||
              (widget.modifyOrderArgs.dscqty != null &&
                  int.parse(widget.modifyOrderArgs.dscqty.toString()) > 0)
          ? true
          : false;

      if (prcType == "MKT" || prcType == "SL-MKT") {
        double ltp = (double.parse("${widget.orderArg.ltp}") *
                double.parse(
                    mktProtCtrl.text.isEmpty ? "0" : mktProtCtrl.text)) /
            100;
        if (widget.modifyOrderArgs.trantype == "B") {
          price = (double.parse("${widget.orderArg.ltp ?? 0.00}") + ltp)
              .toStringAsFixed(2);
        } else {
          price = (double.parse("${widget.orderArg.ltp ?? 0.00}") - ltp)
              .toStringAsFixed(2);
        }
        priceCtrl.text = "Market";
      } else {
        priceCtrl.text = "${widget.modifyOrderArgs.prc}";
        price = priceCtrl.text;
      }

      _isMarketOrder = prcType == "MKT" || prcType == "SL-MKT";
      _isStoplossOrder = prcType == "SL-LMT" || prcType == "SL-MKT";
      _isBOCOOrderEnabled = widget.modifyOrderArgs.sPrdtAli == "BO" ||
          widget.modifyOrderArgs.sPrdtAli == "CO";

      // Set states based on order data (the advanced section is always
      // visible now, so no auto-expand is needed)
      if (["SL-LMT", "SL-MKT"].contains(prcType)) {
        _isStoplossOrder = true;
        // isAdvancedOptionClicked = true;
      }

      if (validity.toUpperCase() == 'IOC' ||
          (widget.modifyOrderArgs.dscqty != null &&
              int.parse(widget.modifyOrderArgs.dscqty.toString()) > 0)) {
        // isAdvancedOptionClicked = true;
        _addValidityAndDisclosedQty = true;
        addValidity = true;
      }

      // Auto-expand for AMO orders (if AMO flag exists in order data)
      // if (isAmo) {
      //   isAdvancedOptionClicked = true;
      //   _afterMarketOrder = true;
      // }

      marginUpdate();
    });
    super.initState();
  }

  void openFunds(String pageis, BuildContext context) {
    if (WebNavigationHelper.isAvailable) {
      WebNavigationHelper.navigateTo(Routes.fundscreen);
    }
  }

  @override
  void dispose() {
    _marginUpdateDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, WidgetRef ref, _) {
        final orderProvide = ref.watch(orderProvider);
        final internet = ref.watch(networkStateProvider);
        final theme = ref.read(themeProvider);
        final clientFundDetail = ref.watch(fundProvider).fundDetailModel;
        final trancation = ref.watch(transcationProvider);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Header with drag functionality
              Builder(
                builder: (context) {
                  final dragNotifier =
                      _ModifyPlaceOrderDialogDragNotifier.of(context);
                  final closeNotifier =
                      _ModifyPlaceOrderDialogCloseNotifier.of(context);

                  Widget headerContent = Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: resolveThemeColor(context, dark: MyntColors.cardDark, light: const Color(0xfffafbff)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Text(
                                      "${widget.scripInfo.masterName ?? (widget.scripInfo.symbol ?? widget.orderArg.tSym).replaceAll("-EQ", "")} ",
                                      style: WebTextStyles.title(
                                        isDarkTheme: theme.isDarkMode,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary),
                                        fontWeight: WebFonts.medium,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.scripInfo.masterName == null &&
                                        (widget.scripInfo.expDate ?? '').isNotEmpty)
                                      Text(
                                        " ${widget.scripInfo.expDate ?? ''} ",
                                        style: WebTextStyles.title(
                                          isDarkTheme: theme.isDarkMode,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                          fontWeight: WebFonts.medium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (widget.scripInfo.masterName == null &&
                                        (widget.scripInfo.option ?? '').isNotEmpty)
                                      Text(
                                        widget.scripInfo.option ?? '',
                                        style: WebTextStyles.sub(
                                          isDarkTheme: theme.isDarkMode,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textPrimaryDark,
                                              light: MyntColors.textPrimary),
                                          fontWeight: WebFonts.medium,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      " ${widget.scripInfo.exch}",
                                      style: WebTextStyles.para(
                                        isDarkTheme: theme.isDarkMode,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary),
                                        fontWeight: WebFonts.medium,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  OrderScreenHeaderWeb(
                                    headerData: widget.orderArg,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                // children: [
                                //   // Green "B" Button
                                //   Material(
                                //     color: Colors.transparent,
                                //     child: InkWell(
                                //       onTap: () {
                                //         setState(() {
                                //           isBuy = true;
                                //         });
                                //         marginUpdate();
                                //       },
                                //       borderRadius: BorderRadius.circular(5),
                                //       child: Container(
                                //         width: 20,
                                //         height: 20,
                                //         decoration: BoxDecoration(
                                //           color: resolveThemeColor(context,
                                //               dark: MyntColors.secondary,
                                //               light: MyntColors.primary),
                                //           borderRadius: BorderRadius.circular(5),
                                //         ),
                                //         child: Center(
                                //           child: Text(
                                //             'B',
                                //             style: WebTextStyles.para(
                                //               isDarkTheme: theme.isDarkMode,
                                //               color: Colors.white,
                                //               fontWeight: WebFonts.medium,
                                //             ),
                                //           ),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                //   const SizedBox(width: 8),
                                //   // Toggle Switch
                                //   MouseRegion(
                                //     cursor: SystemMouseCursors.click,
                                //     child: GestureDetector(
                                //       onTap: () {
                                //         setState(() {
                                //           isBuy = !isBuy;
                                //         });
                                //         marginUpdate();
                                //       },
                                //       child: Container(
                                //         width: 42,
                                //         height: 22,
                                //         decoration: BoxDecoration(
                                //           color: resolveThemeColor(context,
                                //               dark: MyntColors.backgroundColorDark,
                                //               light: MyntColors.backgroundColor),
                                //           border: Border.all(
                                //             color: isBuy
                                //                 ? resolveThemeColor(context,
                                //                     dark: MyntColors.primaryDark,
                                //                     light: MyntColors.primary)
                                //                 : resolveThemeColor(context,
                                //                     dark: MyntColors.tertiary,
                                //                     light: MyntColors.tertiary),
                                //           ),
                                //           borderRadius: BorderRadius.circular(11),
                                //         ),
                                //         child: Stack(
                                //           children: [
                                //             AnimatedPositioned(
                                //               duration:
                                //                   const Duration(milliseconds: 200),
                                //               curve: Curves.easeInOut,
                                //               left: isBuy ? 2 : 24,
                                //               top: 2,
                                //               child: Container(
                                //                 width: 16,
                                //                 height: 16,
                                //                 decoration: BoxDecoration(
                                //                   color: isBuy
                                //                       ? resolveThemeColor(context,
                                //                           dark: MyntColors.primaryDark,
                                //                           light: MyntColors.primary)
                                //                       : resolveThemeColor(context,
                                //                           dark: MyntColors.tertiary,
                                //                           light: MyntColors.tertiary),
                                //                   borderRadius:
                                //                       BorderRadius.circular(8),
                                //                 ),
                                //               ),
                                //             ),
                                //           ],
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                //   const SizedBox(width: 8),
                                //   // Red "S" Button
                                //   Material(
                                //     color: Colors.transparent,
                                //     child: InkWell(
                                //       onTap: () {
                                //         setState(() {
                                //           isBuy = false;
                                //         });
                                //         marginUpdate();
                                //       },
                                //       borderRadius: BorderRadius.circular(5),
                                //       child: Container(
                                //         width: 20,
                                //         height: 20,
                                //         decoration: BoxDecoration(
                                //           color: resolveThemeColor(context,
                                //               dark: MyntColors.errorDark,
                                //               light: MyntColors.tertiary),
                                //           borderRadius: BorderRadius.circular(5),
                                //         ),
                                //         child: Center(
                                //           child: Text(
                                //             'S',
                                //             style: WebTextStyles.para(
                                //               isDarkTheme: theme.isDarkMode,
                                //               color: Colors.white,
                                //               fontWeight: WebFonts.medium,
                                //             ),
                                //           ),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ],
                              ),
                              const SizedBox(width: 12),
                              Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    closeNotifier?.onClose();
                                  },
                                  borderRadius: BorderRadius.circular(5),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.close,
                                      color: resolveThemeColor(context,
                                          dark: MyntColors.textSecondaryDark,
                                          light: MyntColors.textSecondary),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  // Wrap with drag functionality if drag notifier is available
                  if (dragNotifier != null) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: GestureDetector(
                        onPanStart: dragNotifier.onPanStart,
                        onPanUpdate: dragNotifier.onPanUpdate,
                        onPanEnd: dragNotifier.onPanEnd,
                        child: headerContent,
                      ),
                    );
                  }

                  return headerContent;
                },
              ),
              // Body content
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                        // reverse: true,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              // Padding(
                              //     padding: const EdgeInsets.only(left: 16),
                              //     child: headerTitleText("Price type", theme)),
                              // const SizedBox(height: 10),
                              // Padding(
                              //     padding: const EdgeInsets.only(left: 16),
                              //     child: SizedBox(
                              //         height: 38,
                              //         child: ListView.separated(
                              //             scrollDirection: Axis.horizontal,
                              //             itemBuilder: (context, index) {
                              //               return ElevatedButton(
                              //                   onPressed: () {
                              //                     setState(() {
                              //                       for (var i = 0;i <isActivePrice.length;i++) {
                              //                         isActivePrice[i] = false;
                              //                       }
                              //                       isActivePrice[index] = true;
                              //                       if (isActivePrice[1] ||
                              //                           isActivePrice[3]) {
                              //                         double ltp = (double.parse("${widget.orderArg.ltp}") *
                              //                                 double.parse(mktProtCtrl.text.isEmpty
                              //                                     ? "0" : mktProtCtrl.text)) / 100;
                
                              //                         if (widget.modifyOrderArgs.trantype =="B") {
                              //                           price = (double.parse("${widget.orderArg.ltp ?? 0.00}") + ltp).toStringAsFixed(2);
                              //                         } else {
                              //                           price = (double.parse("${widget.orderArg.ltp ?? 0.00}") - ltp)
                              //                               .toStringAsFixed(2);
                              //                         }
                              //                         priceCtrl.text = "Market";
                              //                       } else {
                              //                         priceCtrl.text =
                              //                             "${widget.modifyOrderArgs.prc}";
                              //                       }
                              //                       prcType = isActivePrice[0] ? 'LMT' : isActivePrice[1] ? 'MKT' : isActivePrice[2] ? 'SL-LMT' : "SL-MKT";
                              //                     });
                              //                     FocusScope.of(context)
                              //                         .unfocus();
                              //                   },
                              //                   style: ElevatedButton.styleFrom(
                              //                       elevation: 0,
                              //                       padding: const EdgeInsets
                              //                           .symmetric(
                              //                           horizontal: 12,
                              //                           vertical: 0),
                              //                       backgroundColor: !theme
                              //                               .isDarkMode
                              //                           ? !isActivePrice[index]
                              //                               ? const Color(
                              //                                   0xffF1F3F8)
                              //                               : colors.colorBlack
                              //                           : !isActivePrice[index]
                              //                               ? colors.darkGrey
                              //                               : colors.colorWhite,
                              //                       shape:
                              //                           const StadiumBorder()),
                              //                   child: Text(priceType[index],
                              //                       style: textStyle(
                              //                           !theme.isDarkMode
                              //                               ? !isActivePrice[
                              //                                       index]
                              //                                   ? const Color(
                              //                                       0xff666666)
                              //                                   : colors
                              //                                       .colorWhite
                              //                               : !isActivePrice[
                              //                                       index]
                              //                                   ? const Color(
                              //                                       0xff666666)
                              //                                   : colors
                              //                                       .colorBlack,
                              //                           14,
                              //                           isActivePrice[index]
                              //                               ? FontWeight.w600
                              //                               : FontWeight
                              //                                   .w500)));
                              //             },
                              //             separatorBuilder: (context, index) {
                              //               return const SizedBox(width: 8);
                              //             },
                              //             itemCount:
                              //                 widget.modifyOrderArgs.sPrdtAli == "BO" ||
                              //                 widget.modifyOrderArgs.sPrdtAli == "CO" ? 3 : priceType.length))),
                              // const SizedBox(height: 3),
                              // const Divider(color: Color(0xffDDDDDD)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              headerTitleText(
                                                  widget.scripInfo.exch == "MCX" ? "Lot" : "Qty",
                                                  theme),
                                              // Text(
                                              //   "Lot: ${widget.scripInfo.ls} ${widget.scripInfo.prcunt ?? ''}  ",
                                              //   style: textStyle(
                                              //       const Color(0xff777777),
                                              //       11,
                                              //       FontWeight.w600),
                                              // )
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Focus(
                                            onKeyEvent: (node, event) => _handleQtyArrowKey(event, qtyCtrl),
                                            child: SizedBox(
                                            height: 40,
                                            // width: 150,
                                            child: MyntTextField(
                                              backgroundColor: theme.isDarkMode
                                                  ? colors.darkGrey
                                                  : const Color(0xffF1F3F8),
                                              placeholder:
                                                  "${widget.orderArg.lotSize}",
                                              placeholderStyle:
                                                  WebTextStyles.formInput(
                                                isDarkTheme: theme.isDarkMode,
                                                color: theme.isDarkMode
                                                    ? MyntColors.textSecondary
                                                    : MyntColors.textSecondary,
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly
                                              ],
                                              keyboardType:
                                                  TextInputType.number,
                                              textStyle: WebTextStyles.formInput(
                                                isDarkTheme: theme.isDarkMode,
                                                color: theme.isDarkMode
                                                    ? MyntColors.textPrimaryDark
                                                    : MyntColors.textPrimary,
                                              ),
                                              leadingWidget: _isStock ? null : GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    String input = qtyCtrl.text;
                                                    int currentValue = int.tryParse(input) ?? 0;
                                                    int adjustedQty = currentValue >= multiplayer
                                                        ? ((currentValue / multiplayer).floor()) * multiplayer
                                                        : multiplayer;
                                                    if (currentValue != adjustedQty) {
                                                      qtyCtrl.text = adjustedQty.toString();
                                                    } else if (input.isNotEmpty && currentValue > multiplayer) {
                                                      qtyCtrl.text = (currentValue - multiplayer).toString();
                                                    } else {
                                                      qtyCtrl.text = "$multiplayer";
                                                    }
                                                    qtyCtrl.selection = TextSelection.collapsed(offset: qtyCtrl.text.length);
                                                    marginUpdate();
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                  color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                                                ),
                                              ),
                                              trailingWidget: _isStock ? null : GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    String input = qtyCtrl.text;
                                                    int currentValue = int.tryParse(input) ?? 0;
                                                    int adjustedQty = currentValue >= multiplayer
                                                        ? ((currentValue / multiplayer).floor()) * multiplayer
                                                        : multiplayer;
                                                    final bool hasNoFreezeLimit = frezQty <= lotSize;
                                                    final bool isMcx = widget.scripInfo.exch == "MCX";
                                                    final int capInFieldUnits = hasNoFreezeLimit
                                                        ? 999999999
                                                        : (isMcx
                                                            ? frezQty ~/ lotSize
                                                            : frezQty);
                                                    if (currentValue != adjustedQty) {
                                                      qtyCtrl.text = adjustedQty.toString();
                                                    } else if (input.isEmpty) {
                                                      qtyCtrl.text = "$multiplayer";
                                                    } else if ((currentValue + multiplayer) <= capInFieldUnits) {
                                                      qtyCtrl.text = (currentValue + multiplayer).toString();
                                                    } else {
                                                      ResponsiveSnackBar.showWarning(
                                                          context,
                                                          isMcx
                                                              ? "Maximum Allowed Lots: ${frezQty ~/ lotSize}"
                                                              : "Maximum Allowed Quantity $frezQty");
                                                    }
                                                    qtyCtrl.selection = TextSelection.collapsed(offset: qtyCtrl.text.length);
                                                    marginUpdate();
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: theme.isDarkMode ? MyntColors.primaryDark : MyntColors.primary,
                                                ),
                                              ),
                                              // prefixIcon: InkWell(
                                              //   onTap: () {
                                              //     setState(() {
                
                                              //        String input =
                                              //                 qtyCtrl
                                              //                     .text;
                                              //             int currentQty =
                                              //                 int.tryParse(input) ??
                                              //                     0;
                                              //             int adjustedQty =
                                              //                 ((currentQty / multiplayer).floor()) *
                                              //                     multiplayer;
                                              //             if (currentQty !=
                                              //                 adjustedQty) {
                                              //               qtyCtrl.text =
                                              //                   adjustedQty
                                              //                       .toString();
                                              //             } else if (input
                                              //                   .isNotEmpty && currentQty >
                                              //                   multiplayer) {
                
                                              //                   qtyCtrl
                                              //                       .text = (currentQty -
                                              //                           multiplayer)
                                              //                       .toString();
                                              //               } else {
                                              //               qtyCtrl.text =
                                              //                   "$multiplayer";
                                              //               }
                                              //               marginUpdate();
                                              //           },
                                              //           );
                
                                              //       // String input = qtyCtrl.text;
                                              //       // int quantityValue = int.tryParse(input) ?? 0;
                
                                              //       // if (input.isNotEmpty && quantityValue > multiplayer) {
                                              //       //     qtyCtrl.text = (quantityValue - multiplayer).toString();
                                              //       // } else {
                                              //       //   qtyCtrl.text = "$multiplayer";
                                              //       // }
                                              //       // marginUpdate();
                                              //     // });
                                              //   },
                                              //   child: SvgPicture.asset(
                                              //       theme.isDarkMode
                                              //           ? assets
                                              //               .darkCMinus
                                              //           : theme.isDarkMode
                                              //               ? assets
                                              //                   .darkCMinus
                                              //               : assets
                                              //                   .minusIcon,
                                              //       fit:
                                              //           BoxFit.scaleDown),
                                              // ),
                                              // suffixIcon: InkWell(
                                              //   onTap: () {
                                              //     setState(() {
                                              //             String input =
                                              //                 qtyCtrl
                                              //                 .text;
                                              //         int currentQty =
                                              //             int.tryParse(input) ??
                                              //                 0;
                                              //         int adjustedQty =
                                              //             ((currentQty / multiplayer).round()) *
                                              //                 multiplayer;
                
                                              //         if (currentQty !=
                                              //             adjustedQty) {
                                              //           qtyCtrl.text =
                                              //               adjustedQty
                                              //                   .toString();
                                              //         }
                
                                              //           else if (input
                                              //               .isNotEmpty && currentQty <
                                              //               ((frezQtyOrderSliceMaxLimit*frezQty)==frezQtyOrderSliceMaxLimit?999999:frezQtyOrderSliceMaxLimit*frezQty)) {
                                              //               qtyCtrl.text = (currentQty + multiplayer).toString();
                                              //           } else {
                                              //             ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                              //             ScaffoldMessenger.of(context)
                                              //                 .showSnackBar(warningMessage(context,"Maximum Allowed Quantity $frezQty x $frezQtyOrderSliceMaxLimit = ${frezQtyOrderSliceMaxLimit*frezQty}"));
                                              //           // qtyCtrl.text =
                                              //           //     "$multiplayer";
                                              //           }
                                              //           marginUpdate();
                                              //       });
                
                                              //     //   String input = qtyCtrl.text;
                                              //     //   int quantityValue =int.parse(input);
                
                                              //     //   if (input.isNotEmpty quantityValue) {
                                              //     //     if (number <
                                              //     //         999999) {
                                              //     //       qtyCtrl
                                              //     //           .text = (int.parse(discQtyCtrl.text) +
                                              //     //                       1)
                                              //     //                   .toString();
                                              //     //     }
                                              //     //   } else {
                                              //     //     qtyCtrl.text =
                                              //     //         "$multiplayer";
                                              //     //   }
                                              //     //   marginUpdate();
                                              //     // });
                                              //   },
                                              //   child: SvgPicture.asset(
                                              //       theme.isDarkMode
                                              //           ? assets.darkAdd
                                              //           : assets.addIcon,
                                              //       fit:
                                              //           BoxFit.scaleDown),
                                              // ),
                                              controller: qtyCtrl,
                                              textAlign: _isStock ? TextAlign.start : TextAlign.center,
                                              onChanged: (value) {
                                                if (value.isEmpty ||
                                                    value == "0") {
                                                  ResponsiveSnackBar.showWarning(
                                                      context,
                                                      "Quantity can not be ${value == "0" ? 'zero' : 'empty'}");
                                                } else {
                                                  String newValue =
                                                      value.replaceAll(
                                                          RegExp(r'[^0-9]'),
                                                          '');
                                                  int number = int.tryParse(
                                                          newValue) ??
                                                      0;
                                                  final bool isMcx = widget.scripInfo.exch == "MCX";
                                                  final int numberInUnits = isMcx ? number * lotSize : number;
                                                  if (numberInUnits >
                                                      (frezQty == lotSize
                                                          ? 999999
                                                          : frezQty)) {
                                                    ResponsiveSnackBar
                                                        .showWarning(
                                                            context,
                                                            isMcx
                                                                ? "Maximum Allowed Lots: ${frezQty ~/ lotSize}"
                                                                : "Maximum Allowed Quantity $frezQty");
                                                  }
                                                  if (newValue != value) {
                                                    qtyCtrl.text = newValue;
                                                    qtyCtrl.selection =
                                                        TextSelection
                                                            .fromPosition(
                                                      TextPosition(
                                                          offset: newValue
                                                              .length),
                                                    );
                                                  }
                                                  marginUpdate();
                                                }
                                              },
                                            ),
                
                                            // ScaffoldMessenger.of(
                                            //         context)
                                            //     .hideCurrentSnackBar();
                                            // if (value.isEmpty) {
                                            //   ScaffoldMessenger.of(
                                            //           context)
                                            //       .showSnackBar(
                                            //           warningMessage(
                                            //               context,
                                            //               "Quantity can not be empty"));
                                            // } else {
                                            //   String newValue =
                                            //       value.replaceAll(
                                            //           RegExp(
                                            //               r'[^0-9]'),
                                            //           '');
                                            //   if (newValue != value) {
                                            //     qtyCtrl.text =
                                            //         newValue;
                                            //     qtyCtrl.selection =
                                            //         TextSelection
                                            //             .fromPosition(
                                            //       TextPosition(
                                            //           offset: newValue
                                            //               .length),
                                            //     );
                                            //   }
                                            //   marginUpdate();
                                            // }
                                            //   },
                                            // )
                                          )
                                          ),
                                          // MCX field is in lots — show the
                                          // actual quantity underneath, kept
                                          // live via the controller listener.
                                          // Same lots × lot size the submit
                                          // payload and margin request use.
                                          if (widget.scripInfo.exch == "MCX")
                                            ValueListenableBuilder<
                                                TextEditingValue>(
                                              valueListenable: qtyCtrl,
                                              builder: (context, value, _) =>
                                                  Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  "Qty : ${(int.tryParse(value.text) ?? 0) * lotSize}",
                                                  style: WebTextStyles.para(
                                                    isDarkTheme:
                                                        theme.isDarkMode,
                                                    color: theme.isDarkMode
                                                        ? MyntColors
                                                            .textPrimaryDark
                                                        : MyntColors
                                                            .textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ])),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              // CO/BO stop-loss leg cannot be SL Market — block the
                                              // switch to Market (mirrors Place Order + vendor behaviour).
                                              if (_isBOCOOrderEnabled &&
                                                  _isStoplossOrder &&
                                                  !_isMarketOrder) {
                                                ResponsiveSnackBar.showWarning(context,
                                                    "SL Market order is not allowed for CO-BO orders");
                                                return;
                                              }
                                              setState(() {
                                                _isMarketOrder = !_isMarketOrder;
                                                updatePriceType();
                                                marginUpdate();
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                headerTitleText("Price", theme),
                                                const SizedBox(width: 8),
                                                SvgPicture.asset(
                                                  assets.switchIcon,
                                                  width: 16,
                                                  height: 16,
                                                  fit: BoxFit.contain,
                                                  colorFilter: theme.isDarkMode
                                                      ? const ColorFilter.mode(
                                                          MyntColors.primaryDark,
                                                          BlendMode.srcIn)
                                                      : const ColorFilter.mode(
                                                          MyntColors.primary,
                                                          BlendMode.srcIn
                                                ),
                                            )],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Focus(
                                            onKeyEvent: (node, event) => _handlePriceArrowKey(event, priceCtrl),
                                            child: SizedBox(
                                            height: 40,
                                            // width: 150,
                                            child: MyntTextField(
                                                backgroundColor: theme.isDarkMode
                                                    ? colors.darkGrey
                                                    : const Color(0xffF1F3F8),
                                                inputFormatters: [
                                                  _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
                                                ],
                                                onChanged: (value) {
                                                  double inputPrice =
                                                      double.tryParse(
                                                              value) ??
                                                          0;
                                                  // if (value.isNotEmpty &&
                                                  //     inputPrice > 0) {
                                                  //   final regex = RegExp(
                                                  //       r'^(\d+)?(\.\d{0,2})?$');
                                                  //   if (!regex
                                                  //       .hasMatch(value)) {
                                                  //     priceCtrl.text =
                                                  //         value.substring(
                                                  //             0,
                                                  //             value.length -
                                                  //                 1); // Revert to previous valid input
                                                  //     priceCtrl.selection =
                                                  //         TextSelection.collapsed(
                                                  //             offset: priceCtrl
                                                  //                 .text
                                                  //                 .length); // Keep cursor at the end
                                                  //   }
                                                  // }
                                                  if (value.isEmpty ||
                                                      inputPrice <= 0) {
                                                    ResponsiveSnackBar
                                                        .showWarning(context,
                                                            "Limit Price can not be ${inputPrice <= 0 ? 'zero' : 'empty'}");
                                                  } else {
                                                    // Circuit (LC/UC) check removed from onChange — it fired a toast
                                                    // on every keystroke while typing. Still enforced on the Modify
                                                    // Order click (matches Place Order).
                                                    // if (_hasValidCircuitBreakerValues &&
                                                    //     ((double.parse(value) < double.parse("${widget.scripInfo.lc}")) ||
                                                    //       (double.parse(value) > double.parse("${widget.scripInfo.uc}")))) {
                                                    //       ResponsiveSnackBar.showWarning(
                                                    //           context,
                                                    //           double.parse(value) < double.parse("${widget.scripInfo.lc}")
                                                    //               ? "Limit Price can not be lesser than Lower Circuit Limit ${widget.scripInfo.lc}"
                                                    //               : "Limit Price can not be greater than Upper Circuit Limit ${widget.scripInfo.uc}");
                                                    //   }
                                                    setState(() {
                                                      price = value;
                                                      marginUpdate();
                                                    });
                                                  }
                                                },
                                                placeholder:
                                                    "${widget.orderArg.ltp}",
                                                placeholderStyle:
                                                    WebTextStyles.formInput(
                                                  isDarkTheme:
                                                      theme.isDarkMode,
                                                  color: theme.isDarkMode
                                                      ? MyntColors.textSecondary
                                                      : MyntColors.textSecondary,
                                                ),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                textStyle:
                                                    WebTextStyles.formInput(
                                                  isDarkTheme:
                                                      theme.isDarkMode,
                                                  color: theme.isDarkMode
                                                      ? MyntColors.textPrimaryDark
                                                      : MyntColors.textPrimary,
                                                ),
                                                readOnly: prcType ==
                                                            "MKT" ||
                                                        prcType == "SL-MKT"
                                                    ? true
                                                    : false,
                                                controller: priceCtrl,
                                                textAlign: TextAlign.start),
                                          ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (prcType == "MKT" ||
                                  prcType == "SL-MKT") ...[
                                const SizedBox(height: 16),
                                // Market protection is not editable on modify
                                // (vendor does not allow changing it) — show only.
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Text("Market Protected by",
                                          style: WebTextStyles.sub(
                                            isDarkTheme: theme.isDarkMode,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary),
                                          )),
                                      const SizedBox(width: 6),
                                      Text("${mktProtCtrl.text} %",
                                          style: WebTextStyles.para(
                                            isDarkTheme: theme.isDarkMode,
                                            color: resolveThemeColor(context,
                                                dark: MyntColors.primaryDark,
                                                light: MyntColors.primary),
                                            fontWeight: WebFonts.semiBold,
                                          )),
                                    ],
                                  ),
                                ),
                                // const SizedBox(height: 16),
                              ],
                              // Advanced options — always visible (the former
                              // "Advance" show/hide toggle was removed by
                              // design; its code is kept commented below for
                              // easy rollback).
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  // Center(
                                  //   child: SizedBox(
                                  //     width: 150,
                                  //     child: TextButton(
                                  //       style: TextButton.styleFrom(
                                  //         shape: const RoundedRectangleBorder(),
                                  //         padding: const EdgeInsets.all(0),
                                  //         backgroundColor: Colors.transparent,
                                  //         foregroundColor: resolveThemeColor(context, dark: MyntColors.textPrimaryDark, light: MyntColors.textPrimary),
                                  //         overlayColor: Colors.transparent,
                                  //         elevation: 0.0,
                                  //         minimumSize: const Size(0, 30),
                                  //         side: BorderSide.none,
                                  //       ),
                                  //       onPressed: () {
                                  //         setState(() {
                                  //           if (!_isStoplossOrder &&
                                  //               // !_afterMarketOrder &&
                                  //               !_addValidityAndDisclosedQty) {
                                  //             isAdvancedOptionClicked =
                                  //                 !isAdvancedOptionClicked;
                                  //           }
                                  //           updatePriceType();
                                  //         });
                                  //       },
                                  //       child: Container(
                                  //         color: Colors.transparent,
                                  //         height: 40,
                                  //         child: Center(
                                  //           child: Row(
                                  //             mainAxisSize: MainAxisSize.min,
                                  //             children: [
                                  //               Text('Advance',
                                  //                   style: WebTextStyles.sub(
                                  //                     isDarkTheme: theme.isDarkMode,
                                  //                     color: resolveThemeColor(context,
                                  //                         dark: MyntColors.primaryDark,
                                  //                         light: MyntColors.primary),
                                  //                     fontWeight: WebFonts.semiBold,
                                  //                   )),
                                  //               Padding(
                                  //                 padding: const EdgeInsets.only(
                                  //                     left: 4),
                                  //                 child: Icon(
                                  //                   isAdvancedOptionClicked
                                  //                       ? Icons.keyboard_arrow_up
                                  //                       : Icons.keyboard_arrow_down,
                                  //                   color: resolveThemeColor(context,
                                  //                       dark: MyntColors.primaryDark,
                                  //                       light: MyntColors.primary),
                                  //                 ),
                                  //               ),
                                  //             ],
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  // Visibility(
                                  //   visible: isAdvancedOptionClicked,
                                  //   child:
                                  Column(
                                      children: [
                                        Divider(
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.cardBorderDark,
                                              light: MyntColors.cardBorder),
                                          thickness: 0.5,
                                        ),
                
                                        // Column with Stoploss and Add validity (stacked vertically)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Stoploss order
                                            Theme(
                                              data: ThemeData(
                                                unselectedWidgetColor: theme
                                                        .isDarkMode
                                                    ? MyntColors.textPrimary
                                                    : MyntColors.textPrimary,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 16,
                                                    vertical: 5),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        'Stoploss order',
                                                        style:
                                                            WebTextStyles.sub(
                                                          isDarkTheme: theme
                                                              .isDarkMode,
                                                          color: theme
                                                                  .isDarkMode
                                                              ? MyntColors
                                                                  .textPrimaryDark
                                                              : MyntColors
                                                                  .textSecondary,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Checkbox(
                                                      value: _isStoplossOrder,
                                                      onChanged:
                                                          (bool? value) {
                                                        setState(() {
                                                          _isStoplossOrder =
                                                              value ?? false;
                                                          updatePriceType();
                                                          marginUpdate();
                                                        });
                                                      },
                                                      activeColor: resolveThemeColor(context,
                                                          dark: MyntColors.secondary,
                                                          light: MyntColors.primary),
                                                      checkColor:
                                                          Colors.white,
                                                      side: theme.isDarkMode ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Trigger option (only if stoploss is on)
                                            if (prcType == "SL-LMT" ||
                                                prcType == "SL-MKT") ...[
                                              triggerOption(theme, context,
                                                  widget.scripInfo),
                                            ],
                                            // Divider after Stoploss order
                                            Divider(
                                                      color: resolveThemeColor(
                                                          context,
                                                          dark: colors
                                                              .darkColorDivider,
                                                          light: colors
                                                              .colorDivider),thickness: 0.5,),
                
                                            // Add validity & Disclosed Qty (only if not BO/CO)
                                            if (!_isBOCOOrderEnabled) ...[
                                              Theme(
                                                data: ThemeData(
                                                  unselectedWidgetColor: theme
                                                          .isDarkMode
                                                      ? MyntColors.textPrimary
                                                      : MyntColors.textPrimary,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 5),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          'Add validity & Disclosed quantity',
                                                          style: WebTextStyles
                                                              .sub(
                                                            isDarkTheme: theme
                                                                .isDarkMode,
                                                            color: theme
                                                                    .isDarkMode
                                                                ? MyntColors.textPrimaryDark
                                                                : MyntColors.textSecondary,
                                                          ),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      Checkbox(
                                                        value:
                                                            _addValidityAndDisclosedQty,
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            _addValidityAndDisclosedQty =
                                                                value ??
                                                                    false;
                                                            addValidity =
                                                                _addValidityAndDisclosedQty;
                                                          });
                                                        },
                                                        activeColor: resolveThemeColor(context,
                                                            dark: MyntColors.secondary,
                                                            light: MyntColors.primary),
                                                        checkColor:
                                                            Colors.white,
                                                        side: theme.isDarkMode ? const BorderSide(color: Color(0xFF6E7681), width: 1.5) : null,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Validity options (only if enabled)
                                              if (_addValidityAndDisclosedQty) ...[
                                                addValidityAndDisclosedQtyOption(
                                                    theme,
                                                    context,
                                                    widget.scripInfo),
                                              ],
                                            ],
                                          ],
                                        ),
                
                                        // if (!_isBOCOOrderEnabled) ...[
                                          // AMO switch section
                                          // Divider(
                                          //             color: resolveThemeColor(
                                          //                 context,
                                          //                 dark: colors
                                          //                     .darkColorDivider,
                                          //                 light: colors
                                          //                     .colorDivider),thickness: 0.5,),
                                          // Theme(
                                          //   data: ThemeData(
                                          //     unselectedWidgetColor: theme
                                          //             .isDarkMode
                                          //         ? MyntColors.textPrimary
                                          //         : MyntColors.textPrimary,
                                          //   ),
                                          //   child: Container(
                                          //     padding:
                                          //         const EdgeInsets.symmetric(
                                          //             horizontal: 16,
                                          //             vertical: 5),
                                          //     child: Row(
                                          //       mainAxisAlignment:
                                          //           MainAxisAlignment
                                          //               .spaceBetween,
                                          //       children: [
                                          //         Text(
                                          //           'After market order (AMO)',
                                          //           style: WebTextStyles.sub(
                                          //             isDarkTheme:
                                          //                 theme.isDarkMode,
                                          //             color: theme.isDarkMode
                                          //                 ? MyntColors.textSecondary
                                          //                 : MyntColors.textSecondary,
                                          //           ),
                                          //         ),
                                          //         Checkbox(
                                          //           value: _afterMarketOrder,
                                          //           onChanged: (bool? value) {
                                          //             setState(() {
                                          //               _afterMarketOrder =
                                          //                   value ?? false;
                                          //               isAmo =
                                          //                   _afterMarketOrder;
                                          //             });
                                          //           },
                                          //           activeColor:
                                          //               colors.colorBlue,
                                          //           checkColor: Colors.white,
                                          //         ),
                                          //       ],
                                          //     ),
                                          //   ),
                                          // ),
                                          //  Divider(
                                          //               color: resolveThemeColor(
                                          //                   context,
                                          //                   dark: colors
                                          //                       .darkColorDivider,
                                          //                   light: colors
                                          //                       .colorDivider),thickness: 0.5,),
                                          // ],
                                      ],
                                    ),
                                  // ), // ← closer of the former Visibility
                                ],
                              ),

                              // Trigger option is now handled inside the advanced options section
                              if (_isBOCOOrderEnabled) ...[
                                const SizedBox(height: 16),
                                stopLossOption(
                                    theme, context, widget.scripInfo)
                              ],
                              // Padding(
                              //     padding:
                              //         const EdgeInsets.only(left: 16, right: 4),
                              //     child: Row(
                              //         mainAxisAlignment:
                              //             MainAxisAlignment.spaceBetween,
                              //         children: [
                              //           Text("Add Validity & Disclosed Qty",
                              //               style: textStyle(
                              //                   const Color(0xff666666),
                              //                   14,
                              //                   FontWeight.w500)),
                              //           IconButton(
                              //               onPressed: () {
                              //                 setState(() {
                              //                   addValidity = !addValidity;
                              //                 });
                              //               },
                              //               icon: SvgPicture.asset(theme
                              //                       .isDarkMode
                              //                   ? addValidity
                              //                       ? assets.darkCheckedboxIcon
                              //                       : assets.darkCheckboxIcon
                              //                   : addValidity
                              //                       ? assets.checkedbox
                              //                       : assets.checkbox))
                              //         ])),
                              // if (addValidity) ...[
                              //   Padding(
                              //       padding: const EdgeInsets.symmetric(
                              //           horizontal: 16),
                              //       child: Row(
                              //           crossAxisAlignment:
                              //               CrossAxisAlignment.start,
                              //           children: [
                              //             Expanded(
                              //                 child: Column(
                              //                     crossAxisAlignment:
                              //                         CrossAxisAlignment.start,
                              //                     children: [
                              //                   headerTitleText(
                              //                       "Validity", theme),
                              //                   const SizedBox(height: 7),
                              //                   SizedBox(
                              //                     height: 43,
                              //                     child: ListView.separated(
                              //                         scrollDirection:
                              //                             Axis.horizontal,
                              //                         itemBuilder:
                              //                             (context, index) {
                              //                           return ElevatedButton(
                              //                             onPressed: () {
                              //                               setState(() {
                              //                                 for (var i = 0;
                              //                                     i <
                              //                                         validityType
                              //                                             .length;
                              //                                     i++) {
                              //                                   isActiveValidity[
                              //                                       i] = false;
                              //                                 }
                              //                                 isActiveValidity[
                              //                                     index] = true;
                
                              //                                 validity =
                              //                                     validityType[
                              //                                         index];
                              //                               });
                              //                             },
                              //                             style: ElevatedButton
                              //                                 .styleFrom(
                              //                                     elevation: 0,
                              //                                     padding: const EdgeInsets
                              //                                         .symmetric(
                              //                                         horizontal:
                              //                                             12,
                              //                                         vertical:
                              //                                             0),
                              //                                     backgroundColor: !theme
                              //                                             .isDarkMode
                              //                                         ? !isActiveValidity[
                              //                                                 index]
                              //                                             ? const Color(
                              //                                                 0xffF1F3F8)
                              //                                             : colors
                              //                                                 .colorBlack
                              //                                         : !isActiveValidity[
                              //                                                 index]
                              //                                             ? colors
                              //                                                 .darkGrey
                              //                                             : colors
                              //                                                 .colorWhite,
                              //                                     shape:
                              //                                         const StadiumBorder()),
                              //                             child: Text(
                              //                               validityType[index],
                              //                               style: textStyle(
                              //                                   !theme
                              //                                           .isDarkMode
                              //                                       ? !isActiveValidity[
                              //                                               index]
                              //                                           ? const Color(
                              //                                               0xff666666)
                              //                                           : colors
                              //                                               .colorWhite
                              //                                       : !isActiveValidity[
                              //                                               index]
                              //                                           ? const Color(
                              //                                               0xff666666)
                              //                                           : colors
                              //                                               .colorBlack,
                              //                                   14,
                              //                                   isActiveValidity[
                              //                                           index]
                              //                                       ? FontWeight
                              //                                           .w600
                              //                                       : FontWeight
                              //                                           .w500),
                              //                             ),
                              //                           );
                              //                         },
                              //                         separatorBuilder:
                              //                             (context, index) {
                              //                           return const SizedBox(
                              //                               width: 8);
                              //                         },
                              //                         itemCount:
                              //                             validityType.length),
                              //                   )
                              //                 ])),
                              //             const SizedBox(width: 16),
                              //             Expanded(
                              //                 child: Column(
                              //                     crossAxisAlignment:
                              //                         CrossAxisAlignment.start,
                              //                     children: [
                              //                   headerTitleText(
                              //                       "Disclosed Qty", theme),
                              //                   const SizedBox(height: 7),
                              //                   SizedBox(
                              //                       height: 44,
                              //                       child: CustomTextFormField(
                              //                           fillColor:
                              //                               theme.isDarkMode
                              //                                   ? colors
                              //                                       .darkGrey
                              //                                   : const Color(
                              //                                       0xffF1F3F8),
                              //                           // type:"int",
                              //                           hintText: "0",
                              //                           hintStyle: textStyle(
                              //                               const Color(
                              //                                   0xff666666),
                              //                               15,
                              //                               FontWeight.w400),
                              //                           inputFormate: [
                              //                             FilteringTextInputFormatter
                              //                                 .digitsOnly
                              //                           ],
                              //                           keyboardType:
                              //                               TextInputType
                              //                                   .number,
                              //                           style: textStyle(
                              //                               theme.isDarkMode
                              //                                   ? colors
                              //                                       .colorWhite
                              //                                   : colors
                              //                                       .colorBlack,
                              //                               16,
                              //                               FontWeight.w600),
                              //                           prefixIcon: InkWell(
                              //                             onTap: () {
                              //                               setState(() {
                              //                                 if (discQtyCtrl
                              //                                     .text
                              //                                     .isNotEmpty) {
                              //                                   if (int.parse(
                              //                                           discQtyCtrl
                              //                                               .text) >
                              //                                       0) {
                              //                                     discQtyCtrl
                              //                                             .text =
                              //                                         (int.parse(discQtyCtrl.text) -
                              //                                                 1)
                              //                                             .toString();
                              //                                   } else {
                              //                                     discQtyCtrl
                              //                                             .text =
                              //                                         "0";
                              //                                   }
                              //                                 } else {
                              //                                   discQtyCtrl
                              //                                       .text = "0";
                              //                                 }
                              //                               });
                              //                             },
                              //                             child: SvgPicture.asset(
                              //                                 theme.isDarkMode
                              //                                     ? assets
                              //                                         .darkCMinus
                              //                                     : assets
                              //                                         .minusIcon,
                              //                                 fit: BoxFit
                              //                                     .scaleDown),
                              //                           ),
                              //                           suffixIcon: InkWell(
                              //                             onTap: () {
                              //                               setState(() {
                              //                                 int number =
                              //                                     int.parse(
                              //                                         discQtyCtrl
                              //                                             .text);
                              //                                 if (discQtyCtrl
                              //                                     .text
                              //                                     .isNotEmpty) {
                              //                                   if (number <
                              //                                       999999) {
                              //                                     discQtyCtrl
                              //                                             .text =
                              //                                         (int.parse(discQtyCtrl.text) +
                              //                                                 1)
                              //                                             .toString();
                              //                                   }
                              //                                 } else {
                              //                                   discQtyCtrl.text = "0";
                              //                                 }
                              //                               });
                              //                             },
                              //                             child: SvgPicture.asset(
                              //                                 theme.isDarkMode
                              //                                     ? assets
                              //                                         .darkAdd
                              //                                     : assets
                              //                                         .addIcon,
                              //                                 fit: BoxFit
                              //                                     .scaleDown),
                              //                           ),
                              //                           textCtrl: discQtyCtrl,
                              //                           textAlign:
                              //                               TextAlign.center))
                              //                 ]))
                              //           ])),
                              //   const SizedBox(height: 10)
                              // ],
                              // const Divider(
                              //     color: Color(0xffDDDDDD), height: 0),
                              // Padding(
                              //     padding:
                              //         const EdgeInsets.only(left: 16, right: 4),
                              //     child: Row(
                              //         mainAxisAlignment:
                              //             MainAxisAlignment.spaceBetween,
                              //         children: [
                              //           Text("After Market Order (AMO)",
                              //               style: textStyle(
                              //                   const Color(0xff666666),
                              //                   14,
                              //                   FontWeight.w500)),
                              //           IconButton(
                              //               onPressed: () {
                              //                 setState(() {
                              //                   isAmo = !isAmo;
                              //                 });
                              //               },
                              //               icon: SvgPicture.asset(theme
                              //                       .isDarkMode
                              //                   ? isAmo
                              //                       ? assets.darkCheckedboxIcon
                              //                       : assets.darkCheckboxIcon
                              //                   : isAmo
                              //                       ? assets.checkedbox
                              //                       : assets.checkbox))
                              //         ])),
                              
                              const SizedBox(height: 100)
                            ])),
                    if (internet.connectionStatus ==
                        ConnectivityResult.none) ...[const NoInternetWidget()]
                  ],
                ),
              ),
              // Bottom navigation bar
              internet.connectionStatus == ConnectivityResult.none
                  ? const NoInternetWidget()
                  : SafeArea(
                      child: Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: Container(
                            color: resolveThemeColor(context,
                                dark: MyntColors.backgroundColorDark,
                                light: MyntColors.backgroundColor),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // if (prcType == "MKT" || prcType == "SL-MKT") ...[
                                  //   Padding(
                                  //     padding: const EdgeInsets.only(
                                  //         left: 16.0, bottom: 6),
                                  //     child: headerTitleText(
                                  //         "Market Protection", theme),
                                  //   ),
                                  //   Container(
                                  //       padding: const EdgeInsets.only(
                                  //           left: 16.0, bottom: 6),
                                  //       height: 40,
                                  //       child: Row(children: [
                                  //         Expanded(
                                  //             child: CustomTextFormField(
                                  //                 fillColor: theme.isDarkMode
                                  //                     ? colors.darkGrey
                                  //                     : const Color(0xffF1F3F8),
                                  //                 inputFormate: [
                                  //                   FilteringTextInputFormatter
                                  //                       .digitsOnly
                                  //                 ],
                                  //                 onChanged: (value) {
                                  //                   setState(() {
                                  //                     ScaffoldMessenger.of(context)
                                  //                         .hideCurrentSnackBar();
                                  //                     if (value.isNotEmpty) {
                                  //                       if (int.parse(value) > 20) {
                                  //                         mktProtCtrl.text = "20";
                                  //                         ScaffoldMessenger.of(
                                  //                                 context)
                                  //                             .showSnackBar(
                                  //                                 warningMessage(
                                  //                                     context,
                                  //                                     "can't enter greater than 20% of Market Protection"));
                                  //                       } else if (int.parse(
                                  //                               value) <
                                  //                           1) {
                                  //                         mktProtCtrl.text = "1";
                                  //                         ScaffoldMessenger.of(
                                  //                                 context)
                                  //                             .showSnackBar(
                                  //                                 warningMessage(
                                  //                                     context,
                                  //                                     "can't enter less than 1% of Market Protection"));
                                  //                       }
                                  //                     }
                                  //                   });
                                  //                 },
                                  //                 keyboardType:
                                  //                     TextInputType.number,
                                  //                 style: textStyle(
                                  //                     theme.isDarkMode
                                  //                         ? colors.colorWhite
                                  //                         : colors.colorBlack,
                                  //                     14,
                                  //                     FontWeight.w600),
                                  //                 textCtrl: mktProtCtrl,
                                  //                 textAlign: TextAlign.start))
                                  //       ]))
                                  // ],
                                  Container(
                                      width: MediaQuery.of(context).size.width,
                                      // height: 36,
                                      decoration: BoxDecoration(
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.cardDark,
                                              light: const Color(0xfffafbff)),
                                          border: Border(
                                              top: BorderSide(
                                                  color: resolveThemeColor(context,
                                                      dark: MyntColors.cardBorderDark,
                                                      light: MyntColors.cardBorder)),
                                              bottom: BorderSide(
                                                  color: resolveThemeColor(context,
                                                      dark: MyntColors.cardBorderDark,
                                                      light: MyntColors.cardBorder)))),
                                      padding: const EdgeInsets.only(
                                          left: 16.0, right: 3, top: 0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SingleChildScrollView(
                                            padding: const EdgeInsets.all(0),
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(children: [
                                                    CustomWidgetButton(
                                                        onPress: internet
                                                                    .connectionStatus ==
                                                                ConnectivityResult
                                                                    .none
                                                            ? () {}
                                                            : () {
                                                                marginUpdate();
                                                                // On web, show dialog as overlay entry above the order screen
                                                                final overlay =
                                                                    Overlay.of(
                                                                        context,
                                                                        rootOverlay:
                                                                            true);
                                                                late OverlayEntry
                                                                    dialogOverlayEntry;

                                                                dialogOverlayEntry =
                                                                    OverlayEntry(
                                                                  builder:
                                                                      (overlayContext) =>
                                                                          Stack(
                                                                    children: [
                                                                      // Backdrop
                                                                      Positioned
                                                                          .fill(
                                                                        child:
                                                                            GestureDetector(
                                                                          onTap:
                                                                              () {
                                                                            dialogOverlayEntry.remove();
                                                                          },
                                                                          child:
                                                                              Container(
                                                                            color:
                                                                                Colors.black.withOpacity(0.5),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      // Dialog centered
                                                                      Center(
                                                                        child:
                                                                            Material(
                                                                          color:
                                                                              Colors.transparent,
                                                                          child:
                                                                              MarginDetailsDialogWeb(
                                                                            onClose:
                                                                                () {
                                                                              dialogOverlayEntry.remove();
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );

                                                                overlay.insert(
                                                                    dialogOverlayEntry);
                                                              },
                                                        widget: Row(children: [
                                                          TextWidget.paraText(
                                                              text:
                                                                  "Ord Mrg : ",
                                                              theme: theme
                                                                  .isDarkMode,
                                                              color: theme.isDarkMode
                                                                  ? MyntColors.textPrimaryDark
                                                                  : MyntColors.textSecondary,
                                                              fw: 3),
                                                          Text(
                                                              "₹${orderProvide.orderMarginModel == null ? 0.00 : orderProvide.orderMarginModel!.ordermargin}  + ${orderProvide.getBrokerageModel == null ? 0.00 : orderProvide.getBrokerageModel!.brkageAmt ?? 0.00}",
                                                              style: textStyle(
                                                                  !theme.isDarkMode
                                                                      ? MyntColors.primary
                                                                      : MyntColors.primaryDark,
                                                                  12,
                                                                  FontWeight
                                                                      .w600)),
                                                          Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            color: !theme
                                                                    .isDarkMode
                                                                ? MyntColors.primary
                                                                : MyntColors.primaryDark
                                                          )
                                                        ])),
                                                    const SizedBox(width: 16),
                                                    Row(
                                                      children: [
                                                        TextWidget.paraText(
                                                            text: "Avl Mrg : ",
                                                            theme: theme
                                                                .isDarkMode,
                                                            color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textSecondaryDark
                                                                : colors
                                                                    .textSecondaryLight,
                                                            fw: 3),

                                                        // const SizedBox(width: 4),
                                                        TextWidget.paraText(
                                                            text:
                                                                " ${clientFundDetail?.avlMrg ?? ''}",
                                                            theme: theme
                                                                .isDarkMode,
                                                            color: theme
                                                                    .isDarkMode
                                                                ? colors
                                                                    .textPrimaryDark
                                                                : colors
                                                                    .textPrimaryLight,
                                                            fw: 3),
                                                        // const SizedBox(width: 4),
                                                      ],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    orderProvide.orderMarginModel !=
                                                            null
                                                        ? orderProvide
                                                                    .orderMarginModel!
                                                                    .remarks ==
                                                                "Insufficient Balance"
                                                            ? InkWell(
                                                                onTap: () {
                                                                  // ref
                                                                  //     .read(
                                                                  //         transcationProvider)
                                                                  //     .fetchValidateToken(
                                                                  //         context);
                                                                  // Future.delayed(
                                                                  //     const Duration(
                                                                  //         milliseconds:
                                                                  //             100),
                                                                  //     () async {
                                                                  //   await trancation
                                                                  //       .ip();
                                                                  //   await trancation.fetchupiIdView(
                                                                  //       trancation.bankdetails!.dATA![trancation.indexss]
                                                                  //           [1],
                                                                  //       trancation
                                                                  //           .bankdetails!
                                                                  //           .dATA![trancation.indexss][2]);
                                                                  //   await trancation
                                                                  //       .fetchcwithdraw(
                                                                  //           context);
                                                                  // });

                                                                  // trancation
                                                                  //     .changebool(
                                                                  //         true);
                                                                  // Navigator.pushNamed(
                                                                  //     context,
                                                                  //     Routes
                                                                  //         .fundscreen,
                                                                  //     arguments:
                                                                  //         trancation);
                                                                  openFunds('fund', context);
                                                                },
                                                                child: Row(
                                                                  children: [
                                                                    // Red circular icon with white exclamation mark
                                                                    // Container(
                                                                    //   width: 20,
                                                                    //   height: 20,
                                                                    //   decoration: const BoxDecoration(
                                                                    //     color: Colors.white,
                                                                    //     shape: BoxShape.circle,
                                                                    //   ),
                                                                    //   child: const Center(
                                                                    //     child: Icon(
                                                                    //       Icons.error, // Exclamation icon
                                                                    //       color: Colors.red,
                                                                    //       size: 20,
                                                                    //     ),
                                                                    //   ),
                                                                    // ),

                                                                    // "+ Add fund" text in blue
                                                                    Text(
                                                                      '+ Add fund',
                                                                      style: textStyle(
                                                                          resolveThemeColor(context,
                                                                              dark: MyntColors.primaryDark,
                                                                              light: MyntColors.primary),
                                                                          12,
                                                                          FontWeight.w600),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            8),
                                                                  ],
                                                                ),
                                                              )
                                                            : const SizedBox()
                                                        : const SizedBox(),
                                                    // CustomWidgetButton(
                                                    //   onPress:
                                                    //       internet.connectionStatus ==
                                                    //               ConnectivityResult
                                                    //                   .none
                                                    //           ? () {}
                                                    //           : () {
                                                    //               marginUpdate();

                                                    //               showModalBottomSheet(
                                                    //                   useSafeArea: true,
                                                    //                   isScrollControlled:
                                                    //                       true,
                                                    //                   shape: const RoundedRectangleBorder(
                                                    //                       borderRadius:
                                                    //                           BorderRadius.vertical(
                                                    //                               top: Radius.circular(
                                                    //                                   16))),
                                                    //                   context: context,
                                                    //                   builder:
                                                    //                       (context) {
                                                    //                     return const ChargesDetailsBottomsheet();
                                                    //                   });
                                                    //             },
                                                    //   widget: Row(children: [
                                                    //     Text("Charges: ",
                                                    //         style: textStyle(
                                                    //             const Color(0xff666666),
                                                    //             12,
                                                    //             FontWeight.w500)),
                                                    //     Text(
                                                    //         "₹${orderProvide.getBrokerageModel == null ? 0.00 : orderProvide.getBrokerageModel!.brkageAmt ?? 0.00}",
                                                    //         style: textStyle(
                                                    //             !theme.isDarkMode
                                                    //                 ? colors.colorBlue
                                                    //                 : colors
                                                    //                     .colorLightBlue,
                                                    //             12,
                                                    //             FontWeight.w600)),
                                                    //     Icon(
                                                    //       Icons.arrow_drop_down,
                                                    //       color: !theme.isDarkMode
                                                    //           ? colors.colorBlue
                                                    //           : colors.colorLightBlue,
                                                    //     )
                                                    //   ]),
                                                    // )
                                                  ]),
                                                  IconButton(
                                                      onPressed: internet
                                                                  .connectionStatus ==
                                                              ConnectivityResult
                                                                  .none
                                                          ? null
                                                          : () {
                                                              marginUpdate();
                                                            },
                                                      icon: SvgPicture.asset(
                                                          assets.reloadIcon))
                                                ]),
                                          ),
                                        ],
                                      )),
                                  Builder(builder: (context) {
                                    final closeNotifier =
                                        _ModifyPlaceOrderDialogCloseNotifier.of(
                                            context);
                                    return Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Row(
                                        children: [
                                          // const SizedBox(width: 8),
                                          // Expanded(
                                          //   child: Container(
                                          //     height: 40,
                                          //     decoration: BoxDecoration(
                                          //       border: theme.isDarkMode
                                          //           ? null
                                          //           : Border.all(
                                          //               color:
                                          //                   colors.primaryLight,
                                          //               width: 1),
                                          //       color: theme.isDarkMode
                                          //           ? colors.textSecondaryDark
                                          //               .withOpacity(0.6)
                                          //           : colors.btnBg,
                                          //       borderRadius:
                                          //           BorderRadius.circular(5),
                                          //     ),
                                          //     child: Material(
                                          //       color: Colors.transparent,
                                          //       shape: const CircleBorder(),
                                          //       child: InkWell(
                                          //         customBorder:
                                          //             const BeveledRectangleBorder(),
                                          //         splashColor: theme.isDarkMode
                                          //             ? colors.splashColorDark
                                          //             : colors.splashColorLight,
                                          //         highlightColor: theme
                                          //                 .isDarkMode
                                          //             ? colors.highlightDark
                                          //             : colors.highlightLight,
                                          //         onTap: closeNotifier?.onClose,
                                          //         child: Center(
                                          //           child: Text(
                                          //             "Close",
                                          //             style: WebTextStyles
                                          //                 .buttonMd(
                                          //               isDarkTheme:
                                          //                   theme.isDarkMode,
                                          //               color: theme.isDarkMode
                                          //                   ? colors.colorWhite
                                          //                   : colors
                                          //                       .primaryLight,
                                          //             ),
                                          //           ),
                                          //         ),
                                          //       ),
                                          //     ),
                                          //   ),
                                          // ),
                                          // const SizedBox(width: 8),
                                          Expanded(
                                            child: SizedBox(
                                              height: 40,
                                              child: ElevatedButton(
                                                  onPressed:
                                                      internet.connectionStatus ==
                                                              ConnectivityResult
                                                                  .none
                                                          ? null
                                                          : () async {
                                                              if (!orderProvide
                                                                  .orderloader) {
                                                                if (qtyCtrl.text
                                                                        .isEmpty ||
                                                                    priceCtrl
                                                                        .text
                                                                        .isEmpty) {
                                                                  ResponsiveSnackBar.showWarning(
                                                                      context,
                                                                      qtyCtrl.text
                                                                              .isEmpty
                                                                          ? "${widget.scripInfo.exch == 'MCX' ? 'Lot' : 'Quantity'} cannot be empty"
                                                                          : "Price cannot be empty");
                                                                } else if (qtyCtrl.text ==
                                                                        "0" ||
                                                                    // Limit orders only: block a 0/0.00 limit price.
                                                                    // Market/SL-MKT carry "Market" here, so skip them.
                                                                    ((prcType == "LMT" || prcType == "SL-LMT") &&
                                                                        SafeParse.toDouble(priceCtrl.text) <= 0)) {
                                                                  ResponsiveSnackBar.showWarning(
                                                                      context,
                                                                      qtyCtrl.text ==
                                                                              "0"
                                                                          ? "${widget.scripInfo.exch == 'MCX' ? 'Lot' : 'Quantity'} cannot be 0"
                                                                          : "Price cannot be 0");
                                                                } else if (_hasValidCircuitBreakerValues &&
                                                                    prcType != "MKT" &&
                                                                    prcType != "SL-MKT" &&
                                                                    ((double.parse(priceCtrl.text) < double.parse("${widget.scripInfo.lc}")) ||
                                                                    (double.parse(priceCtrl.text) >
                                                                        double.parse(
                                                                            "${widget.scripInfo.uc}")))) {
                                                                  // Skip for MKT/SL-MKT: they have no limit price ("Market"),
                                                                  // so a price-vs-circuit check would falsely block the modify
                                                                  // (mirrors the Place screen, which gates this to limit orders).
                                                                  ResponsiveSnackBar.showWarning(
                                                                      context,
                                                                      double.parse(priceCtrl.text) <
                                                                              double.parse("${widget.scripInfo.lc}")
                                                                          ? "Price can not be lesser than Lower Circuit Limit ${widget.scripInfo.lc}"
                                                                          : "Price can not be greater than Upper Circuit Limit ${widget.scripInfo.uc}");
                                                                } else if ((prcType ==
                                                                        "SL-LMT" ||
                                                                    prcType ==
                                                                        "SL-MKT")) {
                                                                  if (triggerPriceCtrl
                                                                          .text
                                                                          .isEmpty ||
                                                                      SafeParse.toDouble(triggerPriceCtrl.text) <=
                                                                          0) {
                                                                    showResponsiveWarningMessage(
                                                                        context,
                                                                        triggerPriceCtrl.text.isEmpty
                                                                            ? "Trigger can not be empty"
                                                                            : "Trigger can not be 0");
                                                                  } else {
                                                                    // Get the order price for limit orders
                                                                    String ordPrice = prcType == "SL-MKT" ? price : priceCtrl.text;

                                                                    if (isBuy) {
                                                                      // BUY + SL-MKT: Trigger should be greater than LTP
                                                                      if (prcType == "SL-MKT") {
                                                                        if (SafeParse.toDouble(triggerPriceCtrl.text) <
                                                                            SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be greater than LTP");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be greater than upper circuit limit of ${widget.scripInfo.uc}");
                                                                        } else {
                                                                          modifyOrder();
                                                                        }
                                                                      } else {
                                                                        // BUY + SL-LMT: trigger must be greater than LTP and less
                                                                        // than or equal to the limit price.
                                                                        if (SafeParse.toDouble(triggerPriceCtrl.text) <
                                                                            SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be greater than LTP");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be lesser than lower circuit limit of ${widget.scripInfo.lc}");
                                                                        } else if (SafeParse.toDouble(ordPrice) < SafeParse.toDouble(triggerPriceCtrl.text)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be less than price");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be greater than upper circuit limit of ${widget.scripInfo.uc}");
                                                                        } else {
                                                                          modifyOrder();
                                                                        }
                                                                      }
                                                                    } else {
                                                                      // SELL + SL-MKT: Trigger should be less than LTP
                                                                      if (prcType == "SL-MKT") {
                                                                        if (SafeParse.toDouble(triggerPriceCtrl.text) >
                                                                            SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be lesser than LTP");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be lesser than lower circuit limit of ${widget.scripInfo.lc}");
                                                                        } else {
                                                                          modifyOrder();
                                                                        }
                                                                      } else {
                                                                        // SELL + SL-LMT: trigger must be lesser than LTP and greater
                                                                        // than or equal to the limit price.
                                                                        if (SafeParse.toDouble(triggerPriceCtrl.text) >
                                                                            SafeParse.toDouble(widget.orderArg.ltp)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be lesser than LTP");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) > SafeParse.toDouble(widget.scripInfo.uc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be greater than upper circuit limit of ${widget.scripInfo.uc}");
                                                                        } else if (SafeParse.toDouble(ordPrice) > SafeParse.toDouble(triggerPriceCtrl.text)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger should be greater than price");
                                                                        } else if (_hasValidCircuitBreakerValues &&
                                                                            SafeParse.toDouble(triggerPriceCtrl.text) < SafeParse.toDouble(widget.scripInfo.lc)) {
                                                                          ResponsiveSnackBar.showWarning(
                                                                              context,
                                                                              "Trigger can not be lesser than lower circuit limit of ${widget.scripInfo.lc}");
                                                                        } else {
                                                                          modifyOrder();
                                                                        }
                                                                      }
                                                                    }
                                                                  }
                                                                } else if (widget
                                                                        .modifyOrderArgs
                                                                        .sPrdtAli ==
                                                                    "BO") {
                                                                  if (stopLossCtrl
                                                                          .text
                                                                          .isEmpty ||
                                                                      targetCtrl
                                                                          .text
                                                                          .isEmpty) {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        "${stopLossCtrl.text.isEmpty ? "Stoploss" : "Target"} can not be empty");
                                                                  } else {
                                                                    modifyOrder();
                                                                  }
                                                                } else if (widget
                                                                        .modifyOrderArgs
                                                                        .sPrdtAli ==
                                                                    "CO") {
                                                                  if (stopLossCtrl
                                                                      .text
                                                                      .isEmpty) {
                                                                    ResponsiveSnackBar.showWarning(
                                                                        context,
                                                                        " Stoploss can not be empty");
                                                                  } else {
                                                                    modifyOrder();
                                                                  }
                                                                } else {
                                                                  modifyOrder();
                                                                }
                                                              }
                                                            },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 10),
                                                          minimumSize: const Size(
                                                              double.infinity,
                                                              45),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5),
                                                          ),
                                                          backgroundColor: isBuy
                                                              ? resolveThemeColor(context,
                                                                  dark: MyntColors.secondary,
                                                                  light: MyntColors.primary)
                                                              : resolveThemeColor(context,
                                                                  dark: MyntColors.errorDark,
                                                                  light: MyntColors.tertiary)
                                                          // shape: const StadiumBorder()
                                                          ),
                                                  child: orderProvide
                                                          .orderloader
                                                      ? SizedBox(
                                                          width: 18,
                                                          height: 20,
                                                          child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: Colors.white),
                                                        )
                                                      : TextWidget.subText(
                                                          text: "Modify Order",
                                                          color:
                                                              Colors.white,
                                                          fw: 2,
                                                          theme:
                                                              theme.isDarkMode)

                                                  // Text(, style: textStyle(theme.isDarkMode ? colors.colorBlack : colors.colorWhite, 14, FontWeight.w600))

                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (defaultTargetPlatform ==
                                      TargetPlatform.iOS)
                                    const SizedBox(height: 18)
                                ])),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  headerTitleText(String text, ThemesProvider theme) {
    return Text(
      text,
      style: WebTextStyles.formLabel(
        isDarkTheme: theme.isDarkMode,
        color: theme.isDarkMode
            ? MyntColors.textPrimaryDark
            : MyntColors.textPrimary,
      ),
    );
  }

  TextStyle textStyle(Color color, double fontSize, fWeight) {
    return dysInter(
        textStyle:
            TextStyle(fontWeight: fWeight, color: color, fontSize: fontSize));
  }

  Padding triggerOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Row(children: [
          headerTitleText("Trigger", theme),
          // Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
          //                                                         dark: MyntColors.textPrimaryDark,
          //                                                         light: MyntColors.textPrimary))),
          ],),
          const SizedBox(height: 10),
          Focus(
            onKeyEvent: (node, event) => _handlePriceArrowKey(event, triggerPriceCtrl),
            child: SizedBox(
              height: 40,
              width: 200,
              child: MyntTextField(
                  backgroundColor: theme.isDarkMode
                      ? colors.darkGrey
                      : const Color(0xffF1F3F8),
                  placeholder: "0.00",
                  placeholderStyle: WebTextStyles.formInput(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textSecondary
                        : MyntColors.textSecondary,
                  ),
                  inputFormatters: [
                    _rejectIfNoMatch(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  onChanged: (value) {
                    double inputPrice = double.tryParse(value) ?? 0;
                    if (value.isEmpty || inputPrice <= 0) {
                      ResponsiveSnackBar.showWarning(context,
                          "Trigger can not be ${inputPrice <= 0 ? 'zero' : 'empty'}");
                    }
                  },
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textStyle: WebTextStyles.formInput(
                    isDarkTheme: theme.isDarkMode,
                    color: theme.isDarkMode
                        ? MyntColors.textPrimaryDark
                        : MyntColors.textPrimary,
                  ),
                  controller: triggerPriceCtrl,
                  textAlign: TextAlign.start)),
          )
        ],
      ),
    );
  }

  Padding stopLossOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          prcType == "SL-LMT" ? const SizedBox(height: 10) : Container(),
          if (widget.modifyOrderArgs.sPrdtAli == "BO" &&
              widget.modifyOrderArgs.bpprc != null) ...[
            Row(children: [
            headerTitleText("Target", theme),
            Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary))),
          ],),
            const SizedBox(height: 10),
            SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                    backgroundColor: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    placeholder: "0.00",
                    onChanged: (value) {
                      double inputPrice = double.tryParse(value) ?? 0;

                      if (value.isNotEmpty && inputPrice > 0) {
                        final regex = RegExp(r'^(\d+)?(\.\d{0,2})?$');
                        if (!regex.hasMatch(value)) {
                          targetCtrl.text = value.substring(
                              0,
                              value.length -
                                  1); // Revert to previous valid input
                          targetCtrl.selection = TextSelection.collapsed(
                              offset: targetCtrl
                                  .text.length); // Keep cursor at the end
                        }
                      }

                      if (value.isEmpty || inputPrice <= 0) {
                        ResponsiveSnackBar.showWarning(context,
                            "Target can not be ${inputPrice <= 0 ? 'zero' : 'empty'}");
                      }
                    },
                    placeholderStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondary
                          : MyntColors.textSecondary,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                    ),
                    // prefixIcon: Container(
                    //   margin: const EdgeInsets.all(12),
                    //   decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: theme.isDarkMode ? const Color(0xff555555) : colors.colorWhite),
                    //   child: SvgPicture.asset(color: theme.isDarkMode ? colors.colorWhite : colors.colorGrey, assets.ruppeIcon, fit: BoxFit.scaleDown),
                    // ),
                    controller: targetCtrl,
                    textAlign: TextAlign.start)),
            const SizedBox(height: 10),
          ],
          if ((widget.modifyOrderArgs.sPrdtAli == "CO" ||
                  widget.modifyOrderArgs.sPrdtAli == "BO") &&
              widget.modifyOrderArgs.blprc != null) ...[
            Row(children: [
            headerTitleText("Stoploss", theme),
            Text(" (in Rs)", style: WebTextStyles.para(isDarkTheme: theme.isDarkMode, color: resolveThemeColor(context,
                                                                  dark: MyntColors.textPrimaryDark,
                                                                  light: MyntColors.textPrimary))),
          ],),
            const SizedBox(height: 10),
            SizedBox(
                height: 40,
                width: 200,
                child: MyntTextField(
                    backgroundColor: theme.isDarkMode
                        ? colors.darkGrey
                        : const Color(0xffF1F3F8),
                    onChanged: (value) {
                      double inputPrice = double.tryParse(value) ?? 0;

                      if (value.isNotEmpty && inputPrice > 0) {
                        final regex = RegExp(r'^(\d+)?(\.\d{0,2})?$');
                        if (!regex.hasMatch(value)) {
                          stopLossCtrl.text = value.substring(
                              0,
                              value.length -
                                  1); // Revert to previous valid input
                          stopLossCtrl.selection = TextSelection.collapsed(
                              offset: stopLossCtrl
                                  .text.length); // Keep cursor at the end
                        }
                      }
                      if (value.isEmpty || inputPrice <= 0) {
                        ResponsiveSnackBar.showWarning(context,
                            "Stoploss can not be ${inputPrice <= 0 ? 'zero' : 'empty'}");
                      }
                    },
                    placeholder: "0.00",
                    placeholderStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textSecondary
                          : MyntColors.textSecondary,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textStyle: WebTextStyles.formInput(
                      isDarkTheme: theme.isDarkMode,
                      color: theme.isDarkMode
                          ? MyntColors.textPrimaryDark
                          : MyntColors.textPrimary,
                    ),
                    // prefixIcon: Container(
                    //   margin: const EdgeInsets.all(12),
                    //   decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: theme.isDarkMode ? const Color(0xff555555) : colors.colorWhite),
                    //   child: SvgPicture.asset(color: theme.isDarkMode ? colors.colorWhite : colors.colorGrey, assets.ruppeIcon, fit: BoxFit.scaleDown),
                    // ),
                    controller: stopLossCtrl,
                    textAlign: TextAlign.start)),
          ],
        ],
      ),
    );
  }

  Padding marketProtectionDisclaimer(ThemesProvider theme, BuildContext context,
      ScripInfoModel scripInfo, String marketProtection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Market Protected by",
                  style: WebTextStyles.sub(
                    isDarkTheme: theme.isDarkMode,
                    color: resolveThemeColor(context,
                        dark: MyntColors.primaryDark,
                        light: MyntColors.primary),
                  )),
              InkWell(
                // borderRadius: BorderRadius.circular(8),
                onTap: () {
                  ModifyPlaceOrderScreenWeb.showDialogOverlay(
                    context: context,
                    builder: (BuildContext dialogContext, VoidCallback closeDialog) {
                      return AlertDialog(
                              backgroundColor: resolveThemeColor(context,
                                  dark: MyntColors.cardDark,
                                  light: const Color(0xFFF1F3F8)),
                              titlePadding: const EdgeInsets.only(
                                  left: 4, right: 4, top: 0, bottom: 0),
                              shape: const RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              scrollable: true,
                              contentPadding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 10, top: 0,
                              ),
                              actionsPadding: const EdgeInsets.only(
                                  bottom: 16, right: 16, left: 16, top: 8),
                              insetPadding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 12),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () async {
                                        await Future.delayed(
                                            const Duration(milliseconds: 150));
                                        closeDialog();
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      splashColor: theme.isDarkMode
                                          ? colors.splashColorDark
                                          : colors.splashColorLight,
                                      highlightColor: theme.isDarkMode
                                          ? colors.splashColorDark
                                          : colors.splashColorLight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 22,
                                          color: resolveThemeColor(context,
                                              dark: MyntColors.textSecondaryDark,
                                              light: MyntColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enter Market Protection',
                            textAlign: TextAlign.start,
                                      style: WebTextStyles.formLabel(
                                        isDarkTheme: theme.isDarkMode,
                                        color: resolveThemeColor(context,
                                            dark: MyntColors.textPrimaryDark,
                                            light: MyntColors.textPrimary),
                                      )),
                                  const SizedBox(height: 10),
                            MyntTextField(
                              backgroundColor: theme.isDarkMode
                                          ? colors.darkGrey
                                          : const Color(0xffF1F3F8),
                                      inputFormatters: [
                                        _rejectIfNoMatch(
                                          RegExp(r'^(0|[1-9][0-9]{0,19})$'),
                                        ),
                                      ],
                              onChanged: (value) {
                                setState(() {
                                  if (value.isEmpty) {
                                    ResponsiveSnackBar.showWarning(context,
                                        "Market Protection can not be empty");
                                  }
                                  if (value.isNotEmpty) {
                                    String newValue =
                                        value.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (newValue != value) {
                                      mktProtCtrl.text = newValue;
                                      mktProtCtrl.selection =
                                          TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: newValue.length));
                                    }
                                    if (int.parse(value) > 20) {
                                      mktProtCtrl.text = "20";
                                      ResponsiveSnackBar.showWarning(context,
                                          "can't enter greater than 20% of Market Protection");
                                    } else if (int.parse(value) < 1) {
                                      mktProtCtrl.text = "1";
                                      ResponsiveSnackBar.showWarning(context,
                                          "can't enter less than 1% of Market Protection");
                                    }
                                  }
                                });
                              },
                              keyboardType: TextInputType.number,
                                      textStyle: WebTextStyles.title(
                                        isDarkTheme: theme.isDarkMode,
                                        color: theme.isDarkMode
                                            ? MyntColors.textPrimaryDark
                                            : MyntColors.textPrimary,
                                      ),
                                      controller: mktProtCtrl,
                                      leadingWidget: Container(
                                        margin: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            color: theme.isDarkMode
                                                ? const Color(0xff555555)
                                                : MyntColors.backgroundColor),
                                        child: SvgPicture.asset(
                                            color: theme.isDarkMode
                                                ? MyntColors.textPrimaryDark
                                                : MyntColors.icon,
                                            assets.precentIcon,
                                            fit: BoxFit.scaleDown),
                                      ),
                                      textAlign: TextAlign.start,
                                      placeholder: "Add Market Protection %",
                                      placeholderStyle: WebTextStyles.formLabel(
                                        isDarkTheme: theme.isDarkMode,
                                        color: (theme.isDarkMode
                                                ? MyntColors.textSecondaryDark
                                                : MyntColors.textSecondary)
                                            .withValues(alpha: 0.5),
                                      ),
                            ),
                          ],
                        ),

                        actions: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                updatePriceType();
                                closeDialog();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 45), // width, height
                                side: BorderSide(
                                    color: resolveThemeColor(context,
                                        dark: MyntColors.cardBorderDark,
                                        light: colors.btnOutlinedBorder)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                backgroundColor: resolveThemeColor(context,
                                    dark: MyntColors.secondary,
                                    light: MyntColors.primary),
                              ),
                              child: TextWidget.subText(
                                  text: "Ok",
                                  color: Colors.white,
                                  theme: theme.isDarkMode,
                                  fw: 2),
                            ),
                          ),
                        ],

                        //                         actions: [
                        //   TextButton(
                        //     onPressed: () => Navigator.of(context).pop(),
                        //     child: const Text('Cancel'),
                        //   ),
                        //   TextButton(
                        //     onPressed: () {
                        //       Navigator.of(context).pop();
                        //     },
                        //     child: const Text('OK'),
                        //   ),
                        // ],
                      );
                    },
                  );
                },
                child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 2), // 👈 GAP between text & underline
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          "$marketProtection %",
                          style: WebTextStyles.para(
                            isDarkTheme: theme.isDarkMode,
                            color: resolveThemeColor(context, dark: MyntColors.primaryDark, light: MyntColors.primary),
                            fontWeight: WebFonts.semiBold,
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
          // const SizedBox(height: 4),
          // Text(
          //     "I agreed the trigger executions are not guaranteed. ",
          //   style: textStyle(
          //     theme.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
          //     13,
          //     FontWeight.w400
          //   ),
          // ),
        ],
      ),
    );
  }

  void marginUpdate() {
    OrderMarginInput input = OrderMarginInput(
        exch: "${widget.scripInfo.exch}",
        prc: priceCtrl.text,
        prctyp: prcType,
        prd: widget.modifyOrderArgs.prd!,
        qty: widget.scripInfo.exch == 'MCX'
            ? (double.parse(qtyCtrl.text).toInt() * lotSize).toString()
            : qtyCtrl.text,
        rorgprc: '0',
        rorgqty: '0',
        trantype: widget.modifyOrderArgs.trantype!,
        tsym: "${widget.scripInfo.tsym}",
        blprc: '',
        bpprc: '',
        trgprc: prcType == "SL-LMT" || prcType == "SL-MKT"
            ? triggerPriceCtrl.text
            : "");
    ref.read(orderProvider).fetchOrderMargin(input, context);
    BrokerageInput brokerageInput = BrokerageInput(
        exch: "${widget.scripInfo.exch}",
        prc: priceCtrl.text,
        prd: widget.modifyOrderArgs.prd!,
        qty: widget.scripInfo.exch == 'MCX'
            ? (double.parse(qtyCtrl.text).toInt() * lotSize).toString()
            : qtyCtrl.text,
        trantype: widget.modifyOrderArgs.trantype!,
        tsym: "${widget.scripInfo.tsym}");
    ref.read(orderProvider).fetchGetBrokerage(brokerageInput, context);
  }

  modifyOrder() async {
    bool placeorder = true;
    if (prcType == "LMT" || prcType == "SL-LMT") {
      String r = roundOffWithInterval(double.parse(priceCtrl.text), tik)
          .toStringAsFixed(2);
      if (double.parse(priceCtrl.text) != double.parse(r)) {
        placeorder = false;
        ResponsiveSnackBar.showWarning(
            context, "Price should be multiple of tick size $tik => $r");
      }
    }
    if (placeorder && (prcType == "SL-LMT" || prcType == "SL-MKT")) {
      String r = roundOffWithInterval(double.parse(triggerPriceCtrl.text), tik)
          .toStringAsFixed(2);
      if (double.parse(triggerPriceCtrl.text) != double.parse(r)) {
        placeorder = false;
        ResponsiveSnackBar.showWarning(
            context, "Trigger should be multiple of tick size $tik => $r");
      }
    }
    int q = ((int.parse(qtyCtrl.text) / lotSize).round() * lotSize);
    if (int.parse(qtyCtrl.text) != q && widget.scripInfo.exch != 'MCX') {
      placeorder = false;
      ResponsiveSnackBar.showWarning(
          context, "Quantity should be multiple of lot size $lotSize => $q");
    }
    if (placeorder && frezQty > lotSize) {
      final bool isMcx = widget.scripInfo.exch == "MCX";
      final int finalUnits = isMcx
          ? int.parse(qtyCtrl.text) * lotSize
          : int.parse(qtyCtrl.text);
      if (finalUnits > frezQty) {
        placeorder = false;
        ResponsiveSnackBar.showWarning(
            context,
            isMcx
                ? "Maximum Allowed Lots: ${frezQty ~/ lotSize}"
                : "Maximum Allowed Quantity $frezQty");
      }
    }
    if (placeorder) {
      // Get close notifier before async call
      final closeNotifier = _ModifyPlaceOrderDialogCloseNotifier.of(context);

      ref.read(orderProvider).setOrderloader(true);
      ModifyOrderInput input = ModifyOrderInput(
          dscqty: widget.modifyOrderArgs.dscqty ?? "0",
          token: widget.modifyOrderArgs.token!,
          exch: widget.modifyOrderArgs.exch!,
          mktProt: mktProtCtrl.text.isEmpty
              ? widget.modifyOrderArgs.mktProtection ?? ""
              : mktProtCtrl.text,
          orderNum: widget.modifyOrderArgs.norenordno!,
          prc:
              price, //prcType == "LMT" || prcType == "SL-LMT" ? priceCtrl.text : "0",
          prd: widget.modifyOrderArgs.prd!,
          trantype: widget.modifyOrderArgs.trantype!,
          prctyp: prcType,
          blprc: stopLossCtrl.text,
          bpprc: targetCtrl.text,
          qty: int.parse(widget.modifyOrderArgs.qty ?? "0") ==
                  (int.parse(qtyCtrl.text) +
                      int.parse((widget.modifyOrderArgs.fillshares ?? "0")))
              ? widget.modifyOrderArgs.exch == 'MCX'
                  ? (int.parse(widget.modifyOrderArgs.qty.toString()) * lotSize)
                      .toString()
                  : (widget.modifyOrderArgs.qty.toString())
              : widget.modifyOrderArgs.exch == 'MCX'
                  ? ((int.parse(qtyCtrl.text) +
                              int.parse(
                                  (widget.modifyOrderArgs.fillshares ?? "0"))) *
                          lotSize)
                      .toString()
                  : (int.parse(qtyCtrl.text) +
                          int.parse(widget.modifyOrderArgs.fillshares ?? "0"))
                      .toString(),
          ret: validity,
          trgprc: triggerPriceCtrl.text,
          tsym: widget.modifyOrderArgs.tsym!);
      await ref.read(orderProvider).fetchModifyOrder(input, context);
      ref.read(orderProvider).setOrderloader(false);

      // Close dialog on successful modification
      final modifyOrderModel = ref.read(orderProvider).modifyOrderModel;
      if (modifyOrderModel != null &&
          modifyOrderModel.stat == "Ok" &&
          closeNotifier != null) {
        closeNotifier.onClose();
      }
    }
  }

  void updatePriceType() {
    // CO/BO stoploss must always be SL-Limit — never SL-Market (mirrors Place
    // Order's updatePriceType). This also closes the "Stoploss order" checkbox
    // bypass: uncheck SL -> switch to Market -> re-check SL would otherwise land
    // on SL-MKT for a CO/BO order.
    if (!_isBOCOOrderEnabled && _isStoplossOrder && _isMarketOrder) {
      prcType = "SL-MKT";
    } else if ((_isStoplossOrder && !_isMarketOrder) ||
        (_isBOCOOrderEnabled && _isStoplossOrder && _isMarketOrder)) {
      prcType = "SL-LMT";
    } else if (_isMarketOrder) {
      prcType = "MKT";
    } else {
      prcType = "LMT";
    }

    // Update price controller based on type
    if (prcType == "MKT" || prcType == "SL-MKT") {
      double ltp = (double.parse("${widget.orderArg.ltp}") *
              double.parse(mktProtCtrl.text.isEmpty ? "0" : mktProtCtrl.text)) /
          100;
      if (widget.modifyOrderArgs.trantype == "B") {
        price = (double.parse("${widget.orderArg.ltp ?? 0.00}") + ltp)
            .toStringAsFixed(2);
      } else {
        price = (double.parse("${widget.orderArg.ltp ?? 0.00}") - ltp)
            .toStringAsFixed(2);
      }
      priceCtrl.text = "Market";
    } else if (priceCtrl.text == "Market") {
      priceCtrl.text = (widget.modifyOrderArgs.prc?.isNotEmpty ?? false) &&
              double.tryParse(widget.modifyOrderArgs.prc!) != null &&
              double.tryParse(widget.modifyOrderArgs.prc!)! > 0
          ? "${widget.modifyOrderArgs.prc}"
          : "${widget.orderArg.ltp}";
      price = priceCtrl.text;
    }
  }

  Padding addValidityAndDisclosedQtyOption(
      ThemesProvider theme, BuildContext context, ScripInfoModel scripInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                headerTitleText("Validity", theme),
                const SizedBox(height: 10),
                SizedBox(
                    height: 38,
                    child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          return ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  validity = validityTypes[index];
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  minimumSize: const Size(0, 0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  backgroundColor: validity == validityTypes[index]
                                      ? resolveThemeColor(context,
                                          dark: MyntColors.secondary,
                                          light: MyntColors.primary)
                                      : resolveThemeColor(context,
                                          dark: colors.darkGrey,
                                          light: const Color(0xffF1F3F8)),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5)),
                                  )),
                              child: Text(
                                validityTypes[index],
                                style: WebTextStyles.sub(
                                    color: validity == validityTypes[index]
                                        ? Colors.white
                                        : resolveThemeColor(context,
                                            dark: MyntColors.textSecondaryDark,
                                            light: MyntColors.textSecondary),
                                    isDarkTheme: theme.isDarkMode,
                                    fontWeight: validity == validityTypes[index]
                                        ? FontWeight.w500
                                        : FontWeight.w400),
                              ));
                        },
                        separatorBuilder: (context, index) {
                          return const SizedBox(width: 8);
                        },
                        itemCount: widget.orderArg.exchange == "BSE" ||
                                widget.orderArg.exchange == "BFO"
                            ? validityTypes.length
                            : 2))
              ])),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitleText("Disclosed Qty", theme),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  width: 200,
                  child: MyntTextField(
                      backgroundColor: theme.isDarkMode
                          ? colors.darkGrey
                          : const Color(0xffF1F3F8),
                      placeholder: "0",
                      placeholderStyle: WebTextStyles.formInput(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? MyntColors.textSecondary
                            : MyntColors.textSecondary,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      keyboardType: TextInputType.number,
                      textStyle: WebTextStyles.formInput(
                        isDarkTheme: theme.isDarkMode,
                        color: theme.isDarkMode
                            ? MyntColors.textPrimaryDark
                            : MyntColors.textPrimary,
                      ),
                      controller: discQtyCtrl,
                      textAlign: TextAlign.start),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableModifyPlaceOrderScreenDialog extends ConsumerStatefulWidget {
  final OrderBookModel modifyOrderArgs;
  final ScripInfoModel scripInfo;
  final OrderScreenArgs orderArg;
  final Offset initialPosition;
  final Function(Offset) onPositionChanged;
  final VoidCallback onClose;

  const _DraggableModifyPlaceOrderScreenDialog({
    required this.modifyOrderArgs,
    required this.scripInfo,
    required this.orderArg,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onClose,
  });

  @override
  ConsumerState<_DraggableModifyPlaceOrderScreenDialog> createState() =>
      _DraggableModifyPlaceOrderScreenDialogState();
}

class _DraggableModifyPlaceOrderScreenDialogState
    extends ConsumerState<_DraggableModifyPlaceOrderScreenDialog> {
  late Offset _position;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  // Directly disable all chart iframes and reset cursor (like chart's onExit)
  void _disableAllChartIframes() {
    try {
      final iframes = html.document.querySelectorAll('iframe');
      for (var iframe in iframes) {
        if (iframe is html.IFrameElement && iframe.id.contains('chart-iframe')) {
          iframe.style.pointerEvents = 'none';
        }
      }
      // Also reset cursor on iframes to default
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
        }
      }
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
    final theme = ref.watch(themeProvider);
    final screenSize = MediaQuery.of(context).size;

    // Constrain position to screen bounds
    const dialogWidth = 450.0;
    final dialogHeight = screenSize.height * 0.7;
    final constrainedPosition = Offset(
      _position.dx.clamp(0, screenSize.width - dialogWidth),
      _position.dy.clamp(0, screenSize.height - dialogHeight),
    );

    return Stack(
      children: [
        // Actual dialog
        Positioned(
          left: constrainedPosition.dx,
          top: constrainedPosition.dy,
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
                  onTap: () {}, // Prevent tap from propagating to background
                  child: Material(
                    elevation: _isDragging ? 16 : 8,
                    borderRadius: BorderRadius.circular(5),
                    color: resolveThemeColor(context, dark: MyntColors.backgroundColorDark, light: MyntColors.backgroundColor),
                    child: Container(
                      width: dialogWidth,
                      height: dialogHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: theme.isDarkMode
                              ? MyntColors.dividerDark
                              : MyntColors.divider,
                        ),
                      ),
                      child: _ModifyPlaceOrderDialogCloseNotifier(
                        onClose: widget.onClose,
                        child: _ModifyPlaceOrderDialogDragNotifier(
                          onPanStart: (details) {
                            if (mounted) {
                              setState(() {
                                _isDragging = true;
                              });
                            }
                          },
                          onPanUpdate: (details) {
                            if (mounted) {
                              setState(() {
                                _position = Offset(
                                  _position.dx + details.delta.dx,
                                  _position.dy + details.delta.dy,
                                );
                              });
                              // Safely call onPositionChanged
                              try {
                                widget.onPositionChanged(_position);
                              } catch (e) {
                              }
                            }
                          },
                          onPanEnd: (details) {
                            if (mounted) {
                              setState(() {
                                _isDragging = false;
                              });
                            }
                          },
                          isDragging: _isDragging,
                          child: ModifyPlaceOrderScreenWeb(
                            modifyOrderArgs: widget.modifyOrderArgs,
                            scripInfo: widget.scripInfo,
                            orderArg: widget.orderArg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
